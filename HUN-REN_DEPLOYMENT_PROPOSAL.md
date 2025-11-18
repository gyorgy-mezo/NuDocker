# NuDocker SLURM Cluster Proposal for HUN-REN Cloud

**Based on**: SZTAKI Science Cloud SLURM Reference Architecture v24.05.3
**Project Resources**: 72 vCPU, 192 GB RAM
**Use Case**: MESA Stellar Evolution Parameter Studies with NuDocker

---

## Table of Contents

- [Executive Summary](#executive-summary)
- [Architecture Overview](#architecture-overview)
- [Resource Allocation](#resource-allocation)
- [Node Configuration](#node-configuration)
- [Storage Configuration](#storage-configuration)
- [Network Setup](#network-setup)
- [Deployment Steps](#deployment-steps)
- [NuDocker Integration](#nudocker-integration)
- [Performance Estimates](#performance-estimates)
- [Cost Analysis](#cost-analysis)
- [Maintenance](#maintenance)

---

## Executive Summary

### Recommended Configuration

**Cluster Topology**: 1 Master + 5 Compute Nodes

| Component | vCPU | RAM | Purpose |
|-----------|------|-----|---------|
| Master Node | 8 | 16 GB | Scheduling, NFS, management |
| Compute Nodes (5×) | 12-16 | 32-36 GB | MESA calculations |
| **Total** | **68-88** | **176-196 GB** | Optimal for NuDocker |

### Key Benefits

✅ **Optimal for MESA**: Right-sized for OpenMP workloads (no GPU waste)
✅ **Maximum Throughput**: 5 simultaneous jobs (1 per node)
✅ **Flexible Scaling**: Can run 5-25+ jobs depending on size
✅ **Cost-Efficient**: Uses all allocated resources
✅ **NFS Storage**: Shared MESA installations and results

---

## Architecture Overview

### Master-Worker Topology

```
┌─────────────────────────────────────────────────────────┐
│                    HUN-REN Cloud                         │
│                   (OpenStack)                            │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  ┌──────────────────────┐                              │
│  │   Master Node        │                              │
│  │   (Controller)       │                              │
│  │   - 8 vCPU           │                              │
│  │   - 16 GB RAM        │                              │
│  │   - slurmctld        │                              │
│  │   - NFS server       │                              │
│  │   - Login node       │                              │
│  └──────────┬───────────┘                              │
│             │                                            │
│             │  Private Network                          │
│             │  10.0.0.0/24                              │
│             │                                            │
│     ┌───────┴──────────────────────────────┐           │
│     │                                       │           │
│     ▼                                       ▼           │
│  ┌──────────────┐                    ┌──────────────┐  │
│  │ Compute-01   │  ...  ...  ...     │ Compute-05   │  │
│  │ 16 vCPU      │                    │ 16 vCPU      │  │
│  │ 36 GB RAM    │                    │ 36 GB RAM    │  │
│  │ slurmd       │                    │ slurmd       │  │
│  │ NFS client   │                    │ NFS client   │  │
│  └──────────────┘                    └──────────────┘  │
│                                                          │
│  Shared Storage: /storage (NFS)                         │
│  - /storage/mesa (MESA installations)                   │
│  - /storage/results (Job results)                       │
│  - /storage/containers (Singularity images)             │
│  - /storage/users/<username> (User directories)         │
└─────────────────────────────────────────────────────────┘
```

### Design Principles

1. **Master Node**: Lightweight scheduler, doesn't run compute jobs
2. **Compute Nodes**: Homogeneous for easier scheduling
3. **NFS Storage**: Shared MESA installations, avoid duplication
4. **No GPU**: MESA uses OpenMP, GPU would be wasted
5. **Isolated**: Private network, SSH access only

---

## Resource Allocation

### Option 1: Balanced (Recommended)

**Best for**: Mixed workload (low/medium/high mass stars)

| Node Type | Flavor | Count | vCPU/node | RAM/node | Total vCPU | Total RAM |
|-----------|--------|-------|-----------|----------|------------|-----------|
| Master | m2.large | 1 | 4 | 8 GB | 4 | 8 GB |
| Compute | g2.xlarge | 5 | 8 | 32 GB | 40 | 160 GB |
| **Subtotal** | | **6** | | | **44** | **168 GB** |
| **Remaining** | | | | | **28** | **24 GB** |

**Alternative use of remaining**: Add 1-2 more m2.large compute nodes

**Throughput**:
- 5 simultaneous jobs × 8 CPUs = 40 concurrent CPUs
- Good for: 1-10 M☉ MESA models
- Jobs/day: 10-20 models

---

### Option 2: High-Throughput

**Best for**: Many small/medium models

| Node Type | Flavor | Count | vCPU/node | RAM/node | Total vCPU | Total RAM |
|-----------|--------|-------|-----------|----------|------------|-----------|
| Master | m2.large | 1 | 4 | 8 GB | 4 | 8 GB |
| Compute | m2.large | 8 | 4 | 8 GB | 32 | 64 GB |
| Compute | g2.large | 4 | 4 | 16 GB | 16 | 64 GB |
| **Total** | | **13** | | | **52** | **136 GB** |

**Throughput**:
- 12 simultaneous jobs × 4 CPUs = 48 concurrent CPUs
- Good for: 1-5 M☉ MESA models (many quick jobs)
- Jobs/day: 30-50 models

---

### Option 3: High-Memory

**Best for**: Large/complex models (15-25 M☉)

| Node Type | Flavor | Count | vCPU/node | RAM/node | Total vCPU | Total RAM |
|-----------|--------|-------|-----------|----------|------------|-----------|
| Master | m2.large | 1 | 4 | 8 GB | 4 | 8 GB |
| Compute | g2.2xlarge | 2 | 16 | 64 GB | 32 | 128 GB |
| Compute | g2.xlarge | 2 | 8 | 32 GB | 16 | 64 GB |
| **Total** | | **5** | | | **52** | **200 GB** |

**Throughput**:
- 4 simultaneous jobs × 8-16 CPUs = 32-64 concurrent CPUs
- Good for: 10-25 M☉ MESA models (large, complex)
- Jobs/day: 5-15 models

---

### Recommendation: Option 1 (Balanced)

**Why**:
- ✅ Best match for NuGrid parameter study (mixed masses)
- ✅ 8 CPUs per node = good OpenMP efficiency
- ✅ 32 GB per node = handles 10 M☉ models comfortably
- ✅ 5 nodes = good parallelism
- ✅ Uses ~66% of resources (leaves room for master + storage)

---

## Node Configuration

### Master Node Specifications

**Instance Type**: `m2.large` (or custom: 8 vCPU, 16 GB RAM)

**Services**:
- `slurmctld` - SLURM controller daemon
- `slurmdbd` - SLURM database daemon (optional)
- `nfs-server` - Network file system server
- `sshd` - SSH access for users

**Storage**:
- Root disk: 50 GB (OS + packages)
- Data disk: 500 GB - 1 TB (NFS export)

**Network**:
- Public IP: For SSH access
- Private IP: For cluster communication (10.0.0.1)

**Software**:
- Ubuntu 24.04 LTS
- SLURM 24.05.3
- NFS server
- Singularity 4.x

---

### Compute Node Specifications

**Instance Type**: `g2.xlarge` (8 vCPU, 32 GB RAM) × 5

**Services**:
- `slurmd` - SLURM compute daemon
- `nfs-client` - Mount shared storage
- `singularity` - Container runtime

**Storage**:
- Root disk: 50 GB (OS + packages)
- Local scratch: 100 GB (temporary job files)

**Network**:
- Private IP only: 10.0.0.11-15
- No public IP (security)

**Software**:
- Ubuntu 24.04 LTS
- SLURM 24.05.3
- Singularity 4.x
- NFS client

---

## Storage Configuration

### NFS Shared Storage Layout

**Mount Point**: `/storage`

**Directory Structure**:
```
/storage/
├── mesa/                           # MESA installations
│   ├── mesa-r9575/                 # Pre-compiled
│   ├── mesa-r10398/
│   ├── mesa-r12778/
│   └── mesa-r15140/
│
├── containers/                     # Singularity images
│   ├── nudome_16.0.sif            # 1.5 GB
│   ├── nudome_18.0.sif            # 1.8 GB
│   ├── nudome_20.031.sif          # 2.0 GB
│   └── nudome_20.1.sif            # 2.0 GB
│
├── shared_batch_examples/          # Example SLURM scripts
│   ├── 01_single_mesa_run.slurm
│   ├── 02_array_mesa_run.slurm
│   ├── 04_large_grid.slurm
│   └── compile_mesa.slurm
│
├── results/                        # Job outputs
│   ├── nugrid_study/
│   │   ├── lowmass/
│   │   ├── mediummass/
│   │   └── highmass/
│   └── test_runs/
│
└── users/                          # User home directories
    ├── user1/
    ├── user2/
    └── ...
```

**Storage Requirements**:

| Category | Size | Notes |
|----------|------|-------|
| MESA installations | 10-20 GB | 4 versions × 2-5 GB |
| Containers | 8 GB | 4 images × 2 GB |
| Results (54 models) | 150-300 GB | History + profiles |
| User directories | 50-100 GB | Per user |
| Examples/temp | 10 GB | Scripts, logs |
| **Total** | **230-440 GB** | **Recommend 500 GB - 1 TB** |

**NFS Configuration**:
```bash
# /etc/exports on master node
/storage 10.0.0.0/24(rw,sync,no_subtree_check,no_root_squash)
```

---

## Network Setup

### Network Architecture

**Public Network**: SSH access to master
- Master: Floating IP (e.g., 193.x.x.x)
- Ports: 22 (SSH)

**Private Network**: Cluster communication
- Subnet: 10.0.0.0/24
- Master: 10.0.0.1
- Compute-01: 10.0.0.11
- Compute-02: 10.0.0.12
- Compute-03: 10.0.0.13
- Compute-04: 10.0.0.14
- Compute-05: 10.0.0.15

**Security Groups**:

Master node:
- Ingress: 22/tcp from 0.0.0.0/0 (or restrict to your IP)
- Ingress: All from 10.0.0.0/24 (cluster traffic)
- Egress: All

Compute nodes:
- Ingress: All from 10.0.0.0/24 (cluster only)
- Egress: All

**DNS/Hostname Resolution**:
```
# /etc/hosts on all nodes
10.0.0.1  master master.cluster
10.0.0.11 compute-01 compute-01.cluster
10.0.0.12 compute-02 compute-02.cluster
10.0.0.13 compute-03 compute-03.cluster
10.0.0.14 compute-04 compute-04.cluster
10.0.0.15 compute-05 compute-05.cluster
```

---

## Deployment Steps

### Phase 1: Infrastructure Provisioning (Day 1)

**1.1 Create Network**
```bash
# On HUN-REN Cloud web interface
Networks → Create Network
  Name: nudocker-cluster-network
  Subnet: 10.0.0.0/24
  Gateway: 10.0.0.1
  DNS: 8.8.8.8, 8.8.4.4
```

**1.2 Create Security Groups**
```bash
Security Groups → Create
  Name: master-sg
  Rules:
    - Ingress: TCP 22 from 0.0.0.0/0
    - Ingress: All from 10.0.0.0/24
    - Egress: All

Security Groups → Create
  Name: compute-sg
  Rules:
    - Ingress: All from 10.0.0.0/24
    - Egress: All
```

**1.3 Create Master Node Instance**
```bash
Compute → Instances → Launch Instance
  Name: nudocker-master
  Image: Ubuntu 24.04 LTS
  Flavor: m2.large (4 vCPU, 8 GB RAM)
  Network: nudocker-cluster-network
  Security Group: master-sg
  Key Pair: <your-ssh-key>

Volumes → Create Volume
  Name: nudocker-storage
  Size: 500 GB
  Attach to: nudocker-master at /dev/vdb
```

**1.4 Create Compute Node Instances**
```bash
# Repeat 5 times for compute-01 through compute-05
Compute → Instances → Launch Instance
  Name: nudocker-compute-01
  Image: Ubuntu 24.04 LTS
  Flavor: g2.xlarge (8 vCPU, 32 GB RAM)
  Network: nudocker-cluster-network
  Security Group: compute-sg
  Key Pair: <your-ssh-key>
```

**1.5 Assign Floating IP to Master**
```bash
Floating IPs → Allocate IP
  Associate with: nudocker-master
```

---

### Phase 2: SLURM Installation (Day 1-2)

**2.1 Prepare Master Node**

SSH to master:
```bash
ssh ubuntu@<floating-ip>
```

Install SLURM and NFS:
```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install SLURM controller
sudo apt install -y slurm-wlm slurmdbd munge

# Install NFS server
sudo apt install -y nfs-kernel-server

# Install Singularity
sudo apt install -y singularity-container

# Install other tools
sudo apt install -y vim git htop
```

Configure storage:
```bash
# Format and mount storage volume
sudo mkfs.ext4 /dev/vdb
sudo mkdir /storage
echo '/dev/vdb /storage ext4 defaults 0 0' | sudo tee -a /etc/fstab
sudo mount /storage

# Create directory structure
sudo mkdir -p /storage/{mesa,containers,results,users,shared_batch_examples}
sudo chmod 755 /storage
```

Configure NFS exports:
```bash
echo '/storage 10.0.0.0/24(rw,sync,no_subtree_check,no_root_squash)' | sudo tee /etc/exports
sudo exportfs -ra
sudo systemctl enable nfs-server
sudo systemctl start nfs-server
```

**2.2 Prepare Compute Nodes**

For each compute node:
```bash
ssh ubuntu@10.0.0.11  # Repeat for .12-.15

# Update system
sudo apt update && sudo apt upgrade -y

# Install SLURM compute daemon
sudo apt install -y slurmd munge

# Install Singularity
sudo apt install -y singularity-container

# Install NFS client
sudo apt install -y nfs-common

# Mount NFS storage
sudo mkdir /storage
echo 'master:/storage /storage nfs defaults 0 0' | sudo tee -a /etc/fstab
sudo mount /storage
```

**2.3 Configure SLURM**

On master, create `/etc/slurm/slurm.conf`:
```bash
# SLURM Configuration for NuDocker Cluster
ClusterName=nudocker
SlurmctldHost=master(10.0.0.1)

# Scheduling
SchedulerType=sched/backfill
SelectType=select/cons_tres
SelectTypeParameters=CR_Core_Memory

# Logging
SlurmctldLogFile=/var/log/slurm/slurmctld.log
SlurmdLogFile=/var/log/slurm/slurmd.log

# Process tracking
ProctrackType=proctrack/cgroup
TaskPlugin=task/cgroup

# MPI support
MpiDefault=none

# Accounting
AccountingStorageType=accounting_storage/none
JobAcctGatherType=jobacct_gather/linux

# Node definitions
NodeName=compute-[01-05] CPUs=8 RealMemory=30000 State=UNKNOWN

# Partition definitions
PartitionName=main Nodes=compute-[01-05] Default=YES MaxTime=INFINITE State=UP
```

Copy configuration to all nodes:
```bash
for node in compute-{01..05}; do
  scp /etc/slurm/slurm.conf ubuntu@${node}:/tmp/
  ssh ubuntu@${node} "sudo mv /tmp/slurm.conf /etc/slurm/"
done
```

**2.4 Start SLURM Services**

Master node:
```bash
sudo systemctl enable slurmctld
sudo systemctl start slurmctld
```

Compute nodes (on each):
```bash
sudo systemctl enable slurmd
sudo systemctl start slurmd
```

**2.5 Verify Cluster**
```bash
sinfo
# Should show 5 compute nodes in "idle" state

scontrol show nodes
# Should show all nodes with CPUs=8, RealMemory=30000
```

---

### Phase 3: NuDocker Setup (Day 2-3)

**3.1 Download Singularity Containers**

On master:
```bash
cd /storage/containers

# Pull NuDocker images
singularity pull nudome_16.0.sif docker://nugrid/nudome:16.0
singularity pull nudome_18.0.sif docker://nugrid/nudome:18.0
singularity pull nudome_20.031.sif docker://nugrid/nudome:20.031
singularity pull nudome_20.1.sif docker://nugrid/nudome:20.1

# Verify
ls -lh *.sif
```

**3.2 Download and Pre-compile MESA**

```bash
cd /storage/mesa

# Download MESA r9575 (example)
wget https://zenodo.org/records/2630796/files/mesa-r9575.zip
unzip mesa-r9575.zip

# Pre-compile MESA (saves time later)
singularity exec /storage/containers/nudome_16.0.sif bash -c "
  cd /storage/mesa/mesa-r9575
  export MESASDK_ROOT=/home/user/mesasdk
  export MESA_DIR=/storage/mesa/mesa-r9575
  source \$MESASDK_ROOT/bin/mesasdk_init.sh
  export OMP_NUM_THREADS=8
  ./install
"
```

Repeat for other MESA versions as needed.

**3.3 Copy SLURM Scripts**

```bash
cd /storage/shared_batch_examples

# Copy from NuDocker repository
git clone https://github.com/NuGrid/NuDocker.git /tmp/nudocker
cp /tmp/nudocker/slurm_scripts/*.slurm .
cp /tmp/nudocker/slurm_scripts/*.py .
cp /tmp/nudocker/slurm_scripts/README.md .

# Set permissions
chmod 755 *.slurm *.py
```

---

### Phase 4: Testing (Day 3)

**4.1 Submit Test Job**

Create test script `test_mesa.slurm`:
```bash
#!/bin/bash
#SBATCH --job-name=test-mesa
#SBATCH --partition=main
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=16G
#SBATCH --time=00:30:00
#SBATCH --output=test_mesa_%j.out

echo "Job started on $(hostname) at $(date)"
echo "SLURM_JOB_ID: $SLURM_JOB_ID"
echo "SLURM_CPUS_PER_TASK: $SLURM_CPUS_PER_TASK"

# Test Singularity
singularity exec /storage/containers/nudome_16.0.sif bash -c "
  echo 'Inside container'
  echo 'MESA_DIR: \$MESA_DIR'
  ls -lh /storage/mesa/
"

echo "Job completed at $(date)"
```

Submit:
```bash
sbatch test_mesa.slurm
```

Monitor:
```bash
squeue
tail -f test_mesa_*.out
```

**4.2 Test Full Workflow**

Edit and submit a real MESA job:
```bash
cp /storage/shared_batch_examples/01_single_mesa_run.slurm test_run.slurm

# Edit paths
vim test_run.slurm
# Set:
# CONTAINER=/storage/containers/nudome_16.0.sif
# MESA_SRC=/storage/mesa/mesa-r9575
# WORK_DIR=/storage/results/test_run

sbatch test_run.slurm
```

---

## NuDocker Integration

### SLURM Script Templates

The existing NuDocker SLURM scripts work perfectly with this setup. Just adjust paths:

**For single jobs** (`01_single_mesa_run.slurm`):
```bash
#!/bin/bash
#SBATCH --partition=main
#SBATCH --nodes=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=28G

CONTAINER=/storage/containers/nudome_16.0.sif
MESA_SRC=/storage/mesa/mesa-r9575
WORK_DIR=/storage/results/job_${SLURM_JOB_ID}

singularity exec \
    --bind ${MESA_SRC}:/home/user/mesa \
    --bind ${WORK_DIR}:/home/user/work \
    ${CONTAINER} \
    bash -c "
        source /home/user/mesasdk/bin/mesasdk_init.sh
        export OMP_NUM_THREADS=${SLURM_CPUS_PER_TASK}
        cd /home/user/mesa/star/test_suite/7M_prems_to_AGB
        ./mk && ./rn
    "
```

**For job arrays** (`02_array_mesa_run.slurm`):
```bash
#!/bin/bash
#SBATCH --partition=main
#SBATCH --array=1-18
#SBATCH --nodes=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=28G

# Read parameters from grid file
PARAMS=$(sed -n "${SLURM_ARRAY_TASK_ID}p" /storage/parameter_grid.txt)

# Run model with parameters
singularity exec \
    --bind /storage/mesa/mesa-r9575:/home/user/mesa \
    --bind /storage/results/array_${SLURM_ARRAY_JOB_ID}_${SLURM_ARRAY_TASK_ID}:/home/user/work \
    /storage/containers/nudome_16.0.sif \
    bash -c "
        # Apply parameters and run
        ...
    "
```

### Workflow Examples

**Example 1: 54-Model NuGrid Study**

Using balanced configuration (5 nodes × 8 CPUs):
```bash
# Generate parameter grid
cd /storage
python3 shared_batch_examples/generate_parameter_grid.py > parameter_grid_54.txt

# Submit job array (max 5 running at once)
sbatch --array=1-54%5 shared_batch_examples/04_large_grid.slurm
```

**Timeline**:
- 54 models, 5 nodes
- Each model: 6-24 hours
- Batches of 5 models in parallel
- Total time: 3-7 days (depending on model complexity)

**Example 2: Testing Configuration**

Quick test with 3 models:
```bash
sbatch --array=1-3 shared_batch_examples/02_array_mesa_run.slurm
```

**Example 3: Pre-compilation**

Compile MESA before large runs:
```bash
sbatch shared_batch_examples/compile_mesa.slurm
# Wait ~30 minutes
# Then submit full study
```

---

## Performance Estimates

### Expected Throughput

**Configuration**: 5 compute nodes × 8 CPUs each

| Model Type | CPUs/job | Jobs/node | Total concurrent | Time/model | Models/day |
|------------|----------|-----------|------------------|------------|------------|
| 1-2 M☉ | 8 | 1 | 5 | 2-6 hr | 20-60 |
| 5-10 M☉ | 8 | 1 | 5 | 6-24 hr | 5-20 |
| 15-20 M☉ | 8 | 1 | 5 | 24-72 hr | 2-5 |

### 54-Model NuGrid Study Timeline

**Breakdown**:
- Low-mass (18 models): 3-4 days
- Medium-mass (18 models): 5-7 days
- High-mass (18 models): 7-10 days
- **Total**: 15-21 days

**With optimization**:
- Pre-compile MESA: -1 day
- Run low/medium/high in sequence: 12-18 days
- **Total**: 11-17 days (~2-3 weeks)

### Comparison vs. Single Workstation

**Single workstation** (16 CPUs):
- Sequential: 54 models × 12 hr avg = 648 hours = 27 days
- **SLURM cluster (5 nodes)**: 12-18 days
- **Speedup**: ~1.5-2× faster

---

## Cost Analysis

### Resource Utilization

**Total Resources**:
- Allocated: 72 vCPU, 192 GB RAM
- Used: 44-52 vCPU, 168-200 GB RAM
- Efficiency: 65-70%

**Cost Breakdown** (estimated):

| Component | vCPU | RAM | Storage | Monthly Cost* |
|-----------|------|-----|---------|---------------|
| Master | 4 | 8 GB | 500 GB | ~€50-80 |
| Compute (5×) | 40 | 160 GB | - | ~€200-300 |
| Network/IP | - | - | - | ~€10-20 |
| **Total** | **44** | **168 GB** | **500 GB** | **~€260-400/mo** |

*Costs are estimates - check HUN-REN Cloud pricing

**Cost per Model**:
- 54 models over 2-3 weeks
- Monthly cost: €300
- Cost per model: ~€5-10

### Alternative: Spot/Preemptible Instances

If HUN-REN supports spot instances:
- Reduce compute node costs by 50-70%
- Suitable for MESA (jobs checkpoint automatically)
- Potential savings: €100-150/month

---

## Maintenance

### Monitoring

**SLURM Commands**:
```bash
# Cluster status
sinfo
sinfo -Nel

# Job queue
squeue
squeue -u $USER

# Node details
scontrol show nodes

# Accounting
sacct -u $USER
sacct --format=JobID,JobName,State,CPUTime,MaxRSS
```

**System Monitoring**:
```bash
# On master
htop
df -h /storage
systemctl status slurmctld

# On compute nodes
ssh compute-01
htop
systemctl status slurmd
```

### Backup Strategy

**Critical Data**:
- MESA installations: `/storage/mesa` (backup once)
- Results: `/storage/results` (backup regularly)
- SLURM config: `/etc/slurm/` (version control)
- User data: `/storage/users` (backup regularly)

**Backup Methods**:
1. OpenStack snapshots (volumes)
2. rsync to external storage
3. Cloud object storage (S3-compatible)

**Recommended**:
```bash
# Weekly backup of results
rsync -av /storage/results user@backup-server:/backups/nudocker/

# Monthly snapshot of storage volume
openstack volume snapshot create --volume nudocker-storage snapshot-$(date +%Y%m%d)
```

### Scaling Options

**Scale Up** (more resources per node):
- Replace g2.xlarge (8 vCPU) with g2.2xlarge (16 vCPU)
- Better for high-mass models

**Scale Out** (more nodes):
- Add more compute nodes
- Better for throughput (more concurrent jobs)

**Elasticity** (dynamic):
- Keep 2 nodes always-on
- Add 3 nodes on-demand for large studies
- Reduces idle costs

---

## Deployment Checklist

### Pre-Deployment

- [ ] Verify HUN-REN Cloud quota (72 vCPU, 192 GB RAM)
- [ ] Prepare SSH key pair
- [ ] Plan network addresses
- [ ] Review security requirements

### Infrastructure

- [ ] Create private network (10.0.0.0/24)
- [ ] Create security groups (master-sg, compute-sg)
- [ ] Launch master instance (m2.large)
- [ ] Launch 5 compute instances (g2.xlarge)
- [ ] Create and attach storage volume (500 GB)
- [ ] Assign floating IP to master

### Software Installation

- [ ] Install SLURM on master (slurmctld)
- [ ] Install SLURM on compute nodes (slurmd)
- [ ] Install NFS server on master
- [ ] Install NFS client on compute nodes
- [ ] Install Singularity on all nodes
- [ ] Configure munge for authentication

### SLURM Configuration

- [ ] Create slurm.conf
- [ ] Distribute to all nodes
- [ ] Start slurmctld on master
- [ ] Start slurmd on compute nodes
- [ ] Verify cluster with `sinfo`

### NuDocker Setup

- [ ] Mount storage volume on master
- [ ] Configure NFS exports
- [ ] Mount NFS on compute nodes
- [ ] Pull Singularity containers (4 images)
- [ ] Download MESA versions
- [ ] Pre-compile MESA
- [ ] Copy SLURM script templates

### Testing

- [ ] Submit test job
- [ ] Verify Singularity works
- [ ] Run single MESA model
- [ ] Test job array (3 models)
- [ ] Check NFS file access
- [ ] Verify resource allocation

### Production

- [ ] Generate parameter grid (54 models)
- [ ] Submit full study
- [ ] Monitor progress
- [ ] Collect results
- [ ] Backup data

---

## Troubleshooting

### Common Issues

**1. Nodes show as "down"**
```bash
# Check slurmd on compute node
ssh compute-01
sudo systemctl status slurmd
sudo journalctl -u slurmd

# Restart if needed
sudo systemctl restart slurmd

# On master, update node state
scontrol update NodeName=compute-01 State=IDLE
```

**2. NFS mount fails**
```bash
# Check exports on master
showmount -e master

# Check mount on compute node
mount | grep storage
sudo mount -a
```

**3. Job fails with "singularity: command not found"**
```bash
# Install on compute node
ssh compute-01
sudo apt install singularity-container
```

**4. Out of memory**
```bash
# Check actual usage
ssh compute-01
free -h

# Adjust job request
#SBATCH --mem=24G  # Reduce from 28G
```

---

## Summary

### Recommended Configuration

**Cluster**: 1 master + 5 compute nodes (g2.xlarge)
- Total: 44 vCPU, 168 GB RAM
- Storage: 500 GB NFS
- Cost: ~€300/month
- Throughput: 5-20 models/day

### Why This Configuration

✅ **Optimal for MESA**: 8 CPUs × 32 GB per node matches OpenMP workloads
✅ **Good Parallelism**: 5 nodes = 5 concurrent jobs
✅ **Balanced**: Handles mixed model sizes (1-20 M☉)
✅ **Cost-Effective**: Uses 65% of allocated resources efficiently
✅ **Scalable**: Easy to add nodes or change flavors

### Expected Performance

**54-Model NuGrid Study**:
- Timeline: 12-18 days
- Throughput: 3-5 models/day
- Cost: ~€150-200 total

### Next Steps

1. **Week 1**: Deploy infrastructure, install SLURM
2. **Week 2**: Setup NuDocker, pre-compile MESA
3. **Week 3**: Test with 3-5 models
4. **Week 4**: Launch full 54-model study

---

## References

- HUN-REN Cloud: https://science-cloud.hu
- SLURM Documentation: https://docs.slurm.science-cloud.hu
- SZTAKI Reference Architecture: https://git.sztaki.hu/science-cloud/reference-architectures/slurm
- NuDocker SLURM Scripts: /slurm_scripts in this repository

---

**Document Version**: 1.0
**Date**: 2025-11-18
**Author**: NuDocker Enhancement Project
**Target**: HUN-REN Cloud SLURM Deployment
**Resources**: 72 vCPU, 192 GB RAM
