# Stage 3: Variables
# Configuration variables for single-node HTCondor test

variable "cloud_name" {
  description = "OpenStack cloud name from clouds.yaml"
  type        = string
}

variable "prefix" {
  description = "Prefix for resource names"
  type        = string
  default     = "nudocker-test"
}

variable "custom_image_name" {
  description = "Name of custom image built in Stage 2"
  type        = string
  # Should match image created by Packer: nudocker-test-stage2-YYYYMMDD-HHMM
  # Or use pattern matching: nudocker-test-stage2*
}

variable "flavor_name" {
  description = "VM flavor (size)"
  type        = string
  default     = "m1.medium"
  # m1.medium = 4 vCPU, 8 GB RAM (sufficient for HTCondor + few jobs)
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
