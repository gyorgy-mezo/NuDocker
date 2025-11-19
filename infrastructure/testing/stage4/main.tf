# Stage 4: Multi-Node HTCondor Cluster Test
# Deploys 2-node cluster: 1 central manager + 1 execute node
# Tests distributed job execution, NFS storage, and Ansible configuration
# Resources: 2 VMs (central: 2 vCPU, 4GB; execute: 4 vCPU, 8GB)
# Duration: ~45 minutes
# Cost: ~€2.50-4.00

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
  cloud = var.cloud_name
}

# Data source: Get custom image from Stage 2
data "openstack_images_image_v2" "nudocker_test" {
  name        = var.custom_image_name
  most_recent = true
}

# Security group for HTCondor cluster
resource "openstack_networking_secgroup_v2" "stage4_cluster" {
  name        = "${var.prefix}-stage4-cluster"
  description = "Stage 4: HTCondor multi-node cluster"
}

# SSH access
resource "openstack_networking_secgroup_rule_v2" "stage4_ssh" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.stage4_cluster.id
}

# HTCondor ports
resource "openstack_networking_secgroup_rule_v2" "stage4_htcondor_collector" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 9618
  port_range_max    = 9618
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.stage4_cluster.id
}

resource "openstack_networking_secgroup_rule_v2" "stage4_htcondor_range" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 9600
  port_range_max    = 9700
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.stage4_cluster.id
}

# NFS ports
resource "openstack_networking_secgroup_rule_v2" "stage4_nfs_tcp" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 2049
  port_range_max    = 2049
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.stage4_cluster.id
}

resource "openstack_networking_secgroup_rule_v2" "stage4_nfs_udp" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "udp"
  port_range_min    = 2049
  port_range_max    = 2049
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.stage4_cluster.id
}

# RPC bind (for NFS)
resource "openstack_networking_secgroup_rule_v2" "stage4_rpcbind" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 111
  port_range_max    = 111
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.stage4_cluster.id
}

# Central Manager VM
resource "openstack_compute_instance_v2" "central_manager" {
  name        = "${var.prefix}-stage4-central"
  image_id    = data.openstack_images_image_v2.nudocker_test.id
  flavor_name = var.central_flavor

  key_pair = var.key_pair_name

  security_groups = [
    "default",
    openstack_networking_secgroup_v2.stage4_cluster.name
  ]

  network {
    name = var.network_name
  }

  metadata = {
    Stage       = "4"
    Role        = "Central Manager"
    Purpose     = "Multi-node cluster test"
    Project     = "NuDocker"
    ManagedBy   = "Terraform"
  }

  # Configure as central manager + NFS server
  user_data = <<-EOF
    #!/bin/bash
    set -e

    # Get internal IP
    INTERNAL_IP=$(hostname -I | awk '{print $1}')

    # Configure NFS server
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y nfs-kernel-server

    # Create shared storage
    mkdir -p /storage/{htcondor_jobs,results,config}
    chown -R ubuntu:ubuntu /storage

    # Configure NFS exports
    echo "/storage *(rw,sync,no_subtree_check,no_root_squash)" >> /etc/exports
    exportfs -ra
    systemctl restart nfs-kernel-server

    # Configure HTCondor as central manager
    cat > /etc/condor/config.d/50-central.config <<EOC
# Central Manager configuration
CONDOR_HOST = $INTERNAL_IP
DAEMON_LIST = COLLECTOR, MASTER, NEGOTIATOR, SCHEDD

# Network settings
ALLOW_WRITE = *
ALLOW_READ = *
ALLOW_ADMINISTRATOR = *
ALLOW_NEGOTIATOR = *
ALLOW_CONFIG = *
ALLOW_DAEMON = *

# Security (permissive for testing)
SEC_DEFAULT_AUTHENTICATION = OPTIONAL
SEC_DEFAULT_INTEGRITY = OPTIONAL
SEC_DEFAULT_ENCRYPTION = OPTIONAL

# Shared filesystem
FILESYSTEM_DOMAIN = nudocker-test
UID_DOMAIN = nudocker-test

# Enable Docker Universe
DOCKER = /usr/bin/docker
EOC

    # Start HTCondor
    systemctl enable condor
    systemctl restart condor

    # Create test submit files
    mkdir -p /home/ubuntu/cluster_test
    cat > /home/ubuntu/cluster_test/distributed_job.sub <<EOS
# Distributed job across cluster
universe     = vanilla
executable   = /bin/hostname
output       = job_\$(Process).out
error        = job_\$(Process).err
log          = distributed.log
request_cpus = 1
request_memory = 512M
queue 5
EOS

    chown -R ubuntu:ubuntu /home/ubuntu/cluster_test

    # Save central manager IP for execute nodes
    echo "$INTERNAL_IP" > /storage/config/central_ip.txt

    echo "Central Manager configuration complete"
  EOF
}

# Execute Node VM
resource "openstack_compute_instance_v2" "execute_node" {
  name        = "${var.prefix}-stage4-execute"
  image_id    = data.openstack_images_image_v2.nudocker_test.id
  flavor_name = var.execute_flavor

  key_pair = var.key_pair_name

  security_groups = [
    "default",
    openstack_networking_secgroup_v2.stage4_cluster.name
  ]

  network {
    name = var.network_name
  }

  metadata = {
    Stage       = "4"
    Role        = "Execute Node"
    Purpose     = "Multi-node cluster test"
    Project     = "NuDocker"
    ManagedBy   = "Terraform"
  }

  # Wait for central manager to be ready
  depends_on = [openstack_compute_instance_v2.central_manager]

  # Configure as execute node + NFS client
  user_data = <<-EOF
    #!/bin/bash
    set -e

    # Wait for central manager to be ready
    sleep 30

    # Get central manager IP
    CENTRAL_IP="${openstack_compute_instance_v2.central_manager.access_ip_v4}"

    # Mount NFS
    mkdir -p /storage
    echo "$CENTRAL_IP:/storage /storage nfs defaults,_netdev 0 0" >> /etc/fstab
    mount -a

    # Verify NFS mount
    ls /storage || echo "NFS mount failed"

    # Configure HTCondor as execute node
    cat > /etc/condor/config.d/50-execute.config <<EOC
# Execute Node configuration
CONDOR_HOST = $CENTRAL_IP
DAEMON_LIST = MASTER, STARTD

# Network settings
ALLOW_WRITE = *
ALLOW_READ = *

# Security (permissive for testing)
SEC_DEFAULT_AUTHENTICATION = OPTIONAL
SEC_DEFAULT_INTEGRITY = OPTIONAL
SEC_DEFAULT_ENCRYPTION = OPTIONAL

# Execute node configuration
NUM_SLOTS = 4
SLOT_TYPE_1 = cpus=100%,ram=100%,disk=100%
NUM_SLOTS_TYPE_1 = 4

# Shared filesystem
FILESYSTEM_DOMAIN = nudocker-test
UID_DOMAIN = nudocker-test

# Enable Docker Universe
DOCKER = /usr/bin/docker
DOCKER_VOLUMES = DOCKER_VOLUME_DIR_STORAGE:/storage:rw
EOC

    # Start HTCondor
    systemctl enable condor
    systemctl restart condor

    echo "Execute Node configuration complete"
  EOF
}

# Floating IP for central manager
resource "openstack_networking_floatingip_v2" "central_fip" {
  pool = var.external_network_name
}

resource "openstack_compute_floatingip_associate_v2" "central_fip_assoc" {
  floating_ip = openstack_networking_floatingip_v2.central_fip.address
  instance_id = openstack_compute_instance_v2.central_manager.id
}

# Outputs
output "central_manager_id" {
  description = "Central manager VM ID"
  value       = openstack_compute_instance_v2.central_manager.id
}

output "central_manager_internal_ip" {
  description = "Central manager internal IP"
  value       = openstack_compute_instance_v2.central_manager.access_ip_v4
}

output "central_manager_floating_ip" {
  description = "Central manager floating IP"
  value       = openstack_networking_floatingip_v2.central_fip.address
}

output "execute_node_id" {
  description = "Execute node VM ID"
  value       = openstack_compute_instance_v2.execute_node.id
}

output "execute_node_internal_ip" {
  description = "Execute node internal IP"
  value       = openstack_compute_instance_v2.execute_node.access_ip_v4
}

output "ssh_command" {
  description = "SSH command to central manager"
  value       = "ssh -i ${var.ssh_private_key_path} ubuntu@${openstack_networking_floatingip_v2.central_fip.address}"
}

output "test_commands" {
  description = "Commands to test cluster"
  value = <<-EOT
    # Connect to central manager:
    ssh -i ${var.ssh_private_key_path} ubuntu@${openstack_networking_floatingip_v2.central_fip.address}

    # Check cluster status:
    condor_status

    # Should see execute node with 4 slots
    # Submit distributed job:
    cd ~/cluster_test
    condor_submit distributed_job.sub

    # Watch jobs distribute across nodes:
    watch condor_q
  EOT
}
