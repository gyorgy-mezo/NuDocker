# NuDocker HTCondor Infrastructure Deployment Guide

**Complete Infrastructure-as-Code deployment for HTCondor cluster on HUN-REN Cloud**

Last Updated: 2025-11-18

---

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Architecture](#architecture)
- [Phase 1: Build Images with Packer](#phase-1-build-images-with-packer)
- [Phase 2: Provision Infrastructure with Terraform](#phase-2-provision-infrastructure-with-terraform)
- [Phase 3: Configure Cluster with Ansible](#phase-3-configure-cluster-with-ansible)
- [Phase 4: Validation and Testing](#phase-4-validation-and-testing)
- [Usage Examples](#usage-examples)
- [Troubleshooting](#troubleshooting)
- [Maintenance](#maintenance)
- [Cleanup](#cleanup)

---

## Overview

This deployment guide walks through the complete setup of a production HTCondor cluster on HUN-REN Science Cloud using Infrastructure-as-Code tools:

- **Packer**: Build custom VM images with HTCondor, Docker, and Singularity
- **Terraform**: Provision cloud infrastructure (networks, VMs, storage)
- **Ansible**: Configure HTCondor cluster and NuDocker environment

### Deployed Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     HUN-REN Cloud Project                    │
│                   (72 vCPU, 192 GB RAM)                      │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌──────────────────┐         ┌──────────────────┐          │
│  │ Central Manager  │         │  Shared Storage  │          │
│  │  - Collector     │◄────────┤    500 GB NFS    │          │
│  │  - Negotiator    │         │  - MESA          │          │
│  │  - Schedd        │         │  - Containers    │          │
│  │  - NFS Server    │         │  - Results       │          │
│  │  8 vCPU, 16 GB   │         └──────────────────┘          │
│  │  Floating IP     │                                        │
│  └────────┬─────────┘                                        │
│           │                                                  │
│           │ 10.0.0.0/24 Private Network                      │
│           │                                                  │
│  ┌────────┴─────────────────────────────────────────┐       │
│  │                                                   │       │
│  │  Execute Nodes (5×):                              │       │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐       │       │
│  │  │Execute-01│  │Execute-02│  │Execute-03│ ...   │       │
│  │  │ 8vCPU    │  │ 8vCPU    │  │ 8vCPU    │       │       │
│  │  │ 32GB     │  │ 32GB     │  │ 32GB     │       │       │
│  │  └──────────┘  └──────────┘  └──────────┘       │       │
│  │                                                   │       │
│  └───────────────────────────────────────────────────┘       │
│                                                              │
│  Total Used: 48 vCPU, 176 GB RAM (67% efficiency)           │
└─────────────────────────────────────────────────────────────┘
```

---

## Prerequisites

### 1. Local Machine Requirements

**Required Software**:
- **Terraform** >= 1.0: https://www.terraform.io/downloads
- **Packer** >= 1.8: https://www.packer.io/downloads
- **Ansible** >= 2.12: https://docs.ansible.com/ansible/latest/installation_guide/
- **OpenStack CLI** (optional): `pip install python-openstackclient`
- **SSH** client
- **Git**

**Install on Ubuntu/Debian**:
```bash
# Terraform
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform packer

# Ansible
sudo apt install ansible

# OpenStack CLI
pip3 install python-openstackclient
```

**Install on macOS**:
```bash
brew tap hashicorp/tap
brew install hashicorp/tap/terraform
brew install hashicorp/tap/packer
brew install ansible
pip3 install python-openstackclient
```

### 2. HUN-REN Cloud Access

**Required Credentials**:
- OpenStack project name
- Username
- Password
- Authentication URL: `https://cloud.hunren.hu:5000/v3`
- Project quota: 72 vCPU, 192 GB RAM, 1 TB storage

**Verify Access**:
```bash
export OS_AUTH_URL=https://cloud.hunren.hu:5000/v3
export OS_PROJECT_NAME=your-project-name
export OS_USERNAME=your-username
export OS_PASSWORD=your-password
export OS_USER_DOMAIN_NAME=Default

openstack server list  # Should authenticate successfully
```

### 3. SSH Key Pair

```bash
# Generate SSH key if you don't have one
ssh-keygen -t rsa -b 4096 -C "your_email@example.com" -f ~/.ssh/id_rsa

# Verify key exists
ls -l ~/.ssh/id_rsa.pub
```

### 4. Clone NuDocker Repository

```bash
git clone https://github.com/NuGrid/NuDocker.git
cd NuDocker/infrastructure
```

---

## Phase 1: Build Images with Packer

### Step 1: Configure Packer Variables

```bash
cd packer
cp variables.pkrvars.hcl.example variables.pkrvars.hcl
vim variables.pkrvars.hcl
```

**Edit values**:
```hcl
openstack_project_name = "your-project-name"
openstack_username     = "your-username"
openstack_password     = "your-password"

source_image_name = "Ubuntu-20.04"  # Verify this exists in your project
network_name      = "public"        # Or your network name
```

### Step 2: Validate Packer Template

```bash
packer validate -var-file=variables.pkrvars.hcl nudocker-htcondor.pkr.hcl
```

Expected output:
```
The configuration is valid.
```

### Step 3: Build Base Image

```bash
packer build -var-file=variables.pkrvars.hcl nudocker-htcondor.pkr.hcl
```

**Build Time**: ~30-45 minutes

**What Gets Installed**:
- Ubuntu 20.04 LTS (updated)
- HTCondor 23.10
- Docker 24.0 with containerd
- Singularity/Apptainer 3.11.4
- NFS client/server utilities
- MESA dependencies (compilers, libraries)
- Python 3 with scientific packages

**Output**: Image named `nudocker-htcondor-base-YYYYMMDD-HHMM`

**Save the image name** - you'll need it for Terraform:
```bash
# List images to find yours
openstack image list | grep nudocker

# Note the image ID or name
```

### Step 4: Verify Image

```bash
openstack image show nudocker-htcondor-base-YYYYMMDD-HHMM
```

---

## Phase 2: Provision Infrastructure with Terraform

### Step 1: Configure Terraform Variables

```bash
cd ../terraform
cp terraform.tfvars.example terraform.tfvars
vim terraform.tfvars
```

**Critical Configuration**:
```hcl
# Authentication
openstack_project_name = "your-project-name"
openstack_username     = "your-username"
openstack_password     = "your-password"

# Image built by Packer (IMPORTANT!)
central_manager_image = "nudocker-htcondor-base-YYYYMMDD-HHMM"
execute_node_image    = "nudocker-htcondor-base-YYYYMMDD-HHMM"

# HTCondor security
htcondor_pool_password = "CHANGE-THIS-TO-STRONG-PASSWORD-32-CHARS"

# Network (verify these exist in your project)
external_network_name = "public"

# Resources (adjust if needed)
execute_node_count = 5  # 5 nodes = 40 vCPU, 160 GB RAM
```

### Step 2: Initialize Terraform

```bash
terraform init
```

Expected output:
```
Terraform has been successfully initialized!
```

### Step 3: Plan Deployment

```bash
terraform plan -out=tfplan
```

Review the plan carefully:
- **6 instances** (1 central + 5 execute)
- **1 network** + subnet + router
- **2 security groups**
- **1 floating IP**
- **1 storage volume** (500 GB)

### Step 4: Apply Configuration

```bash
terraform apply tfplan
```

**Deployment Time**: ~10-15 minutes

**Monitor Progress**:
```bash
# In another terminal
watch -n 5 'openstack server list'
```

### Step 5: Save Outputs

```bash
terraform output > ../deployment_info.txt
cat ../deployment_info.txt
```

Expected outputs:
```
central_manager_floating_ip = "193.224.xxx.xxx"
central_manager_private_ip  = "10.0.0.10"
execute_node_ips = [
  "10.0.0.20",
  "10.0.0.21",
  "10.0.0.22",
  "10.0.0.23",
  "10.0.0.24",
]
ssh_command = "ssh -i ~/.ssh/id_rsa ubuntu@193.224.xxx.xxx"
```

### Step 6: Test SSH Access

```bash
# Get floating IP
CENTRAL_IP=$(terraform output -raw central_manager_floating_ip)

# SSH to central manager
ssh -i ~/.ssh/id_rsa ubuntu@$CENTRAL_IP

# Verify cloud-init completed
cloud-init status
# Should show: status: done

# Exit
exit
```

---

## Phase 3: Configure Cluster with Ansible

### Step 1: Update Ansible Inventory

```bash
cd ../ansible

# Get floating IP from Terraform
CENTRAL_IP=$(cd ../terraform && terraform output -raw central_manager_floating_ip)

# Update inventory
sed -i "s/FLOATING_IP_HERE/$CENTRAL_IP/" inventory/hosts.ini

# Verify
cat inventory/hosts.ini
```

### Step 2: Set HTCondor Pool Password

```bash
# Same password as in terraform.tfvars
export HTCONDOR_POOL_PASSWORD="your-strong-password-here"
```

### Step 3: Install Ansible Requirements

```bash
ansible-galaxy collection install -r requirements.yml
```

### Step 4: Test Ansible Connectivity

```bash
# Test central manager (via public IP)
ansible central_manager -m ping

# Test execute nodes (via bastion/jump through central)
ansible execute_nodes -m ping \
  --ssh-common-args='-o ProxyJump=ubuntu@'$CENTRAL_IP
```

Expected output for all nodes:
```
hostname | SUCCESS => {
    "ping": "pong"
}
```

### Step 5: Run Ansible Playbook

```bash
cd playbooks

# Full deployment
ansible-playbook site.yml

# Or step by step
ansible-playbook site.yml --tags common
ansible-playbook site.yml --tags central
ansible-playbook site.yml --tags execute
ansible-playbook site.yml --tags nudocker
ansible-playbook site.yml --tags verify
```

**Configuration Time**: ~20-30 minutes

**What Gets Configured**:
1. **Common (all nodes)**:
   - `/etc/hosts` with cluster nodes
   - System limits and kernel parameters
   - HTCondor directories

2. **Central Manager**:
   - HTCondor collector, negotiator, schedd
   - NFS server with shared storage
   - Pool password authentication
   - NuDocker repository clone

3. **Execute Nodes**:
   - HTCondor startd (execution daemon)
   - NFS client mount to `/storage`
   - Docker and Singularity configured

4. **NuDocker**:
   - Pull Docker images (nugrid/nudome:*)
   - Build Singularity images
   - Deploy HTCondor job templates
   - Configure environment

5. **Verification**:
   - Check all nodes registered
   - Verify NFS mounts
   - Test Docker and Singularity
   - Generate health report

### Step 6: Monitor Playbook Execution

Watch for successful tasks:
```
TASK [cluster-verify : Display pool summary]
ok: [central] => {
    "condor_total_output.stdout_lines": [
        "Total Owner Claimed Unclaimed Matched Preempting",
        "X86_64/LINUX    40    40       0        40       0          0"
    ]
}
```

---

## Phase 4: Validation and Testing

### Step 1: SSH to Central Manager

```bash
ssh -i ~/.ssh/id_rsa ubuntu@$CENTRAL_IP
```

### Step 2: Verify HTCondor Pool

```bash
# Check cluster status
condor_status

# Should show 5 execute nodes, 40 total slots
# Example:
# Name        OpSys   Arch   State    Activity LoadAv Mem
# execute-01  LINUX   X86_64 Unclaimed Idle     0.000  30000
# execute-02  LINUX   X86_64 Unclaimed Idle     0.000  30000
# ...
```

### Step 3: Verify Shared Storage

```bash
# Check NFS mount
df -h /storage

# Should show: 10.0.0.10:/storage  500G ...

# Check directory structure
ls -la /storage/
# Should see: mesa/ containers/ results/ users/ batch_examples/ nudocker/
```

### Step 4: Verify Docker

```bash
# List Docker images
docker images

# Should show:
# nugrid/nudome  20.1a   ...
# nugrid/nudome  20.031  ...
# nugrid/nudome  18.0    ...
# nugrid/nudome  16.0    ...
```

### Step 5: Verify Singularity Images

```bash
ls -lh /storage/containers/

# Should show .sif files:
# nudome-16.0.sif
# nudome-18.0.sif
# nudome-20.031.sif
# nudome-20.1a.sif
```

### Step 6: Submit Test Job

```bash
# Create test submit file
cat > /tmp/test.sub <<'EOF'
universe     = vanilla
executable   = /bin/sleep
arguments    = 30
output       = test_$(Process).out
error        = test_$(Process).err
log          = test.log
request_cpus = 1
request_memory = 1GB
queue 5
EOF

# Submit
condor_submit /tmp/test.sub

# Check queue
condor_q

# Should show 5 jobs running across execute nodes

# Wait for completion
watch -n 2 condor_q

# Verify output files
ls -l test_*.out
```

### Step 7: Submit Docker Universe Test

```bash
cat > /tmp/docker_test.sub <<'EOF'
universe       = docker
docker_image   = nugrid/nudome:20.1a
executable     = /bin/bash
arguments      = -c "echo 'NuDocker test from HTCondor'; condor_version"
output         = docker_test.out
error          = docker_test.err
log            = docker_test.log
request_cpus   = 1
request_memory = 2GB
queue
EOF

condor_submit /tmp/docker_test.sub
watch -n 2 condor_q

# Check output
cat docker_test.out
# Should show HTCondor version and NuDocker message
```

### Step 8: Review Cluster Health Report

```bash
cat /storage/cluster_health_report.txt
```

---

## Usage Examples

### Running MESA Models with HTCondor

#### Example 1: Single MESA Model

```bash
cd /storage/htcondor_jobs
mkdir test_mesa_5M
cd test_mesa_5M

# Create submit file
cat > mesa_5M.sub <<'EOF'
universe        = docker
docker_image    = nugrid/nudome:16.0
docker_network_type = host

executable      = /storage/nudocker/bin/run_mesa_model.sh
arguments       = 0 5.0 0.02 2.0

transfer_input_files = /storage/mesa/mesa-r9575
should_transfer_files = YES
when_to_transfer_output = ON_EXIT

output          = mesa_5M.out
error           = mesa_5M.err
log             = mesa_5M.log

request_cpus    = 8
request_memory  = 8GB
request_disk    = 10GB

queue
EOF

# Submit
condor_submit mesa_5M.sub

# Monitor
condor_q -better-analyze
watch -n 10 condor_q

# Results will be in /storage/results/
```

#### Example 2: Parameter Study (54 Models)

```bash
cd /storage/batch_examples

# Review DAG workflow
cat nudocker_study.dag

# Submit DAG
condor_submit_dag nudocker_study.dag

# Monitor DAG progress
watch -n 30 'condor_q; echo ""; ls -lh /storage/results/'

# DAG status
cat nudocker_study.dag.dagman.out | tail -20
```

### Using Singularity Instead of Docker

```bash
cat > mesa_singularity.sub <<'EOF'
universe        = vanilla
executable      = /usr/bin/singularity
arguments       = exec -B /storage:/storage /storage/containers/nudome-16.0.sif /storage/nudocker/bin/run_mesa_model.sh 0 5.0 0.02 2.0

output          = mesa_sing.out
error           = mesa_sing.err
log             = mesa_sing.log

request_cpus    = 8
request_memory  = 8GB

queue
EOF

condor_submit mesa_singularity.sub
```

---

## Troubleshooting

### HTCondor Issues

**Problem**: Execute nodes not showing in `condor_status`

```bash
# On central manager
sudo systemctl status condor
sudo journalctl -u condor -n 50

# Check network connectivity
ping execute-01
ping 10.0.0.20

# Check pool password
sudo ls -l /etc/condor/pool_password
sudo cat /var/lib/condor/passwords.d/POOL

# On execute node (SSH via central)
ssh execute-01
sudo systemctl status condor
sudo condor_status -schedd
```

**Fix**:
```bash
# Restart HTCondor on execute nodes
ansible execute_nodes -a "systemctl restart condor" --become
```

**Problem**: Jobs stay idle

```bash
# Check match diagnostics
condor_q -better-analyze JOB_ID

# Common issues:
# - Insufficient memory/CPU requested
# - Docker image not available
# - Files not accessible
```

### NFS Issues

**Problem**: `/storage` not mounted on execute nodes

```bash
# Check NFS server
ssh central
sudo exportfs -v
sudo systemctl status nfs-kernel-server

# Check NFS client
ssh execute-01
mount | grep storage
sudo mount -a
```

**Fix**:
```bash
# Re-mount NFS on all execute nodes
ansible execute_nodes -a "mount -a" --become
```

### Docker Issues

**Problem**: Docker Universe jobs fail

```bash
# Check Docker on execute node
ssh execute-01
docker ps
docker images

# Check Docker daemon
sudo systemctl status docker
sudo journalctl -u docker -n 50

# Test Docker manually
docker run hello-world
```

**Fix**:
```bash
# Restart Docker
ansible execute_nodes -a "systemctl restart docker" --become
```

### Network/Firewall Issues

**Problem**: Can't SSH to central manager

```bash
# Check floating IP association
openstack floating ip list
openstack server show nudocker-htcondor-central

# Check security group
openstack security group rule list nudocker-htcondor-central-sg
```

**Fix**:
```bash
# Add your IP to security group
openstack security group rule create \
  --ingress --protocol tcp --dst-port 22 \
  --remote-ip YOUR_IP/32 \
  nudocker-htcondor-central-sg
```

### Storage Issues

**Problem**: Shared storage full

```bash
# Check usage
df -h /storage
du -sh /storage/*

# Clean up old results
cd /storage/results
rm -rf old_job_*
```

---

## Maintenance

### Updating HTCondor

```bash
# On all nodes (via Ansible)
cd /home/user/NuDocker/infrastructure/ansible/playbooks
ansible all -a "apt-get update" --become
ansible all -a "apt-get upgrade -y htcondor" --become
ansible all -a "systemctl restart condor" --become
```

### Adding Execute Nodes

**Edit Terraform**:
```bash
cd /home/user/NuDocker/infrastructure/terraform
vim terraform.tfvars

# Change:
execute_node_count = 7  # Was 5, now 7

# Apply
terraform plan
terraform apply
```

**Configure new nodes**:
```bash
cd ../ansible
# Update inventory with new nodes
ansible-playbook playbooks/site.yml --limit execute_nodes
```

### Backup Critical Data

```bash
# Backup NFS storage
cd /storage
tar czf /tmp/nudocker-backup-$(date +%Y%m%d).tar.gz \
  --exclude='containers/*.sif' \
  mesa/ results/ users/ batch_examples/

# Copy to external storage
scp /tmp/nudocker-backup-*.tar.gz user@backup-server:/backups/
```

### Monitoring

```bash
# Create monitoring script on central manager
cat > /usr/local/bin/condor-monitor.sh <<'EOF'
#!/bin/bash
echo "=== $(date) ==="
echo "HTCondor Status:"
condor_status -total
echo ""
echo "Job Queue:"
condor_q -total
echo ""
echo "Storage Usage:"
df -h /storage
EOF

chmod +x /usr/local/bin/condor-monitor.sh

# Add to crontab
(crontab -l 2>/dev/null; echo "*/10 * * * * /usr/local/bin/condor-monitor.sh >> /var/log/condor-monitor.log") | crontab -
```

---

## Cleanup

### Remove Cluster (Keep Images)

```bash
cd /home/user/NuDocker/infrastructure/terraform

# Destroy infrastructure
terraform destroy

# Terraform will ask for confirmation
# Type: yes
```

**This removes**:
- All VMs (central + execute nodes)
- Networks and security groups
- Floating IP
- Storage volume (WARNING: Data loss!)

**This keeps**:
- Packer-built images

### Remove Everything (Including Images)

```bash
# Destroy Terraform resources
cd terraform
terraform destroy

# Remove Packer images
openstack image list | grep nudocker-htcondor-base
openstack image delete nudocker-htcondor-base-YYYYMMDD-HHMM
```

### Partial Cleanup (Keep Data Volume)

```bash
# Before terraform destroy, comment out volume in main.tf
vim main.tf
# Comment: resource "openstack_blockstorage_volume_v3" "shared_storage"

terraform apply  # Detach volume
terraform destroy  # Remove everything else

# Volume remains and can be reattached later
```

---

## Cost Estimate

**Monthly Costs** (HUN-REN Cloud pricing):

| Resource | Specification | Monthly Cost |
|----------|---------------|--------------|
| Central Manager | 8 vCPU, 16 GB RAM | €60 |
| Execute Nodes (5×) | 40 vCPU, 160 GB RAM | €200 |
| Shared Storage | 500 GB | €20 |
| Network/IP | 1 Floating IP | €5 |
| **Total** | | **~€285/month** |

**Per-Job Cost**:
- 54-model NuGrid study: ~15 days runtime
- Cost: ~€142 (half month)
- **Per model**: ~€2.63

---

## Performance Benchmarks

**Expected Performance** (54-model NuGrid study):

| Mass Range | Concurrent Jobs | Time per Model | Total Time |
|------------|-----------------|----------------|------------|
| Low (1-2 M☉) | 5 | 4-6 hours | 2-3 days |
| Medium (5-10 M☉) | 5 | 12-18 hours | 4-6 days |
| High (15-20 M☉) | 5 | 24-48 hours | 8-12 days |
| **Total** | | | **14-21 days** |

**Throughput**: ~3-4 models per day with 5 nodes

---

## Support and Resources

**NuDocker**:
- GitHub: https://github.com/NuGrid/NuDocker
- Documentation: README.md in repository

**HTCondor**:
- Documentation: https://htcondor.readthedocs.io/
- Manual: https://htcondor.readthedocs.io/en/latest/

**HUN-REN Cloud**:
- Documentation: https://docs.slurm.science-cloud.hu/
- Support: Contact your project administrator

**MESA**:
- Website: http://mesa.sourceforge.net/
- Forum: https://lists.mesastar.org/

---

## Quick Reference Commands

```bash
# Infrastructure
terraform plan                    # Preview changes
terraform apply                   # Deploy infrastructure
terraform destroy                 # Remove infrastructure
terraform output                  # Show outputs

# Ansible
ansible all -m ping              # Test connectivity
ansible-playbook site.yml        # Full deployment
ansible-playbook site.yml --tags verify  # Verification only

# HTCondor (on central manager)
condor_status                    # Show pool status
condor_status -total             # Show summary
condor_q                         # Show job queue
condor_submit job.sub            # Submit job
condor_submit_dag workflow.dag   # Submit DAG
condor_rm JOB_ID                 # Remove job
condor_q -better-analyze         # Analyze why job is idle

# NFS (on central manager)
sudo exportfs -v                 # Show NFS exports
sudo systemctl status nfs-kernel-server

# Docker
docker images                    # List images
docker ps                        # List running containers
docker run -it nugrid/nudome:20.1a bash  # Interactive shell

# Singularity
singularity version              # Check version
ls /storage/containers/*.sif     # List images
singularity shell /storage/containers/nudome-20.1a.sif  # Interactive
```

---

**End of Deployment Guide**

For questions or issues, consult the troubleshooting section or open an issue on the NuDocker GitHub repository.
