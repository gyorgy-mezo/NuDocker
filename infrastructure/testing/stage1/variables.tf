# Stage 1: Variables
# Configuration variables for basic VM provisioning test

variable "cloud_name" {
  description = "OpenStack cloud name from clouds.yaml"
  type        = string
}

variable "prefix" {
  description = "Prefix for resource names"
  type        = string
  default     = "nudocker-test"
}

variable "image_name" {
  description = "Ubuntu image name"
  type        = string
  default     = "ubuntu-22.04"
}

variable "flavor_name" {
  description = "VM flavor (size)"
  type        = string
  default     = "m1.small"
  # m1.small = 2 vCPU, 4 GB RAM (typical)
}

variable "network_name" {
  description = "Internal network name"
  type        = string
}

variable "external_network_name" {
  description = "External network name for floating IPs"
  type        = string
}

variable "key_pair_name" {
  description = "SSH key pair name (must exist in OpenStack)"
  type        = string
}

variable "ssh_private_key_path" {
  description = "Path to SSH private key for connection testing"
  type        = string
  default     = "~/.ssh/id_rsa"
}
