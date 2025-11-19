# Stage 3: Single-Node HTCondor Test
# Deploys one VM with HTCondor in standalone mode
# Tests basic job submission and execution
# Resources: 1 VM (4 vCPU, 8 GB RAM, 40 GB disk)
# Duration: ~30 minutes
# Cost: ~€1.50-2.50

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

# Data source: Get custom image built in Stage 2
data "openstack_images_image_v2" "nudocker_test" {
  name        = var.custom_image_name
  most_recent = true
}

# Security group for HTCondor
resource "openstack_networking_secgroup_v2" "stage3_htcondor" {
  name        = "${var.prefix}-stage3-htcondor"
  description = "Stage 3: HTCondor single-node security group"
}

# SSH access
resource "openstack_networking_secgroup_rule_v2" "stage3_ssh" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.stage3_htcondor.id
}

# HTCondor ports (9618 for collector, 9600-9700 range for other services)
resource "openstack_networking_secgroup_rule_v2" "stage3_htcondor_collector" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 9618
  port_range_max    = 9618
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.stage3_htcondor.id
}

resource "openstack_networking_secgroup_rule_v2" "stage3_htcondor_range" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 9600
  port_range_max    = 9700
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.stage3_htcondor.id
}

# Single HTCondor node (acts as central manager + execute node)
resource "openstack_compute_instance_v2" "htcondor_standalone" {
  name        = "${var.prefix}-stage3-htcondor"
  image_id    = data.openstack_images_image_v2.nudocker_test.id
  flavor_name = var.flavor_name

  key_pair = var.key_pair_name

  security_groups = [
    "default",
    openstack_networking_secgroup_v2.stage3_htcondor.name
  ]

  network {
    name = var.network_name
  }

  metadata = {
    Stage       = "3"
    Purpose     = "Single-node HTCondor test"
    Project     = "NuDocker"
    ManagedBy   = "Terraform"
  }

  # Create working directory and HTCondor configuration
  user_data = <<-EOF
    #!/bin/bash
    set -e

    # Create working directories
    mkdir -p /home/ubuntu/htcondor_test
    mkdir -p /storage/htcondor_jobs
    mkdir -p /storage/results
    chown -R ubuntu:ubuntu /home/ubuntu/htcondor_test
    chown -R ubuntu:ubuntu /storage

    # Configure HTCondor for standalone mode
    cat > /etc/condor/config.d/50-standalone.config <<EOC
# Standalone HTCondor configuration for Stage 3 testing
# This node acts as both Central Manager and Execute node

# Role configuration
CONDOR_HOST = \$(FULL_HOSTNAME)
DAEMON_LIST = COLLECTOR, MASTER, NEGOTIATOR, SCHEDD, STARTD

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

# Execute node configuration
NUM_SLOTS = 4
SLOT_TYPE_1 = cpus=100%,ram=100%,disk=100%
NUM_SLOTS_TYPE_1 = 4

# Enable Docker Universe
DOCKER = /usr/bin/docker
DOCKER_VOLUMES = DOCKER_VOLUME_DIR_STORAGE:/storage:rw

# Logging
MAX_DEFAULT_LOG = 10000000
MAX_NUM_DEFAULT_LOG = 5
EOC

    # Start HTCondor services
    systemctl enable condor
    systemctl restart condor

    # Wait for HTCondor to start
    sleep 10

    # Create test submit file
    cat > /home/ubuntu/htcondor_test/test_job.sub <<EOS
# Simple HTCondor test job
universe     = vanilla
executable   = /bin/echo
arguments    = "Hello from HTCondor job \$(Process)"
output       = test_\$(Process).out
error        = test_\$(Process).err
log          = test.log
request_cpus = 1
request_memory = 512M
queue 3
EOS

    chown ubuntu:ubuntu /home/ubuntu/htcondor_test/test_job.sub

    # Create Docker test submit file
    cat > /home/ubuntu/htcondor_test/docker_test.sub <<EOS
# Docker Universe test job
universe                = docker
docker_image            = ubuntu:22.04
executable              = /bin/bash
arguments               = -c "uname -a && echo 'Docker job successful'"
output                  = docker_\$(Process).out
error                   = docker_\$(Process).err
log                     = docker_test.log
request_cpus            = 1
request_memory          = 512M
should_transfer_files   = YES
when_to_transfer_output = ON_EXIT
queue 2
EOS

    chown ubuntu:ubuntu /home/ubuntu/htcondor_test/docker_test.sub

    echo "HTCondor standalone configuration complete"
  EOF
}

# Floating IP for external access
resource "openstack_networking_floatingip_v2" "htcondor_fip" {
  pool = var.external_network_name
}

resource "openstack_compute_floatingip_associate_v2" "htcondor_fip_assoc" {
  floating_ip = openstack_networking_floatingip_v2.htcondor_fip.address
  instance_id = openstack_compute_instance_v2.htcondor_standalone.id
}

# Outputs
output "htcondor_vm_id" {
  description = "HTCondor VM instance ID"
  value       = openstack_compute_instance_v2.htcondor_standalone.id
}

output "htcondor_internal_ip" {
  description = "HTCondor VM internal IP"
  value       = openstack_compute_instance_v2.htcondor_standalone.access_ip_v4
}

output "htcondor_floating_ip" {
  description = "HTCondor VM floating IP"
  value       = openstack_networking_floatingip_v2.htcondor_fip.address
}

output "ssh_command" {
  description = "SSH command to connect"
  value       = "ssh -i ${var.ssh_private_key_path} ubuntu@${openstack_networking_floatingip_v2.htcondor_fip.address}"
}

output "test_commands" {
  description = "Commands to test HTCondor"
  value = <<-EOT
    # Connect to VM:
    ssh -i ${var.ssh_private_key_path} ubuntu@${openstack_networking_floatingip_v2.htcondor_fip.address}

    # Check HTCondor status:
    condor_status
    condor_q

    # Submit test job:
    cd ~/htcondor_test
    condor_submit test_job.sub

    # Watch job progress:
    watch condor_q

    # Check results:
    cat test_*.out
  EOT
}
