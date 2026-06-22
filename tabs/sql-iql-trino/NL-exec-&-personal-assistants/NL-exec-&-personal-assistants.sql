with cte as (
  SELECT
    month
    ,occupation_top_level_label
    ,occupation_label
    ,country
    ,CAST(coalesce(sum(engaged_js),0) AS FLOAT64) as engaged_js
    ,CAST(coalesce(sum(JS_S_JSCONN_NUM_engaged_js_w_pc),0) AS FLOAT64) as engaged_js_w_pc
    ,CAST(safe_divide(coalesce(sum(JS_S_JSCONN_NUM_engaged_js_w_pc),0), coalesce(sum(engaged_js),0)) AS FLOAT64) as placeholder_pct_eng_pc
    --,CAST(coalesce(sum(jobs_w_hiredsignal),0) AS FLOAT64) as jobs_w_hiredsignal
  FROM `strategy-anlyt-ccoe-4114.occupation_fact.occupation_monthly_by_job_type_v7`
  where
    1=1
    and month >= '2023-05-01'
    and occupation_top_level_label is not null
    and occupation_label = "Executive & Personal Assistants"
    and country in ('NL')
  group by 1,2,3,4
)

SELECT *
FROM cte
UNPIVOT INCLUDE NULLS (value FOR metric_name IN (
  engaged_js,
  engaged_js_w_pc,
  placeholder_pct_eng_pc
))
