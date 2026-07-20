-- Talent Flow analytics views
-- File: sql/07_create_analytics_views.sql
-- MySQL 8.4
--
-- Run after:
--   sql/04_create_analytics_schema.sql
--   sql/05_load_dimensions.sql
--   sql/06_load_facts.sql
--
-- Fanout rule:
-- Never join impression, click, application, and spend facts directly.
-- Stack additive measures with UNION ALL, then aggregate at one declared grain.

USE `talent_flow_analytics`;

DROP VIEW IF EXISTS `vw_campaign_performance_daily`;
DROP VIEW IF EXISTS `vw_employer_performance_daily`;
DROP VIEW IF EXISTS `vw_job_performance_daily`;
DROP VIEW IF EXISTS `vw_marketplace_daily`;
DROP VIEW IF EXISTS `vw_sponsored_performance_daily`;
DROP VIEW IF EXISTS `vw_sponsored_performance_daily_base`;
DROP VIEW IF EXISTS `vw_job_funnel_daily`;
DROP VIEW IF EXISTS `vw_job_funnel_daily_base`;
DROP VIEW IF EXISTS `vw_search_performance_daily`;

-- ============================================================
-- 1. SEARCH PERFORMANCE
-- Grain: date + device_type + traffic_source
-- ============================================================

CREATE VIEW `vw_search_performance_daily` AS
SELECT
    f.`date_key`,
    d.`full_date`,
    d.`day_of_week_name`,
    d.`week_of_year`,
    d.`month_number`,
    d.`month_name`,
    d.`quarter_number`,
    d.`year_number`,
    f.`device_type`,
    dd.`device_group`,
    f.`traffic_source`,
    dt.`channel_group`,
    SUM(f.`search_count`) AS `searches`,
    SUM(f.`results_count`) AS `results_returned`,
    ROUND(
        SUM(f.`results_count`) / NULLIF(SUM(f.`search_count`), 0),
        2
    ) AS `avg_results_per_search`,
    COUNT(DISTINCT f.`session_id`) AS `search_sessions`,
    COUNT(DISTINCT f.`job_seeker_id`) AS `identified_job_seekers`
FROM `fact_search` AS f
INNER JOIN `dim_date` AS d
    ON f.`date_key` = d.`date_key`
INNER JOIN `dim_device` AS dd
    ON f.`device_type` = dd.`device_type`
INNER JOIN `dim_traffic_source` AS dt
    ON f.`traffic_source` = dt.`traffic_source`
GROUP BY
    f.`date_key`,
    d.`full_date`,
    d.`day_of_week_name`,
    d.`week_of_year`,
    d.`month_number`,
    d.`month_name`,
    d.`quarter_number`,
    d.`year_number`,
    f.`device_type`,
    dd.`device_group`,
    f.`traffic_source`,
    dt.`channel_group`;

-- ============================================================
-- 2. JOB FUNNEL BASE
-- Grain: date + job + employer + location + category
--        + campaign + device_type + traffic_source
-- ============================================================

CREATE VIEW `vw_job_funnel_daily_base` AS
SELECT
    x.`date_key`,
    x.`job_id`,
    x.`employer_id`,
    x.`location_id`,
    x.`category_id`,
    x.`campaign_id`,
    x.`device_type`,
    x.`traffic_source`,
    SUM(x.`impressions`) AS `impressions`,
    SUM(x.`sponsored_impressions`) AS `sponsored_impressions`,
    SUM(x.`position_sum`) AS `position_sum`,
    SUM(x.`position_observations`) AS `position_observations`,
    SUM(x.`relevance_sum`) AS `relevance_sum`,
    SUM(x.`relevance_observations`) AS `relevance_observations`,
    SUM(x.`bid_sum`) AS `bid_sum`,
    SUM(x.`bid_observations`) AS `bid_observations`,
    SUM(x.`clicks`) AS `clicks`,
    SUM(x.`dwell_seconds_sum`) AS `dwell_seconds_sum`,
    SUM(x.`dwell_observations`) AS `dwell_observations`,
    SUM(x.`applications_started`) AS `applications_started`,
    SUM(x.`applications_submitted`) AS `applications_submitted`,
    SUM(x.`hires`) AS `hires`
FROM (
    SELECT
        i.`date_key`,
        i.`job_id`,
        i.`employer_id`,
        i.`location_id`,
        i.`category_id`,
        i.`campaign_id`,
        i.`device_type`,
        i.`traffic_source`,
        i.`impression_count` AS `impressions`,
        CASE WHEN i.`is_sponsored` = 1
             THEN i.`impression_count` ELSE 0 END AS `sponsored_impressions`,
        i.`position` * i.`impression_count` AS `position_sum`,
        CASE WHEN i.`position` IS NOT NULL
             THEN i.`impression_count` ELSE 0 END AS `position_observations`,
        CASE WHEN i.`predicted_relevance_score` IS NOT NULL
             THEN i.`predicted_relevance_score` * i.`impression_count`
             ELSE 0 END AS `relevance_sum`,
        CASE WHEN i.`predicted_relevance_score` IS NOT NULL
             THEN i.`impression_count` ELSE 0 END AS `relevance_observations`,
        CASE WHEN i.`bid_amount` IS NOT NULL
             THEN i.`bid_amount` * i.`impression_count`
             ELSE 0 END AS `bid_sum`,
        CASE WHEN i.`bid_amount` IS NOT NULL
             THEN i.`impression_count` ELSE 0 END AS `bid_observations`,
        0 AS `clicks`,
        0 AS `dwell_seconds_sum`,
        0 AS `dwell_observations`,
        0 AS `applications_started`,
        0 AS `applications_submitted`,
        0 AS `hires`
    FROM `fact_impression` AS i

    UNION ALL

    SELECT
        c.`date_key`,
        c.`job_id`,
        c.`employer_id`,
        c.`location_id`,
        c.`category_id`,
        c.`campaign_id`,
        c.`device_type`,
        c.`traffic_source`,
        0, 0, 0, 0, 0, 0, 0, 0,
        c.`click_count`,
        CASE WHEN c.`dwell_seconds` IS NOT NULL
             THEN c.`dwell_seconds` * c.`click_count` ELSE 0 END,
        CASE WHEN c.`dwell_seconds` IS NOT NULL
             THEN c.`click_count` ELSE 0 END,
        0, 0, 0
    FROM `fact_click` AS c

    UNION ALL

    SELECT
        a.`date_key`,
        a.`job_id`,
        a.`employer_id`,
        a.`location_id`,
        a.`category_id`,
        a.`campaign_id`,
        a.`device_type`,
        a.`traffic_source`,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0,
        a.`application_count`,
        a.`submitted_count`,
        a.`hired_count`
    FROM `fact_application` AS a
) AS x
GROUP BY
    x.`date_key`,
    x.`job_id`,
    x.`employer_id`,
    x.`location_id`,
    x.`category_id`,
    x.`campaign_id`,
    x.`device_type`,
    x.`traffic_source`;

-- ============================================================
-- 3. ENRICHED JOB FUNNEL
-- Same grain as vw_job_funnel_daily_base
-- ============================================================

CREATE VIEW `vw_job_funnel_daily` AS
SELECT
    b.`date_key`,
    d.`full_date`,
    d.`day_of_week_name`,
    d.`week_of_year`,
    d.`month_number`,
    d.`month_name`,
    d.`quarter_number`,
    d.`year_number`,

    b.`job_id`,
    j.`job_title`,
    j.`employment_type`,
    j.`experience_level`,
    j.`remote_type`,
    j.`salary_min`,
    j.`salary_max`,
    j.`salary_currency`,
    j.`job_status`,

    b.`employer_id`,
    e.`employer_name`,
    e.`industry`,
    e.`company_size_band`,
    e.`country_code` AS `employer_country_code`,
    e.`is_verified` AS `employer_is_verified`,

    b.`location_id`,
    l.`city`,
    l.`state_region`,
    l.`country_code` AS `job_country_code`,

    b.`category_id`,
    cat.`category_name`,
    cat.`category_family`,
    cat.`parent_category_name`,

    b.`campaign_id`,
    camp.`campaign_name`,
    camp.`billing_model`,
    camp.`campaign_status`,

    b.`device_type`,
    dev.`device_group`,
    b.`traffic_source`,
    traffic.`channel_group`,

    b.`impressions`,
    b.`sponsored_impressions`,
    b.`clicks`,
    b.`applications_started`,
    b.`applications_submitted`,
    b.`hires`,

    ROUND(b.`position_sum` /
          NULLIF(b.`position_observations`, 0), 2) AS `avg_position`,
    ROUND(b.`relevance_sum` /
          NULLIF(b.`relevance_observations`, 0), 4) AS `avg_relevance_score`,
    ROUND(b.`bid_sum` /
          NULLIF(b.`bid_observations`, 0), 2) AS `avg_bid_amount`,
    ROUND(b.`dwell_seconds_sum` /
          NULLIF(b.`dwell_observations`, 0), 2) AS `avg_dwell_seconds`,

    ROUND(100.0 * b.`clicks` /
          NULLIF(b.`impressions`, 0), 2) AS `ctr_pct`,
    ROUND(100.0 * b.`applications_started` /
          NULLIF(b.`impressions`, 0), 2) AS `impression_to_application_pct`,
    ROUND(100.0 * b.`applications_started` /
          NULLIF(b.`clicks`, 0), 2) AS `click_to_application_pct`,
    ROUND(100.0 * b.`applications_submitted` /
          NULLIF(b.`applications_started`, 0), 2) AS `application_submit_rate_pct`,
    ROUND(100.0 * b.`hires` /
          NULLIF(b.`applications_submitted`, 0), 2) AS `submitted_to_hire_rate_pct`
FROM `vw_job_funnel_daily_base` AS b
INNER JOIN `dim_date` AS d
    ON b.`date_key` = d.`date_key`
INNER JOIN `dim_job` AS j
    ON b.`job_id` = j.`job_id`
INNER JOIN `dim_employer` AS e
    ON b.`employer_id` = e.`employer_id`
INNER JOIN `dim_location` AS l
    ON b.`location_id` = l.`location_id`
INNER JOIN `dim_category` AS cat
    ON b.`category_id` = cat.`category_id`
LEFT JOIN `dim_campaign` AS camp
    ON b.`campaign_id` = camp.`campaign_id`
LEFT JOIN `dim_device` AS dev
    ON b.`device_type` = dev.`device_type`
LEFT JOIN `dim_traffic_source` AS traffic
    ON b.`traffic_source` = traffic.`traffic_source`;

-- ============================================================
-- 4. SPONSORED PERFORMANCE BASE
-- Grain: date + campaign + job + employer + location + category
-- ============================================================

CREATE VIEW `vw_sponsored_performance_daily_base` AS
SELECT
    x.`date_key`,
    x.`campaign_id`,
    x.`job_id`,
    x.`employer_id`,
    x.`location_id`,
    x.`category_id`,
    SUM(x.`event_impressions`) AS `event_impressions`,
    SUM(x.`event_clicks`) AS `event_clicks`,
    SUM(x.`event_applications`) AS `event_applications`,
    SUM(x.`event_submissions`) AS `event_submissions`,
    SUM(x.`event_hires`) AS `event_hires`,
    SUM(x.`billed_impressions`) AS `billed_impressions`,
    SUM(x.`billed_clicks`) AS `billed_clicks`,
    SUM(x.`billed_applications`) AS `billed_applications`,
    SUM(x.`billed_units`) AS `billed_units`,
    SUM(x.`spend_amount`) AS `spend_amount`,
    SUM(x.`unit_cost_weighted_sum`) AS `unit_cost_weighted_sum`,
    SUM(x.`unit_cost_weight`) AS `unit_cost_weight`
FROM (
    SELECT
        i.`date_key`, i.`campaign_id`, i.`job_id`,
        i.`employer_id`, i.`location_id`, i.`category_id`,
        i.`impression_count`,
        0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0
    FROM `fact_impression` AS i
    WHERE i.`campaign_id` IS NOT NULL
      AND i.`is_sponsored` = 1

    UNION ALL

    SELECT
        c.`date_key`, c.`campaign_id`, c.`job_id`,
        c.`employer_id`, c.`location_id`, c.`category_id`,
        0, c.`click_count`, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0
    FROM `fact_click` AS c
    WHERE c.`campaign_id` IS NOT NULL

    UNION ALL

    SELECT
        a.`date_key`, a.`campaign_id`, a.`job_id`,
        a.`employer_id`, a.`location_id`, a.`category_id`,
        0, 0, a.`application_count`, a.`submitted_count`, a.`hired_count`,
        0, 0, 0, 0, 0, 0, 0
    FROM `fact_application` AS a
    WHERE a.`campaign_id` IS NOT NULL

    UNION ALL

    SELECT
        s.`date_key`, s.`campaign_id`, s.`job_id`,
        s.`employer_id`, s.`location_id`, s.`category_id`,
        0, 0, 0, 0, 0,
        s.`sponsored_impressions`,
        s.`sponsored_clicks`,
        s.`sponsored_applications`,
        s.`billed_units`,
        s.`spend_amount`,
        s.`unit_cost` * s.`billed_units`,
        s.`billed_units`
    FROM `fact_sponsored_spend` AS s
) AS x (
    `date_key`, `campaign_id`, `job_id`,
    `employer_id`, `location_id`, `category_id`,
    `event_impressions`, `event_clicks`, `event_applications`,
    `event_submissions`, `event_hires`,
    `billed_impressions`, `billed_clicks`, `billed_applications`,
    `billed_units`, `spend_amount`,
    `unit_cost_weighted_sum`, `unit_cost_weight`
)
GROUP BY
    x.`date_key`,
    x.`campaign_id`,
    x.`job_id`,
    x.`employer_id`,
    x.`location_id`,
    x.`category_id`;


-- ============================================================
-- 5. ENRICHED SPONSORED PERFORMANCE
-- Same grain as vw_sponsored_performance_daily_base
-- ============================================================

CREATE VIEW `vw_sponsored_performance_daily` AS
SELECT
    b.`date_key`,
    d.`full_date`,
    d.`week_of_year`,
    d.`month_number`,
    d.`month_name`,
    d.`quarter_number`,
    d.`year_number`,

    b.`campaign_id`,
    camp.`campaign_name`,
    camp.`billing_model`,
    camp.`campaign_status`,
    camp.`daily_budget`,

    b.`job_id`,
    j.`job_title`,
    j.`employment_type`,
    j.`experience_level`,
    j.`remote_type`,

    b.`employer_id`,
    e.`employer_name`,
    e.`industry`,
    e.`company_size_band`,

    b.`location_id`,
    l.`city`,
    l.`state_region`,
    l.`country_code` AS `job_country_code`,

    b.`category_id`,
    cat.`category_name`,
    cat.`category_family`,

    b.`event_impressions`,
    b.`event_clicks`,
    b.`event_applications`,
    b.`event_submissions`,
    b.`event_hires`,

    b.`billed_impressions`,
    b.`billed_clicks`,
    b.`billed_applications`,
    b.`billed_units`,
    ROUND(
        b.`unit_cost_weighted_sum` / NULLIF(b.`unit_cost_weight`, 0),
        2
    ) AS `avg_unit_cost`,
    ROUND(b.`spend_amount`, 2) AS `spend_amount`,

    ROUND(
        100.0 * b.`event_clicks` / NULLIF(b.`event_impressions`, 0),
        2
    ) AS `event_ctr_pct`,
    ROUND(
        100.0 * b.`event_applications` / NULLIF(b.`event_clicks`, 0),
        2
    ) AS `event_click_to_application_pct`,
    ROUND(
        b.`spend_amount` / NULLIF(b.`event_clicks`, 0),
        2
    ) AS `cost_per_event_click`,
    ROUND(
        b.`spend_amount` / NULLIF(b.`event_applications`, 0),
        2
    ) AS `cost_per_event_application`,
    ROUND(
        1000.0 * b.`spend_amount` / NULLIF(b.`event_impressions`, 0),
        2
    ) AS `cost_per_thousand_event_impressions`,
    ROUND(
        b.`spend_amount` / NULLIF(b.`billed_clicks`, 0),
        2
    ) AS `cost_per_billed_click`,
    ROUND(
        b.`spend_amount` / NULLIF(b.`billed_applications`, 0),
        2
    ) AS `cost_per_billed_application`
FROM `vw_sponsored_performance_daily_base` AS b
INNER JOIN `dim_date` AS d
    ON b.`date_key` = d.`date_key`
INNER JOIN `dim_campaign` AS camp
    ON b.`campaign_id` = camp.`campaign_id`
INNER JOIN `dim_job` AS j
    ON b.`job_id` = j.`job_id`
INNER JOIN `dim_employer` AS e
    ON b.`employer_id` = e.`employer_id`
INNER JOIN `dim_location` AS l
    ON b.`location_id` = l.`location_id`
INNER JOIN `dim_category` AS cat
    ON b.`category_id` = cat.`category_id`;

-- ============================================================
-- 6. MARKETPLACE DAILY OVERVIEW
-- Grain: one row per date
-- ============================================================

CREATE VIEW `vw_marketplace_daily` AS
SELECT
    totals.`date_key`,
    d.`full_date`,
    d.`day_of_week_name`,
    d.`week_of_year`,
    d.`month_number`,
    d.`month_name`,
    d.`quarter_number`,
    d.`year_number`,
    d.`is_weekend`,

    totals.`searches`,
    totals.`results_returned`,
    totals.`impressions`,
    totals.`sponsored_impressions`,
    totals.`clicks`,
    totals.`applications_started`,
    totals.`applications_submitted`,
    totals.`hires`,
    ROUND(totals.`spend_amount`, 2) AS `sponsored_spend`,

    ROUND(
        100.0 * totals.`clicks` / NULLIF(totals.`impressions`, 0),
        2
    ) AS `ctr_pct`,
    ROUND(
        100.0 * totals.`applications_started`
        / NULLIF(totals.`clicks`, 0),
        2
    ) AS `click_to_application_pct`,
    ROUND(
        100.0 * totals.`applications_submitted`
        / NULLIF(totals.`applications_started`, 0),
        2
    ) AS `application_submit_rate_pct`,
    ROUND(
        100.0 * totals.`hires`
        / NULLIF(totals.`applications_submitted`, 0),
        2
    ) AS `submitted_to_hire_rate_pct`,
    ROUND(
        totals.`spend_amount` / NULLIF(totals.`clicks`, 0),
        2
    ) AS `sponsored_spend_per_all_clicks`,
    ROUND(
        totals.`spend_amount`
        / NULLIF(totals.`applications_started`, 0),
        2
    ) AS `sponsored_spend_per_all_applications`
FROM (
    SELECT
        x.`date_key`,
        SUM(x.`searches`) AS `searches`,
        SUM(x.`results_returned`) AS `results_returned`,
        SUM(x.`impressions`) AS `impressions`,
        SUM(x.`sponsored_impressions`) AS `sponsored_impressions`,
        SUM(x.`clicks`) AS `clicks`,
        SUM(x.`applications_started`) AS `applications_started`,
        SUM(x.`applications_submitted`) AS `applications_submitted`,
        SUM(x.`hires`) AS `hires`,
        SUM(x.`spend_amount`) AS `spend_amount`
    FROM (
        SELECT
            f.`date_key`,
            SUM(f.`search_count`) AS `searches`,
            SUM(f.`results_count`) AS `results_returned`,
            0 AS `impressions`,
            0 AS `sponsored_impressions`,
            0 AS `clicks`,
            0 AS `applications_started`,
            0 AS `applications_submitted`,
            0 AS `hires`,
            0 AS `spend_amount`
        FROM `fact_search` AS f
        GROUP BY f.`date_key`

        UNION ALL

        SELECT
            f.`date_key`,
            0, 0,
            SUM(f.`impression_count`),
            SUM(CASE WHEN f.`is_sponsored` = 1
                     THEN f.`impression_count` ELSE 0 END),
            0, 0, 0, 0, 0
        FROM `fact_impression` AS f
        GROUP BY f.`date_key`

        UNION ALL

        SELECT
            f.`date_key`,
            0, 0, 0, 0,
            SUM(f.`click_count`),
            0, 0, 0, 0
        FROM `fact_click` AS f
        GROUP BY f.`date_key`

        UNION ALL

        SELECT
            f.`date_key`,
            0, 0, 0, 0, 0,
            SUM(f.`application_count`),
            SUM(f.`submitted_count`),
            SUM(f.`hired_count`),
            0
        FROM `fact_application` AS f
        GROUP BY f.`date_key`

        UNION ALL

        SELECT
            f.`date_key`,
            0, 0, 0, 0, 0, 0, 0, 0,
            SUM(f.`spend_amount`)
        FROM `fact_sponsored_spend` AS f
        GROUP BY f.`date_key`
    ) AS x
    GROUP BY x.`date_key`
) AS totals
INNER JOIN `dim_date` AS d
    ON totals.`date_key` = d.`date_key`;

-- ============================================================
-- 7. JOB PERFORMANCE
-- Grain: one row per date + job
-- ============================================================

CREATE VIEW `vw_job_performance_daily` AS
SELECT
    b.`date_key`,
    d.`full_date`,
    d.`week_of_year`,
    d.`month_number`,
    d.`month_name`,
    d.`quarter_number`,
    d.`year_number`,

    b.`job_id`,
    j.`job_title`,
    j.`employment_type`,
    j.`experience_level`,
    j.`remote_type`,
    j.`salary_min`,
    j.`salary_max`,
    j.`salary_currency`,
    j.`job_status`,

    b.`employer_id`,
    e.`employer_name`,
    e.`industry`,
    e.`company_size_band`,

    b.`location_id`,
    l.`city`,
    l.`state_region`,
    l.`country_code` AS `job_country_code`,

    b.`category_id`,
    cat.`category_name`,
    cat.`category_family`,

    SUM(b.`impressions`) AS `impressions`,
    SUM(b.`sponsored_impressions`) AS `sponsored_impressions`,
    SUM(b.`clicks`) AS `clicks`,
    SUM(b.`applications_started`) AS `applications_started`,
    SUM(b.`applications_submitted`) AS `applications_submitted`,
    SUM(b.`hires`) AS `hires`,

    ROUND(
        SUM(b.`position_sum`) / NULLIF(SUM(b.`position_observations`), 0),
        2
    ) AS `avg_position`,
    ROUND(
        SUM(b.`relevance_sum`) / NULLIF(SUM(b.`relevance_observations`), 0),
        4
    ) AS `avg_relevance_score`,
    ROUND(
        SUM(b.`dwell_seconds_sum`) / NULLIF(SUM(b.`dwell_observations`), 0),
        2
    ) AS `avg_dwell_seconds`,
    ROUND(
        100.0 * SUM(b.`clicks`) / NULLIF(SUM(b.`impressions`), 0),
        2
    ) AS `ctr_pct`,
    ROUND(
        100.0 * SUM(b.`applications_started`)
        / NULLIF(SUM(b.`clicks`), 0),
        2
    ) AS `click_to_application_pct`,
    ROUND(
        100.0 * SUM(b.`applications_submitted`)
        / NULLIF(SUM(b.`applications_started`), 0),
        2
    ) AS `application_submit_rate_pct`
FROM `vw_job_funnel_daily_base` AS b
INNER JOIN `dim_date` AS d
    ON b.`date_key` = d.`date_key`
INNER JOIN `dim_job` AS j
    ON b.`job_id` = j.`job_id`
INNER JOIN `dim_employer` AS e
    ON b.`employer_id` = e.`employer_id`
INNER JOIN `dim_location` AS l
    ON b.`location_id` = l.`location_id`
INNER JOIN `dim_category` AS cat
    ON b.`category_id` = cat.`category_id`
GROUP BY
    b.`date_key`,
    d.`full_date`,
    d.`week_of_year`,
    d.`month_number`,
    d.`month_name`,
    d.`quarter_number`,
    d.`year_number`,
    b.`job_id`,
    j.`job_title`,
    j.`employment_type`,
    j.`experience_level`,
    j.`remote_type`,
    j.`salary_min`,
    j.`salary_max`,
    j.`salary_currency`,
    j.`job_status`,
    b.`employer_id`,
    e.`employer_name`,
    e.`industry`,
    e.`company_size_band`,
    b.`location_id`,
    l.`city`,
    l.`state_region`,
    l.`country_code`,
    b.`category_id`,
    cat.`category_name`,
    cat.`category_family`;

-- ============================================================
-- 8. EMPLOYER PERFORMANCE
-- Grain: one row per date + employer
-- ============================================================

CREATE VIEW `vw_employer_performance_daily` AS
SELECT
    b.`date_key`,
    d.`full_date`,
    d.`week_of_year`,
    d.`month_number`,
    d.`month_name`,
    d.`quarter_number`,
    d.`year_number`,

    b.`employer_id`,
    e.`employer_name`,
    e.`industry`,
    e.`company_size_band`,
    e.`country_code`,
    e.`is_verified`,

    COUNT(DISTINCT b.`job_id`) AS `jobs_with_activity`,
    SUM(b.`impressions`) AS `impressions`,
    SUM(b.`sponsored_impressions`) AS `sponsored_impressions`,
    SUM(b.`clicks`) AS `clicks`,
    SUM(b.`applications_started`) AS `applications_started`,
    SUM(b.`applications_submitted`) AS `applications_submitted`,
    SUM(b.`hires`) AS `hires`,

    ROUND(
        100.0 * SUM(b.`clicks`) / NULLIF(SUM(b.`impressions`), 0),
        2
    ) AS `ctr_pct`,
    ROUND(
        100.0 * SUM(b.`applications_started`)
        / NULLIF(SUM(b.`clicks`), 0),
        2
    ) AS `click_to_application_pct`,
    ROUND(
        100.0 * SUM(b.`applications_submitted`)
        / NULLIF(SUM(b.`applications_started`), 0),
        2
    ) AS `application_submit_rate_pct`,
    ROUND(
        100.0 * SUM(b.`hires`)
        / NULLIF(SUM(b.`applications_submitted`), 0),
        2
    ) AS `submitted_to_hire_rate_pct`
FROM `vw_job_funnel_daily_base` AS b
INNER JOIN `dim_date` AS d
    ON b.`date_key` = d.`date_key`
INNER JOIN `dim_employer` AS e
    ON b.`employer_id` = e.`employer_id`
GROUP BY
    b.`date_key`,
    d.`full_date`,
    d.`week_of_year`,
    d.`month_number`,
    d.`month_name`,
    d.`quarter_number`,
    d.`year_number`,
    b.`employer_id`,
    e.`employer_name`,
    e.`industry`,
    e.`company_size_band`,
    e.`country_code`,
    e.`is_verified`;

-- ============================================================
-- 9. CAMPAIGN PERFORMANCE
-- Grain: one row per date + campaign
-- ============================================================

CREATE VIEW `vw_campaign_performance_daily` AS
SELECT
    b.`date_key`,
    d.`full_date`,
    d.`week_of_year`,
    d.`month_number`,
    d.`month_name`,
    d.`quarter_number`,
    d.`year_number`,

    b.`campaign_id`,
    camp.`campaign_name`,
    camp.`billing_model`,
    camp.`campaign_status`,
    camp.`daily_budget`,
    camp.`start_date`,
    camp.`end_date`,

    COUNT(DISTINCT b.`job_id`) AS `promoted_jobs`,
    SUM(b.`event_impressions`) AS `event_impressions`,
    SUM(b.`event_clicks`) AS `event_clicks`,
    SUM(b.`event_applications`) AS `event_applications`,
    SUM(b.`event_submissions`) AS `event_submissions`,
    SUM(b.`event_hires`) AS `event_hires`,
    SUM(b.`billed_impressions`) AS `billed_impressions`,
    SUM(b.`billed_clicks`) AS `billed_clicks`,
    SUM(b.`billed_applications`) AS `billed_applications`,
    SUM(b.`billed_units`) AS `billed_units`,
    ROUND(SUM(b.`spend_amount`), 2) AS `spend_amount`,

    ROUND(
        SUM(b.`unit_cost_weighted_sum`)
        / NULLIF(SUM(b.`unit_cost_weight`), 0),
        2
    ) AS `avg_unit_cost`,
    ROUND(
        100.0 * SUM(b.`event_clicks`)
        / NULLIF(SUM(b.`event_impressions`), 0),
        2
    ) AS `event_ctr_pct`,
    ROUND(
        100.0 * SUM(b.`event_applications`)
        / NULLIF(SUM(b.`event_clicks`), 0),
        2
    ) AS `event_click_to_application_pct`,
    ROUND(
        SUM(b.`spend_amount`) / NULLIF(SUM(b.`event_clicks`), 0),
        2
    ) AS `cost_per_event_click`,
    ROUND(
        SUM(b.`spend_amount`)
        / NULLIF(SUM(b.`event_applications`), 0),
        2
    ) AS `cost_per_event_application`,
    ROUND(
        100.0 * SUM(b.`spend_amount`)
        / NULLIF(camp.`daily_budget`, 0),
        2
    ) AS `daily_budget_utilization_pct`
FROM `vw_sponsored_performance_daily_base` AS b
INNER JOIN `dim_date` AS d
    ON b.`date_key` = d.`date_key`
INNER JOIN `dim_campaign` AS camp
    ON b.`campaign_id` = camp.`campaign_id`
GROUP BY
    b.`date_key`,
    d.`full_date`,
    d.`week_of_year`,
    d.`month_number`,
    d.`month_name`,
    d.`quarter_number`,
    d.`year_number`,
    b.`campaign_id`,
    camp.`campaign_name`,
    camp.`billing_model`,
    camp.`campaign_status`,
    camp.`daily_budget`,
    camp.`start_date`,
    camp.`end_date`;

-- ============================================================
-- VALIDATION
-- ============================================================

-- Confirm all nine views exist.
SELECT
    `table_name` AS `view_name`
FROM `information_schema`.`views`
WHERE `table_schema` = 'talent_flow_analytics'
ORDER BY `table_name`;

-- Fact totals and view totals must match.
SELECT
    'impressions' AS `metric`,
    (SELECT SUM(`impression_count`) FROM `fact_impression`) AS `fact_total`,
    (SELECT SUM(`impressions`) FROM `vw_job_funnel_daily_base`) AS `view_total`
UNION ALL
SELECT
    'clicks',
    (SELECT SUM(`click_count`) FROM `fact_click`),
    (SELECT SUM(`clicks`) FROM `vw_job_funnel_daily_base`)
UNION ALL
SELECT
    'applications_started',
    (SELECT SUM(`application_count`) FROM `fact_application`),
    (SELECT SUM(`applications_started`) FROM `vw_job_funnel_daily_base`)
UNION ALL
SELECT
    'applications_submitted',
    (SELECT SUM(`submitted_count`) FROM `fact_application`),
    (SELECT SUM(`applications_submitted`) FROM `vw_job_funnel_daily_base`)
UNION ALL
SELECT
    'hires',
    (SELECT SUM(`hired_count`) FROM `fact_application`),
    (SELECT SUM(`hires`) FROM `vw_job_funnel_daily_base`)
UNION ALL
SELECT
    'sponsored_spend',
    (SELECT ROUND(SUM(`spend_amount`), 2)
     FROM `fact_sponsored_spend`),
    (SELECT ROUND(SUM(`spend_amount`), 2)
     FROM `vw_sponsored_performance_daily_base`);

-- Every difference should equal zero.
SELECT
    (SELECT SUM(`impression_count`) FROM `fact_impression`)
      - (SELECT SUM(`impressions`) FROM `vw_job_funnel_daily_base`)
        AS `impression_difference`,
    (SELECT SUM(`click_count`) FROM `fact_click`)
      - (SELECT SUM(`clicks`) FROM `vw_job_funnel_daily_base`)
        AS `click_difference`,
    (SELECT SUM(`application_count`) FROM `fact_application`)
      - (SELECT SUM(`applications_started`)
         FROM `vw_job_funnel_daily_base`)
        AS `application_difference`,
    ROUND(
        (SELECT SUM(`spend_amount`) FROM `fact_sponsored_spend`)
        -
        (SELECT SUM(`spend_amount`)
         FROM `vw_sponsored_performance_daily_base`),
        2
    ) AS `spend_difference`;

-- Preview the presentation views.
SELECT *
FROM `vw_marketplace_daily`
ORDER BY `full_date`
LIMIT 10;

SELECT *
FROM `vw_job_performance_daily`
ORDER BY `full_date`, `impressions` DESC
LIMIT 10;

SELECT *
FROM `vw_campaign_performance_daily`
ORDER BY `full_date`, `spend_amount` DESC
LIMIT 10;
