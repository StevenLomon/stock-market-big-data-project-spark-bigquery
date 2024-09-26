#!/bin/bash

# Update package list and install dependencies for Python 3.9
sudo apt-get update
sudo apt-get install -y software-properties-common

# Add the deadsnakes PPA for newer Python versions
sudo add-apt-repository ppa:deadsnakes/ppa -y

# Install Python 3.9 and its dependencies
sudo apt-get install -y python3.9 python3.9-distutils python3.9-dev

# Install pip for Python 3.9
curl https://bootstrap.pypa.io/get-pip.py | sudo python3.9

# Install PySpark using pip for Python 3.9
sudo /usr/local/bin/python3.9 -m pip install pyspark

# Install Jupyter and IPython dependencies
sudo /usr/local/bin/python3.9 -m pip install jupyter jupyter-client ipython

# Set environment variables to use Python 3.9 for both driver and workers
echo "export PYSPARK_PYTHON=/usr/local/bin/python3.9" | sudo tee -a /etc/environment
echo "export PYSPARK_DRIVER_PYTHON=/usr/local/bin/python3.9" | sudo tee -a /etc/environment

# Apply the environment variables for the current session
export PYSPARK_PYTHON=/usr/local/bin/python3.9
export PYSPARK_DRIVER_PYTHON=/usr/local/bin/python3.9
