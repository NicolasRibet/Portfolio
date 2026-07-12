# Portfolio Summary

**Project:** Databricks Retail Lakehouse Analytics Pipeline

**Stack:** Databricks Free Edition, PySpark, Spark SQL, Delta Lake, Unity Catalog, Databricks Workflows, Databricks SQL

**Highlights:**

- Incremental and idempotent CSV ingestion
- Bronze, Silver, and Gold medallion architecture
- Explicit schemas and ingestion lineage
- Multi-format date parsing and categorical normalization
- Duplicate and invalid-record quarantine
- Star-schema sales model and aggregate marts
- Automated data-quality tests that fail the workflow
- Dashboard-ready Gold Delta tables

**Gold location:** `retail_portfolio.gold`

**Example query:**

```sql
SELECT *
FROM retail_portfolio.gold.fact_sales
LIMIT 100;
```
