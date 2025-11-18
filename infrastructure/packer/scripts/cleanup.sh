#!/bin/bash
# Cleanup script for Packer image
set -e

echo "==> Cleaning up..."

# Clean apt cache
sudo apt-get clean
sudo apt-get autoremove -y

# Remove temporary files
sudo rm -rf /tmp/*
sudo rm -rf /var/tmp/*

# Clear logs
sudo find /var/log -type f -exec truncate -s 0 {} \;

# Remove SSH host keys (will be regenerated on first boot)
sudo rm -f /etc/ssh/ssh_host_*

# Clear shell history
history -c
cat /dev/null > ~/.bash_history

# Remove cloud-init artifacts
sudo cloud-init clean --logs --seed

# Clear machine ID
sudo truncate -s 0 /etc/machine-id

# Sync filesystem
sync

echo "==> Cleanup completed"
