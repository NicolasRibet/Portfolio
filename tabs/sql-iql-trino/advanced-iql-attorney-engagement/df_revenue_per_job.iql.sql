-- df_revenue_per_job --> Revenue per job (IQL: https://link.indeed.tech/IDASH3T64N4)
-- Athena: 7115 rows, Ishbook: 7115 rows (100%) (comp analysis: N/A)
with df_revenue_per_job as (
with daily_total_revenue_cents as (
SELECT
date_trunc('week', parse_datetime(day, 'yyyy-MM-dd')) as "time(7d)",
value as uuid,
country,
sum(daily_total_revenue_cents) as daily_total_revenue_cents
FROM dradis_job2
CROSS JOIN UNNEST(taxo_occupations_most_specific_uuids) as t(value)
WHERE
day >= '2023-08-21' and day < '2023-08-28'
AND country != ''
AND value != ''
GROUP BY 1, 2, 3
),
job_hash as (
SELECT
date_trunc('week', parse_datetime(day, 'yyyy-MM-dd')) as "time(7d)",
value as uuid,
country,
count(distinct job_hash_underscore) as job_hash
FROM dradis_job2
CROSS JOIN UNNEST(taxo_occupations_most_specific_uuids) as t(value)
WHERE
day >= '2023-08-21' and day < '2023-08-28'
AND country != ''
AND value != ''
GROUP BY 1, 2, 3 having count(*) > 0
)
select
distinct daily_total_revenue_cents.*,
job_hash.job_hash,
round(cast(daily_total_revenue_cents.daily_total_revenue_cents as DOUBLE) / cast(job_hash.job_hash as DOUBLE), 4) / 100 as revenue_per_job
from daily_total_revenue_cents
left join job_hash                  on daily_total_revenue_cents."time(7d)" = job_hash."time(7d)"
and daily_total_revenue_cents.uuid = job_hash.uuid
and daily_total_revenue_cents.country = job_hash.country
)
SELECT *
FROM df_revenue_per_job
ORDER BY uuid DESC, country ASC
