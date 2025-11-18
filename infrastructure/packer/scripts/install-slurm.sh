#!/bin/bash
# Install SLURM Workload Manager
# Version: 23.02.x (Ubuntu 20.04 default)

set -e
set -x

echo "================================================"
echo "Installing SLURM Workload Manager"
echo "================================================"

# Update package list
apt-get update

# Install SLURM packages
# Note: Installing full package set for both controller and compute
# Actual role determined by configuration at deployment time
apt-get install -y \
    slurm-wlm \
    slurm-wlm-basic-plugins \
    slurm-client \
    slurmdbd \
    munge \
    libmunge-dev \
    libmunge2 \
    mariadb-server \
    libmariadb-dev

# Create SLURM user and group (if not exists)
if ! id -u slurm >/dev/null 2>&1; then
    useradd -r -s /bin/false -d /var/lib/slurm slurm
fi

# Create necessary directories
mkdir -p /etc/slurm
mkdir -p /var/spool/slurm
mkdir -p /var/spool/slurmctld
mkdir -p /var/spool/slurmd
mkdir -p /var/log/slurm
mkdir -p /var/run/slurm

# Set ownership
chown -R slurm:slurm /etc/slurm
chown -R slurm:slurm /var/spool/slurm*
chown -R slurm:slurm /var/log/slurm
chown -R slurm:slurm /var/run/slurm

# Set permissions
chmod 755 /etc/slurm
chmod 755 /var/spool/slurm*
chmod 755 /var/log/slurm
chmod 755 /var/run/slurm

# Generate munge key (will be overwritten by Ansible with shared key)
if [ ! -f /etc/munge/munge.key ]; then
    create-munge-key
    chown munge:munge /etc/munge/munge.key
    chmod 400 /etc/munge/munge.key
fi

# Enable munge service (but don't start - configuration comes later)
systemctl enable munge

# Do NOT enable slurm services yet - configuration happens at deployment
systemctl disable slurmctld || true
systemctl disable slurmd || true
systemctl disable slurmdbd || true

# Install cgroup tools for resource management
apt-get install -y \
    cgroup-tools \
    libcgroup1

# Configure cgroup v1 (SLURM compatibility)
# Add cgroup_enable=memory swapaccount=1 to kernel parameters if needed
if ! grep -q "cgroup_enable=memory" /etc/default/grub 2>/dev/null; then
    echo "Note: For production, add 'cgroup_enable=memory swapaccount=1' to GRUB_CMDLINE_LINUX"
    echo "      in /etc/default/grub and run update-grub"
fi

# Verify installations
echo ""
echo "Verifying SLURM installation..."
slurmd -V
slurmctld -V
scontrol --version

echo ""
echo "Verifying munge installation..."
munge --version

echo ""
echo "================================================"
echo "SLURM Installation Complete"
echo "================================================"
echo ""
echo "Installed packages:"
dpkg -l | grep -E 'slurm|munge' | awk '{print $2 "\t" $3}'
echo ""
echo "Note: SLURM services will be configured during deployment"
