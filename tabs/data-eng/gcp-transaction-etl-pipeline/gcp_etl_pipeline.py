import argparse
import io
import os

import pandas as pd
from google.cloud import bigquery
from google.cloud import storage


def clean_transactions(source_file):
    """Load and normalize raw transaction data."""
    df = pd.read_csv(source_file)
    clean_df = df.copy()

    clean_df["customer_name"] = clean_df["customer_name"].str.strip().str.title()
    clean_df["amount"] = clean_df["amount"].str.replace("$", "", regex=False)
    clean_df["amount"] = pd.to_numeric(clean_df["amount"], errors="coerce")

    mean_amount = clean_df["amount"].mean()
    clean_df["amount"] = clean_df["amount"].fillna(mean_amount)
    clean_df["purchase_date"] = clean_df["purchase_date"].fillna("Unknown")

    return clean_df


def run_gcp_etl(source_file, bucket_name, gcs_blob_name, bq_table_id):
    """Clean transactions, upload them to GCS, and load them into BigQuery."""
    clean_df = clean_transactions(source_file)

    print(f"Uploading clean data to GCS bucket: {bucket_name}")
    storage_client = storage.Client()
    bucket = storage_client.bucket(bucket_name)
    blob = bucket.blob(gcs_blob_name)

    csv_buffer = io.StringIO()
    clean_df.to_csv(csv_buffer, index=False)
    blob.upload_from_string(csv_buffer.getvalue(), content_type="text/csv")

    print(f"Loading data into BigQuery table: {bq_table_id}")
    bq_client = bigquery.Client()
    job_config = bigquery.LoadJobConfig(
        source_format=bigquery.SourceFormat.CSV,
        skip_leading_rows=1,
        write_disposition=bigquery.WriteDisposition.WRITE_TRUNCATE,
        autodetect=True,
    )

    gcs_uri = f"gs://{bucket_name}/{gcs_blob_name}"
    load_job = bq_client.load_table_from_uri(gcs_uri, bq_table_id, job_config=job_config)
    load_job.result()

    print("GCP data pipeline execution successful.")


def parse_args():
    parser = argparse.ArgumentParser(description="Run the GCP transaction ETL pipeline.")
    parser.add_argument("--source-file", default=os.getenv("SOURCE_FILE", "data/raw_transactions.csv"))
    parser.add_argument("--bucket-name", default=os.getenv("GCP_BUCKET_NAME"), required=not os.getenv("GCP_BUCKET_NAME"))
    parser.add_argument("--gcs-blob-name", default=os.getenv("GCS_BLOB_NAME", "cleaned/daily_transactions.csv"))
    parser.add_argument("--bq-table-id", default=os.getenv("BQ_TABLE_ID"), required=not os.getenv("BQ_TABLE_ID"))
    return parser.parse_args()


if __name__ == "__main__":
    args = parse_args()
    run_gcp_etl(
        source_file=args.source_file,
        bucket_name=args.bucket_name,
        gcs_blob_name=args.gcs_blob_name,
        bq_table_id=args.bq_table_id,
    )
