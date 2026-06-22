-- Source: screenshot-reconstructed from AWS Athena screenshot.
-- Verify against the original screenshot/OCR before running.

WITH segment_class_attach_rate_job_id AS (
    SELECT
        date_trunc('day', parse_datetime(hour, 'yyyy-MM-dd HH:mm:ss')) AS time,
        jobcountry AS country,
        value AS taxo_occupations_uuid,
        jobid,
        round(
            sum(
                cast(segment_classes_count AS DOUBLE)
                / nullif(cast(segment_classes_defined_count AS DOUBLE), 0)
            ),
            4
        ) AS "Avg segment class attach rate across all hosted jobs (KR2.1)"
    FROM searchablejobs
    CROSS JOIN UNNEST(taxo_occupations) AS t(value)
    WHERE hour >= '2023-08-21 00:00:00'
      AND hour < '2023-08-22 00:00:00'
      AND (
            waldovisibilitylevel IN ('jobalert', 'organic')
            OR (waldovisibilitylevel = 'sponsored' AND sponVisibility = 'spon_active')
          )
      AND dupeStatus != 1
      AND jobagedays = 0
      AND feedid = 50461
      AND (segment_classes_defined_count > 0 OR segment_classes_defined_count = 0)
      AND termcount(taxo_occupations_most_specific) = 1
    GROUP BY 1, 2, 3, 4
    HAVING jobcountry IN ('US', 'CA', 'DE', 'FR', 'GB', 'NL', 'AU', 'MX', 'ES', 'BR', 'IT', 'IE', 'BE', 'CH', 'SE', 'PL', 'SG', 'IN', 'JP')
       AND round(
            sum(
                cast(segment_classes_count AS DOUBLE)
                / nullif(cast(segment_classes_defined_count AS DOUBLE), 0)
            ),
            4
          ) IS NOT NULL
)
