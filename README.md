# Scalable Stock Market Data Pipeline using Spark and BigQuery with Power BI Integration

## Description
This project aims to build a scalable big data pipeline using Google Cloud Platform (GCP) services to ingest, process, and analyze stock market data from the Alpha Vantage API. The pipeline leverages Cloud Storage as an intermediate staging area for raw and processed data, ensuring data durability and flexibility. Data is processed using PySpark on Dataproc and loaded into BigQuery for storage and analysis. The workflow is orchestrated with Cloud Composer (managed Apache Airflow), while CI/CD is automated through GitHub Actions, and infrastructure is managed using Terraform.

The final processed data is visualized and reported using Power BI, connected to BigQuery for seamless business intelligence insights.

## Technologies used and project architecture
* Alpha Vantage API for stock data ingestion (https://www.alphavantage.co/)
* Cloud Storage for raw and processed data storage
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

(As a side note, I'm implementing following strategies to stay within the free tier haha. From ChatGPT:
* Start Small: Begin with smaller datasets and run Spark jobs in smaller Dataproc clusters to minimize costs.
* Use Preemptible VMs: When configuring Dataproc clusters, you can use preemptible VMs, which are much cheaper than regular instances but can be stopped by GCP at any time (good for testing but not production).
* Monitor Costs: Use the Google Cloud Billing Dashboard to keep an eye on your resource usage and costs.
Overall, for small-scale testing and development, you can stay within the free tier, but for larger production-like environments, you'll likely need to move beyond the free tier, especially for Dataproc.)

### Setting up IAM
(My very first question was "Does GCP have any equivalent to AWS IAM?" Indeed it does and it even shares the same name haha!)  

In IAM, the first step is to assign appropriate permissions to manage the project. The Google account used to manage the project is granted the Editor role, which allows it to create, modify, and delete resources within the project. This ensures the necessary permissions for project administration without creating a separate IAM User account, as is done in AWS.

Separate service accounts for Dataproc, BigQuery and Cloud Composer are also created since these services will interact with Cloud Storage and other resources. (We can think of service accounts like "robots" or "identities" that represent the applications, allowing them to interact with GCP services with the necessary permissions.) The following roles were assigned to each service account:  

Dataproc:  
* Dataproc Worker: Grants permissions to run Dataproc jobs.
* Storage Object Viewer: Allows the service account to read/write data from/to Cloud Storage (raw and processed data).
* BigQuery Data Editor: Grants permissions to write the processed data to BigQuery.
* BigQuery Job User: Allows the service account to execute queries in BigQuery.
* Secret Manager Secret Accessor: Allows the service account to access the Alpha Vantage API key stored in Secret Manager.

BigQuery:  
* BigQuery Data Editor: Allows editing and inserting data into datasets.
* BigQuery Job User: Allows the service account to run queries.
* Storage Object Viewer: Allows BigQuery to interact directly with Cloud Storage (e.g., load data from Cloud Storage into BigQuery).

Cloud Composer (Airflow):
* Composer Administrator: Provides access to manage and use Cloud Composer (Airflow).
* Storage Object Admin: To access Cloud Storage for reading/writing raw and processed data.
* BigQuery Data Editor: For loading data into BigQuery from your workflows.
* Dataproc Editor: So it can trigger and manage Dataproc jobs.

### Data Ingestion from Alpha Vantage

#### Getting the API key and storing it in Secret Manager
A free API key was generated on the Alpha Vantage site. To store it in Secret Manager (the GCP equivalent to AWS Secrets Manager), the Secret Manager API first had to be enabled. A secret is created with the name `alpha-vantage-api-key` and will be accessed by Dataproc, which is able to do so by having the Secret Manager Secret Accessor role attached to its service account. All default values are used.

#### Setting up the Cloud Dataproc Cluster
A Cloud Dataproc Cluster with Apache Spark is created to run the PySpark jobs. To avoid Kubernetes and containerization (for now haha), the cluster is created on Compute Engine, and to get familiar with Dataproc and Spark, Single Node is chosen rather than Standard. (However, I am stepping out of my Ubuntu comfort bubble and diving into Debian!) Since europe-north1 caused a bunch of trouble (I assume due to free trial limitations. See more down below on errors), us-central1 is chosen as region. 

Default configurations are used with no Spark performance enhancements, and no Dataproc Metastore will not be used. Zeppelin is chosen over Jupyter (the one I have experience using haha) since it is more geared towards Big Data! To put the focus on writign PySpark jobs and working in Zeppelin, everything is left to default values in Configure nodes, Customize cluster and Manage security. The Cloud Dataproc API also had to be enabled.   

The equivalent gcloud command line is:
```
gcloud dataproc clusters create alpha-vantage1 --enable-component-gateway --region europe-north1 --no-address --single-node --master-machine-type n2-standard-4 --master-boot-disk-type pd-balanced --master-boot-disk-size 500 --image-version 2.2-debian12 --optional-components ZEPPELIN --project marine-cable-436701-t7
``` 

Two errors arose when clicking 'Create'.
1. 500 GB is requested but the project quota only allows for 250 GB. Fix: The Primary disk size is set to 250 GB. 
2. The cluster is set to internal IPs only but the subnetwork does not have Private Google Access enabled. Fix: Internal IP only is unchecked. This is the simplest solution and using public IPs for now is fine for development.
3. The default service account (responsible for managing the VMs in the Dataproc cluster) doesn't have the necessary permissions to access Cloud Storage for the Dataproc cluster in the region (europe-north1). The proposed fix: Attach the Storage Object Admin role to the Compute Engine default service account. This didn't solve it haha. The actual fix: Just use us-central1

The updated gcloud command line is:
```
gcloud dataproc clusters create alpha-vantage1 --enable-component-gateway --region us-central1 --single-node --master-machine-type n2-standard-4 --master-boot-disk-type pd-balanced --master-boot-disk-size 250 --image-version 2.2-debian12 --optional-components ZEPPELIN --labels type=spark-learning --project marine-cable-436701-t7
``` 

(Side note: I completely missed enabling Preemptible VMs haha. But I am recommended to experiment with the current cluster and then later set up a more cost-optimized cluster using preemptible VMs once I'm ready for larger-scale or production-like scenarios.)

Once the cluster had been created and provisioned, Cloud Resource Manager API needed to be enabled. 

Before writing the Spark job, the Cloud Storage for the raw data is created:

#### Setting up the raw data Cloud Storage

(I love that they are called buckets in GCP as well haha)  

A bucket called `my-stock-data-bucket` is created where folders and prefixes will be used to achieve the following structure:  
```
my-stock-data-bucket/
   |
   ├── raw-data/
   |     └── (files from Alpha Vantage API, e.g., raw-stock-data.csv)
   |
   └── processed-data/
         └── (processed files from Spark, e.g., processed-stock-data.csv)
```
Once again, us-central1 is chosen as region. Otherwise, default values are used.  

With the bucket created, next up is writing the Spark job:

### Writing the Spark job

(A Spark job for our newly created cluster with the name `stock-market-spark-job1` is created. us-central1 is set as region and PySpark as Job type. NOPE. This is not what we're doing at all haha, this is when you have production-ready code and want to submit it to the cluster.)

From the cluster interface, Zeppelin is accessed via 'Web Interfaces'. A new note called `alpha-vantage-spark-job` is created with python as the Default interpreter. Here a rather big error is encountered: pyspark is not in the list of interpreters. 

Proposed fix: Re-create the cluster and make sure that PySpark is included in the "Optional Components" section.  
Problem: There is no "PySpark" in the list of Optional components haha. ChatGPT also thought that the problem could lie in Component Gateway not being enabled but that checkbox was never unchecked during any of the cluster creation processes so that's not the problem either. %pyspark should be included in the spark interpreter but using that as the Default interpreter led to errors like this where the interpreter is trying to interpret the code in Scala or Java:
![Interpreter errors in Zeppelin](/screenshots/Skärmbild-2024-09-25%20065306.png "Interpreter errors in Zeppelin")

The actual fix: Use Python as the Default interpreter and import PySpark manually in Python. This introduced yet another problem haha: a mismatch between Python versions or dependencies. Fix: Use an initialization action to install Python 3.8 on the Dataproc cluster as part of the cluster creation process. To do this, [a bash script is written](/install-python-3-9.sh) and uploaded to Cloud Storage. The shell script is now accessed under Initialization actions in the cluster creation process via `my-shell-scripts/install-python-3-8.sh`.

The updated gcloud command line is now:
```
gcloud dataproc clusters create alpha-vantage1 --enable-component-gateway --region us-central1 --single-node --master-machine-type n2-standard-4 --master-boot-disk-type pd-balanced --master-boot-disk-size 250 --image-version 2.2-debian12 --optional-components ZEPPELIN --labels type=spark-learning --initialization-actions 'gs://my-shell-scripts/install-python-3-8.sh' --project marine-cable-436701-t7
```

This revealed yet *another* problem haha: The current Dataproc image (Debian 12) is not compatible with Python 3.8. Fix: Use Python 3.9 instead. The shell script was re-written to use Python 3.9 instead and used in the cluster creation process.  

The *final* gcloud command line:
```
gcloud dataproc clusters create alpha-vantage1 --enable-component-gateway --region us-central1 --single-node --master-machine-type n2-standard-4 --master-boot-disk-type pd-balanced --master-boot-disk-size 250 --image-version 2.2-debian12 --optional-components ZEPPELIN --labels type=spark-learning --initialization-actions 'gs://my-shell-scripts/install-python-3-9.sh' --project marine-cable-436701-t7
```

The cluster is now created without error but there is still a dependency error in Zeppelin. The problem is that Zeppelin is not pointing to the Python 3.9 package that we installed on the cluster. Simply going to Interpreters and setting zeppelin.python to `usr/bin/python3.9` under Properties did not work. To find out where Python was installed, SSH was used to access the Master Node. Running `which python3.9` did indeed reveal that Python 3.9 is installed at `/usr/local/bin/python3.9`. This was set as the value for zeppelin.python which fixed the issue of Python not working as an interpreter.

But the problem of PySpark not being installed and also pip not being recognized still had to be addressed. This is resolved by manually installing PySpark in the Master node: 
```
# Installing
sudo /usr/local/bin/python3.9 -m pip install pyspark

# Verifying
/usr/local/bin/python3.9 -m pip show pyspark
```

With this, there were no errors preventing SparkSession from being imported or the Spark session being initialized. But there was still an error in different versions:
"""
pyspark.errors.exceptions.base.PySparkRuntimeError: [PYTHON_VERSION_MISMATCH] Python in worker has different version (3, 11) than that in driver 3.9, PySpark cannot run with different minor versions.
Please check environment variables PYSPARK_PYTHON and PYSPARK_DRIVER_PYTHON are correctly set.
"""
The proposed fix: Set the spark environment variables in Zeppelin in the Interpreter settings
```
PYSPARK_PYTHON = /usr/local/bin/python3.9
PYSPARK_DRIVER_PYTHON = /usr/local/bin/python3.9

```
This was verified with the following lines of code at the top of the notebook:
```
%python

import os
print("PYSPARK_PYTHON:", os.environ.get('PYSPARK_PYTHON'))
print("PYSPARK_DRIVER_PYTHON:", os.environ.get('PYSPARK_DRIVER_PYTHON'))

```

(It was not as easy as just setting the environment variables :') I was stuck here for at least an hour trying to set them and even creating a new custom interpreter but nothing was working)

The actual fix: Re-crate the cluster as a multi-node cluster with the environment variables in the shell script.  
In a multi-node cluster, there are distinct driver and worker nodes, which makes it easier to ensure consistency when setting environment variables like PYSPARK_PYTHON and PYSPARK_DRIVER_PYTHON. In a Single Node setup, the master is both the driver and the worker, which can sometimes cause issues if configurations don’t propagate correctly between these roles.

The disk size for the Master Node is set to 50 GB and each of the two worker node has a disk size of 75 GB, totaling to 250 GB. The shell script was updated, uploaded to the shell scripts bucket and used in the Initialized Actions. 

When trying to create this Cluster, there was an error saying the CPU quota is being hit. The fix: Use a smaller machine type. The machine type for both master node and worker nodes is set to `n1-standard-2`. Preemptible workers (also Secondary workers or Spot VMs) are also enabled; 1 with 50 GB disk size. (With this I also had to change the CPU of the master and worker node, it was a whole puzzle to have everything not exceed the quota haha. Zone f instead of zone a was also chosen due to there not being enough resources in zone a)

The *actual final* gcloud command line:
```
gcloud dataproc clusters create alpha-vantage1 --enable-component-gateway --region us-central1 --zone us-central1-f --master-machine-type n1-standard-2 --master-boot-disk-type pd-balanced --master-boot-disk-size 50 --num-workers 2 --worker-machine-type n1-standard-2 --worker-boot-disk-type pd-balanced --worker-boot-disk-size 75 --num-secondary-workers 1 --secondary-worker-boot-disk-type --secondary-worker-boot-disk-size 50 --num-secondary-worker-local-ssds 0 --image-version 2.2-debian12 --optional-components ZEPPELIN --labels type=spark-learning --initialization-actions 'gs://my-shell-scripts/install-python-3-9-and-set-env.sh' --secondary-worker-type spot --project marine-cable-436701-t7
```

This created the cluster but back in Zeppelin... the environment variables are still not set correctly :')

### Data Processing and Analysis

### Orchastration with Apache Airflow

### Automation with GitHub Actions

### Infrastructure as Code with Terraform