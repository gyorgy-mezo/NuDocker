# Stage 5: Dual-Scheduler Cluster Test (HTCondor + SLURM)
# Deploys 2-node cluster: 1 controller + 1 compute node
# Tests HTCondor and SLURM coexistence, NFS storage, and dual job execution
# Resources: 2 VMs (controller: 2 vCPU, 4GB; compute: 4 vCPU, 8GB)

terraform {
  required_version = ">= 1.0"
  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 1.51"
    }
  }
}

provider "openstack" {
  # Using environment variables for authentication (OS_*)
}

# Data source: Get custom image from Stage 2
data "openstack_images_image_v2" "nudocker_test" {
  name        = var.custom_image_name
  most_recent = true
}

# Security group for dual-scheduler cluster
resource "openstack_networking_secgroup_v2" "stage5_cluster" {
  name        = "${var.prefix}-stage5-cluster"
  description = "Stage 5: HTCondor + SLURM dual-scheduler cluster"
}

# SSH access
resource "openstack_networking_secgroup_rule_v2" "stage5_ssh" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.stage5_cluster.id
}

# HTCondor ports
resource "openstack_networking_secgroup_rule_v2" "stage5_htcondor_collector" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 9618
  port_range_max    = 9618
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.stage5_cluster.id
}

resource "openstack_networking_secgroup_rule_v2" "stage5_htcondor_range" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 9600
  port_range_max    = 9700
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.stage5_cluster.id
}

# SLURM ports
resource "openstack_networking_secgroup_rule_v2" "stage5_slurm_controller" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 6817
  port_range_max    = 6817
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.stage5_cluster.id
}

resource "openstack_networking_secgroup_rule_v2" "stage5_slurm_daemon" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 6818
  port_range_max    = 6818
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.stage5_cluster.id
}

# NFS ports
resource "openstack_networking_secgroup_rule_v2" "stage5_nfs_tcp" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 2049
  port_range_max    = 2049
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.stage5_cluster.id
}

resource "openstack_networking_secgroup_rule_v2" "stage5_nfs_udp" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "udp"
  port_range_min    = 2049
  port_range_max    = 2049
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.stage5_cluster.id
}

# RPC bind (for NFS)
resource "openstack_networking_secgroup_rule_v2" "stage5_rpcbind" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 111
  port_range_max    = 111
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.stage5_cluster.id
}

# Controller VM (HTCondor Central Manager + SLURM Controller)
resource "openstack_compute_instance_v2" "controller" {
  name        = "${var.prefix}-stage5-controller"
  flavor_name = var.central_flavor

  key_pair = var.key_pair_name

  security_groups = [
    "default",
    openstack_networking_secgroup_v2.stage5_cluster.name
  ]

  network {
    name = var.network_name
  }

  metadata = {
    Stage       = "5"
    Role        = "Controller"
    Purpose     = "Dual-scheduler test"
    Project     = "NuDocker"
    ManagedBy   = "Terraform"
  }

  # HUN-REN Cloud requires volume-backed instances
  block_device {
    uuid                  = data.openstack_images_image_v2.nudocker_test.id
    source_type           = "image"
    destination_type      = "volume"
    boot_index            = 0
    volume_size           = 50
    delete_on_termination = true
  }

  # Configure as HTCondor central manager + SLURM controller + NFS server
  user_data = <<EOF
#!/bin/bash
set -e

# Get internal IP
INTERNAL_IP=$(hostname -I | awk '{print $1}')

# Configure NFS server
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y nfs-kernel-server

# Configure NFS exports for /home
echo "/home 192.168.0.0/24(rw,sync,no_subtree_check,no_root_squash)" > /etc/exports
exportfs -ra
systemctl enable nfs-kernel-server
systemctl restart nfs-kernel-server

# Configure HTCondor as central manager
cat > /etc/condor/config.d/50-central.config <<EOC
# Central Manager configuration for HUN-REN Cloud
# Explicit resource detection (auto-detection fails in HUN-REN environment)

# Resource limits (for 2 vCPU, 4 GB RAM flavor)
NUM_CPUS = 2
MEMORY = 4096

# This is a central manager
DAEMON_LIST = MASTER, COLLECTOR, NEGOTIATOR, SCHEDD

# Network configuration
CONDOR_HOST = \$(FULL_HOSTNAME)
NETWORK_INTERFACE = $INTERNAL_IP
CONDOR_VIEW_HOST = \$(CONDOR_HOST)

# Allow all communication (required for execute nodes to register)
ALLOW_READ = *
ALLOW_WRITE = *
ALLOW_NEGOTIATOR = *
ALLOW_ADMINISTRATOR = *
ALLOW_DAEMON = *
HOSTALLOW_WRITE = *

# Security settings
SEC_DEFAULT_AUTHENTICATION = OPTIONAL
SEC_DEFAULT_AUTHENTICATION_METHODS = FS, PASSWORD, CLAIMTOBE
SEC_CLIENT_AUTHENTICATION_METHODS = FS, PASSWORD, CLAIMTOBE

# Shared filesystem
FILESYSTEM_DOMAIN = nudocker-test
UID_DOMAIN = nudocker-test

# Enable Docker Universe
DOCKER = /usr/bin/docker
EOC

# Start HTCondor
systemctl enable condor
systemctl restart condor

# Wait for HTCondor to fully start
sleep 10

# Create test submit files for HTCondor
mkdir -p /home/ubuntu/cluster_test
cat > /home/ubuntu/cluster_test/test_script.sh <<'EOS'
#!/bin/bash
echo "HTCondor Job $1 running on $(hostname) at $(date)"
sleep 5
echo "HTCondor Job $1 completed successfully"
exit 0
EOS
chmod +x /home/ubuntu/cluster_test/test_script.sh

cat > /home/ubuntu/cluster_test/htcondor_job.sub <<'EOS'
# HTCondor distributed job submission file
executable = test_script.sh
arguments = $(Process)

output = htcondor_job_$(Process).out
error = htcondor_job_$(Process).err
log = htcondor_jobs.log

# Request resources
request_cpus = 1
request_memory = 512MB

# Submit 6 jobs to test distribution
queue 6
EOS

# Install SLURM controller
DEBIAN_FRONTEND=noninteractive apt-get install -y slurm-wlm munge

# Generate munge key
dd if=/dev/urandom bs=1 count=1024 > /etc/munge/munge.key
chown munge:munge /etc/munge/munge.key
chmod 400 /etc/munge/munge.key

# Start munge
systemctl enable munge
systemctl restart munge

# Configure SLURM
cat > /etc/slurm/slurm.conf <<'SLURM_CONF'
ClusterName=nudocker-stage5
SlurmctldHost=$(hostname)
MpiDefault=none
ProctrackType=proctrack/linuxproc
ReturnToService=2
SlurmctldPidFile=/var/run/slurmctld.pid
SlurmctldPort=6817
SlurmdPidFile=/var/run/slurmd.pid
SlurmdPort=6818
SlurmdSpoolDir=/var/spool/slurmd
SlurmUser=slurm
StateSaveLocation=/var/spool/slurmctld
SwitchType=switch/none
TaskPlugin=task/none

# TIMERS
InactiveLimit=0
KillWait=30
MinJobAge=300
SlurmctldTimeout=120
SlurmdTimeout=300
Waittime=0

# SCHEDULING
SchedulerType=sched/backfill
SelectType=select/cons_tres
SelectTypeParameters=CR_Core

# LOGGING
SlurmctldDebug=info
SlurmctldLogFile=/var/log/slurmctld.log
SlurmdDebug=info
SlurmdLogFile=/var/log/slurmd.log

# COMPUTE NODES
NodeName=DEFAULT CPUs=4 RealMemory=8000 State=UNKNOWN
NodeName=nudocker-test-stage5-compute Procs=4 State=UNKNOWN
PartitionName=debug Nodes=ALL Default=YES MaxTime=INFINITE State=UP
SLURM_CONF

# Create SLURM directories
mkdir -p /var/spool/slurmctld
chown slurm:slurm /var/spool/slurmctld

# Start SLURM controller
systemctl enable slurmctld
systemctl restart slurmctld

# Create SLURM test script
cat > /home/ubuntu/cluster_test/slurm_test.sh <<'SLURM_TEST'
#!/bin/bash
#SBATCH --job-name=slurm_test
#SBATCH --output=slurm_job_%j.out
#SBATCH --ntasks=1
#SBATCH --time=00:05:00

echo "SLURM Job $SLURM_JOB_ID running on $(hostname) at $(date)"
sleep 5
echo "SLURM Job $SLURM_JOB_ID completed successfully"
SLURM_TEST
chmod +x /home/ubuntu/cluster_test/slurm_test.sh

chown -R ubuntu:ubuntu /home/ubuntu/cluster_test

# Fix permissions for HTCondor access (HTCondor runs as 'condor' user)
# Allow HTCondor to cd into /home/ubuntu
chmod 755 /home/ubuntu
# Allow HTCondor to write job outputs
chmod 777 /home/ubuntu/cluster_test

echo "Controller configuration complete"
EOF
}

# Compute Node VM (HTCondor Execute + SLURM Compute)
resource "openstack_compute_instance_v2" "compute_node" {
  name        = "${var.prefix}-stage5-compute"
  flavor_name = var.execute_flavor

  key_pair = var.key_pair_name

  security_groups = [
    "default",
    openstack_networking_secgroup_v2.stage5_cluster.name
  ]

  network {
    name = var.network_name
  }

  metadata = {
    Stage       = "5"
    Role        = "Compute Node"
    Purpose     = "Dual-scheduler test"
    Project     = "NuDocker"
    ManagedBy   = "Terraform"
  }

  # HUN-REN Cloud requires volume-backed instances
  block_device {
    uuid                  = data.openstack_images_image_v2.nudocker_test.id
    source_type           = "image"
    destination_type      = "volume"
    boot_index            = 0
    volume_size           = 50
    delete_on_termination = true
  }

  # Wait for controller to be ready
  depends_on = [openstack_compute_instance_v2.controller]

  # Configure as HTCondor execute node + SLURM compute + NFS client
  user_data = <<EOF
#!/bin/bash
set -e

# Wait for controller to be ready
sleep 60

# Get controller IP
CONTROLLER_IP="${openstack_compute_instance_v2.controller.access_ip_v4}"

# Install NFS client
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y nfs-common

# Mount NFS /home from controller
echo "$CONTROLLER_IP:/home /home nfs defaults,_netdev 0 0" >> /etc/fstab
mount -a

# Verify NFS mount
df -h | grep home || echo "NFS mount failed"

# Get compute node internal IP
COMPUTE_IP=$(hostname -I | awk '{print $1}')

# Configure HTCondor as execute node
cat > /etc/condor/config.d/50-execute.config <<EOC
# Execute Node configuration for HUN-REN Cloud
# Explicit resource detection (auto-detection fails in HUN-REN environment)

# Resource limits (for 4 vCPU, 8 GB RAM flavor)
NUM_CPUS = 4
MEMORY = 8192

# This is an execute node
DAEMON_LIST = MASTER, STARTD

# Point to controller
CONDOR_HOST = $CONTROLLER_IP

# Network configuration
NETWORK_INTERFACE = $COMPUTE_IP
ALLOW_READ = *
ALLOW_WRITE = *

# Security settings
SEC_DEFAULT_AUTHENTICATION = OPTIONAL
SEC_DEFAULT_AUTHENTICATION_METHODS = FS, PASSWORD, CLAIMTOBE
SEC_CLIENT_AUTHENTICATION_METHODS = FS, PASSWORD, CLAIMTOBE

# Slot configuration (1 CPU per slot to avoid over-allocation)
NUM_SLOTS = 4
SLOT_TYPE_1 = cpus=1
NUM_SLOTS_TYPE_1 = 4

# Shared filesystem
FILESYSTEM_DOMAIN = nudocker-test
UID_DOMAIN = nudocker-test

# Enable Docker Universe
DOCKER = /usr/bin/docker
EOC

# Start HTCondor
systemctl enable condor
systemctl restart condor

# Install SLURM compute daemon
DEBIAN_FRONTEND=noninteractive apt-get install -y slurmd munge

# Wait a bit for NFS and controller munge key
sleep 10

# Copy munge key from controller via NFS-mounted /home
# (Controller should export /etc/munge to NFS or we copy via different method)
# For now, we'll fetch it via scp in a loop
for i in {1..30}; do
  if scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ubuntu@$CONTROLLER_IP:/etc/munge/munge.key /tmp/munge.key 2>/dev/null; then
    break
  fi
  sleep 2
done

if [ -f /tmp/munge.key ]; then
  mv /tmp/munge.key /etc/munge/munge.key
  chown munge:munge /etc/munge/munge.key
  chmod 400 /etc/munge/munge.key
  systemctl enable munge
  systemctl restart munge
fi

# Copy SLURM config from controller
scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ubuntu@$CONTROLLER_IP:/etc/slurm/slurm.conf /etc/slurm/slurm.conf

# Update hostname in config
sed -i "s/SlurmctldHost=.*/SlurmctldHost=$CONTROLLER_IP/" /etc/slurm/slurm.conf

# Create SLURM directories
mkdir -p /var/spool/slurmd
chown slurm:slurm /var/spool/slurmd

# Start SLURM compute daemon
systemctl enable slurmd
systemctl restart slurmd

echo "Compute Node configuration complete"
EOF
}

# Floating IP for controller
resource "openstack_networking_floatingip_v2" "controller_fip" {
  pool = var.external_network_name
}

resource "openstack_compute_floatingip_associate_v2" "controller_fip_assoc" {
  floating_ip = openstack_networking_floatingip_v2.controller_fip.address
  instance_id = openstack_compute_instance_v2.controller.id
}

# Outputs
output "controller_id" {
  description = "Controller VM ID"
  value       = openstack_compute_instance_v2.controller.id
}

output "controller_internal_ip" {
  description = "Controller internal IP"
  value       = openstack_compute_instance_v2.controller.access_ip_v4
}

output "controller_floating_ip" {
  description = "Controller floating IP"
  value       = openstack_networking_floatingip_v2.controller_fip.address
}

output "compute_node_id" {
  description = "Compute node VM ID"
  value       = openstack_compute_instance_v2.compute_node.id
}

output "compute_node_internal_ip" {
  description = "Compute node internal IP"
  value       = openstack_compute_instance_v2.compute_node.access_ip_v4
}

output "ssh_command" {
  description = "SSH command to controller"
  value       = "ssh -i ${var.ssh_private_key_path} ubuntu@${openstack_networking_floatingip_v2.controller_fip.address}"
}

output "test_commands" {
  description = "Commands to test dual-scheduler cluster"
  value = <<-EOT
    # Connect to controller:
    ssh -i ${var.ssh_private_key_path} ubuntu@${openstack_networking_floatingip_v2.controller_fip.address}

    # Test HTCondor:
    condor_status
    cd ~/cluster_test
    condor_submit htcondor_job.sub
    watch condor_q

    # Test SLURM:
    sinfo
    squeue
    sbatch slurm_test.sh
    watch squeue
  EOT
}
