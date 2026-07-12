# Databricks notebook source
from pyspark.sql import functions as F
from pyspark.sql.window import Window

# Transactions
bronze_tx = spark.table("retail_portfolio.bronze.transactions_raw")

tx = (
    bronze_tx
    .withColumn("transaction_id_clean", F.trim("transaction_id"))
    .withColumn("customer_id_clean", F.trim("customer_id"))
    .withColumn("product_id_clean", F.trim("product_id"))
    .withColumn("product_name_clean", F.initcap(F.regexp_replace(F.trim("product_name"), r"\s+", " ")))
    .withColumn("category_clean", F.initcap(F.regexp_replace(F.trim("category"), r"\s+", " ")))
    .withColumn("store_location_clean", F.initcap(F.regexp_replace(F.trim("store_location"), r"\s+", " ")))
    .withColumn("payment_method_clean", F.initcap(F.regexp_replace(F.trim("payment_method"), r"\s+", " ")))
    .withColumn("transaction_timestamp", F.to_timestamp("transaction_date", "yyyy-MM-dd HH:mm:ss"))
    .withColumn("quantity_clean", F.col("quantity").cast("int"))
    .withColumn("unit_price_clean", F.col("unit_price").cast("decimal(12,2)"))
    .withColumn("total_amount_clean", F.col("total_amount").cast("decimal(12,2)"))
    .withColumn("calculated_total", F.round(F.col("quantity_clean") * F.col("unit_price_clean"), 2))
    .withColumn(
        "validation_errors",
        F.array_compact(F.array(
            F.when(~F.col("transaction_id_clean").rlike(r"^TXN[0-9]+$"), F.lit("INVALID_TRANSACTION_ID")),
            F.when(~F.col("customer_id_clean").rlike(r"^C[0-9]+$"), F.lit("INVALID_CUSTOMER_ID")),
            F.when(~F.col("product_id_clean").rlike(r"^P[0-9]+$"), F.lit("INVALID_PRODUCT_ID")),
            F.when(F.col("transaction_timestamp").isNull(), F.lit("INVALID_TIMESTAMP")),
            F.when(F.col("quantity_clean") <= 0, F.lit("INVALID_QUANTITY")),
            F.when(F.col("unit_price_clean") < 0, F.lit("INVALID_UNIT_PRICE")),
            F.when(F.abs(F.col("total_amount_clean") - F.col("calculated_total")) > 0.01, F.lit("TOTAL_AMOUNT_MISMATCH")),
        )),
    )
    .withColumn("is_valid", F.size("validation_errors") == 0)
)

tx_window = Window.partitionBy("transaction_id_clean").orderBy(F.col("ingested_at").desc(), F.col("source_file").desc())
tx = tx.withColumn("duplicate_rank", F.row_number().over(tx_window))

silver_tx = (
    tx.filter(F.col("is_valid") & (F.col("duplicate_rank") == 1))
    .select(
        F.col("transaction_id_clean").alias("transaction_id"),
        "transaction_timestamp",
        F.to_date("transaction_timestamp").alias("transaction_date"),
        F.col("customer_id_clean").alias("customer_id"),
        F.col("product_id_clean").alias("product_id"),
        F.col("product_name_clean").alias("product_name"),
        F.col("category_clean").alias("category"),
        F.col("quantity_clean").alias("quantity"),
        F.col("unit_price_clean").alias("unit_price"),
        F.col("total_amount_clean").alias("total_amount"),
        F.col("store_location_clean").alias("store_location"),
        F.col("payment_method_clean").alias("payment_method"),
        "source_file", "ingested_at",
    )
)

silver_tx.write.format("delta").mode("overwrite").option("overwriteSchema", "true").saveAsTable("retail_portfolio.silver.transactions")
(
    tx.filter((~F.col("is_valid")) | (F.col("duplicate_rank") > 1))
    .withColumn("quarantine_reason", F.when(F.col("duplicate_rank") > 1, F.array_union("validation_errors", F.array(F.lit("DUPLICATE_TRANSACTION")))).otherwise(F.col("validation_errors")))
    .write.format("delta").mode("overwrite").option("overwriteSchema", "true")
    .saveAsTable("retail_portfolio.silver.transactions_quarantine")
)

# COMMAND ----------
# Users
bronze_users = spark.table("retail_portfolio.bronze.users_raw")
users = (
    bronze_users
    .withColumn("user_id_clean", F.upper(F.trim("user_id")))
    .withColumn("first_name_clean", F.initcap(F.trim("first_name")))
    .withColumn("last_name_clean", F.initcap(F.trim("last_name")))
    .withColumn("email_clean", F.lower(F.trim("email")))
    .withColumn("country_clean", F.upper(F.trim("country")))
    .withColumn("referral_source_clean", F.lower(F.trim("referral_source")))
    .withColumn("signup_date_clean", F.coalesce(
        F.to_date("signup_date", "M/d/yy"),
        F.to_date("signup_date", "M.d.yy"),
        F.to_date("signup_date", "MM/dd/yy"),
        F.to_date("signup_date", "MM.dd.yy"),
    ))
    .withColumn(
        "validation_errors",
        F.array_compact(F.array(
            F.when(~F.col("user_id_clean").rlike(r"^USR_[0-9]+$"), F.lit("INVALID_USER_ID")),
            F.when(~F.col("email_clean").rlike(r"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"), F.lit("INVALID_EMAIL")),
            F.when(F.col("signup_date_clean").isNull(), F.lit("INVALID_SIGNUP_DATE")),
            F.when(~F.col("country_clean").isin("US", "CA", "UK", "AU", "DE"), F.lit("INVALID_COUNTRY")),
            F.when(~F.col("referral_source_clean").isin("organic", "google_ads", "social_media", "referral", "partner"), F.lit("INVALID_REFERRAL_SOURCE")),
        )),
    )
    .withColumn("is_valid", F.size("validation_errors") == 0)
)

user_window = Window.partitionBy("user_id_clean").orderBy(F.col("signup_date_clean").isNotNull().desc(), F.col("ingested_at").desc())
users = users.withColumn("duplicate_rank", F.row_number().over(user_window))

silver_users = (
    users.filter(F.col("is_valid") & (F.col("duplicate_rank") == 1))
    .select(
        F.col("user_id_clean").alias("user_id"),
        F.col("first_name_clean").alias("first_name"),
        F.col("last_name_clean").alias("last_name"),
        F.concat_ws(" ", "first_name_clean", "last_name_clean").alias("full_name"),
        F.col("email_clean").alias("email"),
        F.col("signup_date_clean").alias("signup_date"),
        F.col("country_clean").alias("country"),
        F.col("referral_source_clean").alias("referral_source"),
        "source_file", "ingested_at",
    )
)

silver_users.write.format("delta").mode("overwrite").option("overwriteSchema", "true").saveAsTable("retail_portfolio.silver.users")
(
    users.filter((~F.col("is_valid")) | (F.col("duplicate_rank") > 1))
    .withColumn("quarantine_reason", F.when(F.col("duplicate_rank") > 1, F.array_union("validation_errors", F.array(F.lit("DUPLICATE_USER")))).otherwise(F.col("validation_errors")))
    .write.format("delta").mode("overwrite").option("overwriteSchema", "true")
    .saveAsTable("retail_portfolio.silver.users_quarantine")
)
