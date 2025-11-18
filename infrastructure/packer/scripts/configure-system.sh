#!/bin/bash
# Configure system settings for HTCondor cluster
set -e

echo "==> Configuring system settings..."

# Increase file descriptor limits for HTCondor
cat <<'EOF' | sudo tee -a /etc/security/limits.conf
# HTCondor file descriptor limits
condor soft nofile 65536
condor hard nofile 65536
* soft nofile 65536
* hard nofile 65536
EOF

# Kernel parameters for HTCondor and Docker
cat <<'EOF' | sudo tee /etc/sysctl.d/99-nudocker.conf
# Increase inotify limits for Docker
fs.inotify.max_user_watches = 524288
fs.inotify.max_user_instances = 512

# Network performance
net.core.somaxconn = 1024
net.ipv4.tcp_max_syn_backlog = 2048

# Shared memory for MESA
kernel.shmmax = 68719476736
kernel.shmall = 4294967296
EOF

sudo sysctl -p /etc/sysctl.d/99-nudocker.conf

# Configure automatic security updates
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y unattended-upgrades
sudo dpkg-reconfigure -plow unattended-upgrades

# Set timezone to UTC
sudo timedatectl set-timezone UTC

# Configure SSH
sudo sed -i 's/#PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
sudo sed -i 's/#PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config

echo "==> System configuration completed"
