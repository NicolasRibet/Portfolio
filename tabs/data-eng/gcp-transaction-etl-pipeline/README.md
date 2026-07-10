# Enterprise-Grade User Transaction Data ETL Pipeline

Python and Pandas ETL pipeline orchestrated with Apache Airflow. The pipeline cleans raw user transaction data, standardizes customer names, normalizes currency amounts, fills missing metrics, uploads the cleaned CSV to Google Cloud Storage, and loads it into BigQuery.

## Cloud Architecture

- **Extract:** Read raw transaction data from a local CSV, API export, or operational database dump.
- **Transform:** Clean and shape the data with Python and Pandas.
- **Load to GCS:** Write the clean dataset to Google Cloud Storage as a CSV file.
- **Load to BigQuery:** Load the GCS object into an analytics table.
- **Orchestrate:** Schedule retries, task dependencies, and monitoring with Apache Airflow.

## Project Structure

```text
.
├── dags/
│   └── gcp_transaction_dag.py
├── data/
│   └── raw_transactions.csv
├── gcp_etl_pipeline.py
├── requirements.txt
└── README.md
```

## Environment Setup

```bash
python -m venv pipeline_env
source pipeline_env/bin/activate
pip install -r requirements.txt
```

## Sample Source Data

The demo source file is stored at `data/raw_transactions.csv` and includes intentionally messy records:

- customer names with inconsistent spacing and casing
- currency values stored as strings
- missing transaction amounts
- missing purchase dates

## Run the Pipeline

Set the GCP target values, then run the ETL script:

```bash
export GCP_BUCKET_NAME="nicolasr-gcs-bucket"
export GCS_BLOB_NAME="cleaned/daily_transactions.csv"
export BQ_TABLE_ID="sales.users_transactions.transactions"

python gcp_etl_pipeline.py
```

The script reads `data/raw_transactions.csv`, uploads the cleaned output to `gs://$GCP_BUCKET_NAME/$GCS_BLOB_NAME`, and loads that object into `$BQ_TABLE_ID`.

## Airflow DAG

Copy or mount this project into your Airflow environment so the DAG can import `gcp_etl_pipeline.py`. The DAG is defined in `dags/gcp_transaction_dag.py` and runs daily at midnight.

Start Airflow locally:

```bash
airflow standalone
```

Then open `http://localhost:8080`, enable `gcp_etl_transaction_pipeline`, and trigger a run.

## Google Cloud Connection

To let Airflow authenticate with Google Cloud:

1. Create a service account in Google Cloud IAM.
2. Grant permissions for Storage Object Admin and BigQuery Data Editor.
3. Download the service account JSON key.
4. In Airflow, open **Admin > Connections**.
5. Edit `google_cloud_default`, set the connection type to Google Cloud, and paste the JSON key into the keyfile JSON field.

## Notes

The BigQuery load job uses `WRITE_TRUNCATE` for repeatable demo runs. For production historical loads, switch the write disposition to `WRITE_APPEND`.
