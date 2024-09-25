#!/bin/bash

# Update package list
apt-get update

# Install dependencies for Python 3.8
apt-get install -y software-properties-common

# Add the deadsnakes PPA to get newer Python versions
add-apt-repository ppa:deadsnakes/ppa

# Install Python 3.9
sudo apt-get install -y python3.9 python3.9-distutils python3.9-dev

# Set Python 3.9 as the default Python version
sudo update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.9 1

# Install pip for Python 3.9
curl https://bootstrap.pypa.io/get-pip.py | sudo python3.9
