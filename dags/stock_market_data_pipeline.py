# Importing required libraries and modules
from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.providers.google.cloud.transfers.gcs_to_bigquery import GCSToBigQueryOperator
from datetime import datetime, timedelta
from google.cloud import storage
import requests
import json

# Define DAG and its default arguments
default_args = {
    'owner': 'airflow',
    'depends_on_past': False,
    'email_on_failure': False,
    'email_on_retry': False,
    'retries': 1,
    'retry_delay': timedelta(minutes=5),
}

dag = DAG(
    'stock_market_data_pipeline',
    default_args=default_args,
    description='An ETL pipeline for stock market data using Alpha Vantage, PySpark and BigQuery',
    schedule_interval=(timedelta(days=1)),
    start_date=datetime(2024, 10, 6),
    catchup=False,
)