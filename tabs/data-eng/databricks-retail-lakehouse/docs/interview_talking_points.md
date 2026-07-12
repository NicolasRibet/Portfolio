# Interview Talking Points

1. The source arrives as weekly CSV extracts plus a separate dirty user file.
2. Bronze uses explicit all-string schemas, append-only Delta tables, source filenames, and ingestion timestamps.
3. Incremental ingestion skips filenames already present in Bronze, making reruns idempotent for this portfolio scale.
4. Silver standardizes text, casts data types, parses multiple date formats, reconciles transaction arithmetic, and ranks duplicates.
5. Invalid and duplicate rows are retained in quarantine tables instead of being silently discarded.
6. Gold provides a transaction fact table, reusable dimensions, and business-facing aggregate marts.
7. Sales and user acquisition remain separate because the supplied IDs do not provide a legitimate customer crosswalk.
8. Run-level data-quality tests cover uniqueness, completeness, validity, accuracy, and referential integrity.
9. A failing quality test raises an exception and stops the Databricks Workflow.
10. The final managed Delta tables are queried through Unity Catalog under `retail_portfolio.gold`.
