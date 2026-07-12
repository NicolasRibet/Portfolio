-- Databricks notebook source
SELECT 'Bronze transactions' AS dataset, COUNT(*) AS row_count
FROM retail_portfolio.bronze.transactions_raw
UNION ALL
SELECT 'Silver transactions', COUNT(*)
FROM retail_portfolio.silver.transactions
UNION ALL
SELECT 'Quarantined transactions', COUNT(*)
FROM retail_portfolio.silver.transactions_quarantine
UNION ALL
SELECT 'Bronze users', COUNT(*)
FROM retail_portfolio.bronze.users_raw
UNION ALL
SELECT 'Silver users', COUNT(*)
FROM retail_portfolio.silver.users
UNION ALL
SELECT 'Quarantined users', COUNT(*)
FROM retail_portfolio.silver.users_quarantine;

-- COMMAND ----------
SELECT test_name, table_name, test_category, observed_value, expected_value, test_status, tested_at
FROM retail_portfolio.monitoring.data_quality_results
QUALIFY ROW_NUMBER() OVER (PARTITION BY test_name ORDER BY tested_at DESC) = 1
ORDER BY test_status, test_name;

-- COMMAND ----------
SELECT pipeline_name, source_file, target_table, rows_written, ingestion_status, ingestion_timestamp
FROM retail_portfolio.monitoring.ingestion_log
ORDER BY ingestion_timestamp DESC;
