-- Talent Flow analytics-layer validation
-- File: sql/08_quality_checks_analytics.sql
-- MySQL 8.4
--
-- Run after:
--   04_create_analytics_schema.sql
--   05_load_dimensions.sql
--   06_load_facts.sql
--   07_create_analytics_views.sql
--
-- This script is read-only with respect to permanent project objects.
-- It creates one session-scoped TEMPORARY table to collect test results.
--
-- Interpretation:
--   PASS    = the rule was satisfied
--   FAIL    = a required analytics contract was violated
--   WARNING = investigate, but the condition may be acceptable by design
--
-- The final result sets show:
--   1. overall validation status
--   2. failures and warnings
--   3. counts by status and severity
--   4. the complete detailed test register

USE `talent_flow_analytics`;

DROP TEMPORARY TABLE IF EXISTS `tmp_analytics_validation_results`;

CREATE TEMPORARY TABLE `tmp_analytics_validation_results` (
    `check_order` INT NOT NULL,
    `check_group` VARCHAR(50) NOT NULL,
    `check_name` VARCHAR(160) NOT NULL,
    `severity` VARCHAR(10) NOT NULL,
    `status` VARCHAR(10) NOT NULL,
    `actual_value` VARCHAR(255),
    `expected_value` VARCHAR(255),
    `details` VARCHAR(500),
    PRIMARY KEY (`check_order`)
);

-- ============================================================
-- A. OBJECT AND SCHEMA CONTRACTS
-- ============================================================


INSERT INTO `tmp_analytics_validation_results` (
    `check_order`, `check_group`, `check_name`, `severity`,
    `status`, `actual_value`, `expected_value`, `details`
)
SELECT
    10,
    'Schema',
    'Required analytics base tables exist',
    'ERROR',
    CASE WHEN q.`actual_value` = 13 THEN 'PASS' ELSE 'FAIL' END,
    CAST(q.`actual_value` AS CHAR),
    '13',
    'All eight dimensions and five fact tables must exist.'
FROM (
    SELECT COUNT(*) AS `actual_value`
   FROM `information_schema`.`tables`
   WHERE `table_schema` = 'talent_flow_analytics'
     AND `table_type` = 'BASE TABLE'
     AND `table_name` IN (
         'dim_date','dim_employer','dim_job','dim_location',
         'dim_category','dim_device','dim_traffic_source','dim_campaign',
         'fact_search','fact_impression','fact_click',
         'fact_application','fact_sponsored_spend'
     )
) AS q;


INSERT INTO `tmp_analytics_validation_results` (
    `check_order`, `check_group`, `check_name`, `severity`,
    `status`, `actual_value`, `expected_value`, `details`
)
SELECT
    20,
    'Schema',
    'Required analytics views exist',
    'ERROR',
    CASE WHEN q.`actual_value` = 9 THEN 'PASS' ELSE 'FAIL' END,
    CAST(q.`actual_value` AS CHAR),
    '9',
    'All fanout-safe presentation and base views must exist.'
FROM (
    SELECT COUNT(*) AS `actual_value`
   FROM `information_schema`.`views`
   WHERE `table_schema` = 'talent_flow_analytics'
     AND `table_name` IN (
         'vw_search_performance_daily',
         'vw_job_funnel_daily_base',
         'vw_job_funnel_daily',
         'vw_sponsored_performance_daily_base',
         'vw_sponsored_performance_daily',
         'vw_marketplace_daily',
         'vw_job_performance_daily',
         'vw_employer_performance_daily',
         'vw_campaign_performance_daily'
     )
) AS q;


INSERT INTO `tmp_analytics_validation_results` (
    `check_order`, `check_group`, `check_name`, `severity`,
    `status`, `actual_value`, `expected_value`, `details`
)
SELECT
    30,
    'Schema',
    'Analytics foreign-key contract',
    'ERROR',
    CASE WHEN q.`actual_value` = 33 THEN 'PASS' ELSE 'FAIL' END,
    CAST(q.`actual_value` AS CHAR),
    '33',
    'The five facts should expose 33 foreign keys to conformed dimensions.'
FROM (
    SELECT COUNT(*) AS `actual_value`
   FROM `information_schema`.`key_column_usage`
   WHERE `table_schema` = 'talent_flow_analytics'
     AND `referenced_table_name` IS NOT NULL
) AS q;


INSERT INTO `tmp_analytics_validation_results` (
    `check_order`, `check_group`, `check_name`, `severity`,
    `status`, `actual_value`, `expected_value`, `details`
)
SELECT
    40,
    'Schema',
    'Unexpected permanent analytics tables',
    'WARNING',
    CASE WHEN q.`actual_value` = 0 THEN 'PASS' ELSE 'WARNING' END,
    CAST(q.`actual_value` AS CHAR),
    '0',
    'Extra permanent tables are not necessarily wrong, but should be intentional.'
FROM (
    SELECT COUNT(*) AS `actual_value`
   FROM `information_schema`.`tables`
   WHERE `table_schema` = 'talent_flow_analytics'
     AND `table_type` = 'BASE TABLE'
     AND `table_name` NOT IN (
         'dim_date','dim_employer','dim_job','dim_location',
         'dim_category','dim_device','dim_traffic_source','dim_campaign',
         'fact_search','fact_impression','fact_click',
         'fact_application','fact_sponsored_spend'
     )
) AS q;


-- ============================================================
-- B. DIMENSION COMPLETENESS AND SOURCE RECONCILIATION
-- ============================================================


INSERT INTO `tmp_analytics_validation_results` (
    `check_order`, `check_group`, `check_name`, `severity`,
    `status`, `actual_value`, `expected_value`, `details`
)
SELECT
    100,
    'Dimensions',
    'dim_employer row count matches source',
    'ERROR',
    CASE WHEN q.`actual_value` = 0 THEN 'PASS' ELSE 'FAIL' END,
    CAST(q.`actual_value` AS CHAR),
    '0 difference',
    'dim_employer must contain one row per corresponding source entity.'
FROM (
    SELECT
            (SELECT COUNT(*) FROM `dim_employer`) -
            (SELECT COUNT(*) FROM talent_flow_source.employers) AS `actual_value`
) AS q;


INSERT INTO `tmp_analytics_validation_results` (
    `check_order`, `check_group`, `check_name`, `severity`,
    `status`, `actual_value`, `expected_value`, `details`
)
SELECT
    110,
    'Dimensions',
    'dim_job row count matches source',
    'ERROR',
    CASE WHEN q.`actual_value` = 0 THEN 'PASS' ELSE 'FAIL' END,
    CAST(q.`actual_value` AS CHAR),
    '0 difference',
    'dim_job must contain one row per corresponding source entity.'
FROM (
    SELECT
            (SELECT COUNT(*) FROM `dim_job`) -
            (SELECT COUNT(*) FROM talent_flow_source.job_posts) AS `actual_value`
) AS q;


INSERT INTO `tmp_analytics_validation_results` (
    `check_order`, `check_group`, `check_name`, `severity`,
    `status`, `actual_value`, `expected_value`, `details`
)
SELECT
    120,
    'Dimensions',
    'dim_location row count matches source',
    'ERROR',
    CASE WHEN q.`actual_value` = 0 THEN 'PASS' ELSE 'FAIL' END,
    CAST(q.`actual_value` AS CHAR),
    '0 difference',
    'dim_location must contain one row per corresponding source entity.'
FROM (
    SELECT
            (SELECT COUNT(*) FROM `dim_location`) -
            (SELECT COUNT(*) FROM talent_flow_source.locations) AS `actual_value`
) AS q;


INSERT INTO `tmp_analytics_validation_results` (
    `check_order`, `check_group`, `check_name`, `severity`,
    `status`, `actual_value`, `expected_value`, `details`
)
SELECT
    130,
    'Dimensions',
    'dim_category row count matches source',
    'ERROR',
    CASE WHEN q.`actual_value` = 0 THEN 'PASS' ELSE 'FAIL' END,
    CAST(q.`actual_value` AS CHAR),
    '0 difference',
    'dim_category must contain one row per corresponding source entity.'
FROM (
    SELECT
            (SELECT COUNT(*) FROM `dim_category`) -
            (SELECT COUNT(*) FROM talent_flow_source.job_categories) AS `actual_value`
) AS q;


INSERT INTO `tmp_analytics_validation_results` (
    `check_order`, `check_group`, `check_name`, `severity`,
    `status`, `actual_value`, `expected_value`, `details`
)
SELECT
    140,
    'Dimensions',
    'dim_campaign row count matches source',
    'ERROR',
    CASE WHEN q.`actual_value` = 0 THEN 'PASS' ELSE 'FAIL' END,
    CAST(q.`actual_value` AS CHAR),
    '0 difference',
    'dim_campaign must contain one row per corresponding source entity.'
FROM (
    SELECT
            (SELECT COUNT(*) FROM `dim_campaign`) -
            (SELECT COUNT(*) FROM talent_flow_source.sponsorship_campaigns) AS `actual_value`
) AS q;


INSERT INTO `tmp_analytics_validation_results` (
    `check_order`, `check_group`, `check_name`, `severity`,
    `status`, `actual_value`, `expected_value`, `details`
)
SELECT
    150,
    'Dimensions',
    'dim_device matches distinct source devices',
    'ERROR',
    CASE WHEN q.`actual_value` = 0 THEN 'PASS' ELSE 'FAIL' END,
    CAST(q.`actual_value` AS CHAR),
    '0 difference',
    'The device dimension must cover every distinct source device.'
FROM (
    SELECT
       (SELECT COUNT(*) FROM `dim_device`) -
       (SELECT COUNT(DISTINCT `device_type`)
        FROM `talent_flow_source`.`search_sessions`) AS `actual_value`
) AS q;


INSERT INTO `tmp_analytics_validation_results` (
    `check_order`, `check_group`, `check_name`, `severity`,
    `status`, `actual_value`, `expected_value`, `details`
)
SELECT
    160,
    'Dimensions',
    'dim_traffic_source matches distinct source channels',
    'ERROR',
    CASE WHEN q.`actual_value` = 0 THEN 'PASS' ELSE 'FAIL' END,
    CAST(q.`actual_value` AS CHAR),
    '0 difference',
    'The traffic-source dimension must cover every distinct source value.'
FROM (
    SELECT
       (SELECT COUNT(*) FROM `dim_traffic_source`) -
       (SELECT COUNT(DISTINCT `traffic_source`)
        FROM `talent_flow_source`.`search_sessions`) AS `actual_value`
) AS q;


INSERT INTO `tmp_analytics_validation_results` (
    `check_order`, `check_group`, `check_name`, `severity`,
    `status`, `actual_value`, `expected_value`, `details`
)
SELECT
    170,
    'Dimensions',
    'dim_date contains expected portfolio window',
    'ERROR',
    CASE WHEN q.`actual_value` = 90 THEN 'PASS' ELSE 'FAIL' END,
    CAST(q.`actual_value` AS CHAR),
    '90',
    'The generated portfolio dataset covers January 1 through March 31, 2026.'
FROM (
    SELECT COUNT(*) AS `actual_value`
   FROM `dim_date`
   WHERE `full_date` BETWEEN '2026-01-01' AND '2026-03-31'
) AS q;


INSERT INTO `tmp_analytics_validation_results` (
    `check_order`, `check_group`, `check_name`, `severity`,
    `status`, `actual_value`, `expected_value`, `details`
)
SELECT
    180,
    'Dimensions',
    'dim_date is contiguous',
    'ERROR',
    CASE WHEN q.`actual_value` = 0 THEN 'PASS' ELSE 'FAIL' END,
    CAST(q.`actual_value` AS CHAR),
    '0 difference',
    'There must be exactly one date row for every calendar day in the covered range.'
FROM (
    SELECT
       COUNT(*) - (DATEDIFF(MAX(`full_date`), MIN(`full_date`)) + 1)
       AS `actual_value`
   FROM `dim_date`
) AS q;


INSERT INTO `tmp_analytics_validation_results` (
    `check_order`, `check_group`, `check_name`, `severity`,
    `status`, `actual_value`, `expected_value`, `details`
)
SELECT
    200,
    'Dimensions',
    'dim_employer attributes reconcile to source',
    'ERROR',
    CASE WHEN q.`actual_value` = 0 THEN 'PASS' ELSE 'FAIL' END,
    CAST(q.`actual_value` AS CHAR),
    '0',
    'No employer dimension row should be missing or attribute-mismatched.'
FROM (
    SELECT COUNT(*) AS `actual_value`
   FROM `talent_flow_source`.`employers` AS s
   LEFT JOIN `dim_employer` AS d
     ON s.`employer_id` = d.`employer_id`
   WHERE d.`employer_id` IS NULL
      OR d.`employer_name` <> s.`employer_name`
      OR d.`industry` <> s.`industry`
      OR d.`company_size_band` <> s.`company_size_band`
      OR d.`country_code` <> s.`country_code`
      OR d.`is_verified` <> s.`is_verified`
) AS q;


INSERT INTO `tmp_analytics_validation_results` (
    `check_order`, `check_group`, `check_name`, `severity`,
    `status`, `actual_value`, `expected_value`, `details`
)
SELECT
    210,
    'Dimensions',
    'dim_job attributes reconcile to source',
    'ERROR',
    CASE WHEN q.`actual_value` = 0 THEN 'PASS' ELSE 'FAIL' END,
    CAST(q.`actual_value` AS CHAR),
    '0',
    'No job dimension row should be missing or attribute-mismatched.'
FROM (
    SELECT COUNT(*) AS `actual_value`
   FROM `talent_flow_source`.`job_posts` AS s
   LEFT JOIN `dim_job` AS d
     ON s.`job_id` = d.`job_id`
   WHERE d.`job_id` IS NULL
      OR d.`job_title` <> s.`job_title`
      OR d.`employment_type` <> s.`employment_type`
      OR d.`experience_level` <> s.`experience_level`
      OR d.`remote_type` <> s.`remote_type`
      OR NOT (d.`salary_min` <=> s.`salary_min`)
      OR NOT (d.`salary_max` <=> s.`salary_max`)
      OR NOT (d.`salary_currency` <=> s.`salary_currency`)
      OR d.`posted_date` <> DATE(s.`posted_at`)
      OR d.`job_status` <> s.`status`
) AS q;


INSERT INTO `tmp_analytics_validation_results` (
    `check_order`, `check_group`, `check_name`, `severity`,
    `status`, `actual_value`, `expected_value`, `details`
)
SELECT
    220,
    'Dimensions',
    'dim_location attributes reconcile to source',
    'ERROR',
    CASE WHEN q.`actual_value` = 0 THEN 'PASS' ELSE 'FAIL' END,
    CAST(q.`actual_value` AS CHAR),
    '0',
    'No location dimension row should be missing or attribute-mismatched.'
FROM (
    SELECT COUNT(*) AS `actual_value`
   FROM `talent_flow_source`.`locations` AS s
   LEFT JOIN `dim_location` AS d
     ON s.`location_id` = d.`location_id`
   WHERE d.`location_id` IS NULL
      OR d.`city` <> s.`city`
      OR NOT (d.`state_region` <=> s.`state_region`)
      OR d.`country_code` <> s.`country_code`
      OR NOT (d.`postal_code` <=> s.`postal_code`)
) AS q;


INSERT INTO `tmp_analytics_validation_results` (
    `check_order`, `check_group`, `check_name`, `severity`,
    `status`, `actual_value`, `expected_value`, `details`
)
SELECT
    230,
    'Dimensions',
    'dim_category hierarchy reconciles to source',
    'ERROR',
    CASE WHEN q.`actual_value` = 0 THEN 'PASS' ELSE 'FAIL' END,
    CAST(q.`actual_value` AS CHAR),
    '0',
    'Category descriptions and parent names must match the source hierarchy.'
FROM (
    SELECT COUNT(*) AS `actual_value`
   FROM `talent_flow_source`.`job_categories` AS child
   LEFT JOIN `talent_flow_source`.`job_categories` AS parent
     ON child.`parent_category_id` = parent.`category_id`
   LEFT JOIN `dim_category` AS d
     ON child.`category_id` = d.`category_id`
   WHERE d.`category_id` IS NULL
      OR d.`category_name` <> child.`category_name`
      OR d.`category_family` <> child.`category_family`
      OR NOT (d.`parent_category_name` <=> parent.`category_name`)
) AS q;


INSERT INTO `tmp_analytics_validation_results` (
    `check_order`, `check_group`, `check_name`, `severity`,
    `status`, `actual_value`, `expected_value`, `details`
)
SELECT
    240,
    'Dimensions',
    'dim_device grouping is valid',
    'ERROR',
    CASE WHEN q.`actual_value` = 0 THEN 'PASS' ELSE 'FAIL' END,
    CAST(q.`actual_value` AS CHAR),
    '0',
    'Desktop must map to Desktop; all generated mobile clients map to Mobile.'
FROM (
    SELECT COUNT(*) AS `actual_value`
   FROM `dim_device`
   WHERE (`device_type` = 'desktop' AND `device_group` <> 'Desktop')
      OR (`device_type` <> 'desktop' AND `device_group` <> 'Mobile')
) AS q;


INSERT INTO `tmp_analytics_validation_results` (
    `check_order`, `check_group`, `check_name`, `severity`,
    `status`, `actual_value`, `expected_value`, `details`
)
SELECT
    250,
    'Dimensions',
    'dim_traffic_source grouping is valid',
    'ERROR',
    CASE WHEN q.`actual_value` = 0 THEN 'PASS' ELSE 'FAIL' END,
    CAST(q.`actual_value` AS CHAR),
    '0',
    'Traffic-source groupings must follow the documented channel mapping.'
FROM (
    SELECT COUNT(*) AS `actual_value`
   FROM `dim_traffic_source`
   WHERE `channel_group` <>
     CASE
       WHEN LOWER(REPLACE(`traffic_source`, ' ', '_'))
            IN ('direct', 'email') THEN 'Owned'
       WHEN LOWER(REPLACE(`traffic_source`, ' ', '_'))
            IN ('organic', 'organic_search', 'social') THEN 'Organic'
       WHEN LOWER(REPLACE(`traffic_source`, ' ', '_'))
            = 'paid_search' THEN 'Paid'
       ELSE 'Partner'
     END
) AS q;


INSERT INTO `tmp_analytics_validation_results` (
    `check_order`, `check_group`, `check_name`, `severity`,
    `status`, `actual_value`, `expected_value`, `details`
)
SELECT
    260,
    'Dimensions',
    'dim_campaign attributes reconcile to source',
    'ERROR',
    CASE WHEN q.`actual_value` = 0 THEN 'PASS' ELSE 'FAIL' END,
    CAST(q.`actual_value` AS CHAR),
    '0',
    'No campaign dimension row should be missing or attribute-mismatched.'
FROM (
    SELECT COUNT(*) AS `actual_value`
   FROM `talent_flow_source`.`sponsorship_campaigns` AS s
   LEFT JOIN `dim_campaign` AS d
     ON s.`campaign_id` = d.`campaign_id`
   WHERE d.`campaign_id` IS NULL
      OR d.`campaign_name` <> s.`campaign_name`
      OR d.`billing_model` <> s.`billing_model`
      OR d.`campaign_status` <> s.`campaign_status`
      OR d.`start_date` <> s.`start_date`
      OR NOT (d.`end_date` <=> s.`end_date`)
      OR d.`daily_budget` <> s.`daily_budget`
) AS q;


-- ============================================================
-- C. FACT GRAIN AND SOURCE-TO-FACT RECONCILIATION
-- ============================================================


INSERT INTO `tmp_analytics_validation_results` (
    `check_order`, `check_group`, `check_name`, `severity`,
    `status`, `actual_value`, `expected_value`, `details`
)
SELECT
    300,
    'Facts',
    'fact_search row count matches source',
    'ERROR',
    CASE WHEN q.`actual_value` = 0 THEN 'PASS' ELSE 'FAIL' END,
    CAST(q.`actual_value` AS CHAR),
    '0 difference',
    'fact_search must preserve its declared one-row-per-search_id grain.'
FROM (
    SELECT
            (SELECT COUNT(*) FROM `fact_search`) -
            (SELECT COUNT(*) FROM `talent_flow_source`.`searches`)
            AS `actual_value`
) AS q;


INSERT INTO `tmp_analytics_validation_results` (
    `check_order`, `check_group`, `check_name`, `severity`,
    `status`, `actual_value`, `expected_value`, `details`
)
SELECT
    310,
    'Facts',
    'fact_impression row count matches source',
    'ERROR',
    CASE WHEN q.`actual_value` = 0 THEN 'PASS' ELSE 'FAIL' END,
    CAST(q.`actual_value` AS CHAR),
    '0 difference',
    'fact_impression must preserve its declared one-row-per-impression_id grain.'
FROM (
    SELECT
            (SELECT COUNT(*) FROM `fact_impression`) -
            (SELECT COUNT(*) FROM `talent_flow_source`.`job_impressions`)
            AS `actual_value`
) AS q;


INSERT INTO `tmp_analytics_validation_results` (
    `check_order`, `check_group`, `check_name`, `severity`,
    `status`, `actual_value`, `expected_value`, `details`
)
SELECT
    320,
    'Facts',
    'fact_click row count matches source',
    'ERROR',
    CASE WHEN q.`actual_value` = 0 THEN 'PASS' ELSE 'FAIL' END,
    CAST(q.`actual_value` AS CHAR),
    '0 difference',
    'fact_click must preserve its declared one-row-per-click_id grain.'
FROM (
    SELECT
            (SELECT COUNT(*) FROM `fact_click`) -
            (SELECT COUNT(*) FROM `talent_flow_source`.`job_clicks`)
            AS `actual_value`
) AS q;


INSERT INTO `tmp_analytics_validation_results` (
    `check_order`, `check_group`, `check_name`, `severity`,
    `status`, `actual_value`, `expected_value`, `details`
)
SELECT
    330,
    'Facts',
    'fact_application row count matches source',
    'ERROR',
    CASE WHEN q.`actual_value` = 0 THEN 'PASS' ELSE 'FAIL' END,
    CAST(q.`actual_value` AS CHAR),
    '0 difference',
    'fact_application must preserve its declared one-row-per-application_id grain.'
FROM (
    SELECT
            (SELECT COUNT(*) FROM `fact_application`) -
            (SELECT COUNT(*) FROM `talent_flow_source`.`applications`)
            AS `actual_value`
) AS q;


INSERT INTO `tmp_analytics_validation_results` (
    `check_order`, `check_group`, `check_name`, `severity`,
    `status`, `actual_value`, `expected_value`, `details`
)
SELECT
    340,
    'Facts',
    'fact_sponsored_spend row count matches source',
    'ERROR',
    CASE WHEN q.`actual_value` = 0 THEN 'PASS' ELSE 'FAIL' END,
    CAST(q.`actual_value` AS CHAR),
    '0 difference',
    'The spend fact must preserve one row per date, campaign, and job.'
FROM (
    SELECT
       (SELECT COUNT(*) FROM `fact_sponsored_spend`) -
       (SELECT COUNT(*) FROM `talent_flow_source`.`sponsored_spend_daily`)
       AS `actual_value`
) AS q;


INSERT INTO `tmp_analytics_validation_results` (
    `check_order`, `check_group`, `check_name`, `severity`,
    `status`, `actual_value`, `expected_value`, `details`
)
SELECT
    350,
    'Facts',
    'fact_search primary grain is unique',
    'ERROR',
    CASE WHEN q.`actual_value` = 0 THEN 'PASS' ELSE 'FAIL' END,
    CAST(q.`actual_value` AS CHAR),
    '0 duplicate rows',
    'No duplicate search_id values are allowed.'
FROM (
    SELECT COUNT(*) - COUNT(DISTINCT `search_id`) AS `actual_value`
        FROM `fact_search`
) AS q;


INSERT INTO `tmp_analytics_validation_results` (
    `check_order`, `check_group`, `check_name`, `severity`,
    `status`, `actual_value`, `expected_value`, `details`
)
SELECT
    360,
    'Facts',
    'fact_impression primary grain is unique',
    'ERROR',
    CASE WHEN q.`actual_value` = 0 THEN 'PASS' ELSE 'FAIL' END,
    CAST(q.`actual_value` AS CHAR),
    '0 duplicate rows',
    'No duplicate impression_id values are allowed.'
FROM (
    SELECT COUNT(*) - COUNT(DISTINCT `impression_id`) AS `actual_value`
        FROM `fact_impression`
) AS q;


INSERT INTO `tmp_analytics_validation_results` (
    `check_order`, `check_group`, `check_name`, `severity`,
    `status`, `actual_value`, `expected_value`, `details`
)
SELECT
    370,
    'Facts',
    'fact_click primary grain is unique',
    'ERROR',
    CASE WHEN q.`actual_value` = 0 THEN 'PASS' ELSE 'FAIL' END,
    CAST(q.`actual_value` AS CHAR),
    '0 duplicate rows',
    'No duplicate click_id values are allowed.'
FROM (
    SELECT COUNT(*) - COUNT(DISTINCT `click_id`) AS `actual_value`
        FROM `fact_click`
) AS q;


INSERT INTO `tmp_analytics_validation_results` (
    `check_order`, `check_group`, `check_name`, `severity`,
    `status`, `actual_value`, `expected_value`, `details`
)
SELECT
    380,
    'Facts',
    'fact_application primary grain is unique',
    'ERROR',
    CASE WHEN q.`actual_value` = 0 THEN 'PASS' ELSE 'FAIL' END,
    CAST(q.`actual_value` AS CHAR),
    '0 duplicate rows',
    'No duplicate application_id values are allowed.'
FROM (
    SELECT COUNT(*) - COUNT(DISTINCT `application_id`) AS `actual_value`
        FROM `fact_application`
) AS q;


INSERT INTO `tmp_analytics_validation_results` (
    `check_order`, `check_group`, `check_name`, `severity`,
    `status`, `actual_value`, `expected_value`, `details`
)
SELECT
    390,
    'Facts',
    'fact_sponsored_spend composite grain is unique',
    'ERROR',
    CASE WHEN q.`actual_value` = 0 THEN 'PASS' ELSE 'FAIL' END,
    CAST(q.`actual_value` AS CHAR),
    '0 duplicate grains',
    'Spend must be unique by date_key, campaign_id, and job_id.'
FROM (
    SELECT COUNT(*) AS `actual_value`
   FROM (
       SELECT `date_key`, `campaign_id`, `job_id`
       FROM `fact_sponsored_spend`
       GROUP BY `date_key`, `campaign_id`, `job_id`
       HAVING COUNT(*) > 1
   ) AS duplicates
) AS q;


INSERT INTO `tmp_analytics_validation_results` (
    `check_order`, `check_group`, `check_name`, `severity`,
    `status`, `actual_value`, `expected_value`, `details`
)
SELECT
    400,
    'Facts',
    'fact_search content reconciles to source',
    'ERROR',
    CASE WHEN q.`actual_value` = 0 THEN 'PASS' ELSE 'FAIL' END,
    CAST(q.`actual_value` AS CHAR),
    '0',
    'Search facts must reproduce source searches and their session context.'
FROM (
    SELECT COUNT(*) AS `actual_value`
   FROM `talent_flow_source`.`searches` AS s
   INNER JOIN `talent_flow_source`.`search_sessions` AS ss
     ON s.`session_id` = ss.`session_id`
   LEFT JOIN `fact_search` AS f
     ON s.`search_id` = f.`search_id`
   WHERE f.`search_id` IS NULL
      OR f.`date_key` <>
         CAST(DATE_FORMAT(DATE(s.`searched_at`), '%Y%m%d') AS UNSIGNED)
      OR f.`session_id` <> s.`session_id`
      OR NOT (f.`job_seeker_id` <=> ss.`job_seeker_id`)
      OR f.`device_type` <> ss.`device_type`
      OR f.`traffic_source` <> ss.`traffic_source`
      OR f.`searched_at` <> s.`searched_at`
      OR NOT (f.`query_text` <=> s.`query_text`)
      OR NOT (f.`location_text` <=> s.`location_text`)
      OR f.`results_count` <> s.`results_count`
      OR f.`page_number` <> s.`page_number`
      OR f.`search_count` <> 1
) AS q;


INSERT INTO `tmp_analytics_validation_results` (
    `check_order`, `check_group`, `check_name`, `severity`,
    `status`, `actual_value`, `expected_value`, `details`
)
SELECT
    410,
    'Facts',
    'fact_impression content reconciles to source',
    'ERROR',
    CASE WHEN q.`actual_value` = 0 THEN 'PASS' ELSE 'FAIL' END,
    CAST(q.`actual_value` AS CHAR),
    '0',
    'Impression facts must preserve source event and inherited marketplace context.'
FROM (
    SELECT COUNT(*) AS `actual_value`
   FROM `talent_flow_source`.`job_impressions` AS i
   INNER JOIN `talent_flow_source`.`searches` AS s
     ON i.`search_id` = s.`search_id`
   INNER JOIN `talent_flow_source`.`search_sessions` AS ss
     ON s.`session_id` = ss.`session_id`
   INNER JOIN `talent_flow_source`.`job_posts` AS j
     ON i.`job_id` = j.`job_id`
   LEFT JOIN `fact_impression` AS f
     ON i.`impression_id` = f.`impression_id`
   WHERE f.`impression_id` IS NULL
      OR f.`date_key` <>
         CAST(DATE_FORMAT(DATE(i.`impressed_at`), '%Y%m%d') AS UNSIGNED)
      OR f.`search_id` <> i.`search_id`
      OR f.`job_id` <> i.`job_id`
      OR f.`employer_id` <> j.`employer_id`
      OR f.`location_id` <> j.`location_id`
      OR f.`category_id` <> j.`primary_category_id`
      OR NOT (f.`campaign_id` <=> i.`campaign_id`)
      OR f.`device_type` <> ss.`device_type`
      OR f.`traffic_source` <> ss.`traffic_source`
      OR f.`impressed_at` <> i.`impressed_at`
      OR f.`position` <> i.`position`
      OR f.`is_sponsored` <> i.`is_sponsored`
      OR NOT (f.`predicted_relevance_score` <=> i.`predicted_relevance_score`)
      OR NOT (f.`bid_amount` <=> i.`bid_amount`)
      OR f.`impression_count` <> 1
) AS q;


INSERT INTO `tmp_analytics_validation_results` (
    `check_order`, `check_group`, `check_name`, `severity`,
    `status`, `actual_value`, `expected_value`, `details`
)
SELECT
    420,
    'Facts',
    'fact_click content reconciles to source',
    'ERROR',
    CASE WHEN q.`actual_value` = 0 THEN 'PASS' ELSE 'FAIL' END,
    CAST(q.`actual_value` AS CHAR),
    '0',
    'Click facts must preserve source events and inherited impression context.'
FROM (
    SELECT COUNT(*) AS `actual_value`
   FROM `talent_flow_source`.`job_clicks` AS c
   INNER JOIN `talent_flow_source`.`job_impressions` AS i
     ON c.`impression_id` = i.`impression_id`
   INNER JOIN `talent_flow_source`.`searches` AS s
     ON i.`search_id` = s.`search_id`
   INNER JOIN `talent_flow_source`.`search_sessions` AS ss
     ON s.`session_id` = ss.`session_id`
   INNER JOIN `talent_flow_source`.`job_posts` AS j
     ON i.`job_id` = j.`job_id`
   LEFT JOIN `fact_click` AS f
     ON c.`click_id` = f.`click_id`
   WHERE f.`click_id` IS NULL
      OR f.`date_key` <>
         CAST(DATE_FORMAT(DATE(c.`clicked_at`), '%Y%m%d') AS UNSIGNED)
      OR f.`impression_id` <> c.`impression_id`
      OR f.`search_id` <> i.`search_id`
      OR f.`job_id` <> i.`job_id`
      OR f.`employer_id` <> j.`employer_id`
      OR f.`location_id` <> j.`location_id`
      OR f.`category_id` <> j.`primary_category_id`
      OR NOT (f.`campaign_id` <=> i.`campaign_id`)
      OR f.`device_type` <> ss.`device_type`
      OR f.`traffic_source` <> ss.`traffic_source`
      OR f.`clicked_at` <> c.`clicked_at`
      OR NOT (f.`dwell_seconds` <=> c.`dwell_seconds`)
      OR f.`click_count` <> 1
) AS q;


INSERT INTO `tmp_analytics_validation_results` (
    `check_order`, `check_group`, `check_name`, `severity`,
    `status`, `actual_value`, `expected_value`, `details`
)
SELECT
    430,
    'Facts',
    'fact_application content reconciles to source',
    'ERROR',
    CASE WHEN q.`actual_value` = 0 THEN 'PASS' ELSE 'FAIL' END,
    CAST(q.`actual_value` AS CHAR),
    '0',
    'Application facts must preserve source events, job context, and attribution context.'
FROM (
    SELECT COUNT(*) AS `actual_value`
   FROM `talent_flow_source`.`applications` AS a
   INNER JOIN `talent_flow_source`.`job_posts` AS j
     ON a.`job_id` = j.`job_id`
   LEFT JOIN `talent_flow_source`.`job_clicks` AS c
     ON a.`click_id` = c.`click_id`
   LEFT JOIN `talent_flow_source`.`job_impressions` AS i
     ON c.`impression_id` = i.`impression_id`
   LEFT JOIN `talent_flow_source`.`searches` AS s
     ON i.`search_id` = s.`search_id`
   LEFT JOIN `talent_flow_source`.`search_sessions` AS ss
     ON s.`session_id` = ss.`session_id`
   LEFT JOIN `fact_application` AS f
     ON a.`application_id` = f.`application_id`
   WHERE f.`application_id` IS NULL
      OR f.`date_key` <>
         CAST(DATE_FORMAT(DATE(a.`started_at`), '%Y%m%d') AS UNSIGNED)
      OR f.`job_id` <> a.`job_id`
      OR f.`employer_id` <> j.`employer_id`
      OR f.`location_id` <> j.`location_id`
      OR f.`category_id` <> j.`primary_category_id`
      OR NOT (f.`campaign_id` <=> i.`campaign_id`)
      OR NOT (f.`device_type` <=> ss.`device_type`)
      OR NOT (f.`traffic_source` <=> ss.`traffic_source`)
      OR f.`job_seeker_id` <> a.`job_seeker_id`
      OR NOT (f.`click_id` <=> a.`click_id`)
      OR f.`started_at` <> a.`started_at`
      OR NOT (f.`submitted_at` <=> a.`submitted_at`)
      OR f.`application_status` <> a.`application_status`
      OR f.`application_source` <> a.`application_source`
      OR NOT (f.`completion_seconds` <=> a.`completion_seconds`)
      OR f.`application_count` <> 1
      OR f.`submitted_count` <> CASE
           WHEN a.`submitted_at` IS NOT NULL THEN 1 ELSE 0 END
      OR f.`hired_count` <> CASE
           WHEN a.`application_status` = 'hired' THEN 1 ELSE 0 END
) AS q;


INSERT INTO `tmp_analytics_validation_results` (
    `check_order`, `check_group`, `check_name`, `severity`,
    `status`, `actual_value`, `expected_value`, `details`
)
SELECT
    440,
    'Facts',
    'fact_sponsored_spend content reconciles to source',
    'ERROR',
    CASE WHEN q.`actual_value` = 0 THEN 'PASS' ELSE 'FAIL' END,
    CAST(q.`actual_value` AS CHAR),
    '0',
    'Sponsored-spend facts must preserve billing measures and inherited job context.'
FROM (
    SELECT COUNT(*) AS `actual_value`
   FROM `talent_flow_source`.`sponsored_spend_daily` AS s
   INNER JOIN `talent_flow_source`.`job_posts` AS j
     ON s.`job_id` = j.`job_id`
   LEFT JOIN `fact_sponsored_spend` AS f
     ON f.`date_key` =
          CAST(DATE_FORMAT(s.`spend_date`, '%Y%m%d') AS UNSIGNED)
    AND f.`campaign_id` = s.`campaign_id`
    AND f.`job_id` = s.`job_id`
   WHERE f.`job_id` IS NULL
      OR f.`employer_id` <> j.`employer_id`
      OR f.`location_id` <> j.`location_id`
      OR f.`category_id` <> j.`primary_category_id`
      OR f.`sponsored_impressions` <> s.`sponsored_impressions`
      OR f.`sponsored_clicks` <> s.`sponsored_clicks`
      OR f.`sponsored_applications` <> s.`sponsored_applications`
      OR f.`billed_units` <> s.`billed_units`
      OR f.`unit_cost` <> s.`unit_cost`
      OR f.`spend_amount` <> s.`spend_amount`
) AS q;


-- ============================================================
-- D. REFERENTIAL INTEGRITY AND CONFORMED-DIMENSION COVERAGE
-- ============================================================


INSERT INTO `tmp_analytics_validation_results` (
    `check_order`, `check_group`, `check_name`, `severity`,
    `status`, `actual_value`, `expected_value`, `details`
)
SELECT
    500,
    'Integrity',
    'fact_search has no dimension orphans',
    'ERROR',
    CASE WHEN q.`actual_value` = 0 THEN 'PASS' ELSE 'FAIL' END,
    CAST(q.`actual_value` AS CHAR),
    '0',
    'Every search must resolve to date, device, and traffic dimensions.'
FROM (
    SELECT COUNT(*) AS `actual_value`
   FROM `fact_search` AS f
   LEFT JOIN `dim_date` AS d
     ON f.`date_key` = d.`date_key`
   LEFT JOIN `dim_device` AS dev
     ON f.`device_type` = dev.`device_type`
   LEFT JOIN `dim_traffic_source` AS t
     ON f.`traffic_source` = t.`traffic_source`
   WHERE d.`date_key` IS NULL
      OR dev.`device_type` IS NULL
      OR t.`traffic_source` IS NULL
) AS q;


INSERT INTO `tmp_analytics_validation_results` (
    `check_order`, `check_group`, `check_name`, `severity`,
    `status`, `actual_value`, `expected_value`, `details`
)
SELECT
    510,
    'Integrity',
    'fact_impression has no dimension orphans',
    'ERROR',
    CASE WHEN q.`actual_value` = 0 THEN 'PASS' ELSE 'FAIL' END,
    CAST(q.`actual_value` AS CHAR),
    '0',
    'Every fact_impression row must resolve to all applicable conformed dimensions.'
FROM (
    SELECT COUNT(*) AS `actual_value`
        FROM `fact_impression` AS f
        LEFT JOIN `dim_date` AS d ON f.`date_key` = d.`date_key`
        LEFT JOIN `dim_job` AS j ON f.`job_id` = j.`job_id`
        LEFT JOIN `dim_employer` AS e ON f.`employer_id` = e.`employer_id`
        LEFT JOIN `dim_location` AS l ON f.`location_id` = l.`location_id`
        LEFT JOIN `dim_category` AS c ON f.`category_id` = c.`category_id`
        LEFT JOIN `dim_campaign` AS ca ON f.`campaign_id` = ca.`campaign_id`
        LEFT JOIN `dim_device` AS dev ON f.`device_type` = dev.`device_type`
        LEFT JOIN `dim_traffic_source` AS t
          ON f.`traffic_source` = t.`traffic_source`
        WHERE d.`date_key` IS NULL
           OR j.`job_id` IS NULL
           OR e.`employer_id` IS NULL
           OR l.`location_id` IS NULL
           OR c.`category_id` IS NULL
           OR (f.`campaign_id` IS NOT NULL AND ca.`campaign_id` IS NULL)
           OR dev.`device_type` IS NULL
           OR t.`traffic_source` IS NULL
) AS q;


INSERT INTO `tmp_analytics_validation_results` (
    `check_order`, `check_group`, `check_name`, `severity`,
    `status`, `actual_value`, `expected_value`, `details`
)
SELECT
    520,
    'Integrity',
    'fact_click has no dimension orphans',
    'ERROR',
    CASE WHEN q.`actual_value` = 0 THEN 'PASS' ELSE 'FAIL' END,
    CAST(q.`actual_value` AS CHAR),
    '0',
    'Every fact_click row must resolve to all applicable conformed dimensions.'
FROM (
    SELECT COUNT(*) AS `actual_value`
        FROM `fact_click` AS f
        LEFT JOIN `dim_date` AS d ON f.`date_key` = d.`date_key`
        LEFT JOIN `dim_job` AS j ON f.`job_id` = j.`job_id`
        LEFT JOIN `dim_employer` AS e ON f.`employer_id` = e.`employer_id`
        LEFT JOIN `dim_location` AS l ON f.`location_id` = l.`location_id`
        LEFT JOIN `dim_category` AS c ON f.`category_id` = c.`category_id`
        LEFT JOIN `dim_campaign` AS ca ON f.`campaign_id` = ca.`campaign_id`
        LEFT JOIN `dim_device` AS dev ON f.`device_type` = dev.`device_type`
        LEFT JOIN `dim_traffic_source` AS t
          ON f.`traffic_source` = t.`traffic_source`
        WHERE d.`date_key` IS NULL
           OR j.`job_id` IS NULL
           OR e.`employer_id` IS NULL
           OR l.`location_id` IS NULL
           OR c.`category_id` IS NULL
           OR (f.`campaign_id` IS NOT NULL AND ca.`campaign_id` IS NULL)
           OR dev.`device_type` IS NULL
           OR t.`traffic_source` IS NULL
) AS q;


INSERT INTO `tmp_analytics_validation_results` (
    `check_order`, `check_group`, `check_name`, `severity`,
    `status`, `actual_value`, `expected_value`, `details`
)
SELECT
    530,
    'Integrity',
    'fact_application has no dimension orphans',
    'ERROR',
    CASE WHEN q.`actual_value` = 0 THEN 'PASS' ELSE 'FAIL' END,
    CAST(q.`actual_value` AS CHAR),
    '0',
    'Every application must resolve to required dimensions and any optional attribution dimensions.'
FROM (
    SELECT COUNT(*) AS `actual_value`
   FROM `fact_application` AS f
   LEFT JOIN `dim_date` AS d ON f.`date_key` = d.`date_key`
   LEFT JOIN `dim_job` AS j ON f.`job_id` = j.`job_id`
   LEFT JOIN `dim_employer` AS e ON f.`employer_id` = e.`employer_id`
   LEFT JOIN `dim_location` AS l ON f.`location_id` = l.`location_id`
   LEFT JOIN `dim_category` AS c ON f.`category_id` = c.`category_id`
   LEFT JOIN `dim_campaign` AS ca ON f.`campaign_id` = ca.`campaign_id`
   LEFT JOIN `dim_device` AS dev ON f.`device_type` = dev.`device_type`
   LEFT JOIN `dim_traffic_source` AS t
     ON f.`traffic_source` = t.`traffic_source`
   WHERE d.`date_key` IS NULL
      OR j.`job_id` IS NULL
      OR e.`employer_id` IS NULL
      OR l.`location_id` IS NULL
      OR c.`category_id` IS NULL
      OR (f.`campaign_id` IS NOT NULL AND ca.`campaign_id` IS NULL)
      OR (f.`device_type` IS NOT NULL AND dev.`device_type` IS NULL)
      OR (f.`traffic_source` IS NOT NULL AND t.`traffic_source` IS NULL)
) AS q;


INSERT INTO `tmp_analytics_validation_results` (
    `check_order`, `check_group`, `check_name`, `severity`,
    `status`, `actual_value`, `expected_value`, `details`
)
SELECT
    540,
    'Integrity',
    'fact_sponsored_spend has no dimension orphans',
    'ERROR',
    CASE WHEN q.`actual_value` = 0 THEN 'PASS' ELSE 'FAIL' END,
    CAST(q.`actual_value` AS CHAR),
    '0',
    'Every spend row must resolve to date, campaign, job, employer, location, and category.'
FROM (
    SELECT COUNT(*) AS `actual_value`
   FROM `fact_sponsored_spend` AS f
   LEFT JOIN `dim_date` AS d ON f.`date_key` = d.`date_key`
   LEFT JOIN `dim_campaign` AS ca ON f.`campaign_id` = ca.`campaign_id`
   LEFT JOIN `dim_job` AS j ON f.`job_id` = j.`job_id`
   LEFT JOIN `dim_employer` AS e ON f.`employer_id` = e.`employer_id`
   LEFT JOIN `dim_location` AS l ON f.`location_id` = l.`location_id`
   LEFT JOIN `dim_category` AS c ON f.`category_id` = c.`category_id`
   WHERE d.`date_key` IS NULL
      OR ca.`campaign_id` IS NULL
      OR j.`job_id` IS NULL
      OR e.`employer_id` IS NULL
      OR l.`location_id` IS NULL
      OR c.`category_id` IS NULL
) AS q;


-- ============================================================
-- E. TEMPORAL, DOMAIN, AND BUSINESS-RULE VALIDATION
-- ============================================================


INSERT INTO `tmp_analytics_validation_results` (
    `check_order`, `check_group`, `check_name`, `severity`,
    `status`, `actual_value`, `expected_value`, `details`
)
SELECT
    600,
    'Business rules',
    'fact_search date_key matches event date',
    'ERROR',
    CASE WHEN q.`actual_value` = 0 THEN 'PASS' ELSE 'FAIL' END,
    CAST(q.`actual_value` AS CHAR),
    '0',
    'fact_search.date_key must be derived from searched_at.'
FROM (
    SELECT COUNT(*) AS `actual_value`
        FROM `fact_search`
        WHERE `date_key` <>
          CAST(DATE_FORMAT(DATE(`searched_at`), '%Y%m%d') AS UNSIGNED)
) AS q;


INSERT INTO `tmp_analytics_validation_results` (
    `check_order`, `check_group`, `check_name`, `severity`,
    `status`, `actual_value`, `expected_value`, `details`
)
SELECT
    610,
    'Business rules',
    'fact_impression date_key matches event date',
    'ERROR',
    CASE WHEN q.`actual_value` = 0 THEN 'PASS' ELSE 'FAIL' END,
    CAST(q.`actual_value` AS CHAR),
    '0',
    'fact_impression.date_key must be derived from impressed_at.'
FROM (
    SELECT COUNT(*) AS `actual_value`
        FROM `fact_impression`
        WHERE `date_key` <>
          CAST(DATE_FORMAT(DATE(`impressed_at`), '%Y%m%d') AS UNSIGNED)
) AS q;


INSERT INTO `tmp_analytics_validation_results` (
    `check_order`, `check_group`, `check_name`, `severity`,
    `status`, `actual_value`, `expected_value`, `details`
)
SELECT
    620,
    'Business rules',
    'fact_click date_key matches event date',
    'ERROR',
    CASE WHEN q.`actual_value` = 0 THEN 'PASS' ELSE 'FAIL' END,
    CAST(q.`actual_value` AS CHAR),
    '0',
    'fact_click.date_key must be derived from clicked_at.'
FROM (
    SELECT COUNT(*) AS `actual_value`
        FROM `fact_click`
        WHERE `date_key` <>
          CAST(DATE_FORMAT(DATE(`clicked_at`), '%Y%m%d') AS UNSIGNED)
) AS q;


INSERT INTO `tmp_analytics_validation_results` (
    `check_order`, `check_group`, `check_name`, `severity`,
    `status`, `actual_value`, `expected_value`, `details`
)
SELECT
    630,
    'Business rules',
    'fact_application date_key matches event date',
    'ERROR',
    CASE WHEN q.`actual_value` = 0 THEN 'PASS' ELSE 'FAIL' END,
    CAST(q.`actual_value` AS CHAR),
    '0',
    'fact_application.date_key must be derived from started_at.'
FROM (
    SELECT COUNT(*) AS `actual_value`
        FROM `fact_application`
        WHERE `date_key` <>
          CAST(DATE_FORMAT(DATE(`started_at`), '%Y%m%d') AS UNSIGNED)
) AS q;


INSERT INTO `tmp_analytics_validation_results` (
    `check_order`, `check_group`, `check_name`, `severity`,
    `status`, `actual_value`, `expected_value`, `details`
)
SELECT
    640,
    'Business rules',
    'fact_sponsored_spend date_key format is valid',
    'ERROR',
    CASE WHEN q.`actual_value` = 0 THEN 'PASS' ELSE 'FAIL' END,
    CAST(q.`actual_value` AS CHAR),
    '0',
    'Spend date keys must use YYYYMMDD format and agree with dim_date.'
FROM (
    SELECT COUNT(*) AS `actual_value`
   FROM `fact_sponsored_spend` AS f
   INNER JOIN `dim_date` AS d
     ON f.`date_key` = d.`date_key`
   WHERE f.`date_key` <>
     CAST(DATE_FORMAT(d.`full_date`, '%Y%m%d') AS UNSIGNED)
) AS q;


INSERT INTO `tmp_analytics_validation_results` (
    `check_order`, `check_group`, `check_name`, `severity`,
    `status`, `actual_value`, `expected_value`, `details`
)
SELECT
    650,
    'Business rules',
    'Search measures are valid',
    'ERROR',
    CASE WHEN q.`actual_value` = 0 THEN 'PASS' ELSE 'FAIL' END,
    CAST(q.`actual_value` AS CHAR),
    '0',
    'Every search row counts once, returns a nonnegative result count, and has page_number >= 1.'
FROM (
    SELECT COUNT(*) AS `actual_value`
   FROM `fact_search`
   WHERE `search_count` <> 1
      OR `results_count` < 0
      OR `page_number` < 1
) AS q;


INSERT INTO `tmp_analytics_validation_results` (
    `check_order`, `check_group`, `check_name`, `severity`,
    `status`, `actual_value`, `expected_value`, `details`
)
SELECT
    660,
    'Business rules',
    'Impression measures are valid',
    'ERROR',
    CASE WHEN q.`actual_value` = 0 THEN 'PASS' ELSE 'FAIL' END,
    CAST(q.`actual_value` AS CHAR),
    '0',
    'Impression rows must count once and have valid ranking, sponsorship, score, and bid fields.'
FROM (
    SELECT COUNT(*) AS `actual_value`
   FROM `fact_impression`
   WHERE `impression_count` <> 1
      OR `position` < 1
      OR (`predicted_relevance_score` IS NOT NULL
          AND (`predicted_relevance_score` < 0
               OR `predicted_relevance_score` > 1))
      OR (`bid_amount` IS NOT NULL AND `bid_amount` < 0)
      OR (`is_sponsored` = 1 AND `campaign_id` IS NULL)
      OR (`is_sponsored` = 0 AND `campaign_id` IS NOT NULL)
) AS q;


INSERT INTO `tmp_analytics_validation_results` (
    `check_order`, `check_group`, `check_name`, `severity`,
    `status`, `actual_value`, `expected_value`, `details`
)
SELECT
    670,
    'Business rules',
    'Click measures are valid',
    'ERROR',
    CASE WHEN q.`actual_value` = 0 THEN 'PASS' ELSE 'FAIL' END,
    CAST(q.`actual_value` AS CHAR),
    '0',
    'Every click counts once and dwell time cannot be negative.'
FROM (
    SELECT COUNT(*) AS `actual_value`
   FROM `fact_click`
   WHERE `click_count` <> 1
      OR (`dwell_seconds` IS NOT NULL AND `dwell_seconds` < 0)
) AS q;


INSERT INTO `tmp_analytics_validation_results` (
    `check_order`, `check_group`, `check_name`, `severity`,
    `status`, `actual_value`, `expected_value`, `details`
)
SELECT
    680,
    'Business rules',
    'Application indicator measures are valid',
    'ERROR',
    CASE WHEN q.`actual_value` = 0 THEN 'PASS' ELSE 'FAIL' END,
    CAST(q.`actual_value` AS CHAR),
    '0',
    'Application, submission, and hire flags must be internally consistent.'
FROM (
    SELECT COUNT(*) AS `actual_value`
   FROM `fact_application`
   WHERE `application_count` <> 1
      OR `submitted_count` NOT IN (0, 1)
      OR `hired_count` NOT IN (0, 1)
      OR `submitted_count` <>
         CASE WHEN `submitted_at` IS NOT NULL THEN 1 ELSE 0 END
      OR `hired_count` <>
         CASE WHEN `application_status` = 'hired' THEN 1 ELSE 0 END
      OR `hired_count` > `submitted_count`
      OR (`completion_seconds` IS NOT NULL AND `completion_seconds` < 0)
) AS q;


INSERT INTO `tmp_analytics_validation_results` (
    `check_order`, `check_group`, `check_name`, `severity`,
    `status`, `actual_value`, `expected_value`, `details`
)
SELECT
    690,
    'Business rules',
    'Sponsored-spend measures are valid',
    'ERROR',
    CASE WHEN q.`actual_value` = 0 THEN 'PASS' ELSE 'FAIL' END,
    CAST(q.`actual_value` AS CHAR),
    '0',
    'Sponsored funnel counts and billed amount arithmetic must be valid.'
FROM (
    SELECT COUNT(*) AS `actual_value`
   FROM `fact_sponsored_spend`
   WHERE `sponsored_impressions` < 0
      OR `sponsored_clicks` < 0
      OR `sponsored_applications` < 0
      OR `billed_units` < 0
      OR `unit_cost` < 0
      OR `spend_amount` < 0
      OR `sponsored_clicks` > `sponsored_impressions`
      OR `sponsored_applications` > `sponsored_clicks`
      OR ABS(`spend_amount` - ROUND(`billed_units` * `unit_cost`, 2)) > 0.01
) AS q;


INSERT INTO `tmp_analytics_validation_results` (
    `check_order`, `check_group`, `check_name`, `severity`,
    `status`, `actual_value`, `expected_value`, `details`
)
SELECT
    700,
    'Business rules',
    'Campaign billing units match billing model',
    'ERROR',
    CASE WHEN q.`actual_value` = 0 THEN 'PASS' ELSE 'FAIL' END,
    CAST(q.`actual_value` AS CHAR),
    '0',
    'CPC campaigns bill clicks; CPA campaigns bill applications.'
FROM (
    SELECT COUNT(*) AS `actual_value`
   FROM `fact_sponsored_spend` AS f
   INNER JOIN `dim_campaign` AS c
     ON f.`campaign_id` = c.`campaign_id`
   WHERE (c.`billing_model` = 'cpc'
          AND f.`billed_units` <> f.`sponsored_clicks`)
      OR (c.`billing_model` = 'cpa'
          AND f.`billed_units` <> f.`sponsored_applications`)
) AS q;


INSERT INTO `tmp_analytics_validation_results` (
    `check_order`, `check_group`, `check_name`, `severity`,
    `status`, `actual_value`, `expected_value`, `details`
)
SELECT
    710,
    'Business rules',
    'Sponsored rows use jobs assigned to campaigns',
    'ERROR',
    CASE WHEN q.`actual_value` = 0 THEN 'PASS' ELSE 'FAIL' END,
    CAST(q.`actual_value` AS CHAR),
    '0',
    'Sponsored impressions and spend rows must reference a job assigned to the campaign.'
FROM (
    SELECT COUNT(*) AS `actual_value`
   FROM (
       SELECT f.`campaign_id`, f.`job_id`
       FROM `fact_sponsored_spend` AS f
       LEFT JOIN `talent_flow_source`.`campaign_jobs` AS cj
         ON f.`campaign_id` = cj.`campaign_id`
        AND f.`job_id` = cj.`job_id`
       WHERE cj.`job_id` IS NULL

       UNION ALL

       SELECT i.`campaign_id`, i.`job_id`
       FROM `fact_impression` AS i
       LEFT JOIN `talent_flow_source`.`campaign_jobs` AS cj
         ON i.`campaign_id` = cj.`campaign_id`
        AND i.`job_id` = cj.`job_id`
       WHERE i.`campaign_id` IS NOT NULL
         AND cj.`job_id` IS NULL
   ) AS invalid_campaign_jobs
) AS q;


INSERT INTO `tmp_analytics_validation_results` (
    `check_order`, `check_group`, `check_name`, `severity`,
    `status`, `actual_value`, `expected_value`, `details`
)
SELECT
    720,
    'Business rules',
    'Event timestamps follow funnel order',
    'ERROR',
    CASE WHEN q.`actual_value` = 0 THEN 'PASS' ELSE 'FAIL' END,
    CAST(q.`actual_value` AS CHAR),
    '0',
    'Clicks cannot precede impressions, and applications cannot precede their click or submit before starting.'
FROM (
    SELECT
     (
       SELECT COUNT(*)
       FROM `fact_click` AS c
       INNER JOIN `fact_impression` AS i
         ON c.`impression_id` = i.`impression_id`
       WHERE c.`clicked_at` < i.`impressed_at`
     )
     +
     (
       SELECT COUNT(*)
       FROM `fact_application` AS a
       LEFT JOIN `fact_click` AS c
         ON a.`click_id` = c.`click_id`
       WHERE (a.`click_id` IS NOT NULL AND a.`started_at` < c.`clicked_at`)
          OR (a.`submitted_at` IS NOT NULL
              AND a.`submitted_at` < a.`started_at`)
     ) AS `actual_value`
) AS q;


INSERT INTO `tmp_analytics_validation_results` (
    `check_order`, `check_group`, `check_name`, `severity`,
    `status`, `actual_value`, `expected_value`, `details`
)
SELECT
    730,
    'Business rules',
    'Clicked applications match the clicked job',
    'ERROR',
    CASE WHEN q.`actual_value` = 0 THEN 'PASS' ELSE 'FAIL' END,
    CAST(q.`actual_value` AS CHAR),
    '0',
    'An application attributed to a click must be for the same job as that click.'
FROM (
    SELECT COUNT(*) AS `actual_value`
   FROM `fact_application` AS a
   INNER JOIN `fact_click` AS c
     ON a.`click_id` = c.`click_id`
   WHERE a.`job_id` <> c.`job_id`
) AS q;


INSERT INTO `tmp_analytics_validation_results` (
    `check_order`, `check_group`, `check_name`, `severity`,
    `status`, `actual_value`, `expected_value`, `details`
)
SELECT
    740,
    'Business rules',
    'One application per attributed click',
    'WARNING',
    CASE WHEN q.`actual_value` = 0 THEN 'PASS' ELSE 'WARNING' END,
    CAST(q.`actual_value` AS CHAR),
    '0 duplicate click IDs',
    'Multiple applications from one click may indicate duplicate attribution or a changed business rule.'
FROM (
    SELECT COUNT(*) AS `actual_value`
   FROM (
       SELECT `click_id`
       FROM `fact_application`
       WHERE `click_id` IS NOT NULL
       GROUP BY `click_id`
       HAVING COUNT(*) > 1
   ) AS duplicated_clicks
) AS q;


INSERT INTO `tmp_analytics_validation_results` (
    `check_order`, `check_group`, `check_name`, `severity`,
    `status`, `actual_value`, `expected_value`, `details`
)
SELECT
    750,
    'Business rules',
    'Job salary ranges are valid',
    'ERROR',
    CASE WHEN q.`actual_value` = 0 THEN 'PASS' ELSE 'FAIL' END,
    CAST(q.`actual_value` AS CHAR),
    '0',
    'Salary bounds must be complete, nonnegative, ordered, and accompanied by currency.'
FROM (
    SELECT COUNT(*) AS `actual_value`
   FROM `dim_job`
   WHERE (`salary_min` IS NULL) <> (`salary_max` IS NULL)
      OR (`salary_min` IS NOT NULL AND `salary_min` < 0)
      OR (`salary_max` IS NOT NULL AND `salary_max` < `salary_min`)
      OR (`salary_min` IS NOT NULL AND `salary_currency` IS NULL)
) AS q;


INSERT INTO `tmp_analytics_validation_results` (
    `check_order`, `check_group`, `check_name`, `severity`,
    `status`, `actual_value`, `expected_value`, `details`
)
SELECT
    760,
    'Business rules',
    'Campaign dates and budgets are valid',
    'ERROR',
    CASE WHEN q.`actual_value` = 0 THEN 'PASS' ELSE 'FAIL' END,
    CAST(q.`actual_value` AS CHAR),
    '0',
    'Campaign budgets must be positive and end dates cannot precede start dates.'
FROM (
    SELECT COUNT(*) AS `actual_value`
   FROM `dim_campaign`
   WHERE `daily_budget` <= 0
      OR (`end_date` IS NOT NULL AND `end_date` < `start_date`)
) AS q;


INSERT INTO `tmp_analytics_validation_results` (
    `check_order`, `check_group`, `check_name`, `severity`,
    `status`, `actual_value`, `expected_value`, `details`
)
SELECT
    770,
    'Business rules',
    'Sponsored activity falls within campaign dates',
    'ERROR',
    CASE WHEN q.`actual_value` = 0 THEN 'PASS' ELSE 'FAIL' END,
    CAST(q.`actual_value` AS CHAR),
    '0',
    'Sponsored impressions and spend must occur during the campaign flight.'
FROM (
    SELECT COUNT(*) AS `actual_value`
   FROM (
       SELECT i.`campaign_id`, DATE(i.`impressed_at`) AS `activity_date`
       FROM `fact_impression` AS i
       WHERE i.`campaign_id` IS NOT NULL

       UNION ALL

       SELECT s.`campaign_id`, d.`full_date`
       FROM `fact_sponsored_spend` AS s
       INNER JOIN `dim_date` AS d
         ON s.`date_key` = d.`date_key`
   ) AS activity
   INNER JOIN `dim_campaign` AS c
     ON activity.`campaign_id` = c.`campaign_id`
   WHERE activity.`activity_date` < c.`start_date`
      OR (c.`end_date` IS NOT NULL
          AND activity.`activity_date` > c.`end_date`)
) AS q;


INSERT INTO `tmp_analytics_validation_results` (
    `check_order`, `check_group`, `check_name`, `severity`,
    `status`, `actual_value`, `expected_value`, `details`
)
SELECT
    780,
    'Business rules',
    'Overall funnel ordering is plausible',
    'ERROR',
    CASE WHEN q.`actual_value` = 0 THEN 'PASS' ELSE 'FAIL' END,
    CAST(q.`actual_value` AS CHAR),
    '0',
    'The aggregate funnel must satisfy impressions >= clicks and starts >= submissions >= hires.'
FROM (
    SELECT
     CASE
       WHEN
         (SELECT SUM(`impression_count`) FROM `fact_impression`)
           >= (SELECT SUM(`click_count`) FROM `fact_click`)
         AND
         (SELECT SUM(`application_count`) FROM `fact_application`)
           >= (SELECT SUM(`submitted_count`) FROM `fact_application`)
         AND
         (SELECT SUM(`submitted_count`) FROM `fact_application`)
           >= (SELECT SUM(`hired_count`) FROM `fact_application`)
       THEN 0 ELSE 1
     END AS `actual_value`
) AS q;


-- ============================================================
-- F. FANOUT-SAFE VIEW RECONCILIATION
-- ============================================================


INSERT INTO `tmp_analytics_validation_results` (
    `check_order`, `check_group`, `check_name`, `severity`,
    `status`, `actual_value`, `expected_value`, `details`
)
SELECT
    800,
    'Views',
    'Search view total',
    'ERROR',
    CASE WHEN q.`actual_value` = 0 THEN 'PASS' ELSE 'FAIL' END,
    CAST(q.`actual_value` AS CHAR),
    '0 difference',
    'Search totals in the acquisition view must equal the search fact.'
FROM (
    SELECT (SELECT SUM(`search_count`) FROM `fact_search`) - (SELECT SUM(`searches`) FROM `vw_search_performance_daily`) AS `actual_value`
) AS q;


INSERT INTO `tmp_analytics_validation_results` (
    `check_order`, `check_group`, `check_name`, `severity`,
    `status`, `actual_value`, `expected_value`, `details`
)
SELECT
    810,
    'Views',
    'Funnel view impression total',
    'ERROR',
    CASE WHEN q.`actual_value` = 0 THEN 'PASS' ELSE 'FAIL' END,
    CAST(q.`actual_value` AS CHAR),
    '0 difference',
    'The funnel base must not duplicate or lose impressions.'
FROM (
    SELECT (SELECT SUM(`impression_count`) FROM `fact_impression`) - (SELECT SUM(`impressions`) FROM `vw_job_funnel_daily_base`) AS `actual_value`
) AS q;


INSERT INTO `tmp_analytics_validation_results` (
    `check_order`, `check_group`, `check_name`, `severity`,
    `status`, `actual_value`, `expected_value`, `details`
)
SELECT
    820,
    'Views',
    'Funnel view click total',
    'ERROR',
    CASE WHEN q.`actual_value` = 0 THEN 'PASS' ELSE 'FAIL' END,
    CAST(q.`actual_value` AS CHAR),
    '0 difference',
    'The funnel base must not duplicate or lose clicks.'
FROM (
    SELECT (SELECT SUM(`click_count`) FROM `fact_click`) - (SELECT SUM(`clicks`) FROM `vw_job_funnel_daily_base`) AS `actual_value`
) AS q;


INSERT INTO `tmp_analytics_validation_results` (
    `check_order`, `check_group`, `check_name`, `severity`,
    `status`, `actual_value`, `expected_value`, `details`
)
SELECT
    830,
    'Views',
    'Funnel view application total',
    'ERROR',
    CASE WHEN q.`actual_value` = 0 THEN 'PASS' ELSE 'FAIL' END,
    CAST(q.`actual_value` AS CHAR),
    '0 difference',
    'The funnel base must not duplicate or lose applications.'
FROM (
    SELECT (SELECT SUM(`application_count`) FROM `fact_application`) - (SELECT SUM(`applications_started`) FROM `vw_job_funnel_daily_base`) AS `actual_value`
) AS q;


INSERT INTO `tmp_analytics_validation_results` (
    `check_order`, `check_group`, `check_name`, `severity`,
    `status`, `actual_value`, `expected_value`, `details`
)
SELECT
    840,
    'Views',
    'Funnel view submission total',
    'ERROR',
    CASE WHEN q.`actual_value` = 0 THEN 'PASS' ELSE 'FAIL' END,
    CAST(q.`actual_value` AS CHAR),
    '0 difference',
    'The funnel base must not duplicate or lose submissions.'
FROM (
    SELECT (SELECT SUM(`submitted_count`) FROM `fact_application`) - (SELECT SUM(`applications_submitted`) FROM `vw_job_funnel_daily_base`) AS `actual_value`
) AS q;


INSERT INTO `tmp_analytics_validation_results` (
    `check_order`, `check_group`, `check_name`, `severity`,
    `status`, `actual_value`, `expected_value`, `details`
)
SELECT
    850,
    'Views',
    'Funnel view hire total',
    'ERROR',
    CASE WHEN q.`actual_value` = 0 THEN 'PASS' ELSE 'FAIL' END,
    CAST(q.`actual_value` AS CHAR),
    '0 difference',
    'The funnel base must not duplicate or lose hires.'
FROM (
    SELECT (SELECT SUM(`hired_count`) FROM `fact_application`) - (SELECT SUM(`hires`) FROM `vw_job_funnel_daily_base`) AS `actual_value`
) AS q;


INSERT INTO `tmp_analytics_validation_results` (
    `check_order`, `check_group`, `check_name`, `severity`,
    `status`, `actual_value`, `expected_value`, `details`
)
SELECT
    860,
    'Views',
    'Sponsored view spend total',
    'ERROR',
    CASE WHEN q.`actual_value` = 0 THEN 'PASS' ELSE 'FAIL' END,
    CAST(q.`actual_value` AS CHAR),
    '0 difference',
    'The sponsored base must not duplicate or lose spend.'
FROM (
    SELECT ROUND((SELECT SUM(`spend_amount`) FROM `fact_sponsored_spend`) - (SELECT SUM(`spend_amount`) FROM `vw_sponsored_performance_daily_base`), 2) AS `actual_value`
) AS q;


INSERT INTO `tmp_analytics_validation_results` (
    `check_order`, `check_group`, `check_name`, `severity`,
    `status`, `actual_value`, `expected_value`, `details`
)
SELECT
    870,
    'Views',
    'Marketplace view search total',
    'ERROR',
    CASE WHEN q.`actual_value` = 0 THEN 'PASS' ELSE 'FAIL' END,
    CAST(q.`actual_value` AS CHAR),
    '0 difference',
    'The daily marketplace view must reconcile to total searches.'
FROM (
    SELECT (SELECT SUM(`search_count`) FROM `fact_search`) - (SELECT SUM(`searches`) FROM `vw_marketplace_daily`) AS `actual_value`
) AS q;


INSERT INTO `tmp_analytics_validation_results` (
    `check_order`, `check_group`, `check_name`, `severity`,
    `status`, `actual_value`, `expected_value`, `details`
)
SELECT
    880,
    'Views',
    'Marketplace view impression total',
    'ERROR',
    CASE WHEN q.`actual_value` = 0 THEN 'PASS' ELSE 'FAIL' END,
    CAST(q.`actual_value` AS CHAR),
    '0 difference',
    'The daily marketplace view must reconcile to total impressions.'
FROM (
    SELECT (SELECT SUM(`impression_count`) FROM `fact_impression`) - (SELECT SUM(`impressions`) FROM `vw_marketplace_daily`) AS `actual_value`
) AS q;


INSERT INTO `tmp_analytics_validation_results` (
    `check_order`, `check_group`, `check_name`, `severity`,
    `status`, `actual_value`, `expected_value`, `details`
)
SELECT
    890,
    'Views',
    'Marketplace view click total',
    'ERROR',
    CASE WHEN q.`actual_value` = 0 THEN 'PASS' ELSE 'FAIL' END,
    CAST(q.`actual_value` AS CHAR),
    '0 difference',
    'The daily marketplace view must reconcile to total clicks.'
FROM (
    SELECT (SELECT SUM(`click_count`) FROM `fact_click`) - (SELECT SUM(`clicks`) FROM `vw_marketplace_daily`) AS `actual_value`
) AS q;


INSERT INTO `tmp_analytics_validation_results` (
    `check_order`, `check_group`, `check_name`, `severity`,
    `status`, `actual_value`, `expected_value`, `details`
)
SELECT
    900,
    'Views',
    'Marketplace view application total',
    'ERROR',
    CASE WHEN q.`actual_value` = 0 THEN 'PASS' ELSE 'FAIL' END,
    CAST(q.`actual_value` AS CHAR),
    '0 difference',
    'The daily marketplace view must reconcile to total applications.'
FROM (
    SELECT (SELECT SUM(`application_count`) FROM `fact_application`) - (SELECT SUM(`applications_started`) FROM `vw_marketplace_daily`) AS `actual_value`
) AS q;


INSERT INTO `tmp_analytics_validation_results` (
    `check_order`, `check_group`, `check_name`, `severity`,
    `status`, `actual_value`, `expected_value`, `details`
)
SELECT
    910,
    'Views',
    'Marketplace view spend total',
    'ERROR',
    CASE WHEN q.`actual_value` = 0 THEN 'PASS' ELSE 'FAIL' END,
    CAST(q.`actual_value` AS CHAR),
    '0 difference',
    'The daily marketplace view must reconcile to total sponsored spend.'
FROM (
    SELECT ROUND((SELECT SUM(`spend_amount`) FROM `fact_sponsored_spend`) - (SELECT SUM(`sponsored_spend`) FROM `vw_marketplace_daily`), 2) AS `actual_value`
) AS q;


INSERT INTO `tmp_analytics_validation_results` (
    `check_order`, `check_group`, `check_name`, `severity`,
    `status`, `actual_value`, `expected_value`, `details`
)
SELECT
    920,
    'Views',
    'Job performance impression total',
    'ERROR',
    CASE WHEN q.`actual_value` = 0 THEN 'PASS' ELSE 'FAIL' END,
    CAST(q.`actual_value` AS CHAR),
    '0 difference',
    'The job performance view must aggregate impressions without fanout.'
FROM (
    SELECT (SELECT SUM(`impression_count`) FROM `fact_impression`) - (SELECT SUM(`impressions`) FROM `vw_job_performance_daily`) AS `actual_value`
) AS q;


INSERT INTO `tmp_analytics_validation_results` (
    `check_order`, `check_group`, `check_name`, `severity`,
    `status`, `actual_value`, `expected_value`, `details`
)
SELECT
    930,
    'Views',
    'Employer performance click total',
    'ERROR',
    CASE WHEN q.`actual_value` = 0 THEN 'PASS' ELSE 'FAIL' END,
    CAST(q.`actual_value` AS CHAR),
    '0 difference',
    'The employer performance view must aggregate clicks without fanout.'
FROM (
    SELECT (SELECT SUM(`click_count`) FROM `fact_click`) - (SELECT SUM(`clicks`) FROM `vw_employer_performance_daily`) AS `actual_value`
) AS q;


INSERT INTO `tmp_analytics_validation_results` (
    `check_order`, `check_group`, `check_name`, `severity`,
    `status`, `actual_value`, `expected_value`, `details`
)
SELECT
    940,
    'Views',
    'Campaign performance spend total',
    'ERROR',
    CASE WHEN q.`actual_value` = 0 THEN 'PASS' ELSE 'FAIL' END,
    CAST(q.`actual_value` AS CHAR),
    '0 difference',
    'The campaign performance view must aggregate spend without fanout.'
FROM (
    SELECT ROUND((SELECT SUM(`spend_amount`) FROM `fact_sponsored_spend`) - (SELECT SUM(`spend_amount`) FROM `vw_campaign_performance_daily`), 2) AS `actual_value`
) AS q;


INSERT INTO `tmp_analytics_validation_results` (
    `check_order`, `check_group`, `check_name`, `severity`,
    `status`, `actual_value`, `expected_value`, `details`
)
SELECT
    950,
    'Views',
    'vw_marketplace_daily grain is unique',
    'ERROR',
    CASE WHEN q.`actual_value` = 0 THEN 'PASS' ELSE 'FAIL' END,
    CAST(q.`actual_value` AS CHAR),
    '0 duplicate grains',
    'One row per date.'
FROM (
    SELECT COUNT(*) AS `actual_value`
    FROM (
      SELECT `date_key`
      FROM `vw_marketplace_daily`
      GROUP BY `date_key`
      HAVING COUNT(*) > 1
    ) AS d
) AS q;


INSERT INTO `tmp_analytics_validation_results` (
    `check_order`, `check_group`, `check_name`, `severity`,
    `status`, `actual_value`, `expected_value`, `details`
)
SELECT
    960,
    'Views',
    'vw_search_performance_daily grain is unique',
    'ERROR',
    CASE WHEN q.`actual_value` = 0 THEN 'PASS' ELSE 'FAIL' END,
    CAST(q.`actual_value` AS CHAR),
    '0 duplicate grains',
    'One row per date, device, and traffic source.'
FROM (
    SELECT COUNT(*) AS `actual_value`
    FROM (
      SELECT `date_key`, `device_type`, `traffic_source`
      FROM `vw_search_performance_daily`
      GROUP BY `date_key`, `device_type`, `traffic_source`
      HAVING COUNT(*) > 1
    ) AS d
) AS q;


INSERT INTO `tmp_analytics_validation_results` (
    `check_order`, `check_group`, `check_name`, `severity`,
    `status`, `actual_value`, `expected_value`, `details`
)
SELECT
    970,
    'Views',
    'vw_job_performance_daily grain is unique',
    'ERROR',
    CASE WHEN q.`actual_value` = 0 THEN 'PASS' ELSE 'FAIL' END,
    CAST(q.`actual_value` AS CHAR),
    '0 duplicate grains',
    'One row per date and job.'
FROM (
    SELECT COUNT(*) AS `actual_value`
    FROM (
      SELECT `date_key`, `job_id`
      FROM `vw_job_performance_daily`
      GROUP BY `date_key`, `job_id`
      HAVING COUNT(*) > 1
    ) AS d
) AS q;


INSERT INTO `tmp_analytics_validation_results` (
    `check_order`, `check_group`, `check_name`, `severity`,
    `status`, `actual_value`, `expected_value`, `details`
)
SELECT
    980,
    'Views',
    'vw_employer_performance_daily grain is unique',
    'ERROR',
    CASE WHEN q.`actual_value` = 0 THEN 'PASS' ELSE 'FAIL' END,
    CAST(q.`actual_value` AS CHAR),
    '0 duplicate grains',
    'One row per date and employer.'
FROM (
    SELECT COUNT(*) AS `actual_value`
    FROM (
      SELECT `date_key`, `employer_id`
      FROM `vw_employer_performance_daily`
      GROUP BY `date_key`, `employer_id`
      HAVING COUNT(*) > 1
    ) AS d
) AS q;


INSERT INTO `tmp_analytics_validation_results` (
    `check_order`, `check_group`, `check_name`, `severity`,
    `status`, `actual_value`, `expected_value`, `details`
)
SELECT
    990,
    'Views',
    'vw_campaign_performance_daily grain is unique',
    'ERROR',
    CASE WHEN q.`actual_value` = 0 THEN 'PASS' ELSE 'FAIL' END,
    CAST(q.`actual_value` AS CHAR),
    '0 duplicate grains',
    'One row per date and campaign.'
FROM (
    SELECT COUNT(*) AS `actual_value`
    FROM (
      SELECT `date_key`, `campaign_id`
      FROM `vw_campaign_performance_daily`
      GROUP BY `date_key`, `campaign_id`
      HAVING COUNT(*) > 1
    ) AS d
) AS q;


INSERT INTO `tmp_analytics_validation_results` (
    `check_order`, `check_group`, `check_name`, `severity`,
    `status`, `actual_value`, `expected_value`, `details`
)
SELECT
    1000,
    'Views',
    'Presentation views return rows',
    'ERROR',
    CASE WHEN q.`actual_value` = 0 THEN 'PASS' ELSE 'FAIL' END,
    CAST(q.`actual_value` AS CHAR),
    '0 empty presentation views',
    'Every dashboard-facing view must return data.'
FROM (
    SELECT
     (CASE WHEN (SELECT COUNT(*) FROM `vw_search_performance_daily`) > 0
           THEN 0 ELSE 1 END)
   + (CASE WHEN (SELECT COUNT(*) FROM `vw_job_funnel_daily`) > 0
           THEN 0 ELSE 1 END)
   + (CASE WHEN (SELECT COUNT(*) FROM `vw_sponsored_performance_daily`) > 0
           THEN 0 ELSE 1 END)
   + (CASE WHEN (SELECT COUNT(*) FROM `vw_marketplace_daily`) > 0
           THEN 0 ELSE 1 END)
   + (CASE WHEN (SELECT COUNT(*) FROM `vw_job_performance_daily`) > 0
           THEN 0 ELSE 1 END)
   + (CASE WHEN (SELECT COUNT(*) FROM `vw_employer_performance_daily`) > 0
           THEN 0 ELSE 1 END)
   + (CASE WHEN (SELECT COUNT(*) FROM `vw_campaign_performance_daily`) > 0
           THEN 0 ELSE 1 END)
   AS `actual_value`
) AS q;


-- ============================================================
-- G. PORTFOLIO DATASET VOLUME BENCHMARKS
-- These are warnings because changing generator parameters is valid.
-- ============================================================


INSERT INTO `tmp_analytics_validation_results` (
    `check_order`, `check_group`, `check_name`, `severity`,
    `status`, `actual_value`, `expected_value`, `details`
)
SELECT
    1100,
    'Benchmarks',
    'dim_employer matches seed-42 benchmark',
    'WARNING',
    CASE WHEN q.`actual_value` = 150 THEN 'PASS' ELSE 'WARNING' END,
    CAST(q.`actual_value` AS CHAR),
    '150',
    'A different count is acceptable only if generator settings or seed were intentionally changed.'
FROM (
    SELECT COUNT(*) AS `actual_value` FROM `dim_employer`
) AS q;


INSERT INTO `tmp_analytics_validation_results` (
    `check_order`, `check_group`, `check_name`, `severity`,
    `status`, `actual_value`, `expected_value`, `details`
)
SELECT
    1110,
    'Benchmarks',
    'dim_location matches seed-42 benchmark',
    'WARNING',
    CASE WHEN q.`actual_value` = 75 THEN 'PASS' ELSE 'WARNING' END,
    CAST(q.`actual_value` AS CHAR),
    '75',
    'A different count is acceptable only if generator settings or seed were intentionally changed.'
FROM (
    SELECT COUNT(*) AS `actual_value` FROM `dim_location`
) AS q;


INSERT INTO `tmp_analytics_validation_results` (
    `check_order`, `check_group`, `check_name`, `severity`,
    `status`, `actual_value`, `expected_value`, `details`
)
SELECT
    1120,
    'Benchmarks',
    'dim_category matches seed-42 benchmark',
    'WARNING',
    CASE WHEN q.`actual_value` = 24 THEN 'PASS' ELSE 'WARNING' END,
    CAST(q.`actual_value` AS CHAR),
    '24',
    'A different count is acceptable only if generator settings or seed were intentionally changed.'
FROM (
    SELECT COUNT(*) AS `actual_value` FROM `dim_category`
) AS q;


INSERT INTO `tmp_analytics_validation_results` (
    `check_order`, `check_group`, `check_name`, `severity`,
    `status`, `actual_value`, `expected_value`, `details`
)
SELECT
    1130,
    'Benchmarks',
    'dim_job matches seed-42 benchmark',
    'WARNING',
    CASE WHEN q.`actual_value` = 3000 THEN 'PASS' ELSE 'WARNING' END,
    CAST(q.`actual_value` AS CHAR),
    '3000',
    'A different count is acceptable only if generator settings or seed were intentionally changed.'
FROM (
    SELECT COUNT(*) AS `actual_value` FROM `dim_job`
) AS q;


INSERT INTO `tmp_analytics_validation_results` (
    `check_order`, `check_group`, `check_name`, `severity`,
    `status`, `actual_value`, `expected_value`, `details`
)
SELECT
    1140,
    'Benchmarks',
    'dim_device matches seed-42 benchmark',
    'WARNING',
    CASE WHEN q.`actual_value` = 4 THEN 'PASS' ELSE 'WARNING' END,
    CAST(q.`actual_value` AS CHAR),
    '4',
    'A different count is acceptable only if generator settings or seed were intentionally changed.'
FROM (
    SELECT COUNT(*) AS `actual_value` FROM `dim_device`
) AS q;


INSERT INTO `tmp_analytics_validation_results` (
    `check_order`, `check_group`, `check_name`, `severity`,
    `status`, `actual_value`, `expected_value`, `details`
)
SELECT
    1150,
    'Benchmarks',
    'dim_traffic_source matches seed-42 benchmark',
    'WARNING',
    CASE WHEN q.`actual_value` = 6 THEN 'PASS' ELSE 'WARNING' END,
    CAST(q.`actual_value` AS CHAR),
    '6',
    'A different count is acceptable only if generator settings or seed were intentionally changed.'
FROM (
    SELECT COUNT(*) AS `actual_value` FROM `dim_traffic_source`
) AS q;


INSERT INTO `tmp_analytics_validation_results` (
    `check_order`, `check_group`, `check_name`, `severity`,
    `status`, `actual_value`, `expected_value`, `details`
)
SELECT
    1160,
    'Benchmarks',
    'dim_campaign matches seed-42 benchmark',
    'WARNING',
    CASE WHEN q.`actual_value` = 80 THEN 'PASS' ELSE 'WARNING' END,
    CAST(q.`actual_value` AS CHAR),
    '80',
    'A different count is acceptable only if generator settings or seed were intentionally changed.'
FROM (
    SELECT COUNT(*) AS `actual_value` FROM `dim_campaign`
) AS q;


INSERT INTO `tmp_analytics_validation_results` (
    `check_order`, `check_group`, `check_name`, `severity`,
    `status`, `actual_value`, `expected_value`, `details`
)
SELECT
    1170,
    'Benchmarks',
    'fact_search matches seed-42 benchmark',
    'WARNING',
    CASE WHEN q.`actual_value` = 45000 THEN 'PASS' ELSE 'WARNING' END,
    CAST(q.`actual_value` AS CHAR),
    '45000',
    'A different count is acceptable only if generator settings or seed were intentionally changed.'
FROM (
    SELECT COUNT(*) AS `actual_value` FROM `fact_search`
) AS q;


INSERT INTO `tmp_analytics_validation_results` (
    `check_order`, `check_group`, `check_name`, `severity`,
    `status`, `actual_value`, `expected_value`, `details`
)
SELECT
    1180,
    'Benchmarks',
    'fact_application matches seed-42 benchmark',
    'WARNING',
    CASE WHEN q.`actual_value` = 3592 THEN 'PASS' ELSE 'WARNING' END,
    CAST(q.`actual_value` AS CHAR),
    '3592',
    'A different count is acceptable only if generator settings or seed were intentionally changed.'
FROM (
    SELECT COUNT(*) AS `actual_value` FROM `fact_application`
) AS q;


INSERT INTO `tmp_analytics_validation_results` (
    `check_order`, `check_group`, `check_name`, `severity`,
    `status`, `actual_value`, `expected_value`, `details`
)
SELECT
    1190,
    'Benchmarks',
    'fact_impression matches seed-42 benchmark',
    'WARNING',
    CASE WHEN q.`actual_value` = 456998 THEN 'PASS' ELSE 'WARNING' END,
    CAST(q.`actual_value` AS CHAR),
    '456998',
    'A different count is acceptable only if generator settings or seed were intentionally changed.'
FROM (
    SELECT COUNT(*) AS `actual_value` FROM `fact_impression`
) AS q;


INSERT INTO `tmp_analytics_validation_results` (
    `check_order`, `check_group`, `check_name`, `severity`,
    `status`, `actual_value`, `expected_value`, `details`
)
SELECT
    1200,
    'Benchmarks',
    'fact_click matches seed-42 benchmark',
    'WARNING',
    CASE WHEN q.`actual_value` = 28089 THEN 'PASS' ELSE 'WARNING' END,
    CAST(q.`actual_value` AS CHAR),
    '28089',
    'A different count is acceptable only if generator settings or seed were intentionally changed.'
FROM (
    SELECT COUNT(*) AS `actual_value` FROM `fact_click`
) AS q;


INSERT INTO `tmp_analytics_validation_results` (
    `check_order`, `check_group`, `check_name`, `severity`,
    `status`, `actual_value`, `expected_value`, `details`
)
SELECT
    1210,
    'Benchmarks',
    'fact_sponsored_spend matches seed-42 benchmark',
    'WARNING',
    CASE WHEN q.`actual_value` = 21722 THEN 'PASS' ELSE 'WARNING' END,
    CAST(q.`actual_value` AS CHAR),
    '21722',
    'A different count is acceptable only if generator settings or seed were intentionally changed.'
FROM (
    SELECT COUNT(*) AS `actual_value` FROM `fact_sponsored_spend`
) AS q;


-- ============================================================
-- H. FINAL OUTPUTS
-- ============================================================

-- 1. Overall status.
SELECT
    CASE
        WHEN SUM(CASE WHEN `status` = 'FAIL' THEN 1 ELSE 0 END) = 0
        THEN 'PASS'
        ELSE 'FAIL'
    END AS `overall_status`,
    SUM(CASE WHEN `status` = 'PASS' THEN 1 ELSE 0 END) AS `passed_checks`,
    SUM(CASE WHEN `status` = 'FAIL' THEN 1 ELSE 0 END) AS `failed_checks`,
    SUM(CASE WHEN `status` = 'WARNING' THEN 1 ELSE 0 END) AS `warning_checks`,
    COUNT(*) AS `total_checks`,
    NOW() AS `validated_at`
FROM `tmp_analytics_validation_results`;

-- 2. Items requiring attention.
SELECT
    `check_order`,
    `check_group`,
    `check_name`,
    `severity`,
    `status`,
    `actual_value`,
    `expected_value`,
    `details`
FROM `tmp_analytics_validation_results`
WHERE `status` IN ('FAIL', 'WARNING')
ORDER BY
    CASE `status`
        WHEN 'FAIL' THEN 1
        WHEN 'WARNING' THEN 2
        ELSE 3
    END,
    `check_order`;

-- 3. Status summary.
SELECT
    `status`,
    `severity`,
    COUNT(*) AS `check_count`
FROM `tmp_analytics_validation_results`
GROUP BY `status`, `severity`
ORDER BY
    CASE `status`
        WHEN 'FAIL' THEN 1
        WHEN 'WARNING' THEN 2
        WHEN 'PASS' THEN 3
        ELSE 4
    END,
    `severity`;

-- 4. Full validation register.
SELECT
    `check_order`,
    `check_group`,
    `check_name`,
    `severity`,
    `status`,
    `actual_value`,
    `expected_value`,
    `details`
FROM `tmp_analytics_validation_results`
ORDER BY `check_order`;

-- 5. Compact dashboard-ready metric preview.
SELECT
    MIN(`full_date`) AS `first_date`,
    MAX(`full_date`) AS `last_date`,
    SUM(`searches`) AS `searches`,
    SUM(`impressions`) AS `impressions`,
    SUM(`clicks`) AS `clicks`,
    SUM(`applications_started`) AS `applications_started`,
    SUM(`applications_submitted`) AS `applications_submitted`,
    SUM(`hires`) AS `hires`,
    ROUND(SUM(`sponsored_spend`), 2) AS `sponsored_spend`,
    ROUND(
        100.0 * SUM(`clicks`) / NULLIF(SUM(`impressions`), 0),
        2
    ) AS `ctr_pct`,
    ROUND(
        100.0 * SUM(`applications_started`) / NULLIF(SUM(`clicks`), 0),
        2
    ) AS `click_to_application_pct`
FROM `vw_marketplace_daily`;