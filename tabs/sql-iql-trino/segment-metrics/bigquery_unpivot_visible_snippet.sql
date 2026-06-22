-- Source: screenshot-reconstructed from Google BigQuery screenshot.
-- Verify against the original screenshot/OCR before running.

WITH cte AS (
    SELECT
        country,
        occupation_top_level_label,
        occupation_label,
        CAST(COALESCE(SUM(engaged_js), 0) AS FLOAT64) AS engaged_js,
        CAST(COALESCE(SUM(JS_S_JSCONN_NUM_engaged_js_w_pc), 0) AS FLOAT64) AS engaged_js_w_pc,
        CAST(
            SAFE_DIVIDE(
                COALESCE(SUM(JS_S_JSCONN_NUM_engaged_js_w_pc), 0),
                COALESCE(SUM(engaged_js), 0)
            ) AS FLOAT64
        ) AS placeholder_pct_eng_pc
    FROM `strategy-anlyt-ccoe-4114.occupation.fact_occupation_monthly_by_job_type_v7`
    WHERE month >= '2023-05-01'
      AND occupation_top_level_label IS NOT NULL
      AND occupation_label = "Executive & Personal Assistants"
      AND country IN ('NL')
    GROUP BY 1, 2, 3, 4
)
SELECT *
FROM cte
UNPIVOT INCLUDE NULLS (
    value FOR metric_name IN (
        engaged_js_w_pc,
        placeholder_pct_eng_pc
    )
);
