-- Talent Flow analytics star schema
-- File: sql/04_create_analytics_schema.sql
-- MySQL 8.4
--
-- WARNING:
-- This script drops and recreates the analytics tables.
-- It does not modify talent_flow_source.

CREATE DATABASE IF NOT EXISTS `talent_flow_analytics`
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_0900_ai_ci;

USE `talent_flow_analytics`;

SET FOREIGN_KEY_CHECKS = 0;

DROP TABLE IF EXISTS `fact_sponsored_spend`;
DROP TABLE IF EXISTS `fact_application`;
DROP TABLE IF EXISTS `fact_click`;
DROP TABLE IF EXISTS `fact_impression`;
DROP TABLE IF EXISTS `fact_search`;

DROP TABLE IF EXISTS `dim_campaign`;
DROP TABLE IF EXISTS `dim_traffic_source`;
DROP TABLE IF EXISTS `dim_device`;
DROP TABLE IF EXISTS `dim_category`;
DROP TABLE IF EXISTS `dim_location`;
DROP TABLE IF EXISTS `dim_job`;
DROP TABLE IF EXISTS `dim_employer`;
DROP TABLE IF EXISTS `dim_date`;

SET FOREIGN_KEY_CHECKS = 1;

-- ============================================================
-- DIMENSIONS
-- ============================================================

CREATE TABLE `dim_date` (
  `date_key` INT UNSIGNED NOT NULL,
  `full_date` DATE NOT NULL,
  `day_of_week_name` VARCHAR(9) NOT NULL,
  `day_of_month` TINYINT UNSIGNED NOT NULL,
  `week_of_year` TINYINT UNSIGNED NOT NULL,
  `month_number` TINYINT UNSIGNED NOT NULL,
  `month_name` VARCHAR(9) NOT NULL,
  `quarter_number` TINYINT UNSIGNED NOT NULL,
  `year_number` SMALLINT UNSIGNED NOT NULL,
  `is_weekend` BOOLEAN NOT NULL,
  PRIMARY KEY (`date_key`),
  UNIQUE KEY `uq_dim_date_full_date` (`full_date`),
  KEY `idx_dim_date_year_month` (`year_number`, `month_number`)
) ENGINE=InnoDB;

CREATE TABLE `dim_employer` (
  `employer_id` BIGINT NOT NULL,
  `employer_name` VARCHAR(200) NOT NULL,
  `industry` VARCHAR(100) NOT NULL,
  `company_size_band` VARCHAR(50) NOT NULL,
  `country_code` CHAR(2) NOT NULL,
  `is_verified` BOOLEAN NOT NULL,
  PRIMARY KEY (`employer_id`),
  KEY `idx_dim_employer_name` (`employer_name`),
  KEY `idx_dim_employer_industry` (`industry`)
) ENGINE=InnoDB;

CREATE TABLE `dim_job` (
  `job_id` BIGINT NOT NULL,
  `job_title` VARCHAR(200) NOT NULL,
  `employment_type` VARCHAR(50) NOT NULL,
  `experience_level` VARCHAR(50) NOT NULL,
  `remote_type` VARCHAR(50) NOT NULL,
  `salary_min` DECIMAL(12,2),
  `salary_max` DECIMAL(12,2),
  `salary_currency` CHAR(3),
  `posted_date` DATE NOT NULL,
  `job_status` VARCHAR(20) NOT NULL,
  PRIMARY KEY (`job_id`),
  KEY `idx_dim_job_title` (`job_title`),
  KEY `idx_dim_job_status` (`job_status`),
  KEY `idx_dim_job_posted_date` (`posted_date`)
) ENGINE=InnoDB;

CREATE TABLE `dim_location` (
  `location_id` BIGINT NOT NULL,
  `city` VARCHAR(100) NOT NULL,
  `state_region` VARCHAR(100),
  `country_code` CHAR(2) NOT NULL,
  `postal_code` VARCHAR(20),
  PRIMARY KEY (`location_id`),
  KEY `idx_dim_location_geography` (`country_code`, `state_region`, `city`)
) ENGINE=InnoDB;

CREATE TABLE `dim_category` (
  `category_id` BIGINT NOT NULL,
  `category_name` VARCHAR(100) NOT NULL,
  `category_family` VARCHAR(100) NOT NULL,
  `parent_category_name` VARCHAR(100),
  PRIMARY KEY (`category_id`),
  UNIQUE KEY `uq_dim_category_name` (`category_name`),
  KEY `idx_dim_category_family` (`category_family`)
) ENGINE=InnoDB;

CREATE TABLE `dim_device` (
  `device_type` VARCHAR(20) NOT NULL,
  `device_group` VARCHAR(20) NOT NULL,
  PRIMARY KEY (`device_type`),
  KEY `idx_dim_device_group` (`device_group`)
) ENGINE=InnoDB;

CREATE TABLE `dim_traffic_source` (
  `traffic_source` VARCHAR(50) NOT NULL,
  `channel_group` VARCHAR(20) NOT NULL,
  PRIMARY KEY (`traffic_source`),
  KEY `idx_dim_traffic_channel_group` (`channel_group`)
) ENGINE=InnoDB;

CREATE TABLE `dim_campaign` (
  `campaign_id` BIGINT NOT NULL,
  `campaign_name` VARCHAR(200) NOT NULL,
  `billing_model` VARCHAR(10) NOT NULL,
  `campaign_status` VARCHAR(20) NOT NULL,
  `start_date` DATE NOT NULL,
  `end_date` DATE,
  `daily_budget` DECIMAL(12,2) NOT NULL,
  PRIMARY KEY (`campaign_id`),
  KEY `idx_dim_campaign_status` (`campaign_status`),
  KEY `idx_dim_campaign_start_date` (`start_date`)
) ENGINE=InnoDB;

-- ============================================================
-- FACT TABLES
-- These remain empty until sql/06_load_facts.sql is executed.
-- ============================================================

CREATE TABLE `fact_search` (
  `search_id` BIGINT NOT NULL,
  `date_key` INT UNSIGNED NOT NULL,
  `session_id` CHAR(36) NOT NULL,
  `job_seeker_id` BIGINT,
  `device_type` VARCHAR(20) NOT NULL,
  `traffic_source` VARCHAR(50) NOT NULL,
  `searched_at` DATETIME NOT NULL,
  `query_text` VARCHAR(255),
  `location_text` VARCHAR(255),
  `results_count` INT NOT NULL,
  `page_number` INT NOT NULL,
  `search_count` TINYINT UNSIGNED NOT NULL DEFAULT 1,
  PRIMARY KEY (`search_id`),
  KEY `idx_fact_search_date` (`date_key`),
  KEY `idx_fact_search_session` (`session_id`),
  KEY `idx_fact_search_device` (`device_type`),
  KEY `idx_fact_search_traffic` (`traffic_source`),
  CONSTRAINT `fk_fact_search_date`
    FOREIGN KEY (`date_key`) REFERENCES `dim_date` (`date_key`),
  CONSTRAINT `fk_fact_search_device`
    FOREIGN KEY (`device_type`) REFERENCES `dim_device` (`device_type`),
  CONSTRAINT `fk_fact_search_traffic`
    FOREIGN KEY (`traffic_source`) REFERENCES `dim_traffic_source` (`traffic_source`)
) ENGINE=InnoDB;

CREATE TABLE `fact_impression` (
  `impression_id` BIGINT NOT NULL,
  `date_key` INT UNSIGNED NOT NULL,
  `search_id` BIGINT NOT NULL,
  `job_id` BIGINT NOT NULL,
  `employer_id` BIGINT NOT NULL,
  `location_id` BIGINT NOT NULL,
  `category_id` BIGINT NOT NULL,
  `campaign_id` BIGINT,
  `device_type` VARCHAR(20) NOT NULL,
  `traffic_source` VARCHAR(50) NOT NULL,
  `impressed_at` DATETIME NOT NULL,
  `position` INT NOT NULL,
  `is_sponsored` BOOLEAN NOT NULL,
  `predicted_relevance_score` DECIMAL(5,4),
  `bid_amount` DECIMAL(10,2),
  `impression_count` TINYINT UNSIGNED NOT NULL DEFAULT 1,
  PRIMARY KEY (`impression_id`),
  KEY `idx_fact_impression_date` (`date_key`),
  KEY `idx_fact_impression_search` (`search_id`),
  KEY `idx_fact_impression_job` (`job_id`),
  KEY `idx_fact_impression_employer` (`employer_id`),
  KEY `idx_fact_impression_location` (`location_id`),
  KEY `idx_fact_impression_category` (`category_id`),
  KEY `idx_fact_impression_campaign` (`campaign_id`),
  KEY `idx_fact_impression_device` (`device_type`),
  KEY `idx_fact_impression_traffic` (`traffic_source`),
  CONSTRAINT `fk_fact_impression_date`
    FOREIGN KEY (`date_key`) REFERENCES `dim_date` (`date_key`),
  CONSTRAINT `fk_fact_impression_job`
    FOREIGN KEY (`job_id`) REFERENCES `dim_job` (`job_id`),
  CONSTRAINT `fk_fact_impression_employer`
    FOREIGN KEY (`employer_id`) REFERENCES `dim_employer` (`employer_id`),
  CONSTRAINT `fk_fact_impression_location`
    FOREIGN KEY (`location_id`) REFERENCES `dim_location` (`location_id`),
  CONSTRAINT `fk_fact_impression_category`
    FOREIGN KEY (`category_id`) REFERENCES `dim_category` (`category_id`),
  CONSTRAINT `fk_fact_impression_campaign`
    FOREIGN KEY (`campaign_id`) REFERENCES `dim_campaign` (`campaign_id`),
  CONSTRAINT `fk_fact_impression_device`
    FOREIGN KEY (`device_type`) REFERENCES `dim_device` (`device_type`),
  CONSTRAINT `fk_fact_impression_traffic`
    FOREIGN KEY (`traffic_source`) REFERENCES `dim_traffic_source` (`traffic_source`)
) ENGINE=InnoDB;

CREATE TABLE `fact_click` (
  `click_id` BIGINT NOT NULL,
  `date_key` INT UNSIGNED NOT NULL,
  `impression_id` BIGINT NOT NULL,
  `search_id` BIGINT NOT NULL,
  `job_id` BIGINT NOT NULL,
  `employer_id` BIGINT NOT NULL,
  `location_id` BIGINT NOT NULL,
  `category_id` BIGINT NOT NULL,
  `campaign_id` BIGINT,
  `device_type` VARCHAR(20) NOT NULL,
  `traffic_source` VARCHAR(50) NOT NULL,
  `clicked_at` DATETIME NOT NULL,
  `dwell_seconds` INT,
  `click_count` TINYINT UNSIGNED NOT NULL DEFAULT 1,
  PRIMARY KEY (`click_id`),
  UNIQUE KEY `uq_fact_click_impression` (`impression_id`),
  KEY `idx_fact_click_date` (`date_key`),
  KEY `idx_fact_click_search` (`search_id`),
  KEY `idx_fact_click_job` (`job_id`),
  KEY `idx_fact_click_employer` (`employer_id`),
  KEY `idx_fact_click_location` (`location_id`),
  KEY `idx_fact_click_category` (`category_id`),
  KEY `idx_fact_click_campaign` (`campaign_id`),
  KEY `idx_fact_click_device` (`device_type`),
  KEY `idx_fact_click_traffic` (`traffic_source`),
  CONSTRAINT `fk_fact_click_date`
    FOREIGN KEY (`date_key`) REFERENCES `dim_date` (`date_key`),
  CONSTRAINT `fk_fact_click_job`
    FOREIGN KEY (`job_id`) REFERENCES `dim_job` (`job_id`),
  CONSTRAINT `fk_fact_click_employer`
    FOREIGN KEY (`employer_id`) REFERENCES `dim_employer` (`employer_id`),
  CONSTRAINT `fk_fact_click_location`
    FOREIGN KEY (`location_id`) REFERENCES `dim_location` (`location_id`),
  CONSTRAINT `fk_fact_click_category`
    FOREIGN KEY (`category_id`) REFERENCES `dim_category` (`category_id`),
  CONSTRAINT `fk_fact_click_campaign`
    FOREIGN KEY (`campaign_id`) REFERENCES `dim_campaign` (`campaign_id`),
  CONSTRAINT `fk_fact_click_device`
    FOREIGN KEY (`device_type`) REFERENCES `dim_device` (`device_type`),
  CONSTRAINT `fk_fact_click_traffic`
    FOREIGN KEY (`traffic_source`) REFERENCES `dim_traffic_source` (`traffic_source`)
) ENGINE=InnoDB;

CREATE TABLE `fact_application` (
  `application_id` BIGINT NOT NULL,
  `date_key` INT UNSIGNED NOT NULL,
  `job_id` BIGINT NOT NULL,
  `employer_id` BIGINT NOT NULL,
  `location_id` BIGINT NOT NULL,
  `category_id` BIGINT NOT NULL,
  `campaign_id` BIGINT,
  `device_type` VARCHAR(20),
  `traffic_source` VARCHAR(50),
  `job_seeker_id` BIGINT NOT NULL,
  `click_id` BIGINT,
  `started_at` DATETIME NOT NULL,
  `submitted_at` DATETIME,
  `application_status` VARCHAR(20) NOT NULL,
  `application_source` VARCHAR(50) NOT NULL,
  `completion_seconds` INT,
  `application_count` TINYINT UNSIGNED NOT NULL DEFAULT 1,
  `submitted_count` TINYINT UNSIGNED NOT NULL DEFAULT 0,
  `hired_count` TINYINT UNSIGNED NOT NULL DEFAULT 0,
  PRIMARY KEY (`application_id`),
  KEY `idx_fact_application_date` (`date_key`),
  KEY `idx_fact_application_job` (`job_id`),
  KEY `idx_fact_application_employer` (`employer_id`),
  KEY `idx_fact_application_location` (`location_id`),
  KEY `idx_fact_application_category` (`category_id`),
  KEY `idx_fact_application_campaign` (`campaign_id`),
  KEY `idx_fact_application_device` (`device_type`),
  KEY `idx_fact_application_traffic` (`traffic_source`),
  KEY `idx_fact_application_status` (`application_status`),
  CONSTRAINT `fk_fact_application_date`
    FOREIGN KEY (`date_key`) REFERENCES `dim_date` (`date_key`),
  CONSTRAINT `fk_fact_application_job`
    FOREIGN KEY (`job_id`) REFERENCES `dim_job` (`job_id`),
  CONSTRAINT `fk_fact_application_employer`
    FOREIGN KEY (`employer_id`) REFERENCES `dim_employer` (`employer_id`),
  CONSTRAINT `fk_fact_application_location`
    FOREIGN KEY (`location_id`) REFERENCES `dim_location` (`location_id`),
  CONSTRAINT `fk_fact_application_category`
    FOREIGN KEY (`category_id`) REFERENCES `dim_category` (`category_id`),
  CONSTRAINT `fk_fact_application_campaign`
    FOREIGN KEY (`campaign_id`) REFERENCES `dim_campaign` (`campaign_id`),
  CONSTRAINT `fk_fact_application_device`
    FOREIGN KEY (`device_type`) REFERENCES `dim_device` (`device_type`),
  CONSTRAINT `fk_fact_application_traffic`
    FOREIGN KEY (`traffic_source`) REFERENCES `dim_traffic_source` (`traffic_source`)
) ENGINE=InnoDB;

CREATE TABLE `fact_sponsored_spend` (
  `date_key` INT UNSIGNED NOT NULL,
  `campaign_id` BIGINT NOT NULL,
  `job_id` BIGINT NOT NULL,
  `employer_id` BIGINT NOT NULL,
  `location_id` BIGINT NOT NULL,
  `category_id` BIGINT NOT NULL,
  `sponsored_impressions` INT NOT NULL,
  `sponsored_clicks` INT NOT NULL,
  `sponsored_applications` INT NOT NULL,
  `billed_units` INT NOT NULL,
  `unit_cost` DECIMAL(10,2) NOT NULL,
  `spend_amount` DECIMAL(12,2) NOT NULL,
  PRIMARY KEY (`date_key`, `campaign_id`, `job_id`),
  KEY `idx_fact_spend_campaign` (`campaign_id`),
  KEY `idx_fact_spend_job` (`job_id`),
  KEY `idx_fact_spend_employer` (`employer_id`),
  KEY `idx_fact_spend_location` (`location_id`),
  KEY `idx_fact_spend_category` (`category_id`),
  CONSTRAINT `fk_fact_spend_date`
    FOREIGN KEY (`date_key`) REFERENCES `dim_date` (`date_key`),
  CONSTRAINT `fk_fact_spend_campaign`
    FOREIGN KEY (`campaign_id`) REFERENCES `dim_campaign` (`campaign_id`),
  CONSTRAINT `fk_fact_spend_job`
    FOREIGN KEY (`job_id`) REFERENCES `dim_job` (`job_id`),
  CONSTRAINT `fk_fact_spend_employer`
    FOREIGN KEY (`employer_id`) REFERENCES `dim_employer` (`employer_id`),
  CONSTRAINT `fk_fact_spend_location`
    FOREIGN KEY (`location_id`) REFERENCES `dim_location` (`location_id`),
  CONSTRAINT `fk_fact_spend_category`
    FOREIGN KEY (`category_id`) REFERENCES `dim_category` (`category_id`)
) ENGINE=InnoDB;

-- Confirm that the schema was created.
SELECT
  `table_name`,
  `table_type`
FROM `information_schema`.`tables`
WHERE `table_schema` = 'talent_flow_analytics'
ORDER BY `table_name`;
