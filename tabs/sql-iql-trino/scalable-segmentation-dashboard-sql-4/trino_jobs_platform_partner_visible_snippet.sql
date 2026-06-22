-- Source: screenshot-reconstructed from iDash/Trino screenshots.
-- Verify against the original screenshot/OCR before running.

WITH w_r AS (
    SELECT
        visibility,
        rule_id AS ruleId,
        CAST(rule_tag_id AS integer) AS ruleTagId
    FROM datalake.imhotep.waldorulesnapshot
    CROSS JOIN UNNEST(rule_tag_ids) AS t(rule_tag_id)
    WHERE unixtime BETWEEN IMHOTEP_UNIXTIME('2025-04-23 00:00:00')
                      AND IMHOTEP_UNIXTIME('2025-04-23 23:59:59')
      AND delete_timestamp IS NULL
      AND visibility IN ('nowhere')
      AND contains(rule_tag_ids, '997') = FALSE
      AND NOT contains(rule_tags, 'cat_risk')
    GROUP BY 1, 2, 3
),
last_visibility AS (
    SELECT
        s2.jobId AS jobId,
        CASE WHEN s2.lastVisibility = 0 THEN 'nowhere' END AS lastVisibilityStatus,
        matchedLastVisibilityRules,
        matchedLastVisibilityRulesWithMessagingTags,
        COUNT(DISTINCT jobId) AS jobs
    FROM (
        SELECT
            s1.jobId AS jobId,
            lastVisibility,
            COUNT(DISTINCT w_r.ruleId) AS matchedLastVisibilityRules,
            COUNT(DISTINCT CASE WHEN w_r.ruleTagId IS NOT NULL THEN w_r.ruleId ELSE NULL END)
                AS matchedLastVisibilityRulesWithMessagingTags
        FROM (
            SELECT
                s.jobId,
                s.lastVisibility,
                CAST(matchedVisibilityRuleId AS bigint) AS matchedVisibilityRuleId
            FROM (
                SELECT
                    jobId,
                    currentvisibility AS lastVisibility,
                    currentmatchingvisibilityrules AS matchedVisibilityRuleIds,
                    RANK() OVER (PARTITION BY jobid ORDER BY unixtime DESC) AS updateRank
                FROM datalake.imhotep.jobvisibilitystatusupdate
                WHERE unixtime BETWEEN IMHOTEP_UNIXTIME('2025-03-23 00:00:00')
                                  AND IMHOTEP_UNIXTIME('2025-04-23 23:59:59')
                  AND feedId != 50461
            ) s
            CROSS JOIN UNNEST(s.matchedVisibilityRuleIds) AS t(matchedVisibilityRuleId)
            WHERE updateRank = 1
              AND lastVisibility IN (0)
        ) s1
        INNER JOIN w_r ON s1.matchedVisibilityRuleId = w_r.ruleId
        GROUP BY 1, 2
    ) s2
    GROUP BY 1, 2, 3, 4
),
job_data AS (
    SELECT
        CASE
            WHEN jobcountry = 'US' THEN 'US'
            WHEN jobcountry = 'JP' THEN 'JP'
            ELSE 'RoW'
        END AS country_group,
        feedtype,
        jobid
    FROM datalake.imhotep.searchablejobs
    WHERE unixtime BETWEEN IMHOTEP_UNIXTIME('2025-04-23 00:00:00')
                      AND IMHOTEP_UNIXTIME('2025-04-23 23:59:59')
      AND feedid != 50461
      AND feedid IN (
            SELECT feed_id
            FROM partnerappsnapshot
            CROSS JOIN UNNEST(job_feed_ids) AS t(feed_id)
            WHERE unixtime BETWEEN IMHOTEP_UNIXTIME('2025-03-23')
                              AND IMHOTEP_UNIXTIME('2025-04-23')
              AND CONTAINS(partner_labels, 'jobs_platform_partner')
      )
      AND jobid IN (SELECT jobId FROM last_visibility)
)
SELECT country_group, feedtype, COUNT(DISTINCT jobid) AS job_count
FROM job_data
GROUP BY 1, 2
UNION ALL
SELECT country_group, 'SUBTOTAL' AS feedtype, COUNT(DISTINCT jobid) AS job_count
FROM job_data
GROUP BY 1
ORDER BY
    country_group,
    CASE WHEN feedtype = 'SUBTOTAL' THEN 1 ELSE 0 END,
    feedtype;
