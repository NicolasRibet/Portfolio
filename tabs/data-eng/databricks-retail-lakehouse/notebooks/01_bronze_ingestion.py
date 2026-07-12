# Databricks notebook source
from datetime import datetime
from pyspark.sql import functions as F
from pyspark.sql.types import StringType, StructField, StructType

TRANSACTIONS_PATH = "/Volumes/retail_portfolio/landing/raw_files/transactions"
USERS_PATH = "/Volumes/retail_portfolio/landing/raw_files/users"

transaction_schema = StructType([
    StructField("transaction_id", StringType()),
    StructField("transaction_date", StringType()),
    StructField("customer_id", StringType()),
    StructField("product_id", StringType()),
    StructField("product_name", StringType()),
    StructField("category", StringType()),
    StructField("quantity", StringType()),
    StructField("unit_price", StringType()),
    StructField("total_amount", StringType()),
    StructField("store_location", StringType()),
    StructField("payment_method", StringType()),
])

user_schema = StructType([
    StructField("user_id", StringType()),
    StructField("first_name", StringType()),
    StructField("last_name", StringType()),
    StructField("email", StringType()),
    StructField("signup_date", StringType()),
    StructField("country", StringType()),
    StructField("referral_source", StringType()),
])


def processed_files(table_name: str) -> set[str]:
    if not spark.catalog.tableExists(table_name):
        return set()
    return {r.source_file for r in spark.table(table_name).select("source_file").distinct().collect()}


def ingest_csv_incrementally(source_path: str, schema: StructType, target_table: str, pipeline_name: str) -> None:
    available = [f.path for f in dbutils.fs.ls(source_path) if f.path.lower().endswith(".csv")]
    done = processed_files(target_table)
    new_files = [p for p in available if p.rsplit("/", 1)[-1] not in done]

    if not new_files:
        print(f"No new files for {target_table}")
        return

    df = (
        spark.read.option("header", True).schema(schema).csv(new_files)
        .withColumn("source_file", F.regexp_extract(F.input_file_name(), r"([^/]+$)", 1))
        .withColumn("source_file_path", F.input_file_name())
        .withColumn("ingested_at", F.current_timestamp())
        .withColumn("ingestion_date", F.current_date())
    )

    row_count = df.count()
    df.write.format("delta").mode("append").saveAsTable(target_table)

    log = spark.createDataFrame([(
        pipeline_name,
        ", ".join(p.rsplit("/", 1)[-1] for p in new_files),
        target_table,
        row_count,
        "SUCCESS",
        datetime.now(),
    )], "pipeline_name string, source_file string, target_table string, rows_written long, ingestion_status string, ingestion_timestamp timestamp")

    log.write.format("delta").mode("append").saveAsTable("retail_portfolio.monitoring.ingestion_log")
    print(f"Loaded {row_count} rows from {len(new_files)} file(s) into {target_table}")


# COMMAND ----------
ingest_csv_incrementally(
    TRANSACTIONS_PATH,
    transaction_schema,
    "retail_portfolio.bronze.transactions_raw",
    "bronze_transactions_ingestion",
)

# COMMAND ----------
ingest_csv_incrementally(
    USERS_PATH,
    user_schema,
    "retail_portfolio.bronze.users_raw",
    "bronze_users_ingestion",
)

# COMMAND ----------
display(spark.table("retail_portfolio.monitoring.ingestion_log").orderBy(F.col("ingestion_timestamp").desc()))
