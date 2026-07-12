-- Databricks notebook source
CREATE OR REPLACE TABLE retail_portfolio.gold.dim_product USING DELTA AS
SELECT product_id, MAX(product_name) AS product_name, MAX(category) AS category,
       MAX(unit_price) AS current_unit_price
FROM retail_portfolio.silver.transactions
GROUP BY product_id;

-- COMMAND ----------
CREATE OR REPLACE TABLE retail_portfolio.gold.dim_store USING DELTA AS
SELECT DENSE_RANK() OVER (ORDER BY store_location) AS store_key, store_location
FROM (SELECT DISTINCT store_location FROM retail_portfolio.silver.transactions);

-- COMMAND ----------
CREATE OR REPLACE TABLE retail_portfolio.gold.dim_date USING DELTA AS
SELECT DISTINCT
  CAST(DATE_FORMAT(transaction_date, 'yyyyMMdd') AS INT) AS date_key,
  transaction_date AS full_date,
  YEAR(transaction_date) AS year,
  QUARTER(transaction_date) AS quarter,
  MONTH(transaction_date) AS month_number,
  DATE_FORMAT(transaction_date, 'MMMM') AS month_name,
  WEEKOFYEAR(transaction_date) AS week_of_year,
  DAY(transaction_date) AS day_of_month,
  DATE_FORMAT(transaction_date, 'EEEE') AS day_name,
  DAYOFWEEK(transaction_date) IN (1, 7) AS is_weekend
FROM retail_portfolio.silver.transactions;

-- COMMAND ----------
CREATE OR REPLACE TABLE retail_portfolio.gold.fact_sales USING DELTA AS
SELECT
  t.transaction_id,
  CAST(DATE_FORMAT(t.transaction_date, 'yyyyMMdd') AS INT) AS date_key,
  s.store_key,
  t.customer_id,
  t.product_id,
  t.transaction_timestamp,
  t.payment_method,
  t.quantity,
  t.unit_price,
  t.total_amount,
  t.total_amount - (t.quantity * t.unit_price) AS amount_variance
FROM retail_portfolio.silver.transactions t
LEFT JOIN retail_portfolio.gold.dim_store s
  ON t.store_location = s.store_location;

-- COMMAND ----------
CREATE OR REPLACE TABLE retail_portfolio.gold.daily_sales_summary USING DELTA AS
SELECT transaction_date,
       COUNT(DISTINCT transaction_id) AS transaction_count,
       COUNT(DISTINCT customer_id) AS unique_customers,
       SUM(quantity) AS units_sold,
       ROUND(SUM(total_amount), 2) AS gross_revenue,
       ROUND(AVG(total_amount), 2) AS average_order_value
FROM retail_portfolio.silver.transactions
GROUP BY transaction_date;

-- COMMAND ----------
CREATE OR REPLACE TABLE retail_portfolio.gold.product_performance USING DELTA AS
SELECT product_id, product_name, category,
       COUNT(DISTINCT transaction_id) AS transaction_count,
       SUM(quantity) AS units_sold,
       ROUND(SUM(total_amount), 2) AS gross_revenue,
       ROUND(AVG(unit_price), 2) AS average_unit_price,
       ROUND(SUM(total_amount) / SUM(SUM(total_amount)) OVER (), 4) AS revenue_share
FROM retail_portfolio.silver.transactions
GROUP BY product_id, product_name, category;

-- COMMAND ----------
CREATE OR REPLACE TABLE retail_portfolio.gold.store_performance USING DELTA AS
SELECT store_location,
       COUNT(DISTINCT transaction_id) AS transaction_count,
       COUNT(DISTINCT customer_id) AS unique_customers,
       SUM(quantity) AS units_sold,
       ROUND(SUM(total_amount), 2) AS gross_revenue,
       ROUND(AVG(total_amount), 2) AS average_order_value
FROM retail_portfolio.silver.transactions
GROUP BY store_location;

-- COMMAND ----------
CREATE OR REPLACE TABLE retail_portfolio.gold.payment_method_performance USING DELTA AS
SELECT payment_method,
       COUNT(DISTINCT transaction_id) AS transaction_count,
       ROUND(SUM(total_amount), 2) AS gross_revenue,
       ROUND(AVG(total_amount), 2) AS average_order_value,
       ROUND(COUNT(DISTINCT transaction_id) / SUM(COUNT(DISTINCT transaction_id)) OVER (), 4) AS transaction_share
FROM retail_portfolio.silver.transactions
GROUP BY payment_method;

-- COMMAND ----------
CREATE OR REPLACE TABLE retail_portfolio.gold.user_acquisition_summary USING DELTA AS
SELECT YEAR(signup_date) AS signup_year, country, referral_source,
       COUNT(*) AS user_signups,
       ROUND(COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY YEAR(signup_date)), 4) AS annual_signup_share
FROM retail_portfolio.silver.users
GROUP BY YEAR(signup_date), country, referral_source;

-- COMMAND ----------
CREATE OR REPLACE TABLE retail_portfolio.gold.monthly_user_signups USING DELTA AS
SELECT DATE_TRUNC('MONTH', signup_date) AS signup_month,
       referral_source,
       COUNT(*) AS user_signups
FROM retail_portfolio.silver.users
GROUP BY DATE_TRUNC('MONTH', signup_date), referral_source;
