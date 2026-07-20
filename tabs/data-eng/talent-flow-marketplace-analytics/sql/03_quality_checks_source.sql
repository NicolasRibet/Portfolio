--Duplicate primary identifiers (expected result: zero rows)
SELECT impression_id, COUNT(*) AS row_count
FROM job_impressions
GROUP BY impression_id
HAVING COUNT(*) > 1;

--Orphan impressions (expected result: zero)
SELECT COUNT(*) AS orphan_impressions
FROM job_impressions i
LEFT JOIN searches s
    ON i.search_id = s.search_id
LEFT JOIN job_posts j
    ON i.job_id = j.job_id
WHERE s.search_id IS NULL
   OR j.job_id IS NULL;

--Clicks without impressions (expected result: zero)
SELECT COUNT(*) AS orphan_clicks
FROM job_clicks c
LEFT JOIN job_impressions i
    ON c.impression_id = i.impression_id
WHERE i.impression_id IS NULL;

--Invalid event chronology (expected result: zero)
SELECT COUNT(*) AS invalid_click_timestamps
FROM job_clicks c
JOIN job_impressions i
    ON c.impression_id = i.impression_id
WHERE c.clicked_at < i.impressed_at;

-- Invalid application chronology (expected result: zero)
SELECT COUNT(*) AS invalid_application_timestamps
FROM applications
WHERE submitted_at IS NOT NULL
  AND submitted_at < started_at;

--Invalid salary ranges (expected result: zero)
SELECT COUNT(*) AS invalid_salary_ranges
FROM job_posts
WHERE salary_min IS NOT NULL
  AND salary_max IS NOT NULL
  AND salary_max < salary_min;

--Invalid sponsored attribution (expected result: zero)
SELECT COUNT(*) AS invalid_sponsored_impressions
FROM job_impressions
WHERE is_sponsored = TRUE
  AND campaign_id IS NULL;

--Funnel reasonableness
SELECT
    (SELECT COUNT(*) FROM searches) AS searches,
    (SELECT COUNT(*) FROM job_impressions) AS impressions,
    (SELECT COUNT(*) FROM job_clicks) AS clicks,
    (SELECT COUNT(*) FROM applications) AS applications;
-- then 
SELECT
    COUNT(DISTINCT c.click_id) * 1.0 /
        NULLIF(COUNT(DISTINCT i.impression_id), 0) AS ctr
FROM job_impressions i
LEFT JOIN job_clicks c
    ON i.impression_id = c.impression_id;