# Databricks Workflow Setup

Create a Databricks job named **Retail Lakehouse Daily Pipeline** and add these notebook tasks in order:

```text
bronze_ingestion
        ↓
silver_transformations
        ↓
gold_models
        ↓
data_quality_tests
        ↓
pipeline_summary
```

| Task | Notebook | Depends on |
|---|---|---|
| `bronze_ingestion` | `01_bronze_ingestion.py` | None |
| `silver_transformations` | `02_silver_transformations.py` | `bronze_ingestion` |
| `gold_models` | `03_gold_models.sql` | `silver_transformations` |
| `data_quality_tests` | `04_data_quality_tests.py` | `gold_models` |
| `pipeline_summary` | `05_pipeline_summary.sql` | `data_quality_tests` |

Suggested portfolio schedule: weekly on Monday at 7:00 AM in `America/Los_Angeles`, or leave scheduling paused after demonstrating a successful run.

The data-quality task intentionally raises an exception when a test fails, so the job cannot report success after publishing invalid data.
