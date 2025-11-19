# Stage 4: Variables
# Configuration variables for multi-node cluster test

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
}

variable "central_flavor" {
  description = "Central manager VM flavor (size)"
  type        = string
  default     = "m1.small"
  # m1.small = 2 vCPU, 4 GB RAM (sufficient for central manager)
}

variable "execute_flavor" {
  description = "Execute node VM flavor (size)"
  type        = string
  default     = "m1.medium"
  # m1.medium = 4 vCPU, 8 GB RAM (for running jobs)
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
  description = "Path to SSH private key"
  type        = string
  default     = "~/.ssh/id_rsa"
}
