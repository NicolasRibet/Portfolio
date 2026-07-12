-- Databricks notebook source
-- Retail Lakehouse Analytics Pipeline
-- Creates the Unity Catalog objects used by the project.

CREATE CATALOG IF NOT EXISTS retail_portfolio;

CREATE SCHEMA IF NOT EXISTS retail_portfolio.landing;
CREATE SCHEMA IF NOT EXISTS retail_portfolio.bronze;
CREATE SCHEMA IF NOT EXISTS retail_portfolio.silver;
CREATE SCHEMA IF NOT EXISTS retail_portfolio.gold;
CREATE SCHEMA IF NOT EXISTS retail_portfolio.monitoring;

-- COMMAND ----------

CREATE VOLUME IF NOT EXISTS retail_portfolio.landing.raw_files;

-- COMMAND ----------

CREATE TABLE IF NOT EXISTS retail_portfolio.monitoring.ingestion_log (
    pipeline_name STRING,
    source_file STRING,
    target_table STRING,
    rows_written BIGINT,
    ingestion_status STRING,
    ingestion_timestamp TIMESTAMP
)
USING DELTA;

-- COMMAND ----------

CREATE TABLE IF NOT EXISTS retail_portfolio.monitoring.data_quality_results (
    run_id STRING,
    test_name STRING,
    table_name STRING,
    test_category STRING,
    observed_value STRING,
    expected_value STRING,
    test_status STRING,
    tested_at TIMESTAMP
)
USING DELTA;

-- COMMAND ----------

SHOW SCHEMAS IN retail_portfolio;

-- COMMAND ----------

-- After running this notebook, create these directories in a Python cell
-- or through the Catalog Explorer UI:
--
-- dbutils.fs.mkdirs(
--     "/Volumes/retail_portfolio/landing/raw_files/transactions"
-- )
-- dbutils.fs.mkdirs(
--     "/Volumes/retail_portfolio/landing/raw_files/users"
-- )
