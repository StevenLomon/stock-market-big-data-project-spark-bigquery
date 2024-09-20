# Scalable Stock Market Data Pipeline using Spark and BigQuery with Power BI Integration

## Description
This project aims to build a scalable big data pipeline using Google Cloud Platform (GCP) services to ingest, process, and analyze stock market data from the Alpha Vantage API. The pipeline leverages Google Cloud Storage (GCS) as an intermediate staging area for raw and processed data, ensuring data durability and flexibility. Data is processed using PySpark on Dataproc and loaded into BigQuery for storage and analysis. The workflow is orchestrated with Cloud Composer (managed Apache Airflow), while CI/CD is automated through GitHub Actions, and infrastructure is managed using Terraform.

The final processed data is visualized and reported using Power BI, connected to BigQuery for seamless business intelligence insights.

## Technologies used and project architecture
* Alpha Vantage API for stock data ingestion
* GCS for raw and processed data storage
* Dataproc with PySpark for data transformation
* BigQuery as the data warehouse
* Cloud Composer (Apache Airflow) for orchestration
* Power BI connected to BigQuery for reporting and visualization
* GitHub Actions for CI/CD
* Terraform for infrastructure automation (will be integrated in retrospect after the entire project is done the first time round)

The project uses the following architecture:  
IMAGE

## Project journal