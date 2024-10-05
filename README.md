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

#### Trial and ERROR in setting up the Dataproc cluster and Zeppelin

(I'm writing this in retrospect: LOTS of trial and error and failing forward here. Feel free to skip this section if you don't wanna read how I overcame every bump and obstacle. There were a lof of them, I re-created my cluster like 8 times haha)

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

I watched these two YouTube videos: 
* https://www.youtube.com/watch?v=xM8hOdT04po
* https://www.youtube.com/watch?v=FVU6276clBs  
They suggested that it should be as simple as creating a notebook with spark as the default interpreter and putting %pyspark at the top. Trying to do this, and watching the failure logs, revealed two issues:
1. "IPython requirement is not met, checkKernelPrerequisiteResult: jupyter-client is not installed, installed packages:" Fix: Install Jupyter and IPython Dependencies. This was included in the updated shell script
2. The error code 143 suggested that Zeppelin or Spark is running out of resources or timing out. Fix: Going back to 1 master node of 50 GB and 2 workers nodes of 100 GB. All three on n2-standard-2

The *for real now actual final* gcloud command line:
```
gcloud dataproc clusters create alpha-vantage1 --enable-component-gateway --region us-central1 --master-machine-type n2-standard-2 --master-boot-disk-type pd-balanced --master-boot-disk-size 50 --num-workers 2 --worker-machine-type n2-standard-2 --worker-boot-disk-type pd-balanced --worker-boot-disk-size 100 --image-version 2.2-debian12 --optional-components ZEPPELIN --labels type=spark-learning --initialization-actions 'gs://my-shell-scripts/install-python-3-9-and-set-env.sh' --project marine-cable-436701-t7
```

And with this... it finally worked. I was so happy I could cry :')
![PySpark in Zeppelin finally working](/screenshots/Skärmbild-2024-09-26%20094631.png "PySpark in Zeppelin finally working")

#### Actually Writing the Spark job in Zeppelin
When trying to fetch the API key from Secret Manager using Python, an error that was simple to overcome revealed itself: ModuleNotFoundError: No module named 'google'. Fix: SSH into the Master node and install Google Cloud SDK:
```
# Install google-auth and google-cloud-secret-manager for Python 3.9
sudo /usr/local/bin/python3.9 -m pip install google-auth google-cloud-secret-manager
```

The installation is automated by including the pip install in the shell script that is used with Initialized Actions

With the Google Cloud SDK pip installed, another error arose: "google.api_core.exceptions.PermissionDenied: 403 Permission 'secretmanager.versions.access' denied for resource 'projects/1077638373331/secrets/alpha-vantage-api-key/versions/latest' (or it may not exist)." Fix: Add the `Secret Manager Secret Accessor` role to the Compute Engine default service account. 

With this, the API key is successfully fetched and ready to be used. A first API call to the TIME_SREIES_DAILY endpoint to fetch Google stock data was made without errors:
```
%python
import json
print(json.dumps(data, indent=1))

{
 "Meta Data": {
  "1. Information": "Daily Prices (open, high, low, close) and Volumes",
  "2. Symbol": "GOOG",
  "3. Last Refreshed": "2024-09-25",
  "4. Output Size": "Compact",
  "5. Time Zone": "US/Eastern"
 },
 "Time Series (Daily)": {
  "2024-09-25": {
   "1. open": "162.9700",
   "2. high": "164.2170",
   "3. low": "162.7750",
   "4. close": "162.9900",
   "5. volume": "13607892"
  },
  "2024-09-24": {
   "1. open": "164.2500",
   "2. high": "164.5500",
   "3. low": "162.0300",
   "4. close": "163.6400",
   "5. volume": "18774056"
  },
  ...
 }
}
```

A few other smaller hurdles appeared here as well. One of them was that the raw JSON data is interpreted different between the cells that use the Python interpreter (%python) and the ones using the PySpark interpreter (%pyspark): The variable is interpreted as a dict by Python but a list by PySpark.  
The solution to this is to fetch, clean and prepare the data all in Python for further processing. The data is then "passed" to PySpark. To pass variables between cells using the Python interpreter and those using the PySpark interpreter, z.put() and z.get() are used. 

(Before implementing to a simple solution without the use of RDD, ChatGPT did suggest converting the processed Python data to an RDD and then into a PySpark DataFrame using sc.parallelize(), which failed due to `"TypeError: cannot pickle '_thread.RLock' object"`. We don't need to manually create an RDD unless you have a specific reason to do so.)

The other slightly bigger hurdle was that the pyspark kept compalining that `pyspark.errors.exceptions.base.PySparkTypeError: [CANNOT_INFER_SCHEMA_FOR_TYPE] Can not infer schema for type: `set`.` This turned out to stem from the fact that in the change in interpreter from Python and PySpark, the type of the items turned out not to be a list of dicts but instead a `py4j.java_collections.JavaList` of `<class 'py4j.java_collections.JavaMap'>`. The solution with this insight was simply to use a helper funciton to convert these back to data types that Spark could work with.

A PySpark DataFrame is then created from the processed data. With this, code for storing both the raw data and the processed data in Cloud Storage is written:

#### Storing raw and processed data in Cloud Storage
The only hurdle here was Zeppelin not recognizing storage from google.cloud which is easily fixed by pip installing it in the Master node. The shell script is also updated to reflect this and automate this pip installation for the future.

The first API fetch was of Google with outputsize not setting, leading to the default value of compact. To get a taste of big data, an API fetch with outputsize set to full was also made.  
From the API: "By default, outputsize=compact. Strings compact and full are accepted with the following specifications: compact returns only the latest 100 data points; full returns the full-length time series of 20+ years of historical data. The "compact" option is recommended if you would like to reduce the data size of each API call."

Raw and processed for the compact dataset as well as the full dataset were stored in their respective bucket with no hassle at all.

#### Loading the processed data into BigQuery
The BigQuery API is enabled and a dataset for the current GCP project is created. Default values are used. In order to have the Dataproc cluster write to BigQuery, the `BigQuery Data Editor` role is granted to the Compute Engine default service account. Once set, the PySpark BigQuery Connector is configured.

(With one cell, the DataFrame should have been written to BigQuery but of course there's an error haha)
When writing the DataFrame to BigQuery, there was an error saying that the specified bucket doesn't exist. Spark needs a temporary bucket when loading data into BigQuery and this bucket needs to be created and provided manually before the load. It was created with this line in the Google Cloud Shell: (I first tried to create a bucket called `google-stock-data-temp` but bucket names can't start with 'goog' haha)
```
gsutil mb -l us-central1 gs://stock-data-temp/
```
With the name being valid, there was still a permission problem. This however was easily fixed by granting the `BigQuery Job User` to the Google Engine default service account. The role is necessary because loading data into BigQuery through Spark creates a load job behind the scenes. Without this role, the service account does not have permission to create and execute these jobs in BigQuery. The `BigQuery Data Editor` is still needed in addition to this role in order to create, update and delete BigQuery tables and datasets.  

With this, the processed data in the PySpark DataFrame is successfully loaded into BigQuery and ready to be queried with SQL!

(At this point as well, when I was going to load more symbols into BigQuery, I got an HTTP ERROR 502 for the first time when trying to access Zeppelin. This is a Bad Gateway error and the fix is to SSH into the master node and run some commands to see the status of Zeppelin:
```
sudo systemctl status zeppelin
```
Huh?????? I wrote that, went back to the tab with the 502 error and refreshed it just to make sure we still need to check the status. Works fine now. Just waiting the error out works too I guess! But if it wouldn't; check the status. If it's not running, start it manually:
```
sudo systemctl start zeppelin
```
Alternatively, restart the Zeppelin service:
```
sudo systemctl restart zeppelin
```
)

When trying to access the full Apple dataset that spans all the way back to 1999 (unlike the full Google dataset that only spans from 2024-05-03 to 2024-09-25), the cell timed out for the first time: `"Python process is abnormally exited, please check your code and log"`. 
The fix first involves SSH:ing into the Master node and checking the logs:
```
cd /var/log/zeppelin/
cat zeppelin-zeppelin-alpha-vantage1-m.log
```
Inspecting the logs revealed that the processed exited with code `143` meaning that the process was terminated by a `SIGTERM` signal, typically due to memory or resource limitations or timeout issues. To find out specifically what caused the SIGTERM termination, the YARN ResourceManager logs are also checked. This is also done by SSH:ing into the Master node:
```
cd /var/log/hadoop-yarn/
cat hadoop-yarn-timelineserver-alpha-vantage1-m.log
```
The YARN logs just revealed that something is failing but not what. Going to the Spark History Server to find the bucket location for the logs and inspecting the final rows the spark-job-history logs, there is a key entry that revealed that it is most likely a resource management issue rather than a timeout: `{"Event":"SparkListenerExecutorRemoved","Timestamp":...,"Executor ID":"4","Removed Reason":"Executor killed by driver."}`  

To really confirm this, Cloud Monitoring is used. Tinkering around in the Metrics explorer, adding a query targeting our Dataproc cluster and a query monitoring CPU usage, it was made clear that there was a spike in CPU usage:
![CPU spike dashboard from Metrics explorer](/screenshots/Cluster-capacity-deviation-[SUM]-VM-Instance-CPU-utilization-[MEAN].png "CPU spike dashboard from Metrics explorer")

The CPU usage issue during the processing of large datasets can be addressed in one of two ways:
1. Optimize the Spark Configuration: By adjusting Spark settings such as spark.executor.memory, spark.driver.memory, spark.executor.cores, and others, the efficiency of resource utilization within the existing cluster can be improved. This will allow the current setup to handle more computationally intensive tasks without additional hardware.
2. Scale Up or Scale Out: If configuration changes alone are insufficient, the alternative is to increase available resources by adding more workers (scaling out) or upgrading the machine type to provide more CPUs and memory per node (scaling up).

To test the limits of the current setup, the following configuration is added as a cell in the Zeppelin notebook above the resource-heavy cell and run before it:
```
%spark.conf
spark.executor.memory 3g
spark.driver.memory 2g
spark.executor.cores 2
spark.executor.instances 2
spark.sql.shuffle.partitions 5
spark.default.parallelism 5
spark.dynamicAllocation.enabled true
spark.dynamicAllocation.minExecutors 1
spark.dynamicAllocation.maxExecutors 3
```
After running the resource-heavy cell again, it works! The three key reasons it works (from ChatGPT. I am moreso focused on writing Spark jobs and getting the big picture understanding):
1. Memory Allocation: Executors now have sufficient memory to handle the dataset, reducing the chances of running out of memory.
2. CPU Utilization: By limiting each executor to 2 cores, it is ensured that each executor is not overloaded with too many parallel tasks. This helps in controlling CPU utilization and avoiding spikes.
3. Dynamic Resource Management: Dynamic allocation allows the Spark application to scale up and down based on demand, preventing scenarios where there are either too few or too many executors. This leads to a more balanced and efficient use of the cluster resources.

With this configuration, the full dataset for Microsoft is also extracted from the API and loaded into BigQuery.

### Data Analysis in BigQuery
[The following directory](/bigquery-queries/) contains all SQL queries ran on the data loaded into BigQuery to get an understanding of the data.

It was only in the writing SQL queries stage that attention was brought to the fact that the date column is of type `STRING` which requires casting every time a query is written. To make things run smoother, the column type is being changed to `DATE`. The change is both taking place in the loading phase to ensure correct schema for future loads and on a table level to the tables that are already in the warehouse. A data warehouse is often already well established and simply deleting a table and re-loading the data is often off the table as an option since it might be very resource-heavy. Replacing an existing table can be okay for a simpler workflow if the project is still in the development or proof-of-concept phase where data is still in flux. But for production, creating a new table is recommended for data preservation and compliance.

The following code is added in between setting the configuration options for the BigQuery connector and writing the DataFrame to BigQuery to ensure correct for schema for future loading into the warehouse:
```
# Define the schema explicitly
schema = StructType([
    StructField("date", DateType(), True),
    StructField("open", FloatType(), True),
    StructField("high", FloatType(), True),
    StructField("low", FloatType(), True),
    StructField("close", FloatType(), True),
    StructField("volume", IntegerType(), True)
])

# Apply the schema to your existing DataFrame (assuming the DataFrame is named `df`)
df = spark.createDataFrame(df.rdd, schema)
```
As for the tables that are already in the warehouse, they are updated with the [following query.](/bigquery-queries/update_tables_correct_query.sql). The existing queries are also updated to use the updated tables.  

### Visualization in PowerBI and Looker Studio
(Data visualization is not my strong suit at all and I don't really like either haha but for the practice!)

A dashboard is created in Power BI by first connecting to the BigQuery Data Warehouse. Once signed in, the three tables with updated schemas were selected and loaded into Power BI. Import is very straightforward option and a more advanced option is DirectQuery (I tried this to get some hands-on experience) It is a great option:
* When data is too large to fit into memory (e.g., multi-gigabyte or terabyte datasets).
* When real-time data access is required (e.g., monitoring dashboards with real-time metrics).
* When the dataset changes frequently throughout the day, and up-to-the-minute accuracy is necessary.
* When users are querying a centralized data warehouse (like BigQuery) that is used for multiple reporting purposes across the organization.
* For monitoring dashboards that show live data (e.g., sales performance or system health monitoring).
* Analytical use cases where historical trends are combined with up-to-date data.
* When multiple users are accessing and querying the data simultaneously and do not need offline capabilities.

A simple line chart is created displaying the close value for all three companies over time. To achieve this, Power BI needs to know the relationship and cardinality between the tables. A Date Table (also Calendar Table) is created that contains all the unique dates present in the dataset. It will serve as the central reference for each othe three stock tables. In the Modeling tab, New Table is selected and the following DAX expression is used to generate the Date Table:
```
CombinedStockData = 
UNION(
  SELECTCOLUMNS('google_stock_data_v2', "date", 'google_stock_data_v2'[date], "close", 'google_stock_data_v2'[close], "company", "Google"),
  SELECTCOLUMNS('microsoft_stock_data_v2', "date", 'microsoft_stock_data_v2'[date], "close", 'microsoft_stock_data_v2'[close], "company", "Microsoft"),
  SELECTCOLUMNS('apple_stock_data_v2', "date", 'apple_stock_data_v2'[date], "close", 'apple_stock_data_v2'[close], "company", "Apple")
)
```
With this, [the following simple report](/aapl_msft_goog.pdf) was able to be created.

To integrate Looker Studio, a new table is instead created with volume as the focus using [this query](/bigquery-queries/create_combined_volume_data_table.sql). From BigQuery, this table can then be explored in Looker Studio by pressing 'Export' and then 'Explore in Looker Studio'. [The following simple report](/Combined_Volume_Data_GOOG_AAPL_MSFT.pdf) was able to be created.

### Orchastration with Apache Airflow + Automation with GitHub Actions
Next is orchestrating the pipeline! By starting with Airflow/Composer, there will be a clear orchestration pipeline ready to automate with GitHub Actions. But the first step is to ensure an end-to-end data pipeline that manually can be ran and monitored using Airflow.

To start off, the Cloud Composer API is enabled. Composer 3 is chosen over Composer 2 since it builds on the functionalities of its predecessors while simplifying some configuration and management aspects. The latest default Image version is chosen and as for Environment resource size, Medium is chosen. It gives enough headroom to handle commoon Airflow tasks without hitting resource contratints too quickly. It also provides a good balance between cost and resource availability for most use cases, including DAG scheduling, task execution, and monitoring.

The DAG is written in VSCode and at the same time, a GitHub Actions workflow is written. This ensures that the code is automatically tested and, if passed, deployed to Composer whenever there are pushes to the `main` branch. (This is my first time using any sort of CI/CD workflow so it's completely new and uncomfortable but the only focus is to just fail forward!!)

In order for the workflow to work, a connection needs to be made between GitHub Actions and Google Cloud. This can be done in one of two ways: the simpler way is to download and store a JSON key file. This however is not recommended by Google themselves: "Service account keys could pose a security risk if compromised. We recommend you avoid downloading service account keys and instead use the Workload Identity Federation." 
(To get hands-on experience with the Workload Identity Federation, I did my best to see it through:
In IAM & Admin, a Pool called `github-actions-pool` is created in Workload Identity Federation. OIDC is chosen as Identity Provider Type and `github-provider` is entered as Provider ID. The Issuer URL is `https://token.actions.githubusercontent.com` and the allowed audience in this case is `https://github.com/StevenLomon/stock-market-big-data-project-spark-bigquery`. The CEL expression and attribute mapping value for google.subject is entered as `"system:serviceaccount:" + "github.com/" + attributes.repository + ":" + attributes.workflow`. This maps to the structure system:serviceaccount:github.com/{repository}:{workflow} and helps identify the origin of the request. This didn't work... and resulted in a shitshow of OIDC errors, permission errors and "Error code: 400. The attribute condition must reference one of the provider's claims")

The traditional method of using JSON keys is still perfectly fine for non-production use cases or proof-of-concept projects:
A JSON key file of the service account is created in IAM & Admin by creating a new service account with `Composer Administrator` and `Storage Object Admin` attached and downloading the JSON key. The contents of the key is stored as `GCP_SA_KEY` in GitHub Actions together with the project ID as `GCP_PROJECT_ID`. Both are stored as Repository secrets since they are only used for this project and this repository. 
(This is SO MUCH EASIER)

(Here I made a commit with GitHub Actions set up for the first time in my life. And it resulted in a very amusing wake-up call from pylint hahaha:)
![First GitHub Actions log](/screenshots/Skärmbild-2024-10-05%20091033.png "First GitHub Actions log")

### Infrastructure as Code with Terraform