#!/bin/bash
# Apply configuration files
set -e

echo "==> Applying configuration files..."

# Copy NuDocker configuration files if they exist
if [ -d "/tmp/nudocker-files" ]; then
    # Copy bash aliases for MESA environment
    if [ -f "/tmp/nudocker-files/bash_aliases" ]; then
        sudo cp /tmp/nudocker-files/bash_aliases /etc/skel/.bash_aliases
        cp /tmp/nudocker-files/bash_aliases ~/.bash_aliases
    fi

    # Copy HTCondor base configuration
    if [ -f "/tmp/nudocker-files/htcondor_base.conf" ]; then
        sudo cp /tmp/nudocker-files/htcondor_base.conf /etc/condor/config.d/00_base.conf
    fi
fi

echo "==> Configuration files applied"
