# Architecture and Design Decisions

## Medallion data flow

```mermaid
flowchart TD
    A1[transactions_2025_01_06.csv]
    A2[transactions_2025_01_13.csv]
    A3[transactions_2025_01_20.csv]
    A4[transactions_2025_01_27.csv]
    A5[users_dirty.csv]

    A1 --> V1[Transactions Volume]
    A2 --> V1
    A3 --> V1
    A4 --> V1
    A5 --> V2[Users Volume]

    V1 --> B1[bronze.transactions_raw]
    V2 --> B2[bronze.users_raw]

    B1 --> S1[silver.transactions]
    B1 --> Q1[silver.transactions_quarantine]
    B2 --> S2[silver.users]
    B2 --> Q2[silver.users_quarantine]

    S1 --> F[gold.fact_sales]
    S1 --> DP[gold.dim_product]
    S1 --> DS[gold.dim_store]
    S1 --> DD[gold.dim_date]
    S1 --> A6[Sales aggregate marts]
    S2 --> A7[User acquisition marts]

    F --> BI[Databricks SQL Dashboard]
    DP --> BI
    DS --> BI
    DD --> BI
    A6 --> BI
    A7 --> BI

    M1[monitoring.ingestion_log] -. observes .-> B1
    M1 -. observes .-> B2
    M2[monitoring.data_quality_results] -. validates .-> S1
    M2 -. validates .-> S2
    M2 -. validates .-> F
```

## Layer responsibilities

### Landing

The Unity Catalog managed volume stores source files exactly as delivered. Files are separated into transaction and user directories.

### Bronze

Bronze tables are append-only and retain all business columns as strings. Each row also carries:

- `source_file`
- `source_file_path`
- `ingested_at`
- `ingestion_date`

Incremental ingestion compares landing filenames with filenames already present in the Bronze target table.

### Silver

Silver applies:

- Whitespace normalization
- Case standardization
- Data-type conversion
- Identifier validation
- Positive-value checks
- Transaction arithmetic reconciliation
- Duplicate ranking
- Quarantine routing

Silver tables contain one trusted record per business key. Invalid and duplicate rows remain available in separate quarantine tables for diagnosis.

### Gold

Gold contains two analytical domains:

1. **Sales:** transaction facts, date/product/store dimensions, and sales aggregates.
2. **User acquisition:** signup aggregates by date, country, and referral source.

The domains remain separate because the source datasets do not share a documented customer key.

## Orchestration

```mermaid
flowchart LR
    A[Bronze ingestion] --> B[Silver transformations]
    B --> C[Gold models]
    C --> D[Data-quality tests]
    D --> E[Pipeline summary]
```

A failed data-quality test raises a runtime exception and stops the workflow before the run is marked successful.

## Production extensions

A production-scale implementation could add:

- Auto Loader and checkpoints instead of directory enumeration
- A central pipeline-control table
- Run-level correlation IDs
- Schema evolution review and data contracts
- MERGE-based change processing
- Slowly changing dimensions
- Alerting and freshness SLAs
- CI validation for notebook source files
