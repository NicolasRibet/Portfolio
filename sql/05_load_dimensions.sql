-- Talent Flow analytics dimension load
-- File: sql/05_load_dimensions.sql
-- Run after source CSVs are loaded and analytics DDL is created.
-- Run before fact tables are populated.

USE `talent_flow_analytics`;

SET SQL_SAFE_UPDATES = 0;

START TRANSACTION;

DELETE FROM `dim_date`;
DELETE FROM `dim_employer`;
DELETE FROM `dim_job`;
DELETE FROM `dim_location`;
DELETE FROM `dim_category`;
DELETE FROM `dim_device`;
DELETE FROM `dim_traffic_source`;
DELETE FROM `dim_campaign`;

INSERT INTO `dim_date` (
    `date_key`,
    `full_date`,
    `day_of_week_name`,
    `day_of_month`,
    `week_of_year`,
    `month_number`,
    `month_name`,
    `quarter_number`,
    `year_number`,
    `is_weekend`
)
WITH RECURSIVE `calendar` AS (
    SELECT DATE('2026-01-01') AS `full_date`
    UNION ALL
    SELECT DATE_ADD(`full_date`, INTERVAL 1 DAY)
    FROM `calendar`
    WHERE `full_date` < DATE('2026-03-31')
)
SELECT
    CAST(DATE_FORMAT(`full_date`, '%Y%m%d') AS UNSIGNED),
    `full_date`,
    DAYNAME(`full_date`),
    DAY(`full_date`),
    WEEKOFYEAR(`full_date`),
    MONTH(`full_date`),
    MONTHNAME(`full_date`),
    QUARTER(`full_date`),
    YEAR(`full_date`),
    CASE WHEN DAYOFWEEK(`full_date`) IN (1, 7) THEN 1 ELSE 0 END
FROM `calendar`
ORDER BY `full_date`;

INSERT INTO `dim_employer` (
    `employer_id`,
    `employer_name`,
    `industry`,
    `company_size_band`,
    `country_code`,
    `is_verified`
)
SELECT
    `employer_id`,
    `employer_name`,
    `industry`,
    `company_size_band`,
    `country_code`,
    `is_verified`
FROM `talent_flow_source`.`employers`
ORDER BY `employer_id`;

INSERT INTO `dim_job` (
    `job_id`,
    `job_title`,
    `employment_type`,
    `experience_level`,
    `remote_type`,
    `salary_min`,
    `salary_max`,
    `salary_currency`,
    `posted_date`,
    `job_status`
)
SELECT
    `job_id`,
    `job_title`,
    `employment_type`,
    `experience_level`,
    `remote_type`,
    `salary_min`,
    `salary_max`,
    `salary_currency`,
    DATE(`posted_at`),
    `status`
FROM `talent_flow_source`.`job_posts`
ORDER BY `job_id`;

INSERT INTO `dim_location` (
    `location_id`,
    `city`,
    `state_region`,
    `country_code`,
    `postal_code`
)
SELECT
    `location_id`,
    `city`,
    `state_region`,
    `country_code`,
    `postal_code`
FROM `talent_flow_source`.`locations`
ORDER BY `location_id`;

INSERT INTO `dim_category` (
    `category_id`,
    `category_name`,
    `category_family`,
    `parent_category_name`
)
SELECT
    child.`category_id`,
    child.`category_name`,
    child.`category_family`,
    parent.`category_name`
FROM `talent_flow_source`.`job_categories` AS child
LEFT JOIN `talent_flow_source`.`job_categories` AS parent
    ON child.`parent_category_id` = parent.`category_id`
ORDER BY child.`category_id`;

INSERT INTO `dim_device` (
    `device_type`,
    `device_group`
)
SELECT DISTINCT
    `device_type`,
    CASE
        WHEN LOWER(`device_type`) = 'desktop' THEN 'Desktop'
        ELSE 'Mobile'
    END
FROM `talent_flow_source`.`search_sessions`
ORDER BY `device_type`;

INSERT INTO `dim_traffic_source` (
    `traffic_source`,
    `channel_group`
)
SELECT DISTINCT
    `traffic_source`,
    CASE
        WHEN LOWER(REPLACE(`traffic_source`, ' ', '_')) IN ('direct', 'email')
            THEN 'Owned'
        WHEN LOWER(REPLACE(`traffic_source`, ' ', '_')) IN ('organic', 'organic_search', 'social')
            THEN 'Organic'
        WHEN LOWER(REPLACE(`traffic_source`, ' ', '_')) = 'paid_search'
            THEN 'Paid'
        ELSE 'Partner'
    END
FROM `talent_flow_source`.`search_sessions`
ORDER BY `traffic_source`;

INSERT INTO `dim_campaign` (
    `campaign_id`,
    `campaign_name`,
    `billing_model`,
    `campaign_status`,
    `start_date`,
    `end_date`,
    `daily_budget`
)
SELECT
    `campaign_id`,
    `campaign_name`,
    `billing_model`,
    `campaign_status`,
    `start_date`,
    `end_date`,
    `daily_budget`
FROM `talent_flow_source`.`sponsorship_campaigns`
ORDER BY `campaign_id`;

COMMIT;

SELECT 'dim_date' AS `table_name`, COUNT(*) AS `row_count` FROM `dim_date`
UNION ALL
SELECT 'dim_employer', COUNT(*) FROM `dim_employer`
UNION ALL
SELECT 'dim_job', COUNT(*) FROM `dim_job`
UNION ALL
SELECT 'dim_location', COUNT(*) FROM `dim_location`
UNION ALL
SELECT 'dim_category', COUNT(*) FROM `dim_category`
UNION ALL
SELECT 'dim_device', COUNT(*) FROM `dim_device`
UNION ALL
SELECT 'dim_traffic_source', COUNT(*) FROM `dim_traffic_source`
UNION ALL
SELECT 'dim_campaign', COUNT(*) FROM `dim_campaign`;
