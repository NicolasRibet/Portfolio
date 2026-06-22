-- For integrated jobs (xml or api - and actually I think jobs_platform_partner is better as a grouping than just the two feed types), how many jobs are in nowhere on a rule that is not cat_risk?

WITH

w_r as (
    select visibility, rule_id as ruleId, cast(rule_tag_id as integer) as ruleTagId
    FROM datalake.imhotep.waldorulesnapshot
    CROSS JOIN unnest(rule_tag_ids) as t(rule_tag_id)
    WHERE unixtime BETWEEN IMHOTEP_UNIXTIME('2025-04-23 00:00:00') AND IMHOTEP_UNIXTIME('2025-04-23 23:59:59')
      AND delete_timestamp is NULL
      AND visibility in ('nowhere')
      AND contains(rule_tag_ids, '997') = FALSE -- exclude rules jobs with cat_risk tags based on exclusion from jobs management
      AND not contains(rule_tags, 'cat_risk')
      /* AND has_messaging_tags = 0 */
    GROUP BY 1,2,3
),

last_visibility as (

SELECT
    s2.jobId as jobId,
    (case when s2.lastVisibility = 0 THEN 'nowhere' end) as lastVisibilityStatus
    --, matchedLastVisibilityRules
    --, matchedLastVisibilityRulesWithMessagingTags
    , count(distinct(jobId)) as jobs
FROM

    -- add rule tag info
    (SELECT s1.jobId as jobId
        , lastVisibility
        --, count(distinct(w_r.ruleId)) as matchedLastVisibilityRules
        --, count(distinct(case when w_r.tagId is not null then w_r.ruleId else null end)) as matchedLastVisibilityRulesWithMessagingTags
    FROM

        (
            -- Add matching ruleids
            SELECT s.jobId
                , s.lastVisibility
                , cast(matchedVisibilityRuleId as bigint) as matchedVisibilityRuleId
            FROM

                -- Get the jobids where the last visibility is Nowhere
                (SELECT jobId
                    , visibility as lastVisibility
                    , matchedVisibilityRuleIds
                FROM

                    (SELECT jobId
                        , currentvisibility as visibility
                        , currentmatchingvisibilityrules as matchedVisibilityRuleIds
                        , RANK() over (PARTITION BY jobId ORDER BY unixtime desc) updateRank
                    FROM datalake.imhotep.jobvisibilitystatusupdate
                    WHERE unixtime BETWEEN IMHOTEP_UNIXTIME('2025-03-23 00:00:00') AND IMHOTEP_UNIXTIME('2025-04-23 23:59:59')
                      --AND currentcountry != 'JP'
                      AND feedId != 50461
                    )

                WHERE updateRank = 1
                  AND visibility in (0)
                ) s

            CROSS JOIN unnest(s.matchedVisibilityRuleIds) as t(matchedVisibilityRuleId)
            GROUP BY 1,2,3
        ) s1

    INNER JOIN w_r ON s1.matchedVisibilityRuleId = w_r.ruleId
    GROUP BY 1,2
    ) s2

GROUP BY 1,2

),

job_data AS (
    SELECT
        CASE
            WHEN jobcountry = 'US' THEN 'US'
            WHEN jobcountry = 'JP' THEN 'JP'
            ELSE 'RoW' -- Rest of World
        END AS country_group,
        feedtype,

        jobid
    FROM datalake.imhotep.searchablejobs
    WHERE unixtime BETWEEN IMHOTEP_UNIXTIME('2025-04-23 00:00:00') AND IMHOTEP_UNIXTIME('2025-04-23 23:59:59')
      --AND ((ismetadataEmailExist = 1 OR ismetadataApplyEmailExist = 1)
      AND feedid != 50461 -- indexed jobs only
      AND feedid IN (
          SELECT feed_id
          FROM partnerappsnapshot
          CROSS JOIN UNNEST(job_feed_ids) AS t(feed_id)
          WHERE unixtime BETWEEN IMHOTEP_UNIXTIME('2025-03-23') AND IMHOTEP_UNIXTIME('2025-04-23')
            AND CONTAINS(partner_labels, 'jobs_platform_partner')
      )
      -- AND feedtype IN ('jobapi','xml')
      AND jobid IN (SELECT jobId FROM last_visibility)
)

-- Detailed data by country and feedtype
SELECT
    country_group,
    feedtype,
    COUNT(DISTINCT jobid) AS job_count
FROM job_data
GROUP BY 1, 2

UNION ALL

-- Subtotals by country
SELECT
    country_group,
    'SUBTOTAL' AS feedtype,
    COUNT(DISTINCT jobid) AS job_count
FROM job_data
GROUP BY 1

ORDER BY
    country_group,
    CASE WHEN feedtype = 'SUBTOTAL' THEN 1 ELSE 0 END,
    feedtype
