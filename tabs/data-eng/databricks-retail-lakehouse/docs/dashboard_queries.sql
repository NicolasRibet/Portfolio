-- KPI row
SELECT
  ROUND(SUM(total_amount), 2) AS total_revenue,
  COUNT(DISTINCT transaction_id) AS total_transactions,
  SUM(quantity) AS total_units_sold,
  ROUND(AVG(total_amount), 2) AS average_order_value,
  COUNT(DISTINCT customer_id) AS unique_customers
FROM retail_portfolio.silver.transactions;

-- Daily revenue trend
SELECT transaction_date, gross_revenue, transaction_count, average_order_value
FROM retail_portfolio.gold.daily_sales_summary
ORDER BY transaction_date;

-- Product performance
SELECT product_name, category, units_sold, gross_revenue, revenue_share
FROM retail_portfolio.gold.product_performance
ORDER BY gross_revenue DESC;

-- Store performance
SELECT store_location, transaction_count, unique_customers, gross_revenue, average_order_value
FROM retail_portfolio.gold.store_performance
ORDER BY gross_revenue DESC;

-- Payment method mix
SELECT payment_method, transaction_count, gross_revenue, transaction_share
FROM retail_portfolio.gold.payment_method_performance
ORDER BY transaction_count DESC;

-- Acquisition channels
SELECT referral_source, SUM(user_signups) AS total_signups
FROM retail_portfolio.gold.user_acquisition_summary
GROUP BY referral_source
ORDER BY total_signups DESC;

-- Latest quality results
SELECT test_name, test_category, observed_value, expected_value, test_status, tested_at
FROM retail_portfolio.monitoring.data_quality_results
QUALIFY ROW_NUMBER() OVER (PARTITION BY test_name ORDER BY tested_at DESC) = 1
ORDER BY test_status, test_name;
