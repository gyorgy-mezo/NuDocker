# Stage 2: Packer Test Image
# Simplified image build to test Packer functionality
# Installs HTCondor and SLURM components (basic setup only)
# Duration: ~30-45 minutes
# Cost: ~€2.00-3.00

packer {
  required_plugins {
    openstack = {
      version = ">= 1.0.0"
      source  = "github.com/hashicorp/openstack"
    }
  }
}

# Variables
variable "cloud_name" {
  type    = string
  default = "hun-ren-cloud"
}

variable "source_image_name" {
  type    = string
  default = "ubuntu-22.04"
}

variable "flavor" {
  type    = string
  default = "m1.medium"
  # m1.medium = 4 vCPU, 8 GB RAM (needed for compilation)
}

variable "network_id" {
  type    = string
  default = ""
}

variable "floating_ip_network_name" {
  type    = string
  default = "public"
}

variable "ssh_username" {
  type    = string
  default = "ubuntu"
}

variable "image_name" {
  type    = string
  default = "nudocker-test-stage2"
}

# Source configuration
source "openstack" "nudocker_test" {
  cloud_name              = var.cloud_name
  source_image_name       = var.source_image_name
  flavor                  = var.flavor
  ssh_username            = var.ssh_username
  image_name              = "${var.image_name}-${formatdate("YYYYMMDD-hhmm", timestamp())}"
  floating_ip_network_name = var.floating_ip_network_name

  # Use network_id if provided, otherwise use default
  networks = var.network_id != "" ? [var.network_id] : []

  # Metadata
  metadata = {
    Purpose    = "Stage 2 Packer test"
    Project    = "NuDocker"
    Stage      = "2"
    BuildDate  = "${formatdate("YYYY-MM-DD", timestamp())}"
  }
}

# Build
build {
  name = "nudocker-test-stage2"

  sources = [
    "source.openstack.nudocker_test"
  ]

  # Wait for cloud-init to complete
  provisioner "shell" {
    inline = [
      "echo 'Waiting for cloud-init to complete...'",
      "cloud-init status --wait || true",
      "echo 'Cloud-init complete'"
    ]
  }

  # Update system
  provisioner "shell" {
    inline = [
      "echo '=== System Update ==='",
      "sudo apt-get update",
      "sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y",
      "echo 'System updated'"
    ]
  }

  # Install basic dependencies
  provisioner "shell" {
    inline = [
      "echo '=== Installing Basic Dependencies ==='",
      "sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \\",
      "  build-essential \\",
      "  curl \\",
      "  wget \\",
      "  git \\",
      "  vim \\",
      "  nfs-common \\",
      "  python3 \\",
      "  python3-pip",
      "echo 'Basic dependencies installed'"
    ]
  }

  # Install HTCondor (minimal)
  provisioner "shell" {
    inline = [
      "echo '=== Installing HTCondor ==='",
      "# Download HTCondor GPG key",
      "wget -qO - https://research.cs.wisc.edu/htcondor/repo/keys/HTCondor-23.x-Key | sudo apt-key add -",
      "",
      "# Add HTCondor repository",
      "echo 'deb [arch=amd64] https://research.cs.wisc.edu/htcondor/repo/ubuntu/23.x jammy main' | sudo tee /etc/apt/sources.list.d/htcondor.list",
      "",
      "# Update and install",
      "sudo apt-get update",
      "sudo DEBIAN_FRONTEND=noninteractive apt-get install -y htcondor",
      "",
      "# Verify installation",
      "condor_version",
      "echo 'HTCondor installed'"
    ]
  }

  # Install SLURM dependencies
  provisioner "shell" {
    inline = [
      "echo '=== Installing SLURM Dependencies ==='",
      "sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \\",
      "  munge \\",
      "  libmunge-dev \\",
      "  libmunge2",
      "echo 'SLURM dependencies installed'"
    ]
  }

  # Install Docker
  provisioner "shell" {
    inline = [
      "echo '=== Installing Docker ==='",
      "# Install prerequisites",
      "sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \\",
      "  ca-certificates \\",
      "  gnupg \\",
      "  lsb-release",
      "",
      "# Add Docker GPG key",
      "sudo mkdir -p /etc/apt/keyrings",
      "curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg",
      "",
      "# Add Docker repository",
      "echo \"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable\" | sudo tee /etc/apt/sources.list.d/docker.list",
      "",
      "# Install Docker",
      "sudo apt-get update",
      "sudo DEBIAN_FRONTEND=noninteractive apt-get install -y docker-ce docker-ce-cli containerd.io",
      "",
      "# Verify installation",
      "sudo docker --version",
      "echo 'Docker installed'"
    ]
  }

  # Install Singularity/Apptainer
  provisioner "shell" {
    inline = [
      "echo '=== Installing Singularity ==='",
      "# Install dependencies",
      "sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \\",
      "  build-essential \\",
      "  libseccomp-dev \\",
      "  pkg-config \\",
      "  squashfs-tools \\",
      "  cryptsetup",
      "",
      "# Download and install Singularity",
      "export VERSION=3.11.4",
      "cd /tmp",
      "wget https://github.com/sylabs/singularity/releases/download/v${VERSION}/singularity-ce-${VERSION}.tar.gz",
      "tar -xzf singularity-ce-${VERSION}.tar.gz",
      "cd singularity-ce-${VERSION}",
      "",
      "# Build and install",
      "./mconfig",
      "make -C builddir",
      "sudo make -C builddir install",
      "",
      "# Verify installation",
      "singularity --version",
      "",
      "# Cleanup",
      "cd /tmp",
      "rm -rf singularity-ce-${VERSION} singularity-ce-${VERSION}.tar.gz",
      "echo 'Singularity installed'"
    ]
  }

  # Create directory structure
  provisioner "shell" {
    inline = [
      "echo '=== Creating Directory Structure ==='",
      "sudo mkdir -p /storage",
      "sudo mkdir -p /opt/nudocker",
      "echo 'Directories created'"
    ]
  }

  # Cleanup
  provisioner "shell" {
    inline = [
      "echo '=== Cleanup ==='",
      "sudo apt-get autoremove -y",
      "sudo apt-get clean",
      "sudo rm -rf /tmp/*",
      "sudo rm -rf /var/lib/apt/lists/*",
      "echo 'Cleanup complete'"
    ]
  }

  # Create build info file
  provisioner "shell" {
    inline = [
      "echo '=== Creating Build Info ==='",
      "sudo tee /etc/nudocker-image-info.txt > /dev/null <<EOF",
      "NuDocker Test Image - Stage 2",
      "Build Date: ${formatdate("YYYY-MM-DD HH:mm:ss", timestamp())}",
      "Base Image: Ubuntu 22.04 LTS",
      "HTCondor Version: $(condor_version | head -1)",
      "Docker Version: $(docker --version)",
      "Singularity Version: $(singularity --version)",
      "Purpose: Packer functionality test",
      "Stage: 2",
      "EOF",
      "cat /etc/nudocker-image-info.txt"
    ]
  }

  # Post-build verification
  post-processor "shell-local" {
    inline = [
      "echo '=== Post-Build Verification ==='",
      "echo 'Verifying image was created...'",
      "openstack --os-cloud ${var.cloud_name} image list | grep '${var.image_name}' || echo 'Image not found'",
      "echo 'Build complete!'"
    ]
  }
}
