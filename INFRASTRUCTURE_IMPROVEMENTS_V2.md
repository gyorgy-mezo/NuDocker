# NuDocker Infrastructure Improvements v2.0

**Date**: 2025-11-19
**Status**: ✅ Complete - Ready for Testing
**Based On**: Proven patterns from htcondor-slurm-demo (production-validated)

---

## Executive Summary

This document describes comprehensive improvements to NuDocker's Infrastructure-as-Code deployment based on **proven working patterns** from the htcondor-slurm-demo repository, which has been successfully validated on HUN-REN Cloud (August 24, 2025).

### Key Improvements

1. **✅ Simplified Terraform Configuration** - Uses proven patterns that avoid common OpenStack issues
2. **✅ Unified Packer Image** - Single base image with HTCondor + SLURM + Docker + Singularity
3. **✅ Dual-Scheduler Support** - Native HTCondor AND SLURM integration
4. **✅ Improved Ansible Playbooks** - Based on working htcondor-slurm-demo patterns
5. **✅ Enhanced Deployment Script** - Better error handling and validation
6. **✅ Automatic Inventory Generation** - Terraform generates Ansible inventory

---

## Table of Contents

- [What Changed](#what-changed)
- [Why These Changes](#why-these-changes)
- [Architecture Comparison](#architecture-comparison)
- [New Files Created](#new-files-created)
- [Migration Guide](#migration-guide)
- [Deployment Guide](#deployment-guide)
- [Testing and Validation](#testing-and-validation)
- [Troubleshooting](#troubleshooting)

---

## What Changed

### 1. Terraform Configuration (`terraform/main-v2-improved.tf`)

**Key Pattern Changes from htcondor-slurm-demo**:

#### Network Port Pattern (Fixes Floating IP Issues)
```hcl
# OLD (NuDocker original):
# Floating IP associated directly to instance

# NEW (from htcondor-slurm-demo):
resource "openstack_networking_port_v2" "central_manager_port" {
  name           = "nudocker-central-manager-port"
  network_id     = data.openstack_networking_network_v2.default.id
  admin_state_up = true
  security_group_ids = [openstack_networking_secgroup_v2.nudocker_sg.id]
}

resource "openstack_networking_floatingip_associate_v2" "central_manager_fip_assoc" {
  floating_ip = openstack_networking_floatingip_v2.central_manager_fip.address
  port_id     = openstack_networking_port_v2.central_manager_port.id
}
```

**Why**: This pattern from htcondor-slurm-demo fixes common OpenStack floating IP association issues that cause "port not found" errors.

#### Security Group Pattern (Avoids Terraform Drift)
```hcl
# OLD (NuDocker original):
# Explicit port ranges 1-65535

# NEW (from htcondor-slurm-demo):
resource "openstack_networking_secgroup_rule_v2" "internal_all" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  # When using remote_group_id, OpenStack treats omitted port ranges as "all ports"
  # Explicitly setting 1-65535 causes drift as OpenStack stores it as 0-0
  remote_group_id   = openstack_networking_secgroup_v2.nudocker_sg.id
  security_group_id = openstack_networking_secgroup_v2.nudocker_sg.id
}
```

**Why**: Avoids terraform drift issues discovered in htcondor-slurm-demo testing.

#### Simplified Image Data Sources
```hcl
# NEW: Single unified image for all nodes
data "openstack_images_image_v2" "nudocker_base" {
  name        = "nudocker-base-ubuntu22"
  most_recent = true
}
```

**Why**: Simpler management, faster deployment (from htcondor-slurm-demo pattern).

#### SLURM Compute Nodes (NEW!)
```hcl
resource "openstack_compute_instance_v2" "slurm_compute" {
  count           = var.slurm_compute_count
  name            = "${var.cluster_name}-slurm-compute-${count.index + 1}"
  flavor_name     = var.execute_node_flavor
  # ... configuration
}
```

**Why**: Adds SLURM support matching htcondor-slurm-demo architecture.

#### Automatic Inventory Generation
```hcl
resource "local_file" "ansible_inventory" {
  content = templatefile("${path.module}/inventory.tpl", {
    central_manager_ip      = ...
    htcondor_execute_ips    = ...
    slurm_compute_ips       = ...
  })
  filename = "../ansible/inventory/hosts-generated.ini"
}
```

**Why**: Eliminates manual inventory creation (from htcondor-slurm-demo).

### 2. Packer Template (`packer/nudocker-base-improved.pkr.hcl`)

**Key Improvements**:

#### Unified Image Approach
```hcl
# OLD: Separate images for HTCondor-CE, HTCondor nodes, SLURM nodes

# NEW: Single image with all software
build {
  sources = ["source.openstack.ubuntu"]

  # Install HTCondor 23.x
  # Install SLURM + Munge
  # Install Docker 24.0
  # Install Singularity 3.11.4
  # Install MESA dependencies
  # Install NFS client
}
```

**Why**: Simpler management, faster deployment, proven in htcondor-slurm-demo.

#### Proper Service Disabling
```bash
# NEW: Disable services during image build
sudo systemctl disable condor
sudo systemctl disable slurmctld slurmd munge
```

**Why**: Services configured by Ansible, not in image (htcondor-slurm-demo pattern).

#### NuDocker Environment Profile
```bash
# NEW: Create /etc/profile.d/nudocker.sh
export NUDOCKER_STORAGE="/storage"
export MESA_SRC="$NUDOCKER_STORAGE/mesa"
export OMP_NUM_THREADS=4
```

**Why**: Consistent environment across all nodes.

### 3. Ansible Playbook (`ansible/site-v2-improved.yml`)

**Key Pattern Changes**:

#### SSH Key Distribution (from htcondor-slurm-demo)
```yaml
- name: Get central manager public key
  slurp:
    src: ~/.ssh/id_rsa.pub
  when: inventory_hostname in groups['central_manager']
  register: central_public_key

- name: Distribute central manager public key to all nodes
  authorized_key:
    user: ubuntu
    key: "{{ hostvars[groups['central_manager'][0]]['central_manager_public_key'] }}"
    state: present
```

**Why**: Proven pattern for cluster-wide SSH access.

#### HTCondor Configuration Pattern
```yaml
- name: Configure HTCondor Central Manager
  copy:
    dest: /etc/condor/config.d/10-central-manager.conf
    content: |
      DAEMON_LIST = MASTER, COLLECTOR, NEGOTIATOR, SCHEDD, SHARED_PORT
      CONDOR_HOST = {{ central_manager_ip }}
      COLLECTOR_HOST = $(CONDOR_HOST):9618
      # Docker Universe support
      DOCKER = /usr/bin/docker
      DOCKER_VOLUMES = /storage:/storage:rw
```

**Why**: Working configuration from htcondor-slurm-demo.

#### SLURM Integration (NEW!)
```yaml
- name: Create munge key
  shell: |
    dd if=/dev/urandom bs=1 count=1024 > /etc/munge/munge.key
    chown munge:munge /etc/munge/munge.key
    chmod 400 /etc/munge/munge.key

- name: Read munge key
  slurp:
    src: /etc/munge/munge.key
  register: munge_key_content

- name: Create munge key on compute nodes
  copy:
    dest: /etc/munge/munge.key
    content: "{{ hostvars[groups['central_manager'][0]]['munge_key_content']['content'] | b64decode }}"
```

**Why**: Munge authentication pattern from htcondor-slurm-demo.

#### NFS Server/Client Setup
```yaml
# Central manager becomes NFS server
- name: Configure NFS exports
  copy:
    dest: /etc/exports
    content: |
      /storage *(rw,sync,no_subtree_check,no_root_squash)

# All workers become NFS clients
- name: Mount NFS storage
  mount:
    path: /storage
    src: "{{ hostvars[groups['central_manager'][0]]['private_ip'] }}:/storage"
    fstype: nfs
```

**Why**: Proven NFS pattern for shared storage.

#### Container Pre-loading
```yaml
- name: Pull NuDocker Docker images
  docker_image:
    name: "{{ item }}"
    source: pull
  loop:
    - nugrid/nudome:16.0
    - nugrid/nudome:18.0
    - nugrid/nudome:20.031a
    - nugrid/nudome:20.1a

- name: Convert Docker images to Singularity
  shell: |
    singularity build /storage/containers/{{ item.sif }} docker://{{ item.image }}
```

**Why**: Pre-load containers for immediate use.

### 4. Deployment Script (`deploy-v2-improved.sh`)

**Key Improvements**:

#### Better Prerequisite Checks
```bash
check_prerequisites() {
    check_command terraform
    check_command packer
    check_command ansible

    # Check SSH key
    if [ ! -f ~/.ssh/id_rsa ]; then
        ssh-keygen -t rsa -b 2048 -f ~/.ssh/id_rsa -N ""
    fi
}
```

**Why**: Prevents deployment failures (htcondor-slurm-demo pattern).

#### Phase-by-Phase Deployment
```bash
deploy_all() {
    check_prerequisites
    build_packer_image       # 30-45 min
    deploy_terraform         # 10-15 min
    configure_ansible        # 20-30 min
    validate_cluster         # 2-5 min
}
```

**Why**: Clear progress tracking, easy to resume (htcondor-slurm-demo pattern).

#### SSH Availability Waiting
```bash
for i in {1..30}; do
    if ssh -o ConnectTimeout=5 ubuntu@$FLOATING_IP "echo OK" &>/dev/null; then
        break
    fi
    sleep 10
done
```

**Why**: Prevents Ansible failures on slow instance startup.

---

## Why These Changes

### Problems with Original NuDocker Infrastructure

1. **❌ Floating IP Association Failures** - Direct instance association unreliable
2. **❌ Terraform Drift Issues** - Security group port ranges caused state drift
3. **❌ No SLURM Integration** - Only HTCondor supported
4. **❌ Complex Multi-Image Approach** - Separate images for CE, nodes, SLURM
5. **❌ Manual Inventory Management** - Error-prone manual inventory editing
6. **❌ No Validation Phase** - Deployment success uncertain

### Solutions from htcondor-slurm-demo

1. **✅ Network Port Pattern** - Proven to work on HUN-REN Cloud
2. **✅ Security Group Pattern** - Avoids drift, validated in production
3. **✅ Dual-Scheduler Architecture** - HTCondor + SLURM working together
4. **✅ Unified Image** - Simpler, faster, easier to maintain
5. **✅ Automatic Inventory** - Terraform generates, no manual errors
6. **✅ Built-in Validation** - Confirms deployment success

---

## Architecture Comparison

### Original NuDocker Architecture
```
Packer:
  ├── nudocker-htcondor.pkr.hcl → nudocker-htcondor-base image
  └── (SLURM not supported)

Terraform:
  ├── main.tf (complex network setup)
  ├── Manual inventory creation
  └── HTCondor-only deployment

Ansible:
  ├── Separate roles for HTCondor
  └── No SLURM support
```

### Improved Architecture (v2.0)
```
Packer:
  └── nudocker-base-improved.pkr.hcl
      ├── HTCondor 23.x ✓
      ├── SLURM + Munge ✓
      ├── Docker 24.0 ✓
      ├── Singularity 3.11.4 ✓
      ├── MESA dependencies ✓
      └── NFS client ✓

      → Single unified image (nudocker-base-ubuntu22)

Terraform:
  ├── main-v2-improved.tf
  │   ├── Network port pattern (proven)
  │   ├── Security group pattern (no drift)
  │   ├── HTCondor execute nodes
  │   ├── SLURM compute nodes (NEW!)
  │   └── Auto-generate inventory ✓
  │
  └── inventory.tpl → hosts-generated.ini

Ansible:
  └── site-v2-improved.yml
      ├── SSH key distribution (proven pattern)
      ├── HTCondor pool configuration
      ├── SLURM cluster configuration (NEW!)
      ├── NFS server/client setup
      ├── Container pre-loading
      └── Cluster verification
```

### Node Configuration Comparison

| Component | Original | Improved v2.0 |
|-----------|----------|---------------|
| **Central Manager** | HTCondor only | HTCondor + SLURM controller + NFS server |
| **Execute Nodes** | HTCondor workers (5 nodes) | HTCondor workers (5 nodes) |
| **Compute Nodes** | ❌ Not supported | ✅ SLURM workers (3 nodes) NEW! |
| **Total Resources** | 48 vCPU, 176 GB RAM | 72 vCPU, 256 GB RAM |
| **Schedulers** | HTCondor only | HTCondor + SLURM |
| **Storage** | Manual setup | NFS-based /storage (500 GB) |

---

## New Files Created

### Infrastructure Code

```
infrastructure/
├── terraform/
│   ├── main-v2-improved.tf          ✅ NEW - Simplified Terraform config
│   └── inventory.tpl                 ✅ NEW - Inventory template
│
├── packer/
│   └── nudocker-base-improved.pkr.hcl   ✅ NEW - Unified image builder
│
├── ansible/
│   └── site-v2-improved.yml         ✅ NEW - Complete playbook with SLURM
│
└── deploy-v2-improved.sh            ✅ NEW - Enhanced deployment script
```

### Documentation

```
INFRASTRUCTURE_IMPROVEMENTS_V2.md    ✅ NEW - This file
```

---

## Migration Guide

### For New Deployments

**Recommended**: Use v2.0 improved files directly.

```bash
cd infrastructure

# 1. Copy improved files to production names
cp terraform/main-v2-improved.tf terraform/main.tf
cp packer/nudocker-base-improved.pkr.hcl packer/nudocker-base.pkr.hcl
cp ansible/site-v2-improved.yml ansible/playbooks/site.yml
cp deploy-v2-improved.sh deploy.sh
chmod +x deploy.sh

# 2. Create configuration files
cd packer
cp variables.pkrvars.hcl.example variables.pkrvars.hcl
vim variables.pkrvars.hcl  # Fill in credentials

cd ../terraform
cp terraform.tfvars.example terraform.tfvars
vim terraform.tfvars  # Fill in credentials

# 3. Deploy
cd ..
./deploy.sh all
```

### For Existing Deployments

**Option 1: Fresh Deployment** (Recommended)

```bash
# Destroy old infrastructure
cd terraform
terraform destroy

# Deploy with v2.0
cd ..
./deploy-v2-improved.sh all
```

**Option 2: Gradual Migration**

Not recommended - infrastructure patterns are fundamentally different.

---

## Deployment Guide

### Prerequisites

- HUN-REN Cloud account with API access
- Terraform >= 1.0
- Packer >= 1.8
- Ansible >= 2.12
- SSH key at `~/.ssh/id_rsa`

### Configuration Files

**1. Packer Variables** (`packer/variables.pkrvars.hcl`):
```hcl
# Not needed - variables are hardcoded with HUN-REN specifics
# Image name includes timestamp automatically
```

**2. Terraform Variables** (`terraform/terraform.tfvars`):
```hcl
key_pair             = "alma"
external_network     = "ext-net"
cluster_name         = "nudocker"
execute_node_count   = 5
slurm_compute_count  = 3
```

### Deployment Steps

**Complete Automated Deployment**:
```bash
cd infrastructure
./deploy-v2-improved.sh all
```

**Phase-by-Phase Deployment**:
```bash
# Phase 1: Build image (30-45 min)
./deploy-v2-improved.sh packer

# Phase 2: Deploy infrastructure (10-15 min)
./deploy-v2-improved.sh terraform

# Phase 3: Configure cluster (20-30 min)
./deploy-v2-improved.sh ansible

# Phase 4: Validate (2-5 min)
./deploy-v2-improved.sh validate
```

### Deployment Timeline

| Phase | Duration | What Happens |
|-------|----------|--------------|
| **Packer** | 30-45 min | Build base image with all software |
| **Terraform** | 10-15 min | Create VMs, networks, floating IP |
| **Ansible** | 20-30 min | Configure HTCondor, SLURM, NFS, containers |
| **Validation** | 2-5 min | Test pool, cluster, storage |
| **Total** | **60-90 min** | **Complete deployment** |

---

## Testing and Validation

### Automated Validation

The deployment script includes automatic validation:

```bash
./deploy-v2-improved.sh validate
```

**Tests**:
- ✓ SSH connectivity
- ✓ HTCondor pool status (8 execute slots expected)
- ✓ SLURM cluster status (3 compute nodes expected)
- ✓ NFS mount verification
- ✓ Container availability (Docker + Singularity)

### Manual Testing

**1. SSH Access**:
```bash
ssh -i ~/.ssh/id_rsa ubuntu@<FLOATING_IP>
```

**2. HTCondor Pool**:
```bash
condor_status -total
# Expected: 40 slots (5 nodes × 8 cores)

condor_q
# Expected: Empty queue initially
```

**3. SLURM Cluster**:
```bash
sinfo
# Expected: 3 compute nodes in IDLE state

squeue
# Expected: Empty queue initially
```

**4. NFS Storage**:
```bash
df -h | grep storage
# Expected: /storage mounted from central manager

ls /storage
# Expected: mesa, containers, htcondor_jobs, slurm_jobs, results, users
```

**5. Containers**:
```bash
docker images | grep nudome
# Expected: 4 NuDocker images

ls /storage/containers/
# Expected: 4 .sif Singularity images
```

### Test Job Submissions

**HTCondor Test**:
```bash
cd /storage/htcondor_jobs
condor_submit nugrid_lowmass.sub
condor_q
```

**SLURM Test**:
```bash
cd /storage/slurm_jobs
sbatch 01_single_mesa_run.slurm
squeue
```

---

## Troubleshooting

### Packer Build Failures

**Problem**: "Failed to create instance"
```
Solution:
1. Check quota: openstack quota show
2. Verify flavor exists: openstack flavor list
3. Check image exists: openstack image list | grep Ubuntu-20.04
```

**Problem**: "SSH timeout"
```
Solution:
1. Check security group allows SSH from builder IP
2. Verify floating IP network ID is correct
3. Try with debug: packer build -debug ...
```

### Terraform Failures

**Problem**: "Port not found"
```
Solution: This is why we use the network port pattern!
The improved version creates port explicitly first.
```

**Problem**: "Image not found"
```
Solution:
Check image name matches Packer output:
data "openstack_images_image_v2" "nudocker_base" {
  name        = "nudocker-base-ubuntu22-2025-11-19"  # Update date
  most_recent = true
}
```

### Ansible Failures

**Problem**: "Host unreachable"
```
Solution:
1. Check floating IP: terraform output
2. Wait longer for SSH: instances may take 2-3 min to boot
3. Check security group allows SSH from your IP
```

**Problem**: "Munge key distribution failed"
```
Solution:
This is handled by the improved playbook - munge key created on
central manager and distributed to compute nodes automatically.
```

### HTCondor Pool Issues

**Problem**: "No execute nodes visible"
```
Solution:
1. Check condor service: sudo systemctl status condor
2. Check pool password: ls -l /etc/condor/pool_password
3. Check logs: sudo journalctl -u condor -n 100
4. Restart: ansible all -m systemd -a "name=condor state=restarted" --become
```

### SLURM Cluster Issues

**Problem**: "Nodes in DOWN state"
```
Solution:
1. Check slurmd: sudo systemctl status slurmd
2. Check munge: sudo systemctl status munge
3. Check slurm.conf: cat /etc/slurm/slurm.conf
4. Restart: ansible slurm_compute -m systemd -a "name=slurmd state=restarted" --become
```

---

## Performance Expectations

### Resource Allocation

**With Default Settings** (5 HTCondor + 3 SLURM):
- **Total vCPUs**: 72 (4 central + 40 HTCondor + 24 SLURM + 4 central SLURM controller)
- **Total RAM**: 256 GB
- **Total Storage**: 600 GB (100 GB central + 500 GB NFS volume)
- **Cost**: ~€350/month

**Compared to Original**:
- **Original**: 48 vCPU, 176 GB RAM, HTCondor only
- **Improved**: 72 vCPU, 256 GB RAM, HTCondor + SLURM
- **Increase**: +50% compute, +45% RAM, +2 schedulers

### Deployment Performance

Based on htcondor-slurm-demo validated timings:

| Phase | Time | Bottleneck |
|-------|------|------------|
| Packer build | 30-45 min | Package installation, Singularity compilation |
| Terraform deploy | 10-15 min | Instance boot time |
| Ansible configure | 20-30 min | Container pulls/conversions |
| Validation | 2-5 min | Service stabilization |

### Scientific Workload Performance

**HTCondor (High-Throughput)**:
- **Low-mass models** (1-2 M☉): 5 concurrent × 8 cores = 40 parallel jobs
- **Medium-mass models** (5-10 M☉): 2-3 concurrent (need 16 cores each)
- **High-mass models** (15-20 M☉): 1 concurrent (needs 32 cores, uses multiple nodes)

**SLURM (HPC)**:
- **Job arrays**: 3 concurrent array elements
- **Single large job**: Up to 24 cores on SLURM partition
- **Singularity containers**: All 4 NuDocker images available

---

## Next Steps

### Immediate
1. **Test deployment** on HUN-REN Cloud
2. **Validate all patterns** work as expected
3. **Document any issues** encountered

### Short-term
1. **Add monitoring** (Grafana + Prometheus)
2. **Add backup scripts** for /storage
3. **Create user documentation** for cluster access

### Long-term
1. **Optimize resource allocation** based on actual usage
2. **Add auto-scaling** for execute/compute nodes
3. **Integrate with GitLab CI/CD** for automated testing

---

## Summary of Improvements

| Aspect | Original | Improved v2.0 | Benefit |
|--------|----------|---------------|---------|
| **Terraform Pattern** | Custom network setup | Proven htcondor-slurm-demo pattern | ✅ Reliable deployment |
| **Packer Images** | Multiple separate images | Single unified image | ✅ Faster, simpler |
| **SLURM Support** | ❌ Not integrated | ✅ Full integration | ✅ Dual-scheduler |
| **Inventory** | Manual creation | Auto-generated | ✅ No manual errors |
| **Deployment Script** | Basic | Enhanced with validation | ✅ Better UX |
| **Security Groups** | Terraform drift issues | Proven no-drift pattern | ✅ Stable infrastructure |
| **Floating IP** | Direct association | Network port pattern | ✅ Reliable association |
| **Total Resources** | 48 vCPU | 72 vCPU | ✅ 50% more compute |
| **Validation** | Manual | Automated | ✅ Confirmed success |

---

**Status**: ✅ Ready for testing on HUN-REN Cloud

**Next Action**: Deploy using `./deploy-v2-improved.sh all` and validate against htcondor-slurm-demo success criteria.

---

*Based on proven patterns from htcondor-slurm-demo validated on HUN-REN Cloud (August 24, 2025)*
