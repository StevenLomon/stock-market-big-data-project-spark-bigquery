#!/bin/bash

# Update package list
apt-get update

# Install dependencies for Python 3.8
apt-get install -y software-properties-common

# Add the deadsnakes PPA to get newer Python versions
add-apt-repository ppa:deadsnakes/ppa

# Install Python 3.8
apt-get install -y python3.8 python3.8-distutils python3.8-dev

# Set Ptyhon 3.8 as the default Python version
update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.8 1

# Install pip for Python 3.8
curl https://bootstrap.pypa.io/get-pip.py | python3.8
