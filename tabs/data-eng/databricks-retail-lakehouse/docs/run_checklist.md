# Run Checklist

- [ ] Import all six notebook source files into Databricks.
- [ ] Run `00_setup.sql`.
- [ ] Create the `transactions` and `users` directories in the managed volume.
- [ ] Upload the four transaction CSVs and `users_dirty.csv`.
- [ ] Run Bronze ingestion twice and confirm the second run adds no duplicate files.
- [ ] Run Silver transformations and inspect both quarantine tables.
- [ ] Run Gold models and query `retail_portfolio.gold.fact_sales`.
- [ ] Run the data-quality notebook and confirm all tests pass.
- [ ] Create the five-task Databricks Workflow.
- [ ] Build dashboard tiles using `dashboard_queries.sql`.
- [ ] Add screenshots of the successful workflow and dashboard to the project README.
