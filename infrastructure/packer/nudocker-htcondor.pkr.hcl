# Packer Template for NuDocker HTCondor Base Image
# Builds Ubuntu 20.04 image with HTCondor, Docker, and Singularity

packer {
  required_plugins {
    openstack = {
      version = ">= 1.0.0"
      source  = "github.com/hashicorp/openstack"
    }
  }
}

# ==============================================================================
# Variables
# ==============================================================================

variable "openstack_auth_url" {
  type    = string
  default = "https://cloud.hunren.hu:5000/v3"
}

variable "openstack_region" {
  type    = string
  default = "RegionOne"
}

variable "openstack_project_name" {
  type    = string
  default = env("OS_PROJECT_NAME")
}

variable "openstack_username" {
  type    = string
  default = env("OS_USERNAME")
}

variable "openstack_password" {
  type      = string
  default   = env("OS_PASSWORD")
  sensitive = true
}

variable "openstack_user_domain_name" {
  type    = string
  default = "Default"
}

variable "source_image_name" {
  type    = string
  default = "Ubuntu-20.04"
  description = "Base Ubuntu image name in OpenStack"
}

variable "flavor_name" {
  type    = string
  default = "m2.large"
  description = "Flavor to use for building"
}

variable "network_name" {
  type    = string
  default = "public"
  description = "Network to use for building"
}

variable "image_name" {
  type    = string
  default = "nudocker-htcondor-base"
  description = "Name of the output image"
}

variable "htcondor_version" {
  type    = string
  default = "23.10"
  description = "HTCondor version to install"
}

variable "docker_version" {
  type    = string
  default = "24.0"
  description = "Docker version to install"
}

variable "singularity_version" {
  type    = string
  default = "3.11.4"
  description = "Singularity/Apptainer version to install"
}

# ==============================================================================
# Source Configuration
# ==============================================================================

source "openstack" "ubuntu" {
  auth_url            = var.openstack_auth_url
  region              = var.openstack_region
  username            = var.openstack_username
  password            = var.openstack_password
  tenant_name         = var.openstack_project_name
  user_domain_name    = var.openstack_user_domain_name
  project_domain_name = var.openstack_user_domain_name

  image_name        = "${var.image_name}-${formatdate("YYYYMMDD-hhmm", timestamp())}"
  source_image_name = var.source_image_name
  flavor            = var.flavor_name
  ssh_username      = "ubuntu"
  networks          = [var.network_name]
  floating_ip_network = var.network_name
  use_floating_ip   = true

  metadata = {
    "nudocker_version"     = "2.0"
    "htcondor_version"     = var.htcondor_version
    "docker_version"       = var.docker_version
    "singularity_version"  = var.singularity_version
    "built_by"             = "packer"
    "build_date"           = timestamp()
  }
}

# ==============================================================================
# Build Configuration
# ==============================================================================

build {
  sources = ["source.openstack.ubuntu"]

  # Wait for cloud-init to complete
  provisioner "shell" {
    inline = [
      "echo 'Waiting for cloud-init to complete...'",
      "cloud-init status --wait",
      "echo 'Cloud-init completed'"
    ]
  }

  # Update system
  provisioner "shell" {
    inline = [
      "sudo apt-get update",
      "sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y",
      "sudo DEBIAN_FRONTEND=noninteractive apt-get install -y wget curl gnupg2 software-properties-common apt-transport-https ca-certificates"
    ]
  }

  # Install Docker
  provisioner "shell" {
    script = "${path.root}/scripts/install-docker.sh"
  }

  # Install Singularity/Apptainer
  provisioner "shell" {
    script = "${path.root}/scripts/install-singularity.sh"
  }

  # Install HTCondor
  provisioner "shell" {
    script = "${path.root}/scripts/install-htcondor.sh"
    environment_vars = [
      "HTCONDOR_VERSION=${var.htcondor_version}"
    ]
  }

  # Install SLURM Workload Manager
  provisioner "shell" {
    script = "${path.root}/scripts/install-slurm.sh"
  }

  # Install NuDocker dependencies
  provisioner "shell" {
    script = "${path.root}/scripts/install-nudocker-deps.sh"
  }

  # Configure system
  provisioner "shell" {
    script = "${path.root}/scripts/configure-system.sh"
  }

  # Copy configuration files
  provisioner "file" {
    source      = "${path.root}/files/"
    destination = "/tmp/nudocker-files/"
  }

  # Apply configurations
  provisioner "shell" {
    script = "${path.root}/scripts/apply-configs.sh"
  }

  # Cleanup
  provisioner "shell" {
    script = "${path.root}/scripts/cleanup.sh"
  }

  # Create image metadata
  provisioner "shell" {
    inline = [
      "echo 'NuDocker HTCondor Image' | sudo tee /etc/nudocker-image-info",
      "echo 'HTCondor Version: ${var.htcondor_version}' | sudo tee -a /etc/nudocker-image-info",
      "echo 'Docker Version: ${var.docker_version}' | sudo tee -a /etc/nudocker-image-info",
      "echo 'Singularity Version: ${var.singularity_version}' | sudo tee -a /etc/nudocker-image-info",
      "echo 'Build Date: ${timestamp()}' | sudo tee -a /etc/nudocker-image-info"
    ]
  }
}
