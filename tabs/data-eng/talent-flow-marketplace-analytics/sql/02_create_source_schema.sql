USE talent_flow_source;

CREATE TABLE `employers` (
  `employer_id` bigint PRIMARY KEY AUTO_INCREMENT,
  `employer_name` varchar(200) NOT NULL,
  `industry` varchar(100) NOT NULL,
  `company_size_band` varchar(50) NOT NULL,
  `country_code` char(2) NOT NULL,
  `is_verified` boolean NOT NULL DEFAULT false,
  `created_at` datetime NOT NULL
);

CREATE TABLE `locations` (
  `location_id` bigint PRIMARY KEY AUTO_INCREMENT,
  `city` varchar(100) NOT NULL,
  `state_region` varchar(100),
  `country_code` char(2) NOT NULL,
  `postal_code` varchar(20),
  `latitude` decimal(9,6),
  `longitude` decimal(9,6)
);

CREATE TABLE `job_categories` (
  `category_id` bigint PRIMARY KEY AUTO_INCREMENT,
  `category_name` varchar(100) NOT NULL,
  `category_family` varchar(100) NOT NULL,
  `parent_category_id` bigint
);

CREATE TABLE `skills` (
  `skill_id` bigint PRIMARY KEY AUTO_INCREMENT,
  `skill_name` varchar(100) NOT NULL,
  `skill_family` varchar(100) NOT NULL
);

CREATE TABLE `job_posts` (
  `job_id` bigint PRIMARY KEY AUTO_INCREMENT,
  `employer_id` bigint NOT NULL,
  `location_id` bigint NOT NULL,
  `primary_category_id` bigint NOT NULL,
  `job_title` varchar(200) NOT NULL,
  `employment_type` varchar(50) NOT NULL,
  `experience_level` varchar(50) NOT NULL,
  `remote_type` varchar(50) NOT NULL,
  `salary_min` decimal(12,2),
  `salary_max` decimal(12,2),
  `salary_currency` char(3),
  `posted_at` datetime NOT NULL,
  `expires_at` datetime,
  `status` ENUM ('draft', 'active', 'paused', 'closed', 'expired') NOT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL
);

CREATE TABLE `job_skills` (
  `job_id` bigint NOT NULL,
  `skill_id` bigint NOT NULL,
  `is_required` boolean NOT NULL DEFAULT true,
  PRIMARY KEY (`job_id`, `skill_id`)
);

CREATE TABLE `job_seekers` (
  `job_seeker_id` bigint PRIMARY KEY AUTO_INCREMENT,
  `country_code` char(2) NOT NULL,
  `experience_level` varchar(50),
  `created_at` datetime NOT NULL,
  `marketing_opt_in` boolean NOT NULL DEFAULT false
);

CREATE TABLE `search_sessions` (
  `session_id` char(36) PRIMARY KEY,
  `job_seeker_id` bigint,
  `anonymous_user_id` char(36) NOT NULL,
  `started_at` datetime NOT NULL,
  `device_type` ENUM ('desktop', 'mobile_web', 'ios', 'android') NOT NULL,
  `traffic_source` varchar(50) NOT NULL,
  `country_code` char(2) NOT NULL
);

CREATE TABLE `searches` (
  `search_id` bigint PRIMARY KEY AUTO_INCREMENT,
  `session_id` char(36) NOT NULL,
  `searched_at` datetime NOT NULL,
  `query_text` varchar(255),
  `location_text` varchar(255),
  `filters_json` json,
  `results_count` int NOT NULL,
  `page_number` int NOT NULL DEFAULT 1
);

CREATE TABLE `sponsorship_campaigns` (
  `campaign_id` bigint PRIMARY KEY AUTO_INCREMENT,
  `employer_id` bigint NOT NULL,
  `campaign_name` varchar(200) NOT NULL,
  `start_date` date NOT NULL,
  `end_date` date,
  `daily_budget` decimal(12,2) NOT NULL,
  `billing_model` ENUM ('cpc', 'cpa') NOT NULL,
  `campaign_status` ENUM ('planned', 'active', 'paused', 'completed') NOT NULL,
  `created_at` datetime NOT NULL
);

CREATE TABLE `campaign_jobs` (
  `campaign_id` bigint NOT NULL,
  `job_id` bigint NOT NULL,
  `added_at` datetime NOT NULL,
  PRIMARY KEY (`campaign_id`, `job_id`)
);

CREATE TABLE `job_impressions` (
  `impression_id` bigint PRIMARY KEY AUTO_INCREMENT,
  `search_id` bigint NOT NULL,
  `job_id` bigint NOT NULL,
  `campaign_id` bigint,
  `impressed_at` datetime NOT NULL,
  `position` int NOT NULL,
  `is_sponsored` boolean NOT NULL DEFAULT false,
  `predicted_relevance_score` decimal(5,4),
  `bid_amount` decimal(10,2)
);

CREATE TABLE `job_clicks` (
  `click_id` bigint PRIMARY KEY AUTO_INCREMENT,
  `impression_id` bigint NOT NULL,
  `clicked_at` datetime NOT NULL,
  `dwell_seconds` int
);

CREATE TABLE `applications` (
  `application_id` bigint PRIMARY KEY AUTO_INCREMENT,
  `job_id` bigint NOT NULL,
  `job_seeker_id` bigint NOT NULL,
  `click_id` bigint,
  `started_at` datetime NOT NULL,
  `submitted_at` datetime,
  `application_status` ENUM ('started', 'submitted', 'reviewed', 'rejected', 'hired', 'withdrawn') NOT NULL,
  `application_source` varchar(50) NOT NULL,
  `completion_seconds` int
);

CREATE TABLE `sponsored_spend_daily` (
  `spend_date` date NOT NULL,
  `campaign_id` bigint NOT NULL,
  `job_id` bigint NOT NULL,
  `sponsored_impressions` int NOT NULL,
  `sponsored_clicks` int NOT NULL,
  `sponsored_applications` int NOT NULL,
  `billed_units` int NOT NULL,
  `unit_cost` decimal(10,2) NOT NULL,
  `spend_amount` decimal(12,2) NOT NULL,
  PRIMARY KEY (`spend_date`, `campaign_id`, `job_id`)
);

CREATE INDEX `employers_index_0` ON `employers` (`employer_name`);

CREATE INDEX `employers_index_1` ON `employers` (`industry`);

CREATE INDEX `locations_index_2` ON `locations` (`country_code`, `state_region`, `city`);

CREATE UNIQUE INDEX `job_categories_index_3` ON `job_categories` (`category_name`);

CREATE UNIQUE INDEX `skills_index_4` ON `skills` (`skill_name`);

CREATE INDEX `job_posts_index_5` ON `job_posts` (`employer_id`);

CREATE INDEX `job_posts_index_6` ON `job_posts` (`location_id`);

CREATE INDEX `job_posts_index_7` ON `job_posts` (`primary_category_id`);

CREATE INDEX `job_posts_index_8` ON `job_posts` (`posted_at`);

CREATE INDEX `job_posts_index_9` ON `job_posts` (`status`);

CREATE INDEX `search_sessions_index_10` ON `search_sessions` (`job_seeker_id`);

CREATE INDEX `search_sessions_index_11` ON `search_sessions` (`started_at`);

CREATE INDEX `search_sessions_index_12` ON `search_sessions` (`device_type`);

CREATE INDEX `search_sessions_index_13` ON `search_sessions` (`traffic_source`);

CREATE INDEX `searches_index_14` ON `searches` (`session_id`);

CREATE INDEX `searches_index_15` ON `searches` (`searched_at`);

CREATE INDEX `searches_index_16` ON `searches` (`results_count`);

CREATE INDEX `sponsorship_campaigns_index_17` ON `sponsorship_campaigns` (`employer_id`);

CREATE INDEX `sponsorship_campaigns_index_18` ON `sponsorship_campaigns` (`start_date`);

CREATE INDEX `sponsorship_campaigns_index_19` ON `sponsorship_campaigns` (`campaign_status`);

CREATE INDEX `job_impressions_index_20` ON `job_impressions` (`search_id`);

CREATE INDEX `job_impressions_index_21` ON `job_impressions` (`job_id`);

CREATE INDEX `job_impressions_index_22` ON `job_impressions` (`campaign_id`);

CREATE INDEX `job_impressions_index_23` ON `job_impressions` (`impressed_at`);

CREATE INDEX `job_impressions_index_24` ON `job_impressions` (`is_sponsored`);

CREATE UNIQUE INDEX `job_impressions_index_25` ON `job_impressions` (`search_id`, `job_id`, `position`);

CREATE UNIQUE INDEX `job_clicks_index_26` ON `job_clicks` (`impression_id`);

CREATE INDEX `job_clicks_index_27` ON `job_clicks` (`clicked_at`);

CREATE INDEX `applications_index_28` ON `applications` (`job_id`);

CREATE INDEX `applications_index_29` ON `applications` (`job_seeker_id`);

CREATE INDEX `applications_index_30` ON `applications` (`click_id`);

CREATE INDEX `applications_index_31` ON `applications` (`started_at`);

CREATE INDEX `applications_index_32` ON `applications` (`submitted_at`);

CREATE INDEX `applications_index_33` ON `applications` (`application_status`);

CREATE INDEX `sponsored_spend_daily_index_34` ON `sponsored_spend_daily` (`campaign_id`);

CREATE INDEX `sponsored_spend_daily_index_35` ON `sponsored_spend_daily` (`job_id`);

ALTER TABLE `job_categories` ADD FOREIGN KEY (`parent_category_id`) REFERENCES `job_categories` (`category_id`);

ALTER TABLE `job_posts` ADD FOREIGN KEY (`employer_id`) REFERENCES `employers` (`employer_id`);

ALTER TABLE `job_posts` ADD FOREIGN KEY (`location_id`) REFERENCES `locations` (`location_id`);

ALTER TABLE `job_posts` ADD FOREIGN KEY (`primary_category_id`) REFERENCES `job_categories` (`category_id`);

ALTER TABLE `job_skills` ADD FOREIGN KEY (`job_id`) REFERENCES `job_posts` (`job_id`);

ALTER TABLE `job_skills` ADD FOREIGN KEY (`skill_id`) REFERENCES `skills` (`skill_id`);

ALTER TABLE `search_sessions` ADD FOREIGN KEY (`job_seeker_id`) REFERENCES `job_seekers` (`job_seeker_id`);

ALTER TABLE `searches` ADD FOREIGN KEY (`session_id`) REFERENCES `search_sessions` (`session_id`);

ALTER TABLE `sponsorship_campaigns` ADD FOREIGN KEY (`employer_id`) REFERENCES `employers` (`employer_id`);

ALTER TABLE `campaign_jobs` ADD FOREIGN KEY (`campaign_id`) REFERENCES `sponsorship_campaigns` (`campaign_id`);

ALTER TABLE `campaign_jobs` ADD FOREIGN KEY (`job_id`) REFERENCES `job_posts` (`job_id`);

ALTER TABLE `job_impressions` ADD FOREIGN KEY (`search_id`) REFERENCES `searches` (`search_id`);

ALTER TABLE `job_impressions` ADD FOREIGN KEY (`job_id`) REFERENCES `job_posts` (`job_id`);

ALTER TABLE `job_impressions` ADD FOREIGN KEY (`campaign_id`) REFERENCES `sponsorship_campaigns` (`campaign_id`);

ALTER TABLE `job_clicks` ADD FOREIGN KEY (`impression_id`) REFERENCES `job_impressions` (`impression_id`);

ALTER TABLE `applications` ADD FOREIGN KEY (`job_id`) REFERENCES `job_posts` (`job_id`);

ALTER TABLE `applications` ADD FOREIGN KEY (`job_seeker_id`) REFERENCES `job_seekers` (`job_seeker_id`);

ALTER TABLE `applications` ADD FOREIGN KEY (`click_id`) REFERENCES `job_clicks` (`click_id`);

ALTER TABLE `sponsored_spend_daily` ADD FOREIGN KEY (`campaign_id`) REFERENCES `sponsorship_campaigns` (`campaign_id`);

ALTER TABLE `sponsored_spend_daily` ADD FOREIGN KEY (`job_id`) REFERENCES `job_posts` (`job_id`);
