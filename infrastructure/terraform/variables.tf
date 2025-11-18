# Terraform Variables for HUN-REN Cloud HTCondor Cluster
# NuDocker HTCondor Infrastructure
# Based on 72 vCPU, 192 GB RAM allocation

# ==============================================================================
# OpenStack Authentication
# ==============================================================================

variable "openstack_auth_url" {
  description = "OpenStack authentication URL"
  type        = string
  default     = "https://cloud.hunren.hu:5000/v3"
}

variable "openstack_region" {
  description = "OpenStack region"
  type        = string
  default     = "RegionOne"
}

variable "openstack_project_name" {
  description = "OpenStack project name"
  type        = string
}

variable "openstack_user_domain_name" {
  description = "OpenStack user domain name"
  type        = string
  default     = "Default"
}

variable "openstack_username" {
  description = "OpenStack username"
  type        = string
}

variable "openstack_password" {
  description = "OpenStack password"
  type        = string
  sensitive   = true
}

# ==============================================================================
# Cluster Configuration
# ==============================================================================

variable "cluster_name" {
  description = "Name of the HTCondor cluster"
  type        = string
  default     = "nudocker-htcondor"
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
  default     = "prod"
}

# ==============================================================================
# Network Configuration
# ==============================================================================

variable "external_network_name" {
  description = "Name of the external network for floating IPs"
  type        = string
  default     = "public"
}

variable "private_network_cidr" {
  description = "CIDR for private network"
  type        = string
  default     = "10.0.0.0/24"
}

variable "dns_nameservers" {
  description = "DNS nameservers"
  type        = list(string)
  default     = ["8.8.8.8", "8.8.4.4"]
}

# ==============================================================================
# Central Manager Node Configuration
# ==============================================================================

variable "central_manager_flavor" {
  description = "Flavor for central manager node"
  type        = string
  default     = "m2.large"  # 8 vCPU, 16 GB RAM
}

variable "central_manager_image" {
  description = "Image name for central manager (built by Packer)"
  type        = string
  default     = "nudocker-htcondor-central"
}

variable "central_manager_volume_size" {
  description = "Size of central manager root volume in GB"
  type        = number
  default     = 100
}

# ==============================================================================
# Execute Node Configuration
# ==============================================================================

variable "execute_node_count" {
  description = "Number of execute nodes"
  type        = number
  default     = 5
}

variable "execute_node_flavor" {
  description = "Flavor for execute nodes"
  type        = string
  default     = "g2.xlarge"  # 8 vCPU, 32 GB RAM
}

variable "execute_node_image" {
  description = "Image name for execute nodes (built by Packer)"
  type        = string
  default     = "nudocker-htcondor-execute"
}

variable "execute_node_volume_size" {
  description = "Size of execute node root volume in GB"
  type        = number
  default     = 100
}

# ==============================================================================
# Shared Storage Configuration
# ==============================================================================

variable "shared_storage_size" {
  description = "Size of shared storage volume in GB"
  type        = number
  default     = 500
}

variable "shared_storage_type" {
  description = "Type of shared storage volume"
  type        = string
  default     = "standard"
}

# ==============================================================================
# SSH Configuration
# ==============================================================================

variable "ssh_key_name" {
  description = "Name of SSH key pair for instance access"
  type        = string
  default     = "nudocker-key"
}

variable "ssh_public_key_file" {
  description = "Path to SSH public key file"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "allowed_ssh_cidr" {
  description = "CIDR blocks allowed to SSH"
  type        = list(string)
  default     = ["0.0.0.0/0"]  # WARNING: Restrict in production!
}

# ==============================================================================
# HTCondor Configuration
# ==============================================================================

variable "htcondor_version" {
  description = "HTCondor version to install"
  type        = string
  default     = "23.10"
}

variable "htcondor_pool_password" {
  description = "HTCondor pool password for authentication"
  type        = string
  sensitive   = true
}

# ==============================================================================
# Tags and Metadata
# ==============================================================================

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    Project     = "NuDocker"
    ManagedBy   = "Terraform"
    Purpose     = "HTCondor-Cluster"
  }
}
