#!/bin/bash
# Install HTCondor
set -e

echo "==> Installing HTCondor ${HTCONDOR_VERSION}..."

# Add HTCondor repository
wget -qO - https://research.cs.wisc.edu/htcondor/repo/keys/HTCondor-${HTCONDOR_VERSION}-Key | sudo apt-key add -
echo "deb [arch=amd64] http://research.cs.wisc.edu/htcondor/repo/ubuntu/$(lsb_release -cs) $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/htcondor.list

# Update and install HTCondor
sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y htcondor

# Stop HTCondor (will be configured later)
sudo systemctl stop condor
sudo systemctl disable condor

# Create condor directories
sudo mkdir -p /etc/condor/config.d
sudo mkdir -p /var/lib/condor
sudo mkdir -p /var/log/condor
sudo mkdir -p /var/run/condor

# Set permissions
sudo chown -R condor:condor /var/lib/condor
sudo chown -R condor:condor /var/log/condor
sudo chown -R condor:condor /var/run/condor

# Verify installation
condor_version

echo "==> HTCondor installation completed"
