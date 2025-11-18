#!/bin/bash
# Install Singularity/Apptainer
set -e

echo "==> Installing Singularity dependencies..."

# Install dependencies
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
    build-essential \
    libseccomp-dev \
    pkg-config \
    squashfs-tools \
    cryptsetup \
    runc \
    uidmap

# Install Go (required for building Singularity)
echo "==> Installing Go..."
GO_VERSION="1.21.5"
cd /tmp
wget -q https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz
sudo rm -rf /usr/local/go
sudo tar -C /usr/local -xzf go${GO_VERSION}.linux-amd64.tar.gz
rm go${GO_VERSION}.linux-amd64.tar.gz

export PATH=/usr/local/go/bin:$PATH
go version

# Install Apptainer (modern fork of Singularity)
echo "==> Installing Apptainer..."
APPTAINER_VERSION="1.2.5"
cd /tmp
wget -q https://github.com/apptainer/apptainer/releases/download/v${APPTAINER_VERSION}/apptainer-${APPTAINER_VERSION}.tar.gz
tar -xzf apptainer-${APPTAINER_VERSION}.tar.gz
cd apptainer-${APPTAINER_VERSION}

./mconfig --prefix=/usr/local
make -C builddir
sudo make -C builddir install

# Cleanup
cd /tmp
rm -rf apptainer-${APPTAINER_VERSION}*

# Verify installation
apptainer --version
singularity --version || true

echo "==> Apptainer/Singularity installation completed"
