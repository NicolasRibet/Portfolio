/* ============================================================
   FILE: 02_raw_data.sql
   PURPOSE:
     Create synthetic job marketplace source data.
   ============================================================ */

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE JOB_MARKETPLACE_WH;
USE DATABASE JOB_MARKETPLACE;
USE SCHEMA RAW;

/* ---------- Employer accounts ---------- */

CREATE OR REPLACE TABLE EMPLOYERS (
    EMPLOYER_ID             NUMBER       NOT NULL,
    EMPLOYER_NAME           VARCHAR      NOT NULL,
    EMPLOYER_SEGMENT        VARCHAR      NOT NULL,
    ACCOUNT_REGION          VARCHAR      NOT NULL,
    ACCOUNT_MANAGER_NAME    VARCHAR      NOT NULL,
    ACCOUNT_MANAGER_EMAIL   VARCHAR      NOT NULL,
    CREATED_AT              TIMESTAMP_NTZ NOT NULL
);

INSERT INTO EMPLOYERS (
    EMPLOYER_ID,
    EMPLOYER_NAME,
    EMPLOYER_SEGMENT,
    ACCOUNT_REGION,
    ACCOUNT_MANAGER_NAME,
    ACCOUNT_MANAGER_EMAIL,
    CREATED_AT
)
VALUES
    (101, 'Horizon Delivery',   'ENTERPRISE', 'AMER', 'Maya Chen',     'maya.chen@marketplace.example',     '2025-09-10'),
    (102, 'Atlas Software',     'MID_MARKET', 'EMEA', 'Lucas Martin',  'lucas.martin@marketplace.example',  '2025-10-14'),
    (103, 'Meridian Health',    'ENTERPRISE', 'AMER', 'Amelia Brooks', 'amelia.brooks@marketplace.example', '2025-08-05'),
    (104, 'BrightPath Retail',  'SMB',        'EMEA', 'Noah Wilson',   'noah.wilson@marketplace.example',   '2025-11-02'),
    (105, 'Northstar Financial','ENTERPRISE', 'AMER', 'Sofia Patel',   'sofia.patel@marketplace.example',   '2025-07-19'),
    (106, 'Pacifica Services',  'MID_MARKET', 'APAC', 'Ethan Lee',     'ethan.lee@marketplace.example',     '2025-12-01');

/* ---------- Job postings ---------- */

CREATE OR REPLACE TABLE JOBS (
    JOB_ID              NUMBER  NOT NULL,
    EMPLOYER_ID         NUMBER  NOT NULL,
    JOB_TITLE           VARCHAR NOT NULL,
    JOB_CATEGORY        VARCHAR NOT NULL,
    COUNTRY_CODE        VARCHAR NOT NULL,
    MARKET_REGION       VARCHAR NOT NULL,
    SPONSORSHIP_TIER    VARCHAR NOT NULL,
    POSTED_DATE         DATE    NOT NULL,
    CLOSED_DATE         DATE
);

INSERT INTO JOBS (
    JOB_ID,
    EMPLOYER_ID,
    JOB_TITLE,
    JOB_CATEGORY,
    COUNTRY_CODE,
    MARKET_REGION,
    SPONSORSHIP_TIER,
    POSTED_DATE,
    CLOSED_DATE
)
VALUES
    (1001, 101, 'Data Analyst',                 'DATA_AND_ANALYTICS', 'US', 'AMER', 'PREMIUM',  '2026-01-01', NULL),
    (1002, 101, 'Warehouse Associate',          'OPERATIONS',         'US', 'AMER', 'ORGANIC',  '2026-01-05', '2026-02-20'),
    (1003, 102, 'Senior Software Engineer',     'ENGINEERING',        'DE', 'EMEA', 'PREMIUM',  '2026-01-08', NULL),
    (1004, 104, 'Sales Manager',                'SALES',              'GB', 'EMEA', 'STANDARD', '2026-01-10', '2026-03-10'),
    (1005, 103, 'Registered Nurse',             'HEALTHCARE',         'US', 'AMER', 'PREMIUM',  '2026-01-12', NULL),
    (1006, 105, 'Product Manager',              'PRODUCT',            'CA', 'AMER', 'STANDARD', '2026-01-15', '2026-02-28'),
    (1007, 102, 'Data Engineer',                'DATA_AND_ANALYTICS', 'FR', 'EMEA', 'PREMIUM',  '2026-01-20', NULL),
    (1008, 106, 'Customer Support Specialist',  'CUSTOMER_SERVICE',   'SG', 'APAC', 'ORGANIC',  '2026-02-01', NULL);

/* ---------- Daily job funnel data ---------- */

/*
Grain:
One row per event_date, job_id, device_type, and traffic_source.

The generated data covers January 1 through March 31, 2026.
*/

CREATE OR REPLACE TABLE JOB_PERFORMANCE_DAILY AS

WITH DATE_SPINE AS (
    SELECT
        DATEADD(DAY, SEQ4(), '2026-01-01'::DATE) AS EVENT_DATE
    FROM TABLE(GENERATOR(ROWCOUNT => 90))
),

DEVICES AS (
    SELECT COLUMN1::VARCHAR AS DEVICE_TYPE
    FROM VALUES
        ('DESKTOP'),
        ('MOBILE')
),

SOURCES AS (
    SELECT COLUMN1::VARCHAR AS TRAFFIC_SOURCE
    FROM VALUES
        ('ORGANIC'),
        ('SPONSORED'),
        ('PARTNER')
),

PERFORMANCE_GRAIN AS (
    SELECT
        D.EVENT_DATE,
        J.JOB_ID,
        J.MARKET_REGION,
        DV.DEVICE_TYPE,
        S.TRAFFIC_SOURCE
    FROM DATE_SPINE D

    INNER JOIN JOBS J
        ON D.EVENT_DATE >= J.POSTED_DATE
       AND D.EVENT_DATE <= COALESCE(J.CLOSED_DATE, '9999-12-31'::DATE)

    CROSS JOIN DEVICES DV
    CROSS JOIN SOURCES S
),

GENERATED_RATES AS (
    SELECT
        EVENT_DATE,
        JOB_ID,
        MARKET_REGION,
        DEVICE_TYPE,
        TRAFFIC_SOURCE,

        (
            150
            + MOD(
                ABS(HASH(
                    JOB_ID,
                    EVENT_DATE,
                    DEVICE_TYPE,
                    TRAFFIC_SOURCE,
                    'IMPRESSIONS'
                )),
                851
            )
        )::NUMBER AS IMPRESSIONS,

        (
            0.030
            + MOD(
                ABS(HASH(
                    JOB_ID,
                    EVENT_DATE,
                    DEVICE_TYPE,
                    TRAFFIC_SOURCE,
                    'CTR'
                )),
                41
            ) / 1000.0
        ) AS CLICK_RATE,

        (
            0.100
            + MOD(
                ABS(HASH(
                    JOB_ID,
                    EVENT_DATE,
                    DEVICE_TYPE,
                    TRAFFIC_SOURCE,
                    'APPLY_RATE'
                )),
                151
            ) / 1000.0
        ) AS APPLY_RATE,

        (
            0.450
            + MOD(
                ABS(HASH(
                    JOB_ID,
                    EVENT_DATE,
                    DEVICE_TYPE,
                    TRAFFIC_SOURCE,
                    'QUALITY_RATE'
                )),
                301
            ) / 1000.0
        ) AS QUALITY_RATE,

        (
            0.040
            + MOD(
                ABS(HASH(
                    JOB_ID,
                    EVENT_DATE,
                    DEVICE_TYPE,
                    TRAFFIC_SOURCE,
                    'HIRE_RATE'
                )),
                81
            ) / 1000.0
        ) AS HIRE_RATE,

        (
            1.25
            + MOD(
                ABS(HASH(
                    JOB_ID,
                    EVENT_DATE,
                    DEVICE_TYPE,
                    TRAFFIC_SOURCE,
                    'CPC'
                )),
                176
            ) / 100.0
        ) AS COST_PER_CLICK
    FROM PERFORMANCE_GRAIN
),

WITH_CLICKS AS (
    SELECT
        *,
        FLOOR(IMPRESSIONS * CLICK_RATE)::NUMBER AS CLICKS
    FROM GENERATED_RATES
),

WITH_APPLICATIONS AS (
    SELECT
        *,
        FLOOR(CLICKS * APPLY_RATE)::NUMBER AS APPLICATIONS
    FROM WITH_CLICKS
),

WITH_QUALIFIED_APPLICATIONS AS (
    SELECT
        *,
        FLOOR(APPLICATIONS * QUALITY_RATE)::NUMBER
            AS QUALIFIED_APPLICATIONS
    FROM WITH_APPLICATIONS
),

WITH_HIRES AS (
    SELECT
        *,
        FLOOR(QUALIFIED_APPLICATIONS * HIRE_RATE)::NUMBER AS HIRES
    FROM WITH_QUALIFIED_APPLICATIONS
)

SELECT
    EVENT_DATE,
    JOB_ID,
    MARKET_REGION,
    DEVICE_TYPE,
    TRAFFIC_SOURCE,
    IMPRESSIONS,
    CLICKS,
    APPLICATIONS,
    QUALIFIED_APPLICATIONS,
    HIRES,

    IFF(
        TRAFFIC_SOURCE = 'SPONSORED',
        ROUND(CLICKS * COST_PER_CLICK, 2),
        0
    )::NUMBER(12, 2) AS SPONSORED_SPEND_USD,

    CURRENT_TIMESTAMP()::TIMESTAMP_NTZ AS LOADED_AT
FROM WITH_HIRES;
