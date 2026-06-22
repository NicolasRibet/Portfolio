-- attach_rate_attribute_count_job_volume_df --> Avg segment class attach rate, attribute count, job volume. (IQL: https://link.indeed.tech/IDASHZ3YG3T)
-- Athena: rows, Ishbook: rows (%) (comp analysis: )

attach_rate_attribute_count_job_volume_df as (

    -- Athena: rows, Ishbook: rows (%) (comp analysis: )
    with segment_class_attach_rate_job_id as (

        SELECT
            date_trunc('day', parse_datetime(hour, 'yyyy-MM-dd HH:mm:ss')) as time,
            jobcountry as country,
            value as taxo_occupations_uuid,
            jobid,
            -- Segment class attach rate
            -- AVG_OVER(agg_job_id, segment_classes_count/MAX(segment_classes_defined_count, 1)) as `Avg segment class attach rate across all hosted jobs (KR2.1)`,
            round(sum(cast(segment_classes_count as DOUBLE) / NULLIF(cast(segment_classes_defined_count as DOUBLE), 0)), 4) as "Avg segment class attach rate across all hosted jobs (KR2.1)"
        FROM
            searchablejobs
        CROSS JOIN UNNEST(taxo_occupations) as t(value)
        WHERE
            hour >= '2023-08-21 00:00:00' and hour < '2023-08-22 00:00:00'
            AND (waldovisibilitylevel IN ('jobalert','organic') OR (waldovisibilitylevel='sponsored' AND sponVisibility='spon_active'))
            AND dupeStatus != 1
            AND jobagedays = 0
            AND feedid = 50461
            AND (segment_classes_defined_count > 0 OR segment_classes_defined_count = 0) -- Until IMTEPD-689 is fixed
            AND (LENGTH(value) - LENGTH(replace(value, '_', ''))) <= 1 -- source: https://stackoverflow.com/questions/27827376/sql-count-number-of-words-in-field ,
                STRTERMCOUT(taxo_occupations_most_specific)=1 -- a job can have multiple matched occupations, but the segment class is per occupation, so you could get weird numbers if you don’t use the =1 (from Asher).
        GROUP BY
            1, 2, 3, 4
        having jobcountry in ('US' /*group 0*/, 'CA', 'DE', 'FR', 'GB', 'NL' /*group 1*/, 'AU', 'MX', 'ES' /*group 2*/, 'BR', 'IT', 'IE', 'BE', 'CH', 'SE', 'PL',
            'SG' /*group 3*/, 'IN', 'JP' /*group 4*/)
            and round(sum(cast(segment_classes_count as DOUBLE) / NULLIF(cast(segment_classes_defined_count as DOUBLE), 0)), 4) IS NOT NULL
        ORDER BY 1, 2, 3, 4

    ),
