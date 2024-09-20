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
![Project architecture diagram](/project-architecture-diagram.png "Project architecture diagram")

## Project journal
This is my very first project that uses GCP! So I am going into this well versed in AWS but a complete beginner in GCP and will focus on failing forward and translating all my AWS knowledge into GCP

### Setting up IAM
(My very first question was "Does GCP have any equivalent to AWS IAM?" Indeed it does and it even shares the same name haha!)  

In IAM, an IAM User is first created for project management. This User is granted the role of Project Editor to create, modify and delete resources within the project. Separate service accounts for Dataproc, BigQuery and Cloud Composer are also created since these services will interact with Google Cloud Storage and other resources. (We can think of service accounts like "robots" or "identities" that represent the applications, allowing them to interact with GCP services with the necessary permissions.) The following roles were assigned to each service account:  

Dataproc:  
* Dataproc Worker: Grants permissions to run Dataproc jobs.
* Storage Object Viewer: Allows the service account to read/write data from/to Google Cloud Storage (raw and processed data).
* BigQuery Data Editor: Grants permissions to write the processed data to BigQuery.
* BigQuery Job User: Allows the service account to execute queries in BigQuery.

BigQuery:  
* BigQuery Data Editor: Allows editing and inserting data into datasets.
* BigQuery Job User: Allows the service account to run queries.
* Storage Object Viewer: Allows BigQuery to interact directly with GCS (e.g., load data from GCS into BigQuery).

Cloud Composer (Airflow):
* Cloud Composer Admin: Provides access to manage and use Cloud Composer (Airflow).
* Storage Object Admin: To access GCS for reading/writing raw and processed data.
* BigQuery Data Editor: For loading data into BigQuery from your workflows.
* Dataproc Editor: So it can trigger and manage Dataproc jobs.

### Data Ingestion from Alpha Vantage

### Data Processing and Analysis

### Orchastration with Apache Airflow

### Automation with GitHub Actions

### Infrastructure as Code with Terraform