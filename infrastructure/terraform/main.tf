# Main Terraform Configuration for HUN-REN Cloud HTCondor Cluster
# NuDocker HTCondor Infrastructure

terraform {
  required_version = ">= 1.0"

  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 1.52"
    }
  }
}

# ==============================================================================
# Provider Configuration
# ==============================================================================

provider "openstack" {
  auth_url            = var.openstack_auth_url
  region              = var.openstack_region
  user_name           = var.openstack_username
  password            = var.openstack_password
  tenant_name         = var.openstack_project_name
  user_domain_name    = var.openstack_user_domain_name
  project_domain_name = var.openstack_user_domain_name
}

# ==============================================================================
# Data Sources
# ==============================================================================

data "openstack_networking_network_v2" "external" {
  name = var.external_network_name
}

# ==============================================================================
# SSH Key Pair
# ==============================================================================

resource "openstack_compute_keypair_v2" "nudocker_key" {
  name       = var.ssh_key_name
  public_key = file(var.ssh_public_key_file)
}

# ==============================================================================
# Network Infrastructure
# ==============================================================================

resource "openstack_networking_network_v2" "private" {
  name           = "${var.cluster_name}-network"
  admin_state_up = true

  tags = [
    "Project:${var.tags["Project"]}",
    "ManagedBy:${var.tags["ManagedBy"]}"
  ]
}

resource "openstack_networking_subnet_v2" "private" {
  name            = "${var.cluster_name}-subnet"
  network_id      = openstack_networking_network_v2.private.id
  cidr            = var.private_network_cidr
  ip_version      = 4
  dns_nameservers = var.dns_nameservers
}

resource "openstack_networking_router_v2" "router" {
  name                = "${var.cluster_name}-router"
  admin_state_up      = true
  external_network_id = data.openstack_networking_network_v2.external.id
}

resource "openstack_networking_router_interface_v2" "router_interface" {
  router_id = openstack_networking_router_v2.router.id
  subnet_id = openstack_networking_subnet_v2.private.id
}

# ==============================================================================
# Security Groups
# ==============================================================================

# Central Manager Security Group
resource "openstack_networking_secgroup_v2" "central_manager" {
  name        = "${var.cluster_name}-central-manager-sg"
  description = "Security group for HTCondor central manager"
}

# SSH access
resource "openstack_networking_secgroup_rule_v2" "central_ssh" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = var.allowed_ssh_cidr[0]
  security_group_id = openstack_networking_secgroup_v2.central_manager.id
}

# HTCondor collector port
resource "openstack_networking_secgroup_rule_v2" "central_collector" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 9618
  port_range_max    = 9618
  remote_ip_prefix  = var.private_network_cidr
  security_group_id = openstack_networking_secgroup_v2.central_manager.id
}

# HTCondor negotiator port
resource "openstack_networking_secgroup_rule_v2" "central_negotiator" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 9614
  port_range_max    = 9614
  remote_ip_prefix  = var.private_network_cidr
  security_group_id = openstack_networking_secgroup_v2.central_manager.id
}

# HTCondor schedd port (for job submission)
resource "openstack_networking_secgroup_rule_v2" "central_schedd" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 9615
  port_range_max    = 9615
  remote_ip_prefix  = var.private_network_cidr
  security_group_id = openstack_networking_secgroup_v2.central_manager.id
}

# HTCondor high port range
resource "openstack_networking_secgroup_rule_v2" "central_highports" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 41000
  port_range_max    = 42000
  remote_ip_prefix  = var.private_network_cidr
  security_group_id = openstack_networking_secgroup_v2.central_manager.id
}

# NFS port
resource "openstack_networking_secgroup_rule_v2" "central_nfs" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 2049
  port_range_max    = 2049
  remote_ip_prefix  = var.private_network_cidr
  security_group_id = openstack_networking_secgroup_v2.central_manager.id
}

# Execute Node Security Group
resource "openstack_networking_secgroup_v2" "execute_node" {
  name        = "${var.cluster_name}-execute-sg"
  description = "Security group for HTCondor execute nodes"
}

# SSH access (from central manager)
resource "openstack_networking_secgroup_rule_v2" "execute_ssh" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = var.private_network_cidr
  security_group_id = openstack_networking_secgroup_v2.execute_node.id
}

# HTCondor startd port
resource "openstack_networking_secgroup_rule_v2" "execute_startd" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 9618
  port_range_max    = 9618
  remote_ip_prefix  = var.private_network_cidr
  security_group_id = openstack_networking_secgroup_v2.execute_node.id
}

# HTCondor high port range
resource "openstack_networking_secgroup_rule_v2" "execute_highports" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 41000
  port_range_max    = 42000
  remote_ip_prefix  = var.private_network_cidr
  security_group_id = openstack_networking_secgroup_v2.execute_node.id
}

# NFS client access
resource "openstack_networking_secgroup_rule_v2" "execute_nfs" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 2049
  port_range_max    = 2049
  remote_ip_prefix  = var.private_network_cidr
  security_group_id = openstack_networking_secgroup_v2.execute_node.id
}

# ==============================================================================
# Shared Storage Volume
# ==============================================================================

resource "openstack_blockstorage_volume_v3" "shared_storage" {
  name        = "${var.cluster_name}-shared-storage"
  description = "Shared storage for HTCondor cluster (NFS)"
  size        = var.shared_storage_size
  volume_type = var.shared_storage_type

  metadata = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-shared-storage"
    }
  )
}

# ==============================================================================
# Central Manager Instance
# ==============================================================================

resource "openstack_compute_instance_v2" "central_manager" {
  name            = "${var.cluster_name}-central"
  flavor_name     = var.central_manager_flavor
  key_pair        = openstack_compute_keypair_v2.nudocker_key.name
  security_groups = [openstack_networking_secgroup_v2.central_manager.name]

  block_device {
    uuid                  = var.central_manager_image
    source_type           = "image"
    destination_type      = "volume"
    boot_index            = 0
    delete_on_termination = true
    volume_size           = var.central_manager_volume_size
  }

  network {
    uuid = openstack_networking_network_v2.private.id
    fixed_ip_v4 = "10.0.0.10"
  }

  metadata = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-central"
      Role = "central-manager"
    }
  )

  user_data = templatefile("${path.module}/cloud-init/central-manager.yaml", {
    hostname           = "${var.cluster_name}-central"
    cluster_name       = var.cluster_name
    condor_host        = "10.0.0.10"
    pool_password      = var.htcondor_pool_password
  })
}

# Attach shared storage to central manager
resource "openstack_compute_volume_attach_v2" "shared_storage_attach" {
  instance_id = openstack_compute_instance_v2.central_manager.id
  volume_id   = openstack_blockstorage_volume_v3.shared_storage.id
  device      = "/dev/vdb"
}

# Floating IP for central manager
resource "openstack_networking_floatingip_v2" "central_manager_fip" {
  pool = var.external_network_name
}

resource "openstack_compute_floatingip_associate_v2" "central_manager_fip_assoc" {
  floating_ip = openstack_networking_floatingip_v2.central_manager_fip.address
  instance_id = openstack_compute_instance_v2.central_manager.id
}

# ==============================================================================
# Execute Nodes
# ==============================================================================

resource "openstack_compute_instance_v2" "execute_node" {
  count           = var.execute_node_count
  name            = "${var.cluster_name}-execute-${format("%02d", count.index + 1)}"
  flavor_name     = var.execute_node_flavor
  key_pair        = openstack_compute_keypair_v2.nudocker_key.name
  security_groups = [openstack_networking_secgroup_v2.execute_node.name]

  block_device {
    uuid                  = var.execute_node_image
    source_type           = "image"
    destination_type      = "volume"
    boot_index            = 0
    delete_on_termination = true
    volume_size           = var.execute_node_volume_size
  }

  network {
    uuid = openstack_networking_network_v2.private.id
    fixed_ip_v4 = "10.0.0.${20 + count.index}"
  }

  metadata = merge(
    var.tags,
    {
      Name  = "${var.cluster_name}-execute-${format("%02d", count.index + 1)}"
      Role  = "execute-node"
      Index = count.index
    }
  )

  user_data = templatefile("${path.module}/cloud-init/execute-node.yaml", {
    hostname           = "${var.cluster_name}-execute-${format("%02d", count.index + 1)}"
    cluster_name       = var.cluster_name
    condor_host        = "10.0.0.10"
    pool_password      = var.htcondor_pool_password
    num_cpus           = 8
    memory_mb          = 30000
  })
}

# ==============================================================================
# Outputs
# ==============================================================================

output "central_manager_floating_ip" {
  description = "Floating IP of central manager"
  value       = openstack_networking_floatingip_v2.central_manager_fip.address
}

output "central_manager_private_ip" {
  description = "Private IP of central manager"
  value       = openstack_compute_instance_v2.central_manager.access_ip_v4
}

output "execute_node_ips" {
  description = "Private IPs of execute nodes"
  value       = openstack_compute_instance_v2.execute_node[*].access_ip_v4
}

output "ssh_command" {
  description = "SSH command to connect to central manager"
  value       = "ssh -i ~/.ssh/id_rsa ubuntu@${openstack_networking_floatingip_v2.central_manager_fip.address}"
}

output "condor_status_command" {
  description = "Command to check HTCondor status"
  value       = "ssh -i ~/.ssh/id_rsa ubuntu@${openstack_networking_floatingip_v2.central_manager_fip.address} 'condor_status'"
}
