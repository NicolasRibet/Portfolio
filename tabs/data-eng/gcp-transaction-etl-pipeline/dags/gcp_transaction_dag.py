from datetime import datetime, timedelta

from airflow import DAG
from airflow.operators.python import PythonOperator

from gcp_etl_pipeline import run_gcp_etl


default_args = {
    "owner": "nicolasr",
    "depends_on_past": False,
    "start_date": datetime(2026, 1, 1),
    "email_on_failure": True,
    "email_on_retry": False,
    "retries": 2,
    "retry_delay": timedelta(minutes=5),
}


with DAG(
    "gcp_etl_transaction_pipeline",
    default_args=default_args,
    description="Daily automated transaction ETL pipeline pushing records to GCS and BigQuery",
    schedule="0 0 * * *",
    catchup=False,
) as dag:
    execute_etl_task = PythonOperator(
        task_id="run_e2e_gcp_pipeline",
        python_callable=run_gcp_etl,
        op_kwargs={
            "source_file": "/opt/airflow/data/raw_transactions.csv",
            "bucket_name": "nicolasr-gcs-bucket",
            "gcs_blob_name": "cleaned/daily_transactions.csv",
            "bq_table_id": "sales.users_transactions.transactions",
        },
    )

    execute_etl_task
