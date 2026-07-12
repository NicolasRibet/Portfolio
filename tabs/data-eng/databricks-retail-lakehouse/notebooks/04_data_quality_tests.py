# Databricks notebook source
from datetime import datetime
from uuid import uuid4
from pyspark.sql import functions as F

RUN_ID = str(uuid4())
results = []


def record(test_name, table_name, category, observed, expected, passed):
    results.append((
        RUN_ID,
        test_name,
        table_name,
        category,
        str(observed),
        str(expected),
        "PASS" if passed else "FAIL",
        datetime.now(),
    ))


def scalar(sql_text: str, column: str):
    return spark.sql(sql_text).first()[column]


# Uniqueness
row_count = scalar("SELECT COUNT(*) AS value FROM retail_portfolio.silver.transactions", "value")
distinct_count = scalar("SELECT COUNT(DISTINCT transaction_id) AS value FROM retail_portfolio.silver.transactions", "value")
record("transaction_id_is_unique", "retail_portfolio.silver.transactions", "uniqueness", row_count, distinct_count, row_count == distinct_count)

user_count = scalar("SELECT COUNT(*) AS value FROM retail_portfolio.silver.users", "value")
distinct_users = scalar("SELECT COUNT(DISTINCT user_id) AS value FROM retail_portfolio.silver.users", "value")
record("user_id_is_unique", "retail_portfolio.silver.users", "uniqueness", user_count, distinct_users, user_count == distinct_users)

# Completeness and validity
null_tx = scalar("""
SELECT COUNT(*) AS value FROM retail_portfolio.silver.transactions
WHERE transaction_id IS NULL OR transaction_timestamp IS NULL OR customer_id IS NULL
   OR product_id IS NULL OR quantity IS NULL OR unit_price IS NULL OR total_amount IS NULL
""", "value")
record("mandatory_transaction_fields_not_null", "retail_portfolio.silver.transactions", "completeness", null_tx, 0, null_tx == 0)

bad_amounts = scalar("""
SELECT COUNT(*) AS value FROM retail_portfolio.silver.transactions
WHERE ABS(total_amount - quantity * unit_price) > 0.01
""", "value")
record("transaction_amount_is_correct", "retail_portfolio.silver.transactions", "accuracy", bad_amounts, 0, bad_amounts == 0)

bad_quantities = scalar("SELECT COUNT(*) AS value FROM retail_portfolio.silver.transactions WHERE quantity <= 0", "value")
record("quantity_is_positive", "retail_portfolio.silver.transactions", "validity", bad_quantities, 0, bad_quantities == 0)

null_signup_dates = scalar("SELECT COUNT(*) AS value FROM retail_portfolio.silver.users WHERE signup_date IS NULL", "value")
record("signup_date_is_valid", "retail_portfolio.silver.users", "validity", null_signup_dates, 0, null_signup_dates == 0)

bad_countries = scalar("SELECT COUNT(*) AS value FROM retail_portfolio.silver.users WHERE country NOT IN ('US','CA','UK','AU','DE')", "value")
record("country_is_in_allowed_domain", "retail_portfolio.silver.users", "validity", bad_countries, 0, bad_countries == 0)

missing_products = scalar("""
SELECT COUNT(*) AS value
FROM retail_portfolio.gold.fact_sales f
LEFT JOIN retail_portfolio.gold.dim_product p ON f.product_id = p.product_id
WHERE p.product_id IS NULL
""", "value")
record("fact_products_have_dimension_records", "retail_portfolio.gold.fact_sales", "referential_integrity", missing_products, 0, missing_products == 0)

results_df = spark.createDataFrame(results, "run_id string, test_name string, table_name string, test_category string, observed_value string, expected_value string, test_status string, tested_at timestamp")
results_df.write.format("delta").mode("append").saveAsTable("retail_portfolio.monitoring.data_quality_results")
display(results_df)

failed = results_df.filter(F.col("test_status") == "FAIL").count()
if failed:
    raise RuntimeError(f"{failed} data-quality test(s) failed in run {RUN_ID}")
print(f"All tests passed for run {RUN_ID}")
