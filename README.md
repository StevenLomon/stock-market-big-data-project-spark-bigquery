# Stock Market Data Ingestion and Analysis on GCP using Spark and BigQuery

## Description
This project aims to build a scalable big data pipeline using Google Cloud Platform (GCP) services to ingest, process, and analyze stock market data from the Alpha Vantage API. The pipeline leverages Dataproc with PySpark for data processing, Cloud Composer (Apache Airflow) for orchestration, and BigQuery for data storage and analysis. Continuous integration and deployment (CI/CD) will be automated using GitHub Actions, while Terraform will be used to manage and automate infrastructure provisioning on GCP. This end-to-end solution will enable real-time stock data analysis and insights generation.

## Technologies used and project architecture
* Spark (using PySpark)
* Apache Airflow
* BigQuery

The workflow will be automated using GitHub Actions for CI/CD.  
The infrastructure will also be automated using Terraform. (will be integrated in retrospect after the entire project is done the first time round)

The project uses the following architecture:
IMAGE

## Project journal