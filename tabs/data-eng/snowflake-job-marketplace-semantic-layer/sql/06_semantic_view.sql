/* ============================================================
   FILE: 06_semantic_view.sql
   PURPOSE:
     Create the governed marketplace semantic contract.
   ============================================================ */

USE ROLE JOB_MARKETPLACE_SEMANTIC_OWNER;
USE WAREHOUSE JOB_MARKETPLACE_WH;
USE DATABASE JOB_MARKETPLACE;
USE SCHEMA SEMANTIC;

CREATE OR REPLACE SEMANTIC VIEW JOB_MARKETPLACE_PERFORMANCE

TABLES (

    EMPLOYERS AS JOB_MARKETPLACE.ANALYTICS.DIM_EMPLOYER
        PRIMARY KEY (EMPLOYER_ID)
        WITH SYNONYMS (
            'COMPANIES',
            'CLIENTS',
            'ADVERTISERS',
            'HIRING COMPANIES'
        )
        COMMENT = 'Employer accounts purchasing or using marketplace recruiting services'
        WITH TAG (
            JOB_MARKETPLACE.GOVERNANCE.DATA_DOMAIN = 'JOB_MARKETPLACE'
        ),

    JOBS AS JOB_MARKETPLACE.ANALYTICS.DIM_JOB
        PRIMARY KEY (JOB_ID)
        WITH SYNONYMS (
            'JOB POSTINGS',
            'VACANCIES',
            'OPEN ROLES'
        )
        COMMENT = 'Individual job postings available in the marketplace'
        WITH TAG (
            JOB_MARKETPLACE.GOVERNANCE.DATA_DOMAIN = 'JOB_MARKETPLACE'
        ),

    CALENDAR AS JOB_MARKETPLACE.ANALYTICS.DIM_DATE
        PRIMARY KEY (DATE_DAY)
        WITH SYNONYMS (
            'DATE',
            'REPORTING CALENDAR'
        )
        COMMENT = 'Calendar attributes used to aggregate marketplace activity over time'
        WITH TAG (
            JOB_MARKETPLACE.GOVERNANCE.DATA_DOMAIN = 'JOB_MARKETPLACE'
        ),

    PERFORMANCE AS JOB_MARKETPLACE.ANALYTICS.FCT_JOB_PERFORMANCE_DAILY
        PRIMARY KEY (
            EVENT_DATE,
            JOB_ID,
            DEVICE_TYPE,
            TRAFFIC_SOURCE
        )
        WITH SYNONYMS (
            'FUNNEL PERFORMANCE',
            'JOB PERFORMANCE',
            'MARKETPLACE ACTIVITY'
        )
        COMMENT = 'Daily job funnel activity by job, device, and traffic source'
        WITH TAG (
            JOB_MARKETPLACE.GOVERNANCE.DATA_DOMAIN = 'JOB_MARKETPLACE'
        )
)

RELATIONSHIPS (

    JOBS_TO_EMPLOYERS AS
        JOBS (EMPLOYER_ID)
        REFERENCES EMPLOYERS,

    PERFORMANCE_TO_JOBS AS
        PERFORMANCE (JOB_ID)
        REFERENCES JOBS,

    PERFORMANCE_TO_CALENDAR AS
        PERFORMANCE (EVENT_DATE)
        REFERENCES CALENDAR (DATE_DAY)
)

FACTS (

    PRIVATE PERFORMANCE.JOB_KEY
        AS JOB_ID
        COMMENT = 'Private job identifier used for distinct-job metrics',

    PRIVATE PERFORMANCE.IMPRESSION_UNITS
        AS IMPRESSIONS
        COMMENT = 'Private additive impression amount',

    PRIVATE PERFORMANCE.CLICK_UNITS
        AS CLICKS
        COMMENT = 'Private additive click amount',

    PRIVATE PERFORMANCE.APPLICATION_UNITS
        AS APPLICATIONS
        COMMENT = 'Private additive completed application amount',

    PRIVATE PERFORMANCE.QUALIFIED_APPLICATION_UNITS
        AS QUALIFIED_APPLICATIONS
        COMMENT = 'Private additive qualified application amount',

    PRIVATE PERFORMANCE.HIRE_UNITS
        AS HIRES
        COMMENT = 'Private additive attributed hire amount',

    PRIVATE PERFORMANCE.SPONSORED_SPEND_UNITS
        AS SPONSORED_SPEND_USD
        COMMENT = 'Private additive sponsored media spend in US dollars'
)

DIMENSIONS (

    EMPLOYERS.EMPLOYER_NAME
        AS EMPLOYER_NAME
        WITH SYNONYMS (
            'COMPANY',
            'CLIENT',
            'ADVERTISER'
        )
        WITH TAG (
            JOB_MARKETPLACE.GOVERNANCE.DATA_CLASSIFICATION = 'INTERNAL'
        )
        COMMENT = 'Display name of the employer account',

    EMPLOYERS.EMPLOYER_SEGMENT
        AS EMPLOYER_SEGMENT
        WITH SYNONYMS (
            'CLIENT SEGMENT',
            'ACCOUNT SEGMENT'
        )
        COMMENT = 'Commercial segment assigned to the employer',

    EMPLOYERS.ACCOUNT_REGION
        AS ACCOUNT_REGION
        COMMENT = 'Internal region responsible for managing the employer account',

    EMPLOYERS.ACCOUNT_MANAGER_NAME
        AS ACCOUNT_MANAGER_NAME
        COMMENT = 'Internal owner responsible for the employer relationship',

    EMPLOYERS.ACCOUNT_MANAGER_EMAIL
        AS ACCOUNT_MANAGER_EMAIL
        WITH TAG (
            JOB_MARKETPLACE.GOVERNANCE.DATA_CLASSIFICATION = 'CONFIDENTIAL'
        )
        COMMENT = 'Internal employer account contact email protected by masking policy',

    JOBS.JOB_TITLE
        AS JOB_TITLE
        WITH SYNONYMS (
            'ROLE TITLE',
            'POSITION TITLE'
        )
        COMMENT = 'Title displayed on the job posting',

    JOBS.JOB_CATEGORY
        AS JOB_CATEGORY
        WITH SYNONYMS (
            'OCCUPATION CATEGORY',
            'JOB FAMILY'
        )
        COMMENT = 'Standard analytical category assigned to the job',

    JOBS.COUNTRY_CODE
        AS COUNTRY_CODE
        WITH SYNONYMS (
            'COUNTRY',
            'JOB COUNTRY'
        )
        COMMENT = 'ISO-style country code for the job location',

    JOBS.MARKET_REGION
        AS MARKET_REGION
        WITH SYNONYMS (
            'GEOGRAPHIC REGION',
            'MARKET'
        )
        COMMENT = 'Reporting region used for marketplace access control',

    JOBS.SPONSORSHIP_TIER
        AS SPONSORSHIP_TIER
        WITH SYNONYMS (
            'SPONSORED STATUS',
            'PAID TIER'
        )
        COMMENT = 'Commercial sponsorship package associated with the job',

    JOBS.POSTED_DATE
        AS POSTED_DATE
        COMMENT = 'Date the job entered the marketplace',

    JOBS.IS_CURRENTLY_OPEN
        AS IS_CURRENTLY_OPEN
        COMMENT = 'Indicates whether the job remains open in the source data',

    CALENDAR.DATE_DAY
        AS DATE_DAY
        WITH SYNONYMS (
            'DATE',
            'DAY'
        )
        COMMENT = 'Calendar date of the marketplace activity',

    CALENDAR.WEEK_START
        AS WEEK_START
        COMMENT = 'Beginning date of the reporting week',

    CALENDAR.MONTH_START
        AS MONTH_START
        COMMENT = 'Beginning date of the reporting month',

    CALENDAR.QUARTER_START
        AS QUARTER_START
        COMMENT = 'Beginning date of the reporting quarter',

    CALENDAR.CALENDAR_YEAR
        AS CALENDAR_YEAR
        COMMENT = 'Calendar year number',

    CALENDAR.YEAR_MONTH
        AS YEAR_MONTH
        WITH SYNONYMS (
            'REPORTING MONTH',
            'MONTH'
        )
        COMMENT = 'Year and month formatted as YYYY-MM',

    PERFORMANCE.DEVICE_TYPE
        AS DEVICE_TYPE
        WITH SYNONYMS (
            'DEVICE',
            'PLATFORM'
        )
        COMMENT = 'Device category associated with the marketplace activity',

    PERFORMANCE.TRAFFIC_SOURCE
        AS TRAFFIC_SOURCE
        WITH SYNONYMS (
            'CHANNEL',
            'ACQUISITION SOURCE'
        )
        COMMENT = 'Channel responsible for generating marketplace activity'
)

METRICS (

    PUBLIC PERFORMANCE.ACTIVE_JOB_COUNT
        AS COUNT(DISTINCT JOB_KEY)
        WITH SYNONYMS (
            'JOBS WITH ACTIVITY',
            'ACTIVE JOBS'
        )
        WITH TAG (
            JOB_MARKETPLACE.GOVERNANCE.METRIC_TIER = 'CERTIFIED'
        )
        COMMENT = 'Distinct jobs that generated activity in the selected reporting context',

    PUBLIC PERFORMANCE.TOTAL_IMPRESSIONS
        AS SUM(IMPRESSION_UNITS)
        WITH SYNONYMS (
            'IMPRESSIONS',
            'JOB VIEWS'
        )
        WITH TAG (
            JOB_MARKETPLACE.GOVERNANCE.METRIC_TIER = 'CERTIFIED'
        )
        COMMENT = 'Total number of job-result impressions',

    PUBLIC PERFORMANCE.TOTAL_CLICKS
        AS SUM(CLICK_UNITS)
        WITH SYNONYMS (
            'CLICKS',
            'JOB CLICKS'
        )
        WITH TAG (
            JOB_MARKETPLACE.GOVERNANCE.METRIC_TIER = 'CERTIFIED'
        )
        COMMENT = 'Total number of clicks generated from job impressions',

    PUBLIC PERFORMANCE.TOTAL_APPLICATIONS
        AS SUM(APPLICATION_UNITS)
        WITH SYNONYMS (
            'APPLICATIONS',
            'APPLIES',
            'COMPLETED APPLIES'
        )
        WITH TAG (
            JOB_MARKETPLACE.GOVERNANCE.METRIC_TIER = 'CERTIFIED'
        )
        COMMENT = 'Total number of completed application submissions',

    PUBLIC PERFORMANCE.TOTAL_QUALIFIED_APPLICATIONS
        AS SUM(QUALIFIED_APPLICATION_UNITS)
        WITH SYNONYMS (
            'QUALIFIED APPLICATIONS',
            'QUALITY APPLIES'
        )
        WITH TAG (
            JOB_MARKETPLACE.GOVERNANCE.METRIC_TIER = 'CERTIFIED'
        )
        COMMENT = 'Total applications satisfying the marketplace qualification rule',

    PUBLIC PERFORMANCE.TOTAL_HIRES
        AS SUM(HIRE_UNITS)
        WITH SYNONYMS (
            'HIRES',
            'ATTRIBUTED HIRES'
        )
        WITH TAG (
            JOB_MARKETPLACE.GOVERNANCE.METRIC_TIER = 'CERTIFIED'
        )
        COMMENT = 'Total recorded hires attributed to marketplace applications',

    PUBLIC PERFORMANCE.TOTAL_SPONSORED_SPEND_USD
        AS SUM(SPONSORED_SPEND_UNITS)
        WITH SYNONYMS (
            'SPONSORED SPEND',
            'MEDIA SPEND'
        )
        WITH TAG (
            JOB_MARKETPLACE.GOVERNANCE.METRIC_TIER = 'CERTIFIED'
        )
        COMMENT = 'Total sponsored marketplace spend in US dollars',

    PUBLIC PERFORMANCE.CLICK_THROUGH_RATE
        AS SUM(CLICK_UNITS)
           / NULLIF(SUM(IMPRESSION_UNITS), 0)
        WITH SYNONYMS (
            'CTR',
            'CLICK RATE'
        )
        WITH TAG (
            JOB_MARKETPLACE.GOVERNANCE.METRIC_TIER = 'CERTIFIED'
        )
        COMMENT = 'Clicks divided by impressions',

    PUBLIC PERFORMANCE.APPLY_RATE
        AS SUM(APPLICATION_UNITS)
           / NULLIF(SUM(CLICK_UNITS), 0)
        WITH SYNONYMS (
            'APPLICATION RATE',
            'CLICK TO APPLY RATE'
        )
        WITH TAG (
            JOB_MARKETPLACE.GOVERNANCE.METRIC_TIER = 'CERTIFIED'
        )
        COMMENT = 'Completed applications divided by clicks',

    PUBLIC PERFORMANCE.QUALIFIED_APPLICATION_RATE
        AS SUM(QUALIFIED_APPLICATION_UNITS)
           / NULLIF(SUM(APPLICATION_UNITS), 0)
        WITH SYNONYMS (
            'QUALITY APPLY RATE',
            'QUALIFIED APPLY RATE'
        )
        WITH TAG (
            JOB_MARKETPLACE.GOVERNANCE.METRIC_TIER = 'CERTIFIED'
        )
        COMMENT = 'Qualified applications divided by completed applications',

    PUBLIC PERFORMANCE.HIRE_RATE
        AS SUM(HIRE_UNITS)
           / NULLIF(SUM(QUALIFIED_APPLICATION_UNITS), 0)
        WITH SYNONYMS (
            'QUALIFIED APPLY TO HIRE RATE',
            'CONVERSION TO HIRE'
        )
        WITH TAG (
            JOB_MARKETPLACE.GOVERNANCE.METRIC_TIER = 'CERTIFIED'
        )
        COMMENT = 'Attributed hires divided by qualified applications',

    PUBLIC PERFORMANCE.COST_PER_APPLICATION
        AS SUM(SPONSORED_SPEND_UNITS)
           / NULLIF(SUM(APPLICATION_UNITS), 0)
        WITH SYNONYMS (
            'CPA',
            'COST PER APPLY'
        )
        WITH TAG (
            JOB_MARKETPLACE.GOVERNANCE.METRIC_TIER = 'CERTIFIED'
        )
        COMMENT = 'Sponsored spend divided by completed applications',

    PUBLIC PERFORMANCE.COST_PER_QUALIFIED_APPLICATION
        AS SUM(SPONSORED_SPEND_UNITS)
           / NULLIF(SUM(QUALIFIED_APPLICATION_UNITS), 0)
        WITH SYNONYMS (
            'CPQA',
            'COST PER QUALITY APPLY'
        )
        WITH TAG (
            JOB_MARKETPLACE.GOVERNANCE.METRIC_TIER = 'CERTIFIED'
        )
        COMMENT = 'Sponsored spend divided by qualified applications'
)

COMMENT =
    'Governed marketplace performance semantic layer for employer, job, funnel, and sponsored advertising analysis'

AI_SQL_GENERATION
    'Use certified semantic metrics rather than reconstructing calculations. Apply rate means applications divided by clicks. Click-through rate means clicks divided by impressions. Qualified application rate means qualified applications divided by applications. Monetary metrics are denominated in US dollars.'

AI_QUESTION_CATEGORIZATION
    'Use this semantic view for questions about employer performance, job performance, recruiting funnels, sponsored spend, traffic channels, devices, markets, applications, qualified applications, and hires.'

AI_VERIFIED_QUERIES (

    MONTHLY_MARKETPLACE_PERFORMANCE AS (
        QUESTION
            'What are monthly impressions, clicks, applications, and apply rate by market region?'

        VERIFIED_AT 1785369600

        ONBOARDING_QUESTION TRUE

        SQL
            'SELECT *
             FROM SEMANTIC_VIEW(
                 JOB_MARKETPLACE.SEMANTIC.JOB_MARKETPLACE_PERFORMANCE
                 DIMENSIONS
                     CALENDAR.MONTH_START,
                     JOBS.MARKET_REGION
                 METRICS
                     PERFORMANCE.TOTAL_IMPRESSIONS,
                     PERFORMANCE.TOTAL_CLICKS,
                     PERFORMANCE.TOTAL_APPLICATIONS,
                     PERFORMANCE.APPLY_RATE
             )
             ORDER BY MONTH_START, MARKET_REGION'
    )
)

WITH TAG (
    JOB_MARKETPLACE.GOVERNANCE.DATA_DOMAIN = 'JOB_MARKETPLACE',
    JOB_MARKETPLACE.GOVERNANCE.DATA_CLASSIFICATION = 'INTERNAL'
);
