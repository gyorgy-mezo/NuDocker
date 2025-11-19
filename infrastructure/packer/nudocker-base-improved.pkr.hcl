# NuDocker Base Image - IMPROVED
# Based on proven patterns from htcondor-slurm-demo
# Creates unified image with HTCondor + SLURM + Docker + Singularity + MESA deps

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

variables {
  # Image naming with timestamp
  image_name          = "nudocker-base-ubuntu22-${formatdate("YYYY-MM-DD", timestamp())}"

  # OpenStack source image (Ubuntu 22.04 LTS)
  source_image        = "b2be6f4e-ebd8-42af-a526-63691a4d90ea"

  # Network configuration (use IDs for reliability)
  networks            = ["205c5221-9248-4478-9232-947353c49827"]  # default network
  security_groups     = ["default"]
  floating_ip_network = "229d5e38-37db-44fd-af39-c1da0b651706"  # ext-net

  # Build configuration
  flavor              = "m2.large"  # 4 vCPU, 8 GB RAM for building
  volume_size         = 50

  # Software versions
  htcondor_version    = "23.x"
  docker_version      = "24.0"
}

# ==============================================================================
# Source Configuration
# ==============================================================================

source "openstack" "ubuntu" {
  # Image output
  image_name              = var.image_name

  # Source configuration
  source_image            = var.source_image

  # Network settings
  networks                = var.networks
  floating_ip_network     = var.floating_ip_network
  security_groups         = var.security_groups
  use_floating_ip         = true

  # Build configuration
  flavor                  = var.flavor
  use_blockstorage_volume = true
  volume_size             = var.volume_size
  image_disk_format       = "raw"

  # SSH settings
  ssh_username            = "ubuntu"

  # OpenStack settings
  insecure                = false
}

# ==============================================================================
# Build Configuration
# ==============================================================================

build {
  sources = ["source.openstack.ubuntu"]

  # ==============================================================================
  # System Update
  # ==============================================================================

  provisioner "shell" {
    inline = [
      "echo '==> Updating system packages'",
      "sudo apt-get update",
      "sudo DEBIAN_FRONTEND=noninteractive apt-get -y upgrade",
      "sudo apt-get install -y python3-pip wget curl git"
    ]
  }

  # ==============================================================================
  # Install HTCondor
  # ==============================================================================

  provisioner "shell" {
    inline = [
      "echo '==> Installing HTCondor ${var.htcondor_version}'",
      "wget -qO - https://research.cs.wisc.edu/htcondor/repo/keys/HTCondor-${var.htcondor_version}-Key | sudo apt-key add -",
      "echo 'deb [arch=amd64] https://research.cs.wisc.edu/htcondor/repo/ubuntu/${var.htcondor_version} jammy main' | sudo tee /etc/apt/sources.list.d/htcondor.list",
      "sudo apt-get update",
      "sudo apt-get install -y condor"
    ]
  }

  # ==============================================================================
  # Install SLURM
  # ==============================================================================

  provisioner "shell" {
    inline = [
      "echo '==> Installing SLURM workload manager'",
      "sudo apt-get install -y slurm-wlm slurm-client munge",
      "sudo mkdir -p /var/spool/slurm-llnl /var/log/slurm-llnl /var/run/slurm-llnl",
      "sudo chown -R slurm:slurm /var/spool/slurm-llnl /var/log/slurm-llnl /var/run/slurm-llnl"
    ]
  }

  # ==============================================================================
  # Install Docker
  # ==============================================================================

  provisioner "shell" {
    inline = [
      "echo '==> Installing Docker'",
      "sudo apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release",
      "curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg",
      "echo \"deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable\" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null",
      "sudo apt-get update",
      "sudo apt-get install -y docker-ce docker-ce-cli containerd.io",
      "sudo usermod -aG docker ubuntu",
      "sudo systemctl enable docker"
    ]
  }

  # ==============================================================================
  # Install Singularity/Apptainer
  # ==============================================================================

  provisioner "shell" {
    inline = [
      "echo '==> Installing Singularity dependencies'",
      "sudo apt-get install -y build-essential libseccomp-dev pkg-config squashfs-tools cryptsetup",
      "sudo apt-get install -y libssl-dev uuid-dev",
      "echo '==> Installing Go (required for Singularity)'",
      "cd /tmp",
      "wget -q https://go.dev/dl/go1.21.0.linux-amd64.tar.gz",
      "sudo tar -C /usr/local -xzf go1.21.0.linux-amd64.tar.gz",
      "export PATH=$PATH:/usr/local/go/bin",
      "echo '==> Building Singularity 3.11.4'",
      "cd /tmp",
      "wget -q https://github.com/sylabs/singularity/releases/download/v3.11.4/singularity-ce-3.11.4.tar.gz",
      "tar -xzf singularity-ce-3.11.4.tar.gz",
      "cd singularity-ce-3.11.4",
      "./mconfig --prefix=/usr/local",
      "make -C builddir",
      "sudo make -C builddir install",
      "cd /tmp",
      "rm -rf singularity-ce-3.11.4*"
    ]
  }

  # ==============================================================================
  # Install MESA Dependencies
  # ==============================================================================

  provisioner "shell" {
    inline = [
      "echo '==> Installing MESA compilation dependencies'",
      "sudo apt-get install -y gfortran gcc g++ make",
      "sudo apt-get install -y binutils git subversion",
      "sudo apt-get install -y emacs nano vim less tcsh",
      "sudo apt-get install -y libopenblas-dev libopenmpi-dev",
      "sudo apt-get install -y libx11-dev zlib1g-dev libbz2-dev",
      "sudo apt-get install -y openmpi-bin openmpi-common openmpi-doc",
      "sudo apt-get install -y python3 python3-pip python3-virtualenv",
      "sudo apt-get install -y perl wget curl rsync ssh unzip"
    ]
  }

  # ==============================================================================
  # Install NFS Client
  # ==============================================================================

  provisioner "shell" {
    inline = [
      "echo '==> Installing NFS client'",
      "sudo apt-get install -y nfs-common"
    ]
  }

  # ==============================================================================
  # Configure HTCondor Base
  # ==============================================================================

  provisioner "shell" {
    inline = [
      "echo '==> Configuring HTCondor base settings'",
      "sudo mkdir -p /etc/condor/config.d",
      "sudo mkdir -p /var/lib/condor/spool /var/lib/condor/execute",
      "sudo chown -R condor:condor /var/lib/condor/",
      "sudo tee /etc/condor/config.d/00-base.conf > /dev/null <<'EOF'",
      "# NuDocker HTCondor Base Configuration",
      "# Will be customized by Ansible for specific roles",
      "",
      "# Security (permissive for internal cluster)",
      "ALLOW_READ = *",
      "ALLOW_WRITE = *",
      "ALLOW_NEGOTIATOR = *",
      "ALLOW_DAEMON = *",
      "SEC_DEFAULT_AUTHENTICATION = OPTIONAL",
      "SEC_DEFAULT_ENCRYPTION = OPTIONAL",
      "SEC_DEFAULT_INTEGRITY = OPTIONAL",
      "",
      "# Resource detection",
      "NUM_CPUS = auto",
      "MEMORY = auto",
      "DISK = auto",
      "",
      "# Execution settings",
      "START = TRUE",
      "SUSPEND = FALSE",
      "PREEMPT = FALSE",
      "KILL = FALSE",
      "",
      "# Directories",
      "SPOOL = /var/lib/condor/spool",
      "EXECUTE = /var/lib/condor/execute",
      "",
      "# Docker Universe support",
      "DOCKER = /usr/bin/docker",
      "EOF",
      "sudo systemctl disable condor"
    ]
  }

  # ==============================================================================
  # Configure SLURM Base
  # ==============================================================================

  provisioner "shell" {
    inline = [
      "echo '==> Disabling SLURM services (will be configured by Ansible)'",
      "sudo systemctl disable slurmctld slurmd munge || true"
    ]
  }

  # ==============================================================================
  # Setup SSH for Cluster Communication
  # ==============================================================================

  provisioner "shell" {
    inline = [
      "echo '==> Setting up SSH directory'",
      "sudo mkdir -p /home/ubuntu/.ssh",
      "sudo chmod 700 /home/ubuntu/.ssh",
      "sudo touch /home/ubuntu/.ssh/authorized_keys",
      "sudo chmod 600 /home/ubuntu/.ssh/authorized_keys",
      "sudo chown -R ubuntu:ubuntu /home/ubuntu/.ssh"
    ]
  }

  # ==============================================================================
  # Create NuDocker Environment Profile
  # ==============================================================================

  provisioner "shell" {
    inline = [
      "echo '==> Creating NuDocker environment profile'",
      "sudo tee /etc/profile.d/nudocker.sh > /dev/null <<'EOF'",
      "# NuDocker Environment Configuration",
      "",
      "# Storage paths",
      "export NUDOCKER_STORAGE=\"/storage\"",
      "export MESA_SRC=\"$NUDOCKER_STORAGE/mesa\"",
      "export NUDOCKER_CONTAINERS=\"$NUDOCKER_STORAGE/containers\"",
      "export NUDOCKER_RESULTS=\"$NUDOCKER_STORAGE/results\"",
      "",
      "# HTCondor convenience variables",
      "export CONDOR_JOBS=\"$NUDOCKER_STORAGE/htcondor_jobs\"",
      "",
      "# SLURM convenience variables",
      "export SLURM_JOBS=\"$NUDOCKER_STORAGE/slurm_jobs\"",
      "",
      "# MESA settings (when running in container)",
      "export OMP_NUM_THREADS=4",
      "",
      "# Aliases",
      "alias ll='ls -la'",
      "alias condor-status='condor_status -total'",
      "alias slurm-status='sinfo'",
      "EOF",
      "sudo chmod 644 /etc/profile.d/nudocker.sh"
    ]
  }

  # ==============================================================================
  # Cleanup
  # ==============================================================================

  provisioner "shell" {
    inline = [
      "echo '==> Cleaning up image'",
      "sudo apt-get -y autoremove",
      "sudo apt-get -y autoclean",
      "sudo rm -rf /var/lib/apt/lists/*",
      "sudo rm -rf /tmp/*",
      "sudo rm -f /home/ubuntu/.bash_history",
      "sudo find /var/log -type f -exec truncate -s 0 {} \\;",
      "echo '==> Image build complete!'"
    ]
  }
}
