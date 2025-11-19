# Stage 1: Basic VM Provisioning Test
# Minimal Terraform configuration to test OpenStack connectivity
# Resources: 1 VM (2 vCPU, 4 GB RAM, 20 GB disk)
# Duration: ~15 minutes
# Cost: ~€0.50-1.00

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

# Data source: Get Ubuntu 22.04 image
data "openstack_images_image_v2" "ubuntu_2204" {
  name        = var.image_name
  most_recent = true
}

# Security group for SSH access
resource "openstack_networking_secgroup_v2" "stage1_ssh" {
  name        = "${var.prefix}-stage1-ssh"
  description = "Stage 1: Allow SSH access"
}

resource "openstack_networking_secgroup_rule_v2" "stage1_ssh_ingress" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.stage1_ssh.id
}

# Single test VM
resource "openstack_compute_instance_v2" "test_vm" {
  name        = "${var.prefix}-stage1-test"
  image_id    = data.openstack_images_image_v2.ubuntu_2204.id
  flavor_name = var.flavor_name

  key_pair = var.key_pair_name

  security_groups = [
    "default",
    openstack_networking_secgroup_v2.stage1_ssh.name
  ]

  network {
    name = var.network_name
  }

  metadata = {
    Stage       = "1"
    Purpose     = "Basic provisioning test"
    Project     = "NuDocker"
    ManagedBy   = "Terraform"
  }
}

# Floating IP for external access
resource "openstack_networking_floatingip_v2" "test_vm_fip" {
  pool = var.external_network_name
}

resource "openstack_compute_floatingip_associate_v2" "test_vm_fip_assoc" {
  floating_ip = openstack_networking_floatingip_v2.test_vm_fip.address
  instance_id = openstack_compute_instance_v2.test_vm.id
}

# Outputs for verification
output "test_vm_id" {
  description = "Test VM instance ID"
  value       = openstack_compute_instance_v2.test_vm.id
}

output "test_vm_internal_ip" {
  description = "Test VM internal IP address"
  value       = openstack_compute_instance_v2.test_vm.access_ip_v4
}

output "test_vm_floating_ip" {
  description = "Test VM floating IP address"
  value       = openstack_networking_floatingip_v2.test_vm_fip.address
}

output "ssh_command" {
  description = "SSH command to connect to test VM"
  value       = "ssh -i ${var.ssh_private_key_path} ubuntu@${openstack_networking_floatingip_v2.test_vm_fip.address}"
}

output "verification_commands" {
  description = "Commands to verify the VM"
  value = <<-EOT
    # Test SSH connectivity:
    ssh -i ${var.ssh_private_key_path} ubuntu@${openstack_networking_floatingip_v2.test_vm_fip.address} 'hostname && uptime'

    # Check VM info:
    openstack --os-cloud ${var.cloud_name} server show ${openstack_compute_instance_v2.test_vm.id}
  EOT
}
