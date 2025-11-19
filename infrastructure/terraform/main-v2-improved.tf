# NuDocker HTCondor + SLURM Infrastructure v2.0 - IMPROVED
# Based on proven patterns from htcondor-slurm-demo
# Simplified approach using Packer images + Ansible configuration

terraform {
  required_version = ">= 1.0"

  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 1.54.1"
    }
  }
}

# ==============================================================================
# Variables
# ==============================================================================

variable "key_pair" {
  description = "OpenStack SSH key pair name"
  type        = string
  default     = "alma"
}

variable "external_network" {
  description = "External network name for floating IPs"
  type        = string
  default     = "ext-net"
}

variable "cluster_name" {
  description = "Cluster name prefix for resources"
  type        = string
  default     = "nudocker"
}

variable "central_manager_flavor" {
  description = "Flavor for central manager (HTCondor + NFS + SLURM controller)"
  type        = string
  default     = "r2.large"  # 4 vCPU, 16 GB RAM
}

variable "execute_node_flavor" {
  description = "Flavor for execute nodes"
  type        = string
  default     = "r2.xlarge"  # 8 vCPU, 32 GB RAM
}

variable "execute_node_count" {
  description = "Number of HTCondor execute nodes"
  type        = number
  default     = 5
}

variable "slurm_compute_count" {
  description = "Number of SLURM compute nodes"
  type        = number
  default     = 3
}

# ==============================================================================
# Data Sources
# ==============================================================================

data "openstack_networking_network_v2" "default" {
  name = "default"
}

# Packer-built custom images
data "openstack_images_image_v2" "nudocker_base" {
  name        = "nudocker-base-ubuntu22"
  most_recent = true
}

# ==============================================================================
# Security Groups
# ==============================================================================

resource "openstack_networking_secgroup_v2" "nudocker_sg" {
  name        = "${var.cluster_name}-security-group"
  description = "Security group for NuDocker cluster (HTCondor + SLURM)"
}

# SSH access
resource "openstack_networking_secgroup_rule_v2" "ssh" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.nudocker_sg.id
}

# HTCondor collector port
resource "openstack_networking_secgroup_rule_v2" "htcondor_collector" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 9618
  port_range_max    = 9618
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.nudocker_sg.id
}

# HTCondor schedd port
resource "openstack_networking_secgroup_rule_v2" "htcondor_schedd" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 9615
  port_range_max    = 9615
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.nudocker_sg.id
}

# Internal cluster communication (all ports)
# This pattern from htcondor-slurm-demo avoids terraform drift issues
resource "openstack_networking_secgroup_rule_v2" "internal_all" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  # When using remote_group_id, OpenStack treats omitted port ranges as "all ports"
  # Explicitly setting 1-65535 causes drift as OpenStack stores it as 0-0
  remote_group_id   = openstack_networking_secgroup_v2.nudocker_sg.id
  security_group_id = openstack_networking_secgroup_v2.nudocker_sg.id
}

# ==============================================================================
# Network Port for Floating IP
# This pattern from htcondor-slurm-demo fixes floating IP association issues
# ==============================================================================

resource "openstack_networking_port_v2" "central_manager_port" {
  name           = "${var.cluster_name}-central-manager-port"
  network_id     = data.openstack_networking_network_v2.default.id
  admin_state_up = true
  security_group_ids = [
    openstack_networking_secgroup_v2.nudocker_sg.id
  ]
}

# ==============================================================================
# Floating IP
# ==============================================================================

resource "openstack_networking_floatingip_v2" "central_manager_fip" {
  pool = var.external_network
}

resource "openstack_networking_floatingip_associate_v2" "central_manager_fip_assoc" {
  floating_ip = openstack_networking_floatingip_v2.central_manager_fip.address
  port_id     = openstack_networking_port_v2.central_manager_port.id
}

# ==============================================================================
# Central Manager (HTCondor + SLURM Controller + NFS Server)
# ==============================================================================

resource "openstack_compute_instance_v2" "central_manager" {
  name            = "${var.cluster_name}-central-manager"
  flavor_name     = var.central_manager_flavor
  key_pair        = var.key_pair
  security_groups = [openstack_networking_secgroup_v2.nudocker_sg.name]

  # Use pre-built Packer image
  block_device {
    uuid                  = data.openstack_images_image_v2.nudocker_base.id
    source_type           = "image"
    destination_type      = "volume"
    boot_index            = 0
    volume_size           = 100  # Larger for NFS storage
    delete_on_termination = true
  }

  network {
    port = openstack_networking_port_v2.central_manager_port.id
  }

  metadata = {
    role = "central-manager"
    cluster = var.cluster_name
  }
}

# ==============================================================================
# HTCondor Execute Nodes
# ==============================================================================

resource "openstack_compute_instance_v2" "htcondor_execute" {
  count           = var.execute_node_count
  name            = "${var.cluster_name}-execute-${count.index + 1}"
  flavor_name     = var.execute_node_flavor
  key_pair        = var.key_pair
  security_groups = [openstack_networking_secgroup_v2.nudocker_sg.name]

  block_device {
    uuid                  = data.openstack_images_image_v2.nudocker_base.id
    source_type           = "image"
    destination_type      = "volume"
    boot_index            = 0
    volume_size           = 50
    delete_on_termination = true
  }

  network {
    name = "default"
  }

  metadata = {
    role = "htcondor-execute"
    cluster = var.cluster_name
  }
}

# ==============================================================================
# SLURM Compute Nodes (NEW - from htcondor-slurm-demo pattern)
# ==============================================================================

resource "openstack_compute_instance_v2" "slurm_compute" {
  count           = var.slurm_compute_count
  name            = "${var.cluster_name}-slurm-compute-${count.index + 1}"
  flavor_name     = var.execute_node_flavor
  key_pair        = var.key_pair
  security_groups = [openstack_networking_secgroup_v2.nudocker_sg.name]

  block_device {
    uuid                  = data.openstack_images_image_v2.nudocker_base.id
    source_type           = "image"
    destination_type      = "volume"
    boot_index            = 0
    volume_size           = 50
    delete_on_termination = true
  }

  network {
    name = "default"
  }

  metadata = {
    role = "slurm-compute"
    cluster = var.cluster_name
  }
}

# ==============================================================================
# Ansible Inventory Generation (from htcondor-slurm-demo pattern)
# ==============================================================================

resource "local_file" "ansible_inventory" {
  content = templatefile("${path.module}/inventory.tpl", {
    central_manager_ip      = openstack_networking_floatingip_v2.central_manager_fip.address
    central_manager_private = openstack_compute_instance_v2.central_manager.network[0].fixed_ip_v4
    htcondor_execute_ips    = [for instance in openstack_compute_instance_v2.htcondor_execute : instance.network[0].fixed_ip_v4]
    slurm_compute_ips       = [for instance in openstack_compute_instance_v2.slurm_compute : instance.network[0].fixed_ip_v4]
  })
  filename = "../ansible/inventory/hosts-generated.ini"
}

# ==============================================================================
# Outputs
# ==============================================================================

output "central_manager_floating_ip" {
  value       = openstack_networking_floatingip_v2.central_manager_fip.address
  description = "Public IP address of the central manager (SSH access point)"
}

output "central_manager_private_ip" {
  value       = openstack_compute_instance_v2.central_manager.network[0].fixed_ip_v4
  description = "Private IP of central manager (for internal configuration)"
}

output "htcondor_execute_nodes" {
  value = {
    for idx, instance in openstack_compute_instance_v2.htcondor_execute :
    instance.name => instance.network[0].fixed_ip_v4
  }
  description = "HTCondor execute node names and IPs"
}

output "slurm_compute_nodes" {
  value = {
    for idx, instance in openstack_compute_instance_v2.slurm_compute :
    instance.name => instance.network[0].fixed_ip_v4
  }
  description = "SLURM compute node names and IPs"
}

output "ssh_command" {
  value = "ssh -i ~/.ssh/id_rsa ubuntu@${openstack_networking_floatingip_v2.central_manager_fip.address}"
  description = "SSH command to connect to central manager"
}

output "cluster_summary" {
  value = {
    cluster_name         = var.cluster_name
    central_manager      = openstack_networking_floatingip_v2.central_manager_fip.address
    htcondor_nodes       = var.execute_node_count
    slurm_nodes          = var.slurm_compute_count
    total_cpus_htcondor  = var.execute_node_count * 8  # Assuming r2.xlarge
    total_cpus_slurm     = var.slurm_compute_count * 8
    total_cpus           = (var.execute_node_count + var.slurm_compute_count) * 8 + 4
  }
  description = "Cluster deployment summary"
}
