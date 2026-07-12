# Testing Strategy

The pipeline writes each test result to `retail_portfolio.monitoring.data_quality_results` and raises an exception when any test fails.

## Test categories

| Category | Test | Expected result |
|---|---|---|
| Uniqueness | Transaction IDs are unique | Total rows equal distinct IDs |
| Uniqueness | User IDs are unique | Total rows equal distinct IDs |
| Completeness | Required transaction fields are populated | Zero null rows |
| Accuracy | `total_amount = quantity × unit_price` | Zero mismatches above $0.01 |
| Validity | Transaction quantities are positive | Zero invalid rows |
| Validity | User signup dates parse successfully | Zero null parsed dates |
| Validity | Country belongs to the allowed domain | Zero invalid rows |
| Referential integrity | Every fact product exists in `dim_product` | Zero unmatched facts |

## Failure behavior

The test notebook appends run-level results using a UUID. If any result has `FAIL` status, the notebook raises `RuntimeError`. In a Databricks Workflow this stops downstream execution and prevents the pipeline run from being marked successful.

## Quarantine validation

Invalid and duplicate records are not silently deleted. They are written to:

- `retail_portfolio.silver.transactions_quarantine`
- `retail_portfolio.silver.users_quarantine`

Each quarantined record retains the source columns, ingestion metadata, validation errors, and duplicate rank.

## Suggested manual checks

```sql
SELECT source_file, COUNT(*)
FROM retail_portfolio.bronze.transactions_raw
GROUP BY source_file
ORDER BY source_file;
```

```sql
SELECT quarantine_reason, COUNT(*)
FROM retail_portfolio.silver.users_quarantine
GROUP BY quarantine_reason;
```

```sql
SELECT *
FROM retail_portfolio.monitoring.data_quality_results
ORDER BY tested_at DESC;
```
