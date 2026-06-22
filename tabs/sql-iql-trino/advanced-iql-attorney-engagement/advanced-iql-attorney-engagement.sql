WITH params AS (
    SELECT
        'us' AS countryvar,
        '.*law.*|.*attorney.*' AS anydegreename,
        '.*attorney.*' AS lastworkexp,
        '.*assistant.*' AS excludelastworkexp
),

qualified_accounts AS (
    SELECT DISTINCT r.accountid
    FROM resumedata r
    CROSS JOIN params p
    WHERE r.date >= DATE '2011-01-01'
      AND r.rezCountry = p.countryvar
      AND r.searchable = 'yes'
      AND regexp_like(r.education_degreename, p.anydegreename)
      AND regexp_like(r.work_jobtitle_0, p.lastworkexp)
      AND NOT regexp_like(r.work_jobtitle_0, p.excludelastworkexp)
),

organic_all AS (
    SELECT *
    FROM organic
    WHERE date >= current_date - INTERVAL '6' MONTH

    UNION ALL

    SELECT *
    FROM mobileorganic
    WHERE date >= current_date - INTERVAL '6' MONTH
),

title_metrics AS (
    SELECT
        o.titleid,
        SUM(CASE WHEN q.accountid IS NOT NULL THEN o.clicked ELSE 0 END) AS qualified_clicks,
        COUNT_IF(q.accountid IS NOT NULL) AS qualified_count,
        SUM(o.clicked) AS all_clicks,
        COUNT(*) AS all_count
    FROM organic_all o
    CROSS JOIN params p
    LEFT JOIN qualified_accounts q
        ON o.accountid = q.accountid
    WHERE o.country = p.countryvar
      AND o.grp NOT IN ('privileged', 'spider')
    GROUP BY o.titleid
)

SELECT
    titleid,
    qualified_clicks,
    format('%.4f', CAST(qualified_clicks AS DOUBLE) / NULLIF(qualified_count, 0)) AS qualified_ctr,
    all_clicks,
    format('%.4f', CAST(all_clicks AS DOUBLE) / NULLIF(all_count, 0)) AS all_ctr
FROM title_metrics
ORDER BY qualified_clicks DESC
LIMIT 100;
