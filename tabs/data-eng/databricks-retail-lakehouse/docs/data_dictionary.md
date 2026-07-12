# Data Dictionary

## Silver transactions

| Column | Type | Description |
|---|---|---|
| `transaction_id` | string | Unique transaction identifier |
| `transaction_timestamp` | timestamp | Transaction date and time |
| `transaction_date` | date | Calendar transaction date |
| `customer_id` | string | Source customer identifier |
| `product_id` | string | Product identifier |
| `product_name` | string | Standardized product name |
| `category` | string | Standardized category |
| `quantity` | integer | Units purchased |
| `unit_price` | decimal(12,2) | Price per unit |
| `total_amount` | decimal(12,2) | Recorded transaction revenue |
| `store_location` | string | Store city |
| `payment_method` | string | Standardized payment method |
| `source_file` | string | Originating CSV filename |
| `ingested_at` | timestamp | Bronze ingestion timestamp |

## Silver users

| Column | Type | Description |
|---|---|---|
| `user_id` | string | Unique source user identifier |
| `first_name` | string | Standardized first name |
| `last_name` | string | Standardized last name |
| `full_name` | string | Combined display name |
| `email` | string | Lowercase validated email |
| `signup_date` | date | Parsed signup date |
| `country` | string | Two-letter source country code |
| `referral_source` | string | Acquisition channel |
| `source_file` | string | Originating CSV filename |
| `ingested_at` | timestamp | Bronze ingestion timestamp |

## Gold model

| Table | Grain |
|---|---|
| `fact_sales` | One row per valid transaction |
| `dim_product` | One row per product ID |
| `dim_store` | One row per store location |
| `dim_date` | One row per transaction date |
| `daily_sales_summary` | One row per transaction date |
| `product_performance` | One row per product and category |
| `store_performance` | One row per store location |
| `payment_method_performance` | One row per payment method |
| `user_acquisition_summary` | One row per signup year, country, and referral source |
| `monthly_user_signups` | One row per signup month and referral source |
