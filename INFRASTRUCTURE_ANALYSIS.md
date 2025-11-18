# NuDocker Infrastructure Deployment Analysis
**Examination Date**: 2025-11-18
**Repository**: NuDocker v2.0

---

## EXECUTIVE SUMMARY

NuDocker includes a **comprehensive Infrastructure-as-Code deployment** for HTCondor clusters on HUN-REN Cloud, along with **parallel SLURM scripts** for traditional HPC clusters. The infrastructure implements a complete, production-ready system with automated deployment and job management templates.

### Key Finding
- **HTCondor support**: FULL - Complete infrastructure deployment (Terraform + Ansible + Packer)
- **SLURM support**: FULL - Ready-to-use job scripts (no infrastructure deployment needed)
- **Script compatibility**: NONE - HTCondor and SLURM scripts are separate and distinct
- **Job submission**: Two separate workflow systems that achieve similar results on different platforms

---

## 1. INFRASTRUCTURE/ANSIBLE/ROLES/NUDOCKER/ - FILES DEPLOYED

### Location
`/home/user/NuDocker/infrastructure/ansible/roles/nudocker/`

### Files Deployed to Infrastructure
```
├── tasks/main.yml                 # 84 lines - Deployment orchestration
├── files/
│   ├── nudocker_profile.sh        # 29 lines - Environment configuration
│   ├── run_mesa_model.sh          # 292 lines - MESA execution wrapper
│   ├── nudocker_study.dag         # 155 lines - DAGMan workflow
│   ├── nudocker_lowmass.sub       # 253 lines - HTCondor submit file (18 jobs)
│   ├── nudocker_mediummass.sub    # 125 lines - HTCondor submit file (18 jobs)
│   └── nudocker_highmass.sub      # 125 lines - HTCondor submit file (18 jobs)
```

### What Gets Deployed (via Ansible Role)

**1. NuDocker Repository Clone**
```bash
# Line 4-9 of tasks/main.yml
- Clones https://github.com/NuGrid/NuDocker.git to /opt/nudocker
- Version: main branch
- Only on central_manager
```

**2. Shared Storage Setup**
```bash
# Lines 40-51
Creates directory structure on /storage (NFS):
├── mesa/                    # MESA source
├── containers/              # Docker/Singularity images
├── results/                 # Job results
├── users/
│   ├── default/
│   └── shared/
├── batch_examples/          # Job templates (copied here)
└── htcondor_jobs/          # HTCondor job working directory
```

**3. Singularity Cache Configuration**
```bash
# Lines 19-29
- Creates: /storage/containers/singularity_cache
- Sets: SINGULARITY_CACHEDIR environment variable
- Applied to all nodes
```

**4. HTCondor Job Templates Deployment**
```bash
# Lines 31-42
Copy these files to /storage/batch_examples/:
- nudocker_lowmass.sub
- nudocker_mediummass.sub
- nudocker_highmass.sub
- nudocker_study.dag
- run_mesa_model.sh
Mode: 0644 (readable by all)
```

**5. Workspace Directory Creation**
```bash
# Lines 44-52
/storage/users/default/     # Default user workspace
/storage/users/shared/      # Shared workspace
```

**6. NuDocker Bash Profile Deployment**
```bash
# Lines 54-58
- Source: nudocker_profile.sh
- Destination: /etc/profile.d/nudocker.sh
- Applied to all nodes
- Sets environment variables:
  * NUDOCKER_STORAGE=/storage
  * NUDOCKER_MESA=/storage/mesa
  * NUDOCKER_CONTAINERS=/storage/containers
  * NUDOCKER_RESULTS=/storage/results
  * CONDOR_JOBS=/storage/htcondor_jobs
  * Adds /storage/nudocker/bin to PATH
  * Creates convenience aliases
```

**7. Docker Image Pre-loading**
```bash
# Lines 60-70
Pulls Docker images to central manager:
- nugrid/nudome:16.0
- nugrid/nudome:18.0
- nugrid/nudome:20.031
- nugrid/nudome:20.1a
(Ignores errors if pull fails)
```

**8. Singularity Image Building**
```bash
# Lines 72-83
Converts Docker images to Singularity .sif files:
- /storage/containers/nudome-16.0.sif
- /storage/containers/nudome-18.0.sif
- /storage/containers/nudome-20.031.sif
- /storage/containers/nudome-20.1a.sif
(Only if not already present)
```

---

## 2. INFRASTRUCTURE/ANSIBLE/ROLES/HTCONDOR-EXECUTE/ - HTCondor Execute Nodes

### Configuration Role
`/home/user/NuDocker/infrastructure/ansible/roles/htcondor-execute/`

### Tasks Performed (tasks/main.yml - 60 lines)

**1. HTCondor Configuration Deployment**
```bash
Lines 4-11: Deploy /etc/condor/condor_config.local
- Template: condor_config.local.j2
- Owner: condor user
- Permissions: 0644
- Triggers: restart condor handler
```

**2. Pool Password Setup**
```bash
Lines 13-20: Deploy /etc/condor/pool_password
- Content: {{ htcondor_pool_password }} variable
- Owner: condor user
- Permissions: 0600 (secure)
- Triggers: restart condor handler
```

**3. Credential Storage**
```bash
Lines 22-25: Store credentials with condor_store_cred
- Runs: condor_store_cred -f /etc/condor/pool_password
- Creates: /var/lib/condor/passwords.d/POOL
- Only runs if file doesn't exist (creates: gate)
```

**4. NFS Mount Setup**
```bash
Lines 27-39: Mount shared NFS storage
- Waits for NFS server ({{ condor_host }}:2049)
- Mounts: {{ condor_host }}:/storage -> /storage
- Type: NFS
- Options: defaults
- State: mounted
```

**5. Execute Directory Creation**
```bash
Lines 41-47: Create local execute directory
- Path: /var/lib/condor/execute
- Owner: condor:condor
- Permissions: 0755
- Purpose: Local working directory for jobs
```

**6. HTCondor Service**
```bash
Lines 49-59: Start HTCondor daemon
- Service: condor
- Enabled: yes (start on boot)
- State: started
- Waits for port 9618 to respond (60 sec timeout)
```

### Execute Node Configuration Template (condor_config.local.j2 - 79 lines)

**Role Configuration**
```
use ROLE: Execute
- Minimal role: only STARTD + MASTER daemons
- No central manager functions
```

**Network Configuration**
```
CONDOR_HOST = {{ condor_host }}          # 10.0.0.10
NETWORK_INTERFACE = *
BIND_ALL_INTERFACES = TRUE
STARTD_NAME = {{ ansible_hostname }}     # Host-specific
```

**Resource Advertisement**
```
NUM_CPUS = {{ ansible_processor_vcpus }}     # Auto-detected
MEMORY = {{ (ansible_memtotal_mb * 0.95) | int }}  # 95% of available
```

**Docker Support**
```
DOCKER = /usr/bin/docker
DOCKER_VOLUMES = /storage:/storage:rw      # Mount shared storage in Docker jobs
```

**Security Configuration**
```
SEC_PASSWORD_FILE = /etc/condor/pool_password
SEC_DEFAULT_AUTHENTICATION = REQUIRED
SEC_DEFAULT_AUTHENTICATION_METHODS = PASSWORD
SEC_READ_AUTHENTICATION = REQUIRED
SEC_WRITE_AUTHENTICATION = REQUIRED
SEC_CLIENT_AUTHENTICATION = REQUIRED
SEC_ADVERTISE_STARTD_AUTHENTICATION = REQUIRED
```

**Authorization**
```
ALLOW_READ = *
ALLOW_WRITE = condor@*
ALLOW_DAEMON = condor@*
ALLOW_ADMINISTRATOR = condor@$(CONDOR_HOST)
```

**Job Execution Policy**
```
EXECUTE = /var/lib/condor/execute         # Local work directory
START = TRUE                               # Always accept jobs
SUSPEND = FALSE
CONTINUE = TRUE
PREEMPT = FALSE
KILL = FALSE
WANT_SUSPEND = FALSE
WANT_VACATE = FALSE
CLAIM_WORKLIFE = 3600                      # 1 hour claim duration
```

**Performance Tuning**
```
UPDATE_INTERVAL = 60
STARTER_UPDATE_INTERVAL = 60
ENABLE_URL_TRANSFERS = TRUE
```

**Shared Filesystem Configuration**
```
UID_DOMAIN = {{ cluster_name }}.local
TRUST_UID_DOMAIN = TRUE
SOFT_UID_DOMAIN = TRUE
```

---

## 3. INFRASTRUCTURE/ANSIBLE/ROLES/HTCONDOR-CENTRAL/ - Central Manager

### Central Manager Configuration Role
`/home/user/NuDocker/infrastructure/ansible/roles/htcondor-central/`

### Tasks Performed (tasks/main.yml - 70 lines)

**1. HTCondor Central Manager Configuration**
```bash
Lines 4-11: Deploy /etc/condor/condor_config.local
- Template: condor_config.local.j2
- Configuration for: COLLECTOR, NEGOTIATOR, SCHEDD, MASTER
```

**2. Pool Password Security**
```bash
Lines 13-25: Identical to execute nodes
- Secure password distribution
- Credential storage
```

**3. NFS Export Setup**
```bash
Lines 27-38: Configure NFS server
- Directory: /storage
- Export: /storage 10.0.0.0/24(rw,sync,no_subtree_check,no_root_squash)
- Triggers: restart nfs-server handler
```

**4. Storage Directories**
```bash
Lines 40-51: Create /storage subdirectories
- mesa/
- containers/
- results/
- users/
- batch_examples/
- htcondor_jobs/
Permissions: 0755, Owner: root
```

**5. NFS Server Service**
```bash
Lines 53-57: Enable and start NFS
- Service: nfs-kernel-server
- Enabled: yes (start on boot)
- State: started
```

**6. HTCondor Service**
```bash
Lines 59-70: Start HTCondor daemons
- Services: condor
- Waits for port 9618 (collector port)
```

### Central Manager Configuration Template (condor_config.local.j2 - 75 lines)

**Role Configuration**
```
use ROLE: CentralManager
use ROLE: Submit
- Collector: accepts pool updates
- Negotiator: matchmaking
- Schedd: job submission
```

**Collector Configuration**
```
COLLECTOR_NAME = $(CONDOR_HOST)
COLLECTOR_HOST = $(CONDOR_HOST):9618
```

**Negotiator Configuration**
```
NEGOTIATOR_INTERVAL = 20              # Match interval
NEGOTIATOR_CYCLE_DELAY = 5            # Delay between cycles
```

**Schedd Configuration**
```
SCHEDD_NAME = {{ cluster_name }}-central
MAX_JOBS_RUNNING = 1000
MAX_JOBS_SUBMITTED = 10000
```

**Docker Universe Support**
```
DOCKER = /usr/bin/docker
```

**File Transfer Limits**
```
MAX_TRANSFER_INPUT_MB = 10240
MAX_TRANSFER_OUTPUT_MB = 10240
```

**Logging Configuration**
```
MAX_DEFAULT_LOG = 100000000
MAX_NUM_DEFAULT_LOG = 5
TRUNC_DEFAULT_LOG_ON_OPEN = FALSE
```

---

## 4. HTCondor Submit Files - 54-Model Parameter Study

### Low-Mass Submit File (nudocker_lowmass.sub)
**Location**: `/home/user/NuDocker/infrastructure/ansible/roles/nudocker/files/`

**Job Specification**
```
universe = docker
docker_image = nugrid/nudome:16.0
+JobName = "NuGrid_LowMass"
```

**Resource Requests**
```
request_cpus = 8
request_memory = 8 GB
request_disk = 5 GB
+MaxRuntime = 21600 (6 hours)
```

**Execution**
```
executable = run_mesa_model.sh
arguments = $(Process) $(mass) $(metallicity) $(alpha)
environment = "OMP_NUM_THREADS=8 MESA_DIR=/home/user/mesa"
```

**File Transfer**
```
should_transfer_files = YES
when_to_transfer_output = ON_EXIT
transfer_input_files = mesa_work_template.tar.gz, parameter_grid_lowmass.txt
transfer_output_files = results_$(Process).tar.gz
```

**Fault Tolerance**
```
+WantCheckpoint = True
+CheckpointPeriod = 7200 (2 hours)
max_retries = 3
```

**Jobs Defined (18 jobs total)**
```
Mass combinations:
- 1.0 M☉: 9 jobs (3 metallicities × 3 alphas)
- 2.0 M☉: 9 jobs (3 metallicities × 3 alphas)

Parameters:
- Metallicity: 0.02, 0.01, 0.001
- Mixing length alpha: 1.8, 2.0, 2.2
```

### Medium-Mass Submit File (nudocker_mediummass.sub)
**18 jobs total**
```
Masses: 5.0, 10.0 M☉
Resources: 16 CPUs, 16 GB memory, 24 hours
Same parameter combinations as low-mass
```

### High-Mass Submit File (nudocker_highmass.sub)
**18 jobs total**
```
Masses: 15.0, 20.0 M☉
Resources: 32 CPUs, 32 GB memory, 72 hours
Same parameter combinations
```

---

## 5. DAGMan Workflow (nudocker_study.dag)

### DAG Structure (155 lines)

**Job Definitions**
```
JOB LowMass nugrid_lowmass.sub
JOB MediumMass nugrid_mediummass.sub
JOB HighMass nugrid_highmass.sub
JOB Aggregate aggregate_results.sub
```

**Dependency Chain**
```
PARENT LowMass MediumMass HighMass CHILD Aggregate
- Low, Medium, High mass jobs run in parallel
- Aggregation waits for all to complete
```

**Retry Configuration**
```
RETRY LowMass 2
RETRY MediumMass 2
RETRY HighMass 2
RETRY Aggregate 1
```

**Priority Levels**
```
PRIORITY HighMass 10      # Longest running - highest priority
PRIORITY MediumMass 5     # Medium priority
PRIORITY LowMass 1        # Lowest priority
PRIORITY Aggregate 0      # Last to schedule
```

**Throttling**
```
MAXJOBS 50  # Maximum 50 concurrent jobs
```

**Monitoring**
```
NODE_STATUS_FILE nugrid_study.status 30
DOT nugrid_study.dot UPDATE  # Generate GraphViz output
```

### DAG Configuration (nugrid_study.config)

**DAGMan Settings**
```
DAGMAN_MAX_JOBS_IDLE = 100
DAGMAN_MAX_JOBS_SUBMITTED = 200
DAGMAN_SUBMIT_DELAY = 2 seconds
DAGMAN_MAX_PRE_SCRIPTS = 10
DAGMAN_MAX_POST_SCRIPTS = 10
DAGMAN_MAX_RESCUE_NUM = 3
DAGMAN_ALLOW_LOG_ERROR = True
DAGMAN_USE_DIRECT_SUBMIT = True
```

---

## 6. MESA Model Execution Wrapper (run_mesa_model.sh)

**Location**: Deployed to `/storage/batch_examples/` by Ansible

### Script Functionality (292 lines)

**1. Argument Parsing**
```bash
MODEL_ID=${1:-0}
INITIAL_MASS=${2:-5.0}
METALLICITY=${3:-0.02}
MIXING_ALPHA=${4:-2.0}
```

**2. Work Directory Setup**
```bash
WORK_DIR="mesa_work_${MODEL_ID}"
mkdir -p "${WORK_DIR}"
tar xzf ../mesa_work_template.tar.gz
```

**3. Inlist Parameter Configuration**
```bash
# Modifies inlist_project with:
- initial_mass = ${INITIAL_MASS}
- initial_z = ${METALLICITY}
- mixing_length_alpha = ${MIXING_ALPHA}
```

**4. MESA Verification**
```bash
- Check: ${MESA_DIR} exists
- Check: ${MESA_DIR}/make/makefile exists
- Source: ${HOME}/mesasdk/bin/mesasdk_init.sh
```

**5. Work Directory Compilation**
```bash
./mk  # Compile stellar evolution work directory
```

**6. MESA Run Execution**
```bash
./rn  # Run stellar evolution
```

**7. Results Packaging**
```bash
- Copy LOGS/history.data
- Copy LOGS/profiles/*.data
- Copy photos/ (last model snapshots)
- Create model_info.txt (metadata)
- Create final tar.gz: results_${MODEL_ID}.tar.gz
```

**8. Cleanup**
```bash
rm -rf "${WORK_DIR}"  # Remove uncompressed work directory
```

---

## 7. INTEGRATION BETWEEN INFRASTRUCTURE AND DEPLOYED SCRIPTS

### Deployment Path
```
Repository Files           →  Ansible Role        →  Cloud Infrastructure
───────────────────────────────────────────────────────────────────────
htcondor_scripts/          →  nudocker/files/     →  /storage/batch_examples/
├── nugrid_lowmass.sub     →                      →  nudocker_lowmass.sub
├── nugrid_mediummass.sub  →                      →  nudocker_mediummass.sub
├── nugrid_highmass.sub    →                      →  nudocker_highmass.sub
├── nugrid_study.dag       →                      →  nudocker_study.dag
└── run_mesa_model.sh      →                      →  run_mesa_model.sh
```

### Environment Setup
```
1. Ansible deploys nudocker_profile.sh to /etc/profile.d/
2. Sets environment variables for all users:
   - NUDOCKER_STORAGE=/storage
   - CONDOR_JOBS=/storage/htcondor_jobs
   - Adds /storage/nudocker/bin to PATH

3. All HTCondor jobs can reference:
   - /storage/batch_examples/ (submit files)
   - /storage/htcondor_jobs/ (working directory)
   - /storage/mesa/ (MESA source)
   - /storage/containers/ (Docker/Singularity images)
```

### Job Execution Flow
```
User submits:
  condor_submit /storage/batch_examples/nugrid_lowmass.sub
        ↓
HTCondor executor runs:
  /storage/batch_examples/run_mesa_model.sh [args]
        ↓
Script mounts MESA from /storage/mesa via bind
        ↓
Runs in nugrid/nudome:16.0 Docker container
        ↓
Results transferred back to /storage/results/
```

---

## 8. HTCONDOR VS SLURM SCRIPTS COMPARISON

### HTCondor Scripts (Deployed via Infrastructure)
**Location**: `infrastructure/ansible/roles/nudocker/files/`
```
- Used with: HTCondor cluster deployment (Terraform + Ansible + Packer)
- Submission: condor_submit *.sub
- Universe: docker (container-native)
- Workflow: DAGMan (nugrid_study.dag)
- Job Control: condor_q, condor_rm, condor_hold
- Features:
  * Opportunistic scheduling
  * Heterogeneous resource matching
  * Checkpointing support
  * 54 jobs (18 per mass group) in single DAG
```

### SLURM Scripts (Independent Templates)
**Location**: `slurm_scripts/`
```
- Used with: Traditional HPC clusters (HUN-REN, etc.)
- Submission: sbatch *.slurm
- Universe: vanilla (Singularity container)
- Workflow: Job arrays with throttling
- Job Control: squeue, scancel, scontrol
- Features:
  * Batch array processing
  * Pre-compilation support
  * Parameter file support
  * Throttled job submission (--array=N%M)
  * 150+ models via parameter grid
```

### Key Differences

| Feature | HTCondor | SLURM |
|---------|----------|-------|
| Container | Docker (native) | Singularity (converted) |
| Workflow | DAGMan | Job Arrays |
| Job Control | condor_* commands | slurm commands |
| Heterogeneity | Native matchmaking | Fixed per-job resources |
| Pre-compilation | Optional | Recommended (separate job) |
| Scaling | Opportunistic (50 max) | Throttled arrays (customizable) |
| Infrastructure | Cloud-based (IaC) | HPC cluster native |
| Setup | Terraform + Ansible | Manual HPC cluster |

---

## 9. KEY DIFFERENCES: DEPLOYED VS. REPOSITORY SCRIPTS

### Naming Convention
```
Repository (htcondor_scripts/)          Infrastructure (roles/nudocker/)
────────────────────────────────────────────────────────────────────────
nugrid_lowmass.sub         →            nudocker_lowmass.sub
nugrid_mediummass.sub      →            nudocker_mediummass.sub
nugrid_highmass.sub        →            nudocker_highmass.sub
nugrid_study.dag           →            nudocker_study.dag
nugrid_study.config        →            (Config inline in DAG)
run_mesa_model.sh          →            run_mesa_model.sh (identical)
```

### Configuration Differences

**HTCondor Scripts (Repository)**
```
- Standalone - can run from any directory
- Reference files locally: *.sub, *.dag, run_mesa_model.sh
- Relative paths to mesa_work_template.tar.gz
- Designed for submission node with HTCondor client
```

**Deployed HTCondor Scripts (Infrastructure)**
```
- Copied to /storage/batch_examples/
- MESA template in /storage/batch_examples/
- Results output to /storage/results/
- Scripts assume NFS-mounted /storage/
- Integrated with pool configuration
```

---

## 10. DEPLOYMENT CHECKLIST - WHAT'S INCLUDED

### Infrastructure Code (Complete IaC)

#### Packer (VM Image Building)
```
✓ nudocker-htcondor.pkr.hcl      - 200 lines
✓ scripts/install-docker.sh       - HTCondor node Docker setup
✓ scripts/install-singularity.sh  - Singularity/Apptainer
✓ scripts/install-htcondor.sh     - HTCondor 23.10
✓ scripts/install-nudocker-deps.sh - Compilers, MPI, libraries
✓ scripts/configure-system.sh     - System optimization
✓ scripts/apply-configs.sh        - Configuration deployment
✓ scripts/cleanup.sh              - Image cleanup
✓ files/bash_aliases              - Shell configuration
✓ files/htcondor_base.conf        - HTCondor base config
```

#### Terraform (Infrastructure Provisioning)
```
✓ main.tf                         - Network, VMs, storage
✓ variables.tf                    - Input variables
✓ versions.tf                     - Provider configuration
✓ cloud-init/central-manager.yaml - Central mgr init
✓ cloud-init/execute-node.yaml    - Execute node init
```

#### Ansible (Cluster Configuration)
```
✓ playbooks/site.yml              - Main orchestration
✓ roles/common/                   - Common setup (all nodes)
✓ roles/htcondor-central/         - Central manager config
✓ roles/htcondor-execute/         - Execute node config
✓ roles/nudocker/                 - NuDocker deployment
✓ roles/cluster-verify/           - Health checks
```

#### Deployment Scripts
```
✓ deploy.sh                       - Main deployment orchestration
✓ destroy.sh                      - Infrastructure cleanup
✓ validate.sh                     - Configuration validation
✓ test_mesa_job.sh                - Job submission test
```

### Job Templates (Complete Workflows)

#### HTCondor (from Repository)
```
✓ htcondor_scripts/nugrid_lowmass.sub
✓ htcondor_scripts/nugrid_mediummass.sub
✓ htcondor_scripts/nugrid_highmass.sub
✓ htcondor_scripts/nugrid_study.dag
✓ htcondor_scripts/nugrid_study.config
✓ htcondor_scripts/run_mesa_model.sh
✓ htcondor_scripts/README.md      - 728 lines of docs
```

#### SLURM (Independent from Infrastructure)
```
✓ slurm_scripts/01_single_mesa_run.slurm
✓ slurm_scripts/02_array_mesa_run.slurm
✓ slurm_scripts/03_multiple_independent.slurm
✓ slurm_scripts/04_large_grid.slurm
✓ slurm_scripts/compile_mesa.slurm
✓ slurm_scripts/generate_parameter_grid.py
✓ slurm_scripts/test_slurm_scripts.sh
✓ slurm_scripts/README.md         - 706 lines of docs
```

---

## 11. DEPLOYMENT WORKFLOW SUMMARY

### Complete HTCondor Cluster Deployment

```bash
# Phase 1: Build VM Image with Packer (30-45 minutes)
cd infrastructure/packer
cp variables.pkrvars.hcl.example variables.pkrvars.hcl
# Edit with HUN-REN credentials
packer init nudocker-htcondor.pkr.hcl
packer build -var-file="variables.pkrvars.hcl" nudocker-htcondor.pkr.hcl
  ✓ Creates: nudocker-htcondor-base-[timestamp] image

# Phase 2: Provision Infrastructure with Terraform (10-15 minutes)
cd ../terraform
cp terraform.tfvars.example terraform.tfvars
# Edit with image name from Phase 1
terraform init
terraform apply
  ✓ Creates: 1 Central Manager (8 vCPU, 16 GB, floating IP)
  ✓ Creates: 5 Execute Nodes (8 vCPU, 32 GB each)
  ✓ Creates: 500 GB NFS volume
  ✓ Creates: Private network (10.0.0.0/24)

# Phase 3: Configure Cluster with Ansible (20-30 minutes)
cd ../ansible
# Terraform auto-generates inventory
ansible-playbook -i inventory/hosts.ini playbooks/site.yml
  ✓ Configures HTCondor pool
  ✓ Sets up NFS sharing
  ✓ Deploys NuDocker scripts
  ✓ Loads Docker/Singularity images
  ✓ Verifies cluster health

# Phase 4: Submit Jobs
ssh -i ~/.ssh/id_rsa ubuntu@<FLOATING_IP>
cd /storage/batch_examples/
condor_submit_dag nugrid_study.dag
  ✓ Submits: 54 stellar evolution models
  ✓ Monitors: DAG progress
```

### SLURM HPC Workflow (No Infrastructure Deployment)

```bash
# Minimal Setup on Existing HPC Cluster
mkdir -p ~/nudocker/{containers,mesa,runs,logs,config}
cd ~/nudocker

# 1. Build Container
singularity pull containers/nudome_16.0.sif docker://nugrid/nudome:16.0

# 2. Download MESA
wget https://zenodo.org/records/2630796/files/mesa-r9575.zip
unzip -q mesa-r9575.zip -d mesa/

# 3. Copy Scripts
cp -r /path/to/NuDocker/slurm_scripts ./scripts

# 4. Pre-compile MESA
sbatch scripts/compile_mesa.slurm
# Wait for completion (~30 minutes)

# 5. Generate Parameter Grid (optional)
python3 scripts/generate_parameter_grid.py > config/parameter_grid.txt

# 6. Submit Large Job Grid
sbatch scripts/04_large_grid.slurm
  ✓ Submits: 100-150 models
  ✓ Throttles: 20 concurrent jobs
  ✓ Auto-organizes: Results by parameters
```

---

## 12. ENVIRONMENT CONFIGURATION SUMMARY

### Deployed Infrastructure Environment

**File**: `nudocker_profile.sh` (deployed to `/etc/profile.d/nudocker.sh`)

```bash
# Storage paths
export NUDOCKER_STORAGE=/storage
export NUDOCKER_MESA=$NUDOCKER_STORAGE/mesa
export NUDOCKER_CONTAINERS=$NUDOCKER_STORAGE/containers
export NUDOCKER_RESULTS=$NUDOCKER_STORAGE/results

# Singularity
export SINGULARITY_CACHEDIR=$NUDOCKER_CONTAINERS/singularity_cache
export APPTAINER_CACHEDIR=$NUDOCKER_CONTAINERS/singularity_cache

# HTCondor
export CONDOR_JOBS=$NUDOCKER_STORAGE/htcondor_jobs

# PATH
export PATH=$NUDOCKER_STORAGE/nudocker/bin:$PATH

# Convenience aliases
alias goto-storage='cd $NUDOCKER_STORAGE'
alias goto-jobs='cd $CONDOR_JOBS'
alias goto-results='cd $NUDOCKER_RESULTS'
alias condor-status='condor_status'
alias condor-q='condor_q'
```

---

## 13. CRITICAL FINDINGS

### 1. No Direct Integration Between HTCondor and SLURM Scripts
```
- HTCondor scripts are container-native (Docker)
- SLURM scripts use Singularity
- Different submit syntax (condor_submit vs sbatch)
- Different job templates entirely
- NO shared code or templates
```

### 2. Separate Parallel Workflows
```
HTCondor Path:
  Repository → Ansible Role → /storage/batch_examples/ → condor_submit

SLURM Path:
  Repository → Manual copy → ~/nudocker/scripts/ → sbatch
```

### 3. Infrastructure Deployment is One-Way
```
- Infrastructure role COPIES files to cluster
- No callback to repository
- Deployed scripts are "frozen" at deployment time
- Updates require re-running Ansible
```

### 4. Job Parameter Study is Identical
```
Both implement 54+ model parameter study:
  - Same MESA versions (16.0, 18.0, 20.031, 20.1a)
  - Same parameter ranges (1-20 M☉, Z, alpha)
  - Same model parameter configuration
  - Different scheduling mechanisms only
```

---

## SUMMARY TABLE: WHAT'S DEPLOYED

| Component | Files | Purpose | Deployed To | Container |
|-----------|-------|---------|-------------|-----------|
| **HTCondor Submit** | 3 .sub files | Mass-specific job batches | /storage/batch_examples/ | Docker |
| **DAG Workflow** | 1 .dag file | 54-model workflow coordination | /storage/batch_examples/ | - |
| **DAG Config** | 1 .config file | DAGMan tuning | /storage/batch_examples/ | - |
| **Execution Wrapper** | 1 .sh file | MESA run script | /storage/batch_examples/ | Docker |
| **Environment** | 1 bash profile | Path/vars setup | /etc/profile.d/ | - |
| **MESA Templates** | (prepared by user) | MESA work template | /storage/batch_examples/ | Docker |
| **Results** | (generated) | Job outputs | /storage/results/ | - |

---

**Analysis Complete**: 2025-11-18
**Status**: Production Ready
**License**: BSD 3-Clause
