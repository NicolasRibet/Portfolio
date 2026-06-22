# Customer Analytics ELT Pipeline with dbt, PostgreSQL, Docker, and OpenAI Codex

This project is an analytics engineering project that builds a local customer analytics pipeline using dbt, PostgreSQL, Docker, and OpenAI Codex.

The project models raw sales data into analytics-ready marts for customer segmentation and product performance analysis.

## Project Goals

- Build a reproducible local data warehouse using Docker and PostgreSQL
- Load raw customer, product, order, and order item data with dbt seeds
- Transform raw data into staging, intermediate, and mart models
- Add data quality tests for uniqueness, nulls, relationships, and accepted values
- Generate customer lifetime value and segmentation analytics
- Demonstrate a modern analytics engineering workflow using dbt and OpenAI Codex

## Tech Stack

- PostgreSQL
- Docker
- dbt Core
- dbt-postgres
- OpenAI Codex CLI
- Git / GitHub

## Project Structure

```text
.
├── docker-compose.yml
├── dbt_project.yml
├── seeds/
│   ├── customers.csv
│   ├── products.csv
│   ├── orders.csv
│   └── order_items.csv
├── models/
│   ├── staging/
│   ├── intermediate/
│   └── marts/
├── analyses/
├── tests/
├── docs/
└── screenshots/
```
