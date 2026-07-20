-- Talent Flow analytics fact load
-- File: sql/06_load_facts.sql
-- MySQL 8.4
--
-- Prerequisites:
--   1. talent_flow_source contains all 15 populated source tables.
--   2. sql/04_create_analytics_schema.sql has created the analytics tables.
--   3. sql/05_load_dimensions.sql has populated all dimension tables.
--
-- Fact grains:
--   fact_search            = one row per search
--   fact_impression        = one row per job impression
--   fact_click             = one row per job click
--   fact_application       = one row per application
--   fact_sponsored_spend   = one row per date, campaign, and job
--
-- This script is rerunnable: it deletes existing fact rows before reloading them.
-- If execution stops with an error before COMMIT, run ROLLBACK before retrying.

USE `talent_flow_analytics`;

SET @previous_sql_safe_updates = @@SQL_SAFE_UPDATES;
SET SQL_SAFE_UPDATES = 0;

-- ============================================================
-- PRE-LOAD CHECKS
-- These should match the generated source-data volumes.
-- ============================================================

SELECT 'source_searches' AS `check_name`, COUNT(*) AS `row_count`
FROM `talent_flow_source`.`searches`
UNION ALL
SELECT 'source_job_impressions', COUNT(*)
FROM `talent_flow_source`.`job_impressions`
UNION ALL
SELECT 'source_job_clicks', COUNT(*)
FROM `talent_flow_source`.`job_clicks`
UNION ALL
SELECT 'source_applications', COUNT(*)
FROM `talent_flow_source`.`applications`
UNION ALL
SELECT 'source_sponsored_spend_daily', COUNT(*)
FROM `talent_flow_source`.`sponsored_spend_daily`;

SELECT 'dim_date' AS `check_name`, COUNT(*) AS `row_count`
FROM `dim_date`
UNION ALL
SELECT 'dim_employer', COUNT(*)
FROM `dim_employer`
UNION ALL
SELECT 'dim_job', COUNT(*)
FROM `dim_job`
UNION ALL
SELECT 'dim_location', COUNT(*)
FROM `dim_location`
UNION ALL
SELECT 'dim_category', COUNT(*)
FROM `dim_category`
UNION ALL
SELECT 'dim_device', COUNT(*)
FROM `dim_device`
UNION ALL
SELECT 'dim_traffic_source', COUNT(*)
FROM `dim_traffic_source`
UNION ALL
SELECT 'dim_campaign', COUNT(*)
FROM `dim_campaign`;

START TRANSACTION;

-- Delete child/event facts first so that the script is safe to rerun.
DELETE FROM `fact_sponsored_spend`;
DELETE FROM `fact_application`;
DELETE FROM `fact_click`;
DELETE FROM `fact_impression`;
DELETE FROM `fact_search`;

-- ============================================================
-- 1. FACT SEARCH
-- Grain: one row per source search_id.
-- ============================================================

INSERT INTO `fact_search` (
    `search_id`,
    `date_key`,
    `session_id`,
    `job_seeker_id`,
    `device_type`,
    `traffic_source`,
    `searched_at`,
    `query_text`,
    `location_text`,
    `results_count`,
    `page_number`,
    `search_count`
)
SELECT
    s.`search_id`,
    CAST(DATE_FORMAT(DATE(s.`searched_at`), '%Y%m%d') AS UNSIGNED) AS `date_key`,
    s.`session_id`,
    ss.`job_seeker_id`,
    ss.`device_type`,
    ss.`traffic_source`,
    s.`searched_at`,
    s.`query_text`,
    s.`location_text`,
    s.`results_count`,
    s.`page_number`,
    1 AS `search_count`
FROM `talent_flow_source`.`searches` AS s
INNER JOIN `talent_flow_source`.`search_sessions` AS ss
    ON s.`session_id` = ss.`session_id`
ORDER BY s.`search_id`;

-- ============================================================
-- 2. FACT IMPRESSION
-- Grain: one row per source impression_id.
-- ============================================================

INSERT INTO `fact_impression` (
    `impression_id`,
    `date_key`,
    `search_id`,
    `job_id`,
    `employer_id`,
    `location_id`,
    `category_id`,
    `campaign_id`,
    `device_type`,
    `traffic_source`,
    `impressed_at`,
    `position`,
    `is_sponsored`,
    `predicted_relevance_score`,
    `bid_amount`,
    `impression_count`
)
SELECT
    i.`impression_id`,
    CAST(DATE_FORMAT(DATE(i.`impressed_at`), '%Y%m%d') AS UNSIGNED) AS `date_key`,
    i.`search_id`,
    i.`job_id`,
    j.`employer_id`,
    j.`location_id`,
    j.`primary_category_id` AS `category_id`,
    i.`campaign_id`,
    ss.`device_type`,
    ss.`traffic_source`,
    i.`impressed_at`,
    i.`position`,
    i.`is_sponsored`,
    i.`predicted_relevance_score`,
    i.`bid_amount`,
    1 AS `impression_count`
FROM `talent_flow_source`.`job_impressions` AS i
INNER JOIN `talent_flow_source`.`searches` AS s
    ON i.`search_id` = s.`search_id`
INNER JOIN `talent_flow_source`.`search_sessions` AS ss
    ON s.`session_id` = ss.`session_id`
INNER JOIN `talent_flow_source`.`job_posts` AS j
    ON i.`job_id` = j.`job_id`
ORDER BY i.`impression_id`;

-- ============================================================
-- 3. FACT CLICK
-- Grain: one row per source click_id.
-- Search, marketplace, and campaign context are inherited from
-- the impression that generated the click.
-- ============================================================

INSERT INTO `fact_click` (
    `click_id`,
    `date_key`,
    `impression_id`,
    `search_id`,
    `job_id`,
    `employer_id`,
    `location_id`,
    `category_id`,
    `campaign_id`,
    `device_type`,
    `traffic_source`,
    `clicked_at`,
    `dwell_seconds`,
    `click_count`
)
SELECT
    c.`click_id`,
    CAST(DATE_FORMAT(DATE(c.`clicked_at`), '%Y%m%d') AS UNSIGNED) AS `date_key`,
    c.`impression_id`,
    i.`search_id`,
    i.`job_id`,
    j.`employer_id`,
    j.`location_id`,
    j.`primary_category_id` AS `category_id`,
    i.`campaign_id`,
    ss.`device_type`,
    ss.`traffic_source`,
    c.`clicked_at`,
    c.`dwell_seconds`,
    1 AS `click_count`
FROM `talent_flow_source`.`job_clicks` AS c
INNER JOIN `talent_flow_source`.`job_impressions` AS i
    ON c.`impression_id` = i.`impression_id`
INNER JOIN `talent_flow_source`.`searches` AS s
    ON i.`search_id` = s.`search_id`
INNER JOIN `talent_flow_source`.`search_sessions` AS ss
    ON s.`session_id` = ss.`session_id`
INNER JOIN `talent_flow_source`.`job_posts` AS j
    ON i.`job_id` = j.`job_id`
ORDER BY c.`click_id`;

-- ============================================================
-- 4. FACT APPLICATION
-- Grain: one row per source application_id.
--
-- Applications attributed to a click inherit campaign, device,
-- and traffic-source context through:
-- application -> click -> impression -> search -> session.
--
-- Direct, saved-job, and email-alert applications can have a
-- NULL click_id; their campaign/device/traffic fields remain NULL.
-- ============================================================

INSERT INTO `fact_application` (
    `application_id`,
    `date_key`,
    `job_id`,
    `employer_id`,
    `location_id`,
    `category_id`,
    `campaign_id`,
    `device_type`,
    `traffic_source`,
    `job_seeker_id`,
    `click_id`,
    `started_at`,
    `submitted_at`,
    `application_status`,
    `application_source`,
    `completion_seconds`,
    `application_count`,
    `submitted_count`,
    `hired_count`
)
SELECT
    a.`application_id`,
    CAST(DATE_FORMAT(DATE(a.`started_at`), '%Y%m%d') AS UNSIGNED) AS `date_key`,
    a.`job_id`,
    j.`employer_id`,
    j.`location_id`,
    j.`primary_category_id` AS `category_id`,
    i.`campaign_id`,
    ss.`device_type`,
    ss.`traffic_source`,
    a.`job_seeker_id`,
    a.`click_id`,
    a.`started_at`,
    a.`submitted_at`,
    a.`application_status`,
    a.`application_source`,
    a.`completion_seconds`,
    1 AS `application_count`,
    CASE
        WHEN a.`submitted_at` IS NOT NULL THEN 1
        ELSE 0
    END AS `submitted_count`,
    CASE
        WHEN a.`application_status` = 'hired' THEN 1
        ELSE 0
    END AS `hired_count`
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
ORDER BY a.`application_id`;

-- ============================================================
-- 5. FACT SPONSORED SPEND
-- Grain: one row per spend_date, campaign_id, and job_id.
-- ============================================================

INSERT INTO `fact_sponsored_spend` (
    `date_key`,
    `campaign_id`,
    `job_id`,
    `employer_id`,
    `location_id`,
    `category_id`,
    `sponsored_impressions`,
    `sponsored_clicks`,
    `sponsored_applications`,
    `billed_units`,
    `unit_cost`,
    `spend_amount`
)
SELECT
    CAST(DATE_FORMAT(s.`spend_date`, '%Y%m%d') AS UNSIGNED) AS `date_key`,
    s.`campaign_id`,
    s.`job_id`,
    j.`employer_id`,
    j.`location_id`,
    j.`primary_category_id` AS `category_id`,
    s.`sponsored_impressions`,
    s.`sponsored_clicks`,
    s.`sponsored_applications`,
    s.`billed_units`,
    s.`unit_cost`,
    s.`spend_amount`
FROM `talent_flow_source`.`sponsored_spend_daily` AS s
INNER JOIN `talent_flow_source`.`job_posts` AS j
    ON s.`job_id` = j.`job_id`
ORDER BY s.`spend_date`, s.`campaign_id`, s.`job_id`;

COMMIT;

SET SQL_SAFE_UPDATES = @previous_sql_safe_updates;

-- ============================================================
-- POST-LOAD ROW-COUNT RECONCILIATION
-- source_row_count and fact_row_count should match on every row.
-- ============================================================

SELECT
    'fact_search' AS `fact_table`,
    (SELECT COUNT(*) FROM `talent_flow_source`.`searches`) AS `source_row_count`,
    (SELECT COUNT(*) FROM `fact_search`) AS `fact_row_count`
UNION ALL
SELECT
    'fact_impression',
    (SELECT COUNT(*) FROM `talent_flow_source`.`job_impressions`),
    (SELECT COUNT(*) FROM `fact_impression`)
UNION ALL
SELECT
    'fact_click',
    (SELECT COUNT(*) FROM `talent_flow_source`.`job_clicks`),
    (SELECT COUNT(*) FROM `fact_click`)
UNION ALL
SELECT
    'fact_application',
    (SELECT COUNT(*) FROM `talent_flow_source`.`applications`),
    (SELECT COUNT(*) FROM `fact_application`)
UNION ALL
SELECT
    'fact_sponsored_spend',
    (SELECT COUNT(*) FROM `talent_flow_source`.`sponsored_spend_daily`),
    (SELECT COUNT(*) FROM `fact_sponsored_spend`);

-- ============================================================
-- BUSINESS-SANITY CHECKS
-- ============================================================

SELECT
    SUM(`search_count`) AS `searches`,
    SUM(`results_count`) AS `total_results_returned`
FROM `fact_search`;

SELECT
    SUM(`impression_count`) AS `impressions`,
    SUM(`is_sponsored`) AS `sponsored_impressions`
FROM `fact_impression`;

SELECT
    SUM(`click_count`) AS `clicks`,
    ROUND(
        100.0 * SUM(`click_count`)
        / NULLIF((SELECT SUM(`impression_count`) FROM `fact_impression`), 0),
        2
    ) AS `overall_ctr_pct`
FROM `fact_click`;

SELECT
    SUM(`application_count`) AS `applications_started`,
    SUM(`submitted_count`) AS `applications_submitted`,
    SUM(`hired_count`) AS `hires`
FROM `fact_application`;

SELECT
    SUM(`sponsored_impressions`) AS `sponsored_impressions`,
    SUM(`sponsored_clicks`) AS `sponsored_clicks`,
    SUM(`sponsored_applications`) AS `sponsored_applications`,
    ROUND(SUM(`spend_amount`), 2) AS `total_spend`
FROM `fact_sponsored_spend`;

-- These should all return 0.
SELECT
    (SELECT COUNT(*)
     FROM `fact_search` AS f
     LEFT JOIN `dim_date` AS d
       ON f.`date_key` = d.`date_key`
     WHERE d.`date_key` IS NULL) AS `searches_with_missing_date`,
    (SELECT COUNT(*)
     FROM `fact_impression` AS f
     LEFT JOIN `dim_job` AS d
       ON f.`job_id` = d.`job_id`
     WHERE d.`job_id` IS NULL) AS `impressions_with_missing_job`,
    (SELECT COUNT(*)
     FROM `fact_click` AS f
     LEFT JOIN `dim_employer` AS d
       ON f.`employer_id` = d.`employer_id`
     WHERE d.`employer_id` IS NULL) AS `clicks_with_missing_employer`,
    (SELECT COUNT(*)
     FROM `fact_application` AS f
     LEFT JOIN `dim_location` AS d
       ON f.`location_id` = d.`location_id`
     WHERE d.`location_id` IS NULL) AS `applications_with_missing_location`,
    (SELECT COUNT(*)
     FROM `fact_sponsored_spend` AS f
     LEFT JOIN `dim_campaign` AS d
       ON f.`campaign_id` = d.`campaign_id`
     WHERE d.`campaign_id` IS NULL) AS `spend_rows_with_missing_campaign`;