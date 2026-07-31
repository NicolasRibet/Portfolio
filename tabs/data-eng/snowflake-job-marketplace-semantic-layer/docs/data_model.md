# Data Model

## Entity relationship diagram

```mermaid
erDiagram
    DIM_EMPLOYER ||--o{ DIM_JOB : "employer_id"
    DIM_JOB ||--o{ FCT_JOB_PERFORMANCE_DAILY : "job_id"
    DIM_DATE ||--o{ FCT_JOB_PERFORMANCE_DAILY : "event_date"

    DIM_EMPLOYER {
        number employer_id PK
        varchar employer_name
        varchar employer_segment
        varchar account_region
        varchar account_manager_name
        varchar account_manager_email
    }

    DIM_JOB {
        number job_id PK
        number employer_id FK
        varchar job_title
        varchar job_category
        varchar country_code
        varchar market_region
        varchar sponsorship_tier
        date posted_date
        date closed_date
        boolean is_currently_open
    }

    DIM_DATE {
        date date_day PK
        date week_start
        date month_start
        date quarter_start
        number calendar_year
        number calendar_month
        varchar year_month
    }

    FCT_JOB_PERFORMANCE_DAILY {
        date event_date PK
        number job_id PK
        varchar device_type PK
        varchar traffic_source PK
        varchar market_region
        number impressions
        number clicks
        number applications
        number qualified_applications
        number hires
        number sponsored_spend_usd
    }
```

## Declared grains

| Model | Grain |
|---|---|
| `DIM_EMPLOYER` | One row per employer account |
| `DIM_JOB` | One row per job posting |
| `DIM_DATE` | One row per calendar date |
| `FCT_JOB_PERFORMANCE_DAILY` | One row per event date, job, device type, and traffic source |

## Relationship paths

```text
DIM_EMPLOYER.employer_id
    1 ──< DIM_JOB.employer_id

DIM_JOB.job_id
    1 ──< FCT_JOB_PERFORMANCE_DAILY.job_id

DIM_DATE.date_day
    1 ──< FCT_JOB_PERFORMANCE_DAILY.event_date
```

The semantic view uses one unambiguous path from employer to job to performance. Calendar attributes join directly to the daily performance fact.

## Modeling rationale

- Employer attributes are modeled separately from jobs to avoid repeating account data.
- Job attributes are conformed across every performance slice.
- Calendar fields support governed day, week, month, quarter, and year aggregation.
- Funnel amounts remain additive at the declared fact grain.
- Conversion metrics are calculated only after aggregation.
- `market_region` exists on both the job dimension and performance fact so row-access controls protect metric queries and dimension-only queries.
