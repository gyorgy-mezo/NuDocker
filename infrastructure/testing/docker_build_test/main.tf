terraform {
  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 1.54.0"
    }
  }
}

provider "openstack" {
  # Authentication configured via environment variables
}

# Variables
variable "key_name" {
  description = "SSH key pair name"
  type        = string
  default     = "alma"
}

variable "image_name" {
  description = "Ubuntu image name"
  type        = string
  default     = "Ubuntu 22.04 LTS"
}

variable "flavor" {
  description = "VM flavor for Docker builds"
  type        = string
  default     = "m2.4xlarge"  # 32 vCPU, 64GB RAM
}

variable "network_name" {
  description = "Private network name"
  type        = string
  default     = "default"
}

variable "floating_ip_pool" {
  description = "Floating IP pool name"
  type        = string
  default     = "ext-net"
}

variable "volume_size" {
  description = "Boot volume size in GB"
  type        = number
  default     = 100  # Large enough for Docker images
}

# Security group for Docker build testing
resource "openstack_networking_secgroup_v2" "docker_test" {
  name        = "nudocker-docker-build-test"
  description = "Security group for Docker build performance testing"
}

# SSH access
resource "openstack_networking_secgroup_rule_v2" "ssh" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.docker_test.id
}

# Allow all outbound
resource "openstack_networking_secgroup_rule_v2" "egress" {
  direction         = "egress"
  ethertype         = "IPv4"
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.docker_test.id
}

# Data source for image
data "openstack_images_image_v2" "ubuntu" {
  name        = var.image_name
  most_recent = true
}

# Data source for network
data "openstack_networking_network_v2" "private" {
  name = var.network_name
}

# VM for testing ORIGINAL Docker builds
resource "openstack_blockstorage_volume_v3" "original_boot" {
  name        = "nudocker-test-original-boot"
  size        = var.volume_size
  image_id    = data.openstack_images_image_v2.ubuntu.id
  volume_type = "SSD"
}

resource "openstack_compute_instance_v2" "original" {
  name        = "nudocker-test-original-build"
  flavor_name = var.flavor
  key_pair    = var.key_name

  security_groups = [
    openstack_networking_secgroup_v2.docker_test.name
  ]

  block_device {
    uuid                  = openstack_blockstorage_volume_v3.original_boot.id
    source_type           = "volume"
    boot_index            = 0
    destination_type      = "volume"
    delete_on_termination = true
  }

  network {
    name = var.network_name
  }

  user_data = <<EOF
#!/bin/bash
set -e

# Update system
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y

# Install Docker
apt-get install -y ca-certificates curl gnupg lsb-release
mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Add ubuntu user to docker group
usermod -aG docker ubuntu

# Enable Docker BuildKit globally
mkdir -p /etc/docker
cat > /etc/docker/daemon.json <<DOCKER_DAEMON
{
  "features": {
    "buildkit": true
  },
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
DOCKER_DAEMON

systemctl restart docker

# Install build tools
apt-get install -y git make time

# Clone NuDocker repository
cd /home/ubuntu
git clone https://github.com/gyorgy-mezo/NuDocker.git
chown -R ubuntu:ubuntu NuDocker

# Create test directory
mkdir -p /home/ubuntu/test_results
chown ubuntu:ubuntu /home/ubuntu/test_results

# Create test script for ORIGINAL builds
cat > /home/ubuntu/test_original.sh <<'TEST_SCRIPT'
#!/bin/bash
set -e

cd /home/ubuntu/NuDocker/build_docker_images

echo "=========================================="
echo "TESTING ORIGINAL DOCKER BUILD SYSTEM"
echo "=========================================="
echo "Test started: $(date)"
echo ""

# Test nudome20.1 (most critical - 43 layers!)
echo "Building nudome20.1 with ORIGINAL Dockerfile..."
echo "Target: Ubuntu 20.04 + MESA SDK 21.4.1"
echo ""

# Clean start
docker system prune -af --volumes
sync

# Measure build time and capture metrics
START_TIME=$(date +%s)
/usr/bin/time -v make nudome20.1 2>&1 | tee /home/ubuntu/test_results/original_build.log
END_TIME=$(date +%s)

BUILD_TIME=$((END_TIME - START_TIME))

echo ""
echo "=========================================="
echo "BUILD COMPLETED"
echo "=========================================="
echo "Build time: $${BUILD_TIME} seconds ($$((BUILD_TIME / 60)) minutes)"
echo ""

# Capture image details
docker images nugrid/nudome:20.1a > /home/ubuntu/test_results/original_image_size.txt
docker history nugrid/nudome:20.1a > /home/ubuntu/test_results/original_layers.txt

# Count layers
LAYER_COUNT=$(docker history nugrid/nudome:20.1a --no-trunc | wc -l)
IMAGE_SIZE=$(docker images nugrid/nudome:20.1a --format "{{.Size}}")

echo "Image size: $IMAGE_SIZE"
echo "Layer count: $LAYER_COUNT"
echo ""

# Save metrics
cat > /home/ubuntu/test_results/original_metrics.txt <<METRICS
Build Time: $${BUILD_TIME} seconds ($$((BUILD_TIME / 60)) minutes)
Image Size: $IMAGE_SIZE
Layer Count: $LAYER_COUNT
Dockerfile: Dockerfile_template.20 (ORIGINAL)
VM Flavor: m2.4xlarge (32 vCPU, 64GB RAM)
Test Date: $(date)
METRICS

echo "Results saved to /home/ubuntu/test_results/"
echo "Test completed: $(date)"
TEST_SCRIPT

chmod +x /home/ubuntu/test_original.sh
chown ubuntu:ubuntu /home/ubuntu/test_original.sh

# Signal completion
touch /home/ubuntu/cloud-init-complete
EOF

  metadata = {
    role = "original-docker-build-test"
  }
}

# Floating IP for original build VM
resource "openstack_networking_floatingip_v2" "original" {
  pool = var.floating_ip_pool
}

resource "openstack_compute_floatingip_associate_v2" "original" {
  floating_ip = openstack_networking_floatingip_v2.original.address
  instance_id = openstack_compute_instance_v2.original.id
}

# VM for testing OPTIMIZED Docker builds
resource "openstack_blockstorage_volume_v3" "optimized_boot" {
  name        = "nudocker-test-optimized-boot"
  size        = var.volume_size
  image_id    = data.openstack_images_image_v2.ubuntu.id
  volume_type = "SSD"
}

resource "openstack_compute_instance_v2" "optimized" {
  name        = "nudocker-test-optimized-build"
  flavor_name = var.flavor
  key_pair    = var.key_name

  security_groups = [
    openstack_networking_secgroup_v2.docker_test.name
  ]

  block_device {
    uuid                  = openstack_blockstorage_volume_v3.optimized_boot.id
    source_type           = "volume"
    boot_index            = 0
    destination_type      = "volume"
    delete_on_termination = true
  }

  network {
    name = var.network_name
  }

  user_data = <<EOF
#!/bin/bash
set -e

# Update system
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y

# Install Docker
apt-get install -y ca-certificates curl gnupg lsb-release
mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Add ubuntu user to docker group
usermod -aG docker ubuntu

# Enable Docker BuildKit globally
mkdir -p /etc/docker
cat > /etc/docker/daemon.json <<DOCKER_DAEMON
{
  "features": {
    "buildkit": true
  },
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
DOCKER_DAEMON

systemctl restart docker

# Install build tools
apt-get install -y git make time

# Clone NuDocker repository
cd /home/ubuntu
git clone https://github.com/gyorgy-mezo/NuDocker.git
chown -R ubuntu:ubuntu NuDocker

# Create test directory
mkdir -p /home/ubuntu/test_results
chown ubuntu:ubuntu /home/ubuntu/test_results

# Create test script for OPTIMIZED builds
cat > /home/ubuntu/test_optimized.sh <<'TEST_SCRIPT'
#!/bin/bash
set -e

cd /home/ubuntu/NuDocker/build_docker_images

echo "=========================================="
echo "TESTING OPTIMIZED DOCKER BUILD SYSTEM"
echo "=========================================="
echo "Test started: $(date)"
echo ""

# Test nudome20.1 with OPTIMIZED Dockerfile
echo "Building nudome20.1 with OPTIMIZED Dockerfile..."
echo "Target: Ubuntu 20.04 + MESA SDK 21.4.1"
echo "Optimizations: 43 layers -> 3 layers, BuildKit cache mounts"
echo ""

# Clean start
docker system prune -af --volumes
sync

# Measure build time and capture metrics
START_TIME=$(date +%s)
/usr/bin/time -v make -f makefile.optimized nudome20.1 2>&1 | tee /home/ubuntu/test_results/optimized_build.log
END_TIME=$(date +%s)

BUILD_TIME=$((END_TIME - START_TIME))

echo ""
echo "=========================================="
echo "BUILD COMPLETED"
echo "=========================================="
echo "Build time: $${BUILD_TIME} seconds ($$((BUILD_TIME / 60)) minutes)"
echo ""

# Capture image details
docker images nugrid/nudome:20.1a > /home/ubuntu/test_results/optimized_image_size.txt
docker history nugrid/nudome:20.1a > /home/ubuntu/test_results/optimized_layers.txt

# Count layers
LAYER_COUNT=$(docker history nugrid/nudome:20.1a --no-trunc | wc -l)
IMAGE_SIZE=$(docker images nugrid/nudome:20.1a --format "{{.Size}}")

echo "Image size: $IMAGE_SIZE"
echo "Layer count: $LAYER_COUNT"
echo ""

# Save metrics
cat > /home/ubuntu/test_results/optimized_metrics.txt <<METRICS
Build Time: $${BUILD_TIME} seconds ($$((BUILD_TIME / 60)) minutes)
Image Size: $IMAGE_SIZE
Layer Count: $LAYER_COUNT
Dockerfile: Dockerfile_template.20.optimized
VM Flavor: m2.4xlarge (32 vCPU, 64GB RAM)
Test Date: $(date)
METRICS

echo "Results saved to /home/ubuntu/test_results/"
echo "Test completed: $(date)"
TEST_SCRIPT

chmod +x /home/ubuntu/test_optimized.sh
chown ubuntu:ubuntu /home/ubuntu/test_optimized.sh

# Signal completion
touch /home/ubuntu/cloud-init-complete
EOF

  metadata = {
    role = "optimized-docker-build-test"
  }
}

# Floating IP for optimized build VM
resource "openstack_networking_floatingip_v2" "optimized" {
  pool = var.floating_ip_pool
}

resource "openstack_compute_floatingip_associate_v2" "optimized" {
  floating_ip = openstack_networking_floatingip_v2.optimized.address
  instance_id = openstack_compute_instance_v2.optimized.id
}

# Outputs
output "original_vm_ip" {
  value = openstack_networking_floatingip_v2.original.address
  description = "Floating IP for original build test VM"
}

output "optimized_vm_ip" {
  value = openstack_networking_floatingip_v2.optimized.address
  description = "Floating IP for optimized build test VM"
}

output "original_vm_id" {
  value = openstack_compute_instance_v2.original.id
}

output "optimized_vm_id" {
  value = openstack_compute_instance_v2.optimized.id
}

output "test_instructions" {
  value = <<INSTRUCTIONS

Docker Build Test Infrastructure Ready
======================================

Original Build VM:  ssh ubuntu@${openstack_networking_floatingip_v2.original.address}
Optimized Build VM: ssh ubuntu@${openstack_networking_floatingip_v2.optimized.address}

Both VMs are identical: m2.4xlarge (32 vCPU, 64GB RAM, 100GB SSD)

Test Procedure:
--------------
1. Wait for cloud-init to complete (~3-5 minutes):
   ssh ubuntu@${openstack_networking_floatingip_v2.original.address} 'tail -f /var/log/cloud-init-output.log'

2. Run original build test:
   ssh ubuntu@${openstack_networking_floatingip_v2.original.address} './test_original.sh'

3. Run optimized build test:
   ssh ubuntu@${openstack_networking_floatingip_v2.optimized.address} './test_optimized.sh'

4. Collect results:
   scp ubuntu@${openstack_networking_floatingip_v2.original.address}:test_results/* ./results_original/
   scp ubuntu@${openstack_networking_floatingip_v2.optimized.address}:test_results/* ./results_optimized/

5. Compare metrics and generate report

INSTRUCTIONS
}
