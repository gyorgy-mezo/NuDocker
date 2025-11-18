#!/bin/bash
# Install NuDocker dependencies and utilities
set -e

echo "==> Installing NuDocker dependencies..."

# Install MESA-related packages
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
    gcc \
    gfortran \
    g++ \
    binutils \
    make \
    git \
    subversion \
    emacs \
    nano \
    vim \
    libopenblas-dev \
    libopenmpi-dev \
    libx11-dev \
    zlib1g-dev \
    openmpi-bin \
    openmpi-common \
    openmpi-doc \
    bzip2 \
    less \
    perl \
    python3 \
    python3-pip \
    python3-virtualenv \
    rsync \
    ssh \
    tcsh \
    unzip \
    wget \
    htop \
    tmux \
    tree

# Install Python packages useful for analysis
sudo pip3 install numpy scipy matplotlib h5py

# Install NFS client utilities
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y nfs-common

# Create standard directories
sudo mkdir -p /storage
sudo mkdir -p /home/user

echo "==> NuDocker dependencies installation completed"
