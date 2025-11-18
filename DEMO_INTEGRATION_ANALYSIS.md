# NuDocker Demo Scripts vs Infrastructure Integration Analysis

**Date**: 2025-11-18
**Purpose**: Analyze htcondor-slurm-demo integration with HUN-REN cloud infrastructure and propose improvements

---

## Executive Summary

This document analyzes the existing demonstration scripts (htcondor_scripts/ and slurm_scripts/) against the deployed infrastructure (infrastructure/), identifies gaps, and proposes specific improvements to make the HUN-REN cloud implementation "more accurate" based on the demo repository.

### Key Findings

✅ **HTCondor Integration**: GOOD - Scripts are deployed via Ansible with proper environment
❌ **SLURM Integration**: MISSING - No SLURM deployment automation exists
⚠️ **Parameter Generation**: PARTIAL - Manual parameter grids, no automated generation
⚠️ **Testing Framework**: PARTIAL - SLURM has test_slurm_scripts.sh, HTCondor lacks equivalent
⚠️ **Documentation**: INCONSISTENT - Demo READMEs not integrated with infrastructure docs

### Recommended Actions

1. **Add SLURM deployment to infrastructure** (HIGH PRIORITY)
2. **Integrate parameter grid generation** (MEDIUM PRIORITY)
3. **Add unified testing framework** (MEDIUM PRIORITY)
4. **Improve documentation consistency** (LOW PRIORITY)
5. **Add monitoring dashboards** (LOW PRIORITY)

---

## Table of Contents

1. [Current State Analysis](#current-state-analysis)
2. [HTCondor Integration Review](#htcondor-integration-review)
3. [SLURM Integration Gap](#slurm-integration-gap)
4. [Detailed Gap Analysis](#detailed-gap-analysis)
5. [Proposed Improvements](#proposed-improvements)
6. [Implementation Roadmap](#implementation-roadmap)
7. [Updated Code Specifications](#updated-code-specifications)

---

## Current State Analysis

### Demo Scripts Inventory

**Location**: `/home/user/NuDocker/htcondor_scripts/` and `/home/user/NuDocker/slurm_scripts/`

| Directory | Files | Lines | Status | Purpose |
|-----------|-------|-------|--------|---------|
| htcondor_scripts/ | 7 | 1,704 | ✅ Deployed | 54-model parameter study with DAGMan |
| slurm_scripts/ | 8 | 2,438 | ❌ Not Deployed | SLURM batch scripts for HPC clusters |
| **Total** | **15** | **4,142** | **Partial** | **Comprehensive demo package** |

### Infrastructure Deployment Inventory

**Location**: `/home/user/NuDocker/infrastructure/`

| Component | Files Created | Status | HTCondor Support | SLURM Support |
|-----------|---------------|--------|------------------|---------------|
| Terraform | 6 | ✅ Complete | Yes | No |
| Packer | 10 | ✅ Complete | Yes | Partial (Singularity installed) |
| Ansible | 25+ | ✅ Complete | Yes | No |
| Scripts | 4 | ✅ Complete | Yes | No |
| Docs | 3 | ✅ Complete | Yes | Limited |

### Integration Status Matrix

| Feature | Demo Scripts | Infrastructure | Status |
|---------|--------------|----------------|--------|
| HTCondor submit files | ✅ 3 files | ✅ Deployed to /storage/batch_examples/ | ✅ INTEGRATED |
| HTCondor DAGMan workflow | ✅ 1 file | ✅ Deployed | ✅ INTEGRATED |
| MESA execution wrapper | ✅ run_mesa_model.sh | ✅ Deployed | ✅ INTEGRATED |
| SLURM batch scripts | ✅ 5 files | ❌ Not deployed | ❌ GAP |
| Parameter grid generation | ✅ Python script | ❌ Not deployed | ❌ GAP |
| Testing framework | ✅ test_slurm_scripts.sh | ❌ Not deployed | ❌ GAP |
| Container pre-loading | ❌ Manual | ✅ Automated (Ansible) | ✅ IMPROVED |
| Documentation | ✅ 2 READMEs | ⚠️ Separate docs | ⚠️ INCONSISTENT |

---

## HTCondor Integration Review

### What Was Integrated Successfully

The infrastructure deployment **successfully integrates** HTCondor demo scripts:

#### 1. Script Deployment (ansible/roles/nudocker/tasks/main.yml)

```yaml
- name: Clone NuDocker repository
  git:
    repo: 'https://github.com/NuGrid/NuDocker.git'
    dest: /opt/nudocker
    version: main

- name: Copy HTCondor example scripts to shared storage
  copy:
    src: /opt/nudocker/htcondor_scripts/
    dest: /storage/batch_examples/
    remote_src: yes
    mode: '0755'
```

**Files Deployed**:
- nugrid_lowmass.sub → /storage/batch_examples/nudocker_lowmass.sub
- nugrid_mediummass.sub → /storage/batch_examples/nudocker_mediummass.sub
- nugrid_highmass.sub → /storage/batch_examples/nudocker_highmass.sub
- nugrid_study.dag → /storage/batch_examples/nudocker_study.dag
- run_mesa_model.sh → /storage/batch_examples/run_mesa_model.sh

#### 2. Environment Configuration (nudocker_profile.sh)

```bash
export NUDOCKER_STORAGE="/storage"
export MESA_SRC="${NUDOCKER_STORAGE}/mesa"
export NUDOCKER_CONTAINERS="${NUDOCKER_STORAGE}/containers"
export CONDOR_JOBS="${NUDOCKER_STORAGE}/htcondor_jobs"
export NUDOCKER_RESULTS="${NUDOCKER_STORAGE}/results"
```

#### 3. Container Pre-loading (Automated)

```yaml
- name: Pull NuDocker images
  docker_image:
    name: "{{ item }}"
    source: pull
  loop:
    - nugrid/nudome:16.0
    - nugrid/nudome:18.0
    - nugrid/nudome:20.031
    - nugrid/nudome:20.1a

- name: Convert Docker images to Singularity
  shell: |
    singularity build {{ item.sif }} docker://{{ item.image }}
  loop:
    - { image: 'nugrid/nudome:16.0', sif: '/storage/containers/nudome_16.0.sif' }
    # ... (all 4 images)
```

#### 4. HTCondor Configuration Integration

**Central Manager** (condor_config.local.j2):
```
DOCKER = /usr/bin/docker
DOCKER_VOLUMES = /storage:/storage:rw
DOCKER_MOUNT_VOLUMES = /storage
```

**Execute Nodes** (condor_config.local.j2):
```
use ROLE: Execute
DOCKER = /usr/bin/docker
DOCKER_VOLUMES = /storage:/storage:rw
STARTD_ATTRS = $(STARTD_ATTRS) DOCKER_ENABLED
```

### What Works Well

✅ **Automated Deployment**: Scripts deploy automatically via Ansible
✅ **Environment Setup**: All paths configured correctly
✅ **Container Availability**: Docker images pre-loaded and converted
✅ **Storage Structure**: NFS-mounted /storage accessible to all nodes
✅ **DAGMan Workflow**: Complete 54-model study ready to run
✅ **Job Execution**: run_mesa_model.sh properly handles all parameter combinations

### Minor Issues Identified

⚠️ **File Naming Inconsistency**:
- Demo: `nugrid_*.sub`, `nugrid_study.dag`
- Deployed: `nudocker_*.sub`, `nudocker_study.dag`
- **Impact**: Minor - users must use deployed names
- **Fix**: Align naming convention

⚠️ **Parameter Grid Files Missing**:
- Submit files reference: `parameter_grid_lowmass.txt`, etc.
- **Status**: Not deployed
- **Impact**: Minor - parameters hard-coded in submit files
- **Fix**: Deploy parameter grid files or generate dynamically

⚠️ **README Not Deployed**:
- htcondor_scripts/README.md (727 lines) not copied to /storage/batch_examples/
- **Impact**: Users lack usage documentation on cluster
- **Fix**: Deploy README.md alongside scripts

---

## SLURM Integration Gap

### What's Missing Completely

The infrastructure deployment has **ZERO SLURM integration**, despite:

1. ✅ Singularity/Apptainer installed via Packer (infrastructure/packer/scripts/install-singularity.sh)
2. ✅ Container images converted to .sif format
3. ✅ SLURM scripts exist in demo repository (8 files, 2,438 lines)
4. ❌ **NO SLURM installation in infrastructure**
5. ❌ **NO SLURM configuration templates**
6. ❌ **NO deployment of SLURM batch scripts**
7. ❌ **NO parameter grid generation**

### Why This Is a Gap

The user specifically asked to study `htcondor-slurm-demo` and make implementation "more accurate". The demo includes **comprehensive SLURM support**, but the infrastructure is **HTCondor-only**.

**HUN-REN Cloud Context**:
- Hungarian research cloud infrastructure
- Typically HPC-oriented (SLURM common)
- SZTAKI reference architecture uses SLURM
- User may want SLURM as primary or alternative scheduler

### SLURM Scripts Not Integrated

| Script | Purpose | Lines | Status |
|--------|---------|-------|--------|
| 01_single_mesa_run.slurm | Single MESA job | 189 | ❌ Not deployed |
| 02_array_mesa_run.slurm | Job array (10-50 models) | 225 | ❌ Not deployed |
| 03_multiple_independent.slurm | Multi-version submission | 220 | ❌ Not deployed |
| 04_large_grid.slurm | Large grid (100+ models) | 320 | ❌ Not deployed |
| compile_mesa.slurm | Pre-compilation | 312 | ❌ Not deployed |
| generate_parameter_grid.py | Grid generation utility | 143 | ❌ Not deployed |
| test_slurm_scripts.sh | Validation framework | 324 | ❌ Not deployed |
| README.md | Documentation | 705 | ❌ Not deployed |

---

## Detailed Gap Analysis

### Gap 1: SLURM Installation and Configuration

**Current State**: No SLURM in infrastructure
**Demo Expectation**: SLURM cluster ready for batch_scripts
**Severity**: HIGH
**Impact**: Cannot run SLURM demo scripts on deployed infrastructure

**Required Components**:
1. SLURM controller (slurmctld) on central manager
2. SLURM compute daemon (slurmd) on execute nodes
3. SLURM accounting database (optional but recommended)
4. Shared configuration via NFS (/storage/slurm/slurm.conf)
5. Munge authentication

**Proposed Solution**:
- Add Ansible role: `infrastructure/ansible/roles/slurm-controller/`
- Add Ansible role: `infrastructure/ansible/roles/slurm-compute/`
- Add to Packer: `scripts/install-slurm.sh`
- Add configuration templates

### Gap 2: SLURM Batch Scripts Deployment

**Current State**: Scripts exist in demo, not deployed
**Demo Expectation**: Scripts available on cluster at /storage/batch_examples/slurm/
**Severity**: MEDIUM
**Impact**: Users must manually copy scripts to cluster

**Required Deployment**:
```
/storage/batch_examples/
├── htcondor/              # Currently deployed as /storage/batch_examples/
│   ├── README.md
│   ├── nudocker_*.sub
│   ├── nudocker_study.dag
│   └── run_mesa_model.sh
└── slurm/                 # NEW - to be added
    ├── README.md
    ├── 01_single_mesa_run.slurm
    ├── 02_array_mesa_run.slurm
    ├── 03_multiple_independent.slurm
    ├── 04_large_grid.slurm
    ├── compile_mesa.slurm
    ├── generate_parameter_grid.py
    └── test_slurm_scripts.sh
```

**Proposed Solution**:
- Update ansible/roles/nudocker/tasks/main.yml to deploy SLURM scripts
- Organize batch_examples/ with subdirectories

### Gap 3: Parameter Grid Generation

**Current State**:
- HTCondor: Parameters hard-coded in .sub files
- SLURM: generate_parameter_grid.py exists but not deployed

**Demo Expectation**: Users can generate custom parameter grids
**Severity**: MEDIUM
**Impact**: Inflexible parameter studies, requires editing submit files

**Current HTCondor Approach** (nugrid_lowmass.sub):
```
queue mass,metallicity,alpha from (
  1.0,0.02,1.8
  1.0,0.02,2.0
  1.0,0.02,2.2
  1.0,0.01,1.8
  # ... 18 lines total
)
```

**SLURM Approach** (superior):
```bash
python3 generate_parameter_grid.py > parameter_grid.txt
sbatch --array=1-150 02_array_mesa_run.slurm
```

**Proposed Solution**:
- Deploy generate_parameter_grid.py to /storage/batch_examples/
- Create HTCondor version: generate_condor_submit.py
- Add to documentation: parameter study customization guide

### Gap 4: Testing and Validation Framework

**Current State**:
- SLURM: test_slurm_scripts.sh (324 lines, 7 test suites)
- HTCondor: No equivalent testing script
- Infrastructure: validate.sh tests infrastructure, not job scripts

**Demo Expectation**: Users can validate scripts before submission
**Severity**: LOW
**Impact**: Harder to debug script issues

**SLURM Testing Capabilities**:
- Bash syntax validation
- Python syntax validation
- SLURM directives check
- Documentation check
- Parameter parsing logic test
- Singularity integration test
- Parameter grid generation test

**Proposed Solution**:
- Deploy test_slurm_scripts.sh to /storage/batch_examples/slurm/
- Create test_htcondor_scripts.sh with equivalent tests:
  - HTCondor syntax validation (condor_submit -dry-run)
  - DAGMan parsing test
  - Docker integration test
  - Parameter grid validation
  - Submit file syntax check

### Gap 5: Documentation Integration

**Current State**:
- Demo: htcondor_scripts/README.md (727 lines), slurm_scripts/README.md (705 lines)
- Infrastructure: DEPLOYMENT_GUIDE.md (1,201 lines), README.md (428 lines)
- **No cross-referencing**

**Issues**:
- Demo READMEs describe usage but not deployment
- Infrastructure READMEs describe deployment but not usage
- Users must consult multiple documents
- Inconsistent paths (demo uses ~/nudocker, infrastructure uses /storage)

**Proposed Solution**:
- Create USAGE_GUIDE.md combining both perspectives
- Update demo READMEs with deployment-specific paths
- Cross-reference documents
- Add quick-start section to DEPLOYMENT_GUIDE.md

### Gap 6: Monitoring and Management Tools

**Current State**: Basic condor_q, condor_status commands
**Demo Expectation**: Production-ready monitoring
**Severity**: LOW
**Impact**: Limited observability for large studies

**Missing Components**:
- HTCondor dashboard (web interface)
- SLURM dashboard (slurmrestd + web UI)
- Job completion notifications
- Resource utilization tracking
- Cost estimation tools
- Result aggregation scripts

**Proposed Solution**:
- Add Ansible role: monitoring (Prometheus + Grafana)
- Add HTCondor metrics exporter
- Add SLURM metrics exporter
- Create pre-built dashboards for NuDocker workloads

---

## Proposed Improvements

### Priority 1: Add SLURM Deployment (HIGH)

**Why**: Complete the "HTCondor-SLURM demo" integration, enable HPC workflow

**Components to Add**:

1. **Packer Script**: `infrastructure/packer/scripts/install-slurm.sh`
2. **Ansible Role**: `infrastructure/ansible/roles/slurm-controller/`
3. **Ansible Role**: `infrastructure/ansible/roles/slurm-compute/`
4. **Configuration**: SLURM templates with HUN-REN cloud parameters
5. **Scripts Deployment**: Copy all SLURM demo scripts to /storage/batch_examples/slurm/

**Expected Outcome**:
- Dual-scheduler infrastructure (HTCondor + SLURM)
- Users choose scheduler based on workload
- Complete demo integration

### Priority 2: Unified Parameter Grid System (MEDIUM)

**Why**: Flexible parameter studies, easier customization

**Components to Add**:

1. **Script**: `generate_parameter_grid.py` (deploy existing)
2. **Script**: `generate_condor_submit.py` (new - HTCondor equivalent)
3. **Template**: `parameter_study_template.sub` (HTCondor)
4. **Template**: `parameter_study_template.slurm` (SLURM)
5. **Documentation**: Parameter study customization guide

**Expected Outcome**:
- Users generate custom grids: masses, metallicities, physics parameters
- No editing of submit files required
- Consistent workflow for both schedulers

### Priority 3: Comprehensive Testing Framework (MEDIUM)

**Why**: Catch errors before job submission, validate environment

**Components to Add**:

1. **Script**: `test_htcondor_scripts.sh` (new)
2. **Script**: `test_slurm_scripts.sh` (deploy existing)
3. **Script**: `test_infrastructure.sh` (new - end-to-end validation)
4. **CI/CD**: GitHub Actions workflow for script validation

**Expected Outcome**:
- Pre-submission validation
- Automated testing in repository
- Faster debugging cycles

### Priority 4: Improved Documentation (LOW)

**Why**: Better user experience, lower support burden

**Components to Add**:

1. **Document**: `USAGE_GUIDE.md` (new - comprehensive user guide)
2. **Updates**: Align demo READMEs with infrastructure paths
3. **Updates**: Add quick-start to DEPLOYMENT_GUIDE.md
4. **Document**: `TROUBLESHOOTING.md` (common issues + solutions)

**Expected Outcome**:
- Single source of truth for usage
- Clear path from deployment to running jobs
- Reduced time to first successful job

### Priority 5: Monitoring and Dashboards (LOW)

**Why**: Production observability, resource optimization

**Components to Add**:

1. **Ansible Role**: `monitoring` (Prometheus + Grafana)
2. **Exporter**: HTCondor metrics
3. **Exporter**: SLURM metrics
4. **Dashboard**: NuDocker HTCondor overview
5. **Dashboard**: NuDocker SLURM overview
6. **Dashboard**: MESA job statistics

**Expected Outcome**:
- Real-time cluster status
- Job completion tracking
- Resource utilization visualization
- Cost estimation

---

## Implementation Roadmap

### Phase 1: SLURM Integration (2-3 days)

**Day 1**: SLURM Installation
- Create install-slurm.sh Packer script
- Test SLURM installation on Ubuntu 20.04
- Create slurm-controller Ansible role
- Create slurm-compute Ansible role

**Day 2**: SLURM Configuration
- Create slurm.conf template for HUN-REN cloud
- Configure partitions and resource limits
- Set up munge authentication
- Test controller + compute node communication

**Day 3**: Script Deployment and Testing
- Update nudocker Ansible role to deploy SLURM scripts
- Organize /storage/batch_examples/ structure
- Test single job submission
- Test job array submission
- Test large grid workflow

**Deliverables**:
- ✅ Dual-scheduler infrastructure (HTCondor + SLURM)
- ✅ All demo SLURM scripts deployed and functional
- ✅ Documentation updated

### Phase 2: Parameter Grid System (1 day)

**Tasks**:
- Deploy generate_parameter_grid.py
- Create generate_condor_submit.py
- Create parameter study templates
- Add documentation section
- Test custom parameter grid generation

**Deliverables**:
- ✅ Flexible parameter study generation
- ✅ Works for both HTCondor and SLURM
- ✅ Example workflows documented

### Phase 3: Testing Framework (1 day)

**Tasks**:
- Deploy test_slurm_scripts.sh
- Create test_htcondor_scripts.sh
- Create test_infrastructure.sh (end-to-end)
- Add GitHub Actions workflow
- Document testing procedures

**Deliverables**:
- ✅ Pre-submission validation scripts
- ✅ Automated CI/CD testing
- ✅ Reduced debugging time

### Phase 4: Documentation (0.5 days)

**Tasks**:
- Create USAGE_GUIDE.md
- Update demo READMEs with deployment paths
- Add quick-start to DEPLOYMENT_GUIDE.md
- Create TROUBLESHOOTING.md
- Cross-reference all documents

**Deliverables**:
- ✅ Unified documentation
- ✅ Clear quick-start path
- ✅ Common issues documented

### Phase 5: Monitoring (Optional, 1-2 days)

**Tasks**:
- Create monitoring Ansible role
- Deploy Prometheus and Grafana
- Configure HTCondor metrics exporter
- Configure SLURM metrics exporter
- Create NuDocker dashboards

**Deliverables**:
- ✅ Real-time cluster monitoring
- ✅ Job tracking dashboards
- ✅ Resource utilization insights

**Total Estimated Time**: 5.5-7.5 days for complete implementation

---

## Updated Code Specifications

### Spec 1: SLURM Controller Ansible Role

**File**: `infrastructure/ansible/roles/slurm-controller/tasks/main.yml`

```yaml
---
# SLURM Controller Installation and Configuration
# Manages slurmctld, slurmrestd, and accounting

- name: Install SLURM controller packages
  apt:
    name:
      - slurm-wlm
      - slurm-wlm-basic-plugins
      - slurm-client
      - munge
      - libmunge-dev
      - mariadb-server
      - slurmdbd
    state: present
    update_cache: yes

- name: Create SLURM configuration directory
  file:
    path: /etc/slurm
    state: directory
    owner: slurm
    group: slurm
    mode: '0755'

- name: Generate munge key
  command: create-munge-key
  args:
    creates: /etc/munge/munge.key

- name: Set munge key permissions
  file:
    path: /etc/munge/munge.key
    owner: munge
    group: munge
    mode: '0400'

- name: Start and enable munge service
  systemd:
    name: munge
    state: started
    enabled: yes

- name: Deploy SLURM configuration
  template:
    src: slurm.conf.j2
    dest: /etc/slurm/slurm.conf
    owner: slurm
    group: slurm
    mode: '0644'
  notify: restart slurmctld

- name: Create SLURM spool directory
  file:
    path: /var/spool/slurmctld
    state: directory
    owner: slurm
    group: slurm
    mode: '0755'

- name: Create SLURM log directory
  file:
    path: /var/log/slurm
    state: directory
    owner: slurm
    group: slurm
    mode: '0755'

- name: Export SLURM configuration via NFS
  lineinfile:
    path: /etc/exports
    line: "/etc/slurm 10.0.0.0/24(ro,sync,no_subtree_check)"
  notify: restart nfs-server

- name: Start and enable slurmctld
  systemd:
    name: slurmctld
    state: started
    enabled: yes

- name: Configure slurmdbd (optional accounting)
  template:
    src: slurmdbd.conf.j2
    dest: /etc/slurm/slurmdbd.conf
    owner: slurm
    group: slurm
    mode: '0600'
  when: slurm_accounting_enabled | default(false)

- name: Start and enable slurmdbd
  systemd:
    name: slurmdbd
    state: started
    enabled: yes
  when: slurm_accounting_enabled | default(false)
```

**File**: `infrastructure/ansible/roles/slurm-controller/templates/slurm.conf.j2`

```
# SLURM Configuration for NuDocker HUN-REN Cloud
# Generated by Ansible

# Controller Configuration
ClusterName={{ cluster_name }}
SlurmctldHost={{ ansible_hostname }}({{ ansible_default_ipv4.address }})
SlurmctldPort=6817
SlurmctldLogFile=/var/log/slurm/slurmctld.log
StateSaveLocation=/var/spool/slurmctld

# Authentication
AuthType=auth/munge
CryptoType=crypto/munge

# Scheduling
SchedulerType=sched/backfill
SelectType=select/cons_tres
SelectTypeParameters=CR_Core_Memory

# Timeouts
SlurmctldTimeout=300
SlurmdTimeout=300
InactiveLimit=0
MinJobAge=300
KillWait=30
Waittime=0

# Logging
SlurmctldDebug=info
SlurmctldLogFile=/var/log/slurm/slurmctld.log
SlurmdDebug=info
SlurmdLogFile=/var/log/slurm/slurmd.log

# Process Tracking
ProctrackType=proctrack/linuxproc
TaskPlugin=task/affinity,task/cgroup

# Accounting (optional)
{% if slurm_accounting_enabled | default(false) %}
AccountingStorageType=accounting_storage/slurmdbd
AccountingStorageHost={{ ansible_hostname }}
AccountingStoragePort=6819
JobAcctGatherType=jobacct_gather/linux
JobAcctGatherFrequency=30
{% else %}
AccountingStorageType=accounting_storage/none
{% endif %}

# Job Completion
JobCompType=jobcomp/none

# Compute Nodes
{% for i in range(1, execute_node_count + 1) %}
NodeName={{ cluster_name }}-execute-{{ "%02d"|format(i) }} \
    NodeAddr=10.0.0.{{ 10 + i }} \
    CPUs={{ execute_node_cpus }} \
    RealMemory={{ execute_node_memory_mb }} \
    State=UNKNOWN
{% endfor %}

# Partitions
PartitionName=normal \
    Nodes={{ cluster_name }}-execute-[01-{{ "%02d"|format(execute_node_count) }}] \
    Default=YES \
    MaxTime=INFINITE \
    State=UP \
    Priority=1

PartitionName=long \
    Nodes={{ cluster_name }}-execute-[01-{{ "%02d"|format(execute_node_count) }}] \
    Default=NO \
    MaxTime=7-00:00:00 \
    State=UP \
    Priority=0

# Resource Limits
MaxJobCount=10000
MaxSubmitJobs=10000
MaxArraySize=10000
```

**File**: `infrastructure/ansible/roles/slurm-controller/handlers/main.yml`

```yaml
---
- name: restart slurmctld
  systemd:
    name: slurmctld
    state: restarted

- name: restart nfs-server
  systemd:
    name: nfs-server
    state: restarted
```

### Spec 2: SLURM Compute Ansible Role

**File**: `infrastructure/ansible/roles/slurm-compute/tasks/main.yml`

```yaml
---
# SLURM Compute Node Configuration
# Manages slurmd daemon on execute nodes

- name: Install SLURM compute packages
  apt:
    name:
      - slurmd
      - slurm-client
      - munge
      - libmunge-dev
    state: present
    update_cache: yes

- name: Create SLURM configuration directory
  file:
    path: /etc/slurm
    state: directory
    owner: slurm
    group: slurm
    mode: '0755'

- name: Mount SLURM configuration from NFS
  mount:
    path: /etc/slurm
    src: "{{ slurm_controller_ip }}:/etc/slurm"
    fstype: nfs
    opts: ro
    state: mounted

- name: Copy munge key from central manager
  copy:
    src: "{{ munge_key_file }}"
    dest: /etc/munge/munge.key
    owner: munge
    group: munge
    mode: '0400'

- name: Start and enable munge service
  systemd:
    name: munge
    state: started
    enabled: yes

- name: Create SLURM spool directory
  file:
    path: /var/spool/slurmd
    state: directory
    owner: slurm
    group: slurm
    mode: '0755'

- name: Create SLURM log directory
  file:
    path: /var/log/slurm
    state: directory
    owner: slurm
    group: slurm
    mode: '0755'

- name: Configure cgroup support
  copy:
    dest: /etc/slurm/cgroup.conf
    content: |
      CgroupAutomount=yes
      ConstrainCores=yes
      ConstrainRAMSpace=yes
      ConstrainSwapSpace=yes
    owner: slurm
    group: slurm
    mode: '0644'

- name: Start and enable slurmd
  systemd:
    name: slurmd
    state: started
    enabled: yes
```

### Spec 3: Updated nudocker Ansible Role

**File**: `infrastructure/ansible/roles/nudocker/tasks/main.yml` (additions)

```yaml
# ... (existing tasks)

- name: Reorganize batch examples directory structure
  file:
    path: "{{ item }}"
    state: directory
    owner: ubuntu
    group: ubuntu
    mode: '0755'
  loop:
    - /storage/batch_examples
    - /storage/batch_examples/htcondor
    - /storage/batch_examples/slurm
    - /storage/batch_examples/common

- name: Copy HTCondor example scripts
  copy:
    src: /opt/nudocker/htcondor_scripts/
    dest: /storage/batch_examples/htcondor/
    remote_src: yes
    owner: ubuntu
    group: ubuntu
    mode: '0755'

- name: Copy SLURM example scripts
  copy:
    src: /opt/nudocker/slurm_scripts/
    dest: /storage/batch_examples/slurm/
    remote_src: yes
    owner: ubuntu
    group: ubuntu
    mode: '0755'

- name: Deploy parameter grid generation script
  copy:
    src: /opt/nudocker/slurm_scripts/generate_parameter_grid.py
    dest: /storage/batch_examples/common/generate_parameter_grid.py
    remote_src: yes
    owner: ubuntu
    group: ubuntu
    mode: '0755'

- name: Deploy unified usage guide
  template:
    src: USAGE_GUIDE.md.j2
    dest: /storage/batch_examples/USAGE_GUIDE.md
    owner: ubuntu
    group: ubuntu
    mode: '0644'

- name: Create symbolic links for convenience
  file:
    src: "{{ item.src }}"
    dest: "{{ item.dest }}"
    state: link
  loop:
    - { src: '/storage/batch_examples/htcondor/README.md', dest: '/storage/batch_examples/README.htcondor.md' }
    - { src: '/storage/batch_examples/slurm/README.md', dest: '/storage/batch_examples/README.slurm.md' }
```

### Spec 4: HTCondor Testing Script

**File**: `htcondor_scripts/test_htcondor_scripts.sh`

```bash
#!/bin/bash
# HTCondor Scripts Testing and Validation Framework
# Tests submit files, DAG files, and wrapper scripts

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counters
TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0

print_result() {
    local test_name="$1"
    local result="$2"
    TESTS_TOTAL=$((TESTS_TOTAL + 1))

    if [ "$result" == "PASS" ]; then
        echo -e "${GREEN}✓ PASS${NC}: $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    elif [ "$result" == "FAIL" ]; then
        echo -e "${RED}✗ FAIL${NC}: $test_name"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    elif [ "$result" == "WARN" ]; then
        echo -e "${YELLOW}⚠ WARN${NC}: $test_name"
    else
        echo -e "${BLUE}ℹ INFO${NC}: $test_name"
    fi
}

echo "========================================="
echo "HTCondor Scripts Testing Framework"
echo "========================================="
echo ""

# Test 1: Bash Syntax Validation
echo "Test Suite 1: Bash Syntax Validation"
echo "-------------------------------------"

for script in run_mesa_model.sh; do
    if [ -f "$script" ]; then
        if bash -n "$script" 2>/dev/null; then
            print_result "Bash syntax: $script" "PASS"
        else
            print_result "Bash syntax: $script" "FAIL"
        fi
    else
        print_result "File exists: $script" "FAIL"
    fi
done
echo ""

# Test 2: HTCondor Submit File Syntax
echo "Test Suite 2: HTCondor Submit File Syntax"
echo "------------------------------------------"

if command -v condor_submit >/dev/null 2>&1; then
    for submit in nugrid_*.sub; do
        if [ -f "$submit" ]; then
            if condor_submit -dry-run "$submit" >/dev/null 2>&1; then
                print_result "Submit syntax: $submit" "PASS"
            else
                print_result "Submit syntax: $submit" "FAIL"
            fi
        fi
    done
else
    print_result "HTCondor installed (condor_submit)" "WARN"
    echo "  Skipping submit file validation (HTCondor not available)"
fi
echo ""

# Test 3: DAGMan Syntax Validation
echo "Test Suite 3: DAGMan Syntax Validation"
echo "---------------------------------------"

if command -v condor_submit_dag >/dev/null 2>&1; then
    for dag in *.dag; do
        if [ -f "$dag" ]; then
            if condor_submit_dag -no_submit "$dag" >/dev/null 2>&1; then
                print_result "DAG syntax: $dag" "PASS"
            else
                print_result "DAG syntax: $dag" "FAIL"
            fi
        fi
    done
else
    print_result "DAGMan installed (condor_submit_dag)" "WARN"
    echo "  Skipping DAG validation (HTCondor not available)"
fi
echo ""

# Test 4: Submit File Required Directives
echo "Test Suite 4: Submit File Required Directives"
echo "----------------------------------------------"

for submit in nugrid_*.sub; do
    if [ ! -f "$submit" ]; then continue; fi

    # Check universe
    if grep -q "^universe" "$submit"; then
        print_result "$submit has 'universe'" "PASS"
    else
        print_result "$submit has 'universe'" "FAIL"
    fi

    # Check executable
    if grep -q "^executable" "$submit"; then
        print_result "$submit has 'executable'" "PASS"
    else
        print_result "$submit has 'executable'" "FAIL"
    fi

    # Check log file
    if grep -q "^log" "$submit"; then
        print_result "$submit has 'log'" "PASS"
    else
        print_result "$submit has 'log'" "FAIL"
    fi
done
echo ""

# Test 5: Docker Integration Check
echo "Test Suite 5: Docker Integration Check"
echo "---------------------------------------"

if command -v docker >/dev/null 2>&1; then
    print_result "Docker installed" "PASS"

    # Check if NuDocker images exist
    for image in nugrid/nudome:16.0 nugrid/nudome:18.0 nugrid/nudome:20.031; do
        if docker image inspect "$image" >/dev/null 2>&1; then
            print_result "Docker image exists: $image" "PASS"
        else
            print_result "Docker image exists: $image" "WARN"
            echo "  Pull with: docker pull $image"
        fi
    done
else
    print_result "Docker installed" "FAIL"
fi
echo ""

# Test 6: Parameter Queue Validation
echo "Test Suite 6: Parameter Queue Validation"
echo "-----------------------------------------"

for submit in nugrid_*.sub; do
    if [ ! -f "$submit" ]; then continue; fi

    # Check for queue directive
    if grep -q "^queue" "$submit"; then
        print_result "$submit has 'queue' directive" "PASS"

        # Count expected jobs
        QUEUE_LINE=$(grep "^queue" "$submit" | head -1)
        if echo "$QUEUE_LINE" | grep -q "from"; then
            # Count parameter lines
            PARAM_START=$(grep -n "queue.*from (" "$submit" | cut -d: -f1)
            if [ -n "$PARAM_START" ]; then
                JOB_COUNT=$(tail -n +$((PARAM_START + 1)) "$submit" | grep -c "^  [0-9]")
                print_result "$submit expects $JOB_COUNT jobs" "INFO"
            fi
        fi
    else
        print_result "$submit has 'queue' directive" "FAIL"
    fi
done
echo ""

# Test 7: Documentation Check
echo "Test Suite 7: Documentation Check"
echo "----------------------------------"

if [ -f "README.md" ]; then
    print_result "README.md exists" "PASS"

    # Check for required sections
    for section in "Usage" "Quick Start" "Requirements"; do
        if grep -qi "$section" README.md; then
            print_result "README has '$section' section" "PASS"
        else
            print_result "README has '$section' section" "WARN"
        fi
    done
else
    print_result "README.md exists" "FAIL"
fi
echo ""

# Test 8: Required Input Files Check
echo "Test Suite 8: Required Input Files Check"
echo "-----------------------------------------"

REQUIRED_FILES=(
    "run_mesa_model.sh"
    "nugrid_lowmass.sub"
    "nugrid_mediummass.sub"
    "nugrid_highmass.sub"
    "nugrid_study.dag"
)

for file in "${REQUIRED_FILES[@]}"; do
    if [ -f "$file" ]; then
        print_result "Required file exists: $file" "PASS"
    else
        print_result "Required file exists: $file" "FAIL"
    fi
done
echo ""

# Summary
echo "========================================="
echo "Test Summary"
echo "========================================="
echo "Total tests: $TESTS_TOTAL"
echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
echo -e "${RED}Failed: $TESTS_FAILED${NC}"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}✗ Some tests failed.${NC}"
    exit 1
fi
```

### Spec 5: Unified Usage Guide Template

**File**: `infrastructure/ansible/roles/nudocker/templates/USAGE_GUIDE.md.j2`

```markdown
# NuDocker Batch Job Usage Guide

**Cluster**: {{ cluster_name }}
**Deployed**: {{ ansible_date_time.iso8601 }}
**Storage**: /storage/

---

## Quick Start

### Choose Your Scheduler

This cluster supports **two** batch schedulers:

| Scheduler | Best For | Command Prefix |
|-----------|----------|----------------|
| **HTCondor** | Opportunistic scheduling, Docker containers, DAGMan workflows | `condor_submit` |
| **SLURM** | Traditional HPC, job arrays, resource guarantees | `sbatch` |

---

## HTCondor Workflow

### Location
```bash
cd /storage/batch_examples/htcondor/
ls -la
```

### Files Available
- `nudocker_study.dag` - Complete 54-model parameter study
- `nudocker_lowmass.sub` - Low-mass stars (1-2 M☉), 18 jobs
- `nudocker_mediummass.sub` - Medium-mass stars (5-10 M☉), 18 jobs
- `nudocker_highmass.sub` - High-mass stars (15-20 M☉), 18 jobs
- `run_mesa_model.sh` - MESA execution wrapper
- `README.md` - Detailed HTCondor documentation

### Submit Complete Study (DAGMan)
```bash
cd /storage/batch_examples/htcondor/
condor_submit_dag nudocker_study.dag
```

### Monitor DAGMan Workflow
```bash
# Check DAG status
tail -f nudocker_study.dag.dagman.out

# View job status
condor_q

# View cluster resources
condor_status
```

### Submit Individual Mass Group
```bash
condor_submit nudocker_lowmass.sub       # 18 jobs, 6 hours each
condor_submit nudocker_mediummass.sub    # 18 jobs, 24 hours each
condor_submit nudocker_highmass.sub      # 18 jobs, 72 hours each
```

### Check Results
```bash
ls -lh /storage/results/
tar xzf /storage/results/results_1.tar.gz
cd model_1/
cat model_info.txt
```

---

## SLURM Workflow

### Location
```bash
cd /storage/batch_examples/slurm/
ls -la
```

### Files Available
- `01_single_mesa_run.slurm` - Single MESA job
- `02_array_mesa_run.slurm` - Job array (10-50 models)
- `03_multiple_independent.slurm` - Multi-version submission script
- `04_large_grid.slurm` - Large parameter grid (100+ models)
- `compile_mesa.slurm` - Pre-compile MESA
- `generate_parameter_grid.py` - Parameter grid generator
- `test_slurm_scripts.sh` - Validation framework
- `README.md` - Detailed SLURM documentation

### Pre-compile MESA (Recommended)
```bash
cd /storage/batch_examples/slurm/
sbatch compile_mesa.slurm
squeue -u $USER
```

### Submit Single Job
```bash
sbatch 01_single_mesa_run.slurm
```

### Submit Job Array
```bash
# Generate parameter grid (150 models)
python3 generate_parameter_grid.py > /storage/config/parameter_grid.txt

# Submit array (max 20 concurrent)
sbatch 02_array_mesa_run.slurm
```

### Submit Large Grid
```bash
# Generate large grid (525 models)
python3 generate_parameter_grid.py > /storage/config/parameter_grid.txt

# Submit with throttling
sbatch 04_large_grid.slurm
```

### Monitor SLURM Jobs
```bash
# Check queue
squeue

# Check cluster status
sinfo

# View job details
scontrol show job <JOBID>

# Cancel job
scancel <JOBID>

# Cancel all your jobs
scancel -u $USER
```

### Check Results
```bash
ls -lh /storage/results/grid_study/
cd /storage/results/grid_study/model_1_M7.0_Z0.02_a1.8/
cat model_parameters.txt
cat final_model_state.dat
```

---

## Common Tasks

### View Available MESA Versions
```bash
ls /storage/mesa/
```

### View Available Containers
```bash
# Docker images (HTCondor)
docker images | grep nudome

# Singularity images (SLURM)
ls /storage/containers/*.sif
```

### Create Custom Parameter Grid
```bash
cd /storage/batch_examples/common/
python3 generate_parameter_grid.py --help
```

### Test Scripts Before Submission
```bash
# Test HTCondor scripts
cd /storage/batch_examples/htcondor/
bash test_htcondor_scripts.sh

# Test SLURM scripts
cd /storage/batch_examples/slurm/
bash test_slurm_scripts.sh
```

---

## Resource Guidelines

### Job Sizing (HTCondor)

| Mass Range | CPUs | Memory | Runtime | Jobs |
|------------|------|--------|---------|------|
| 1-2 M☉ | 8 | 8 GB | 6 hours | 18 |
| 5-10 M☉ | 16 | 16 GB | 24 hours | 18 |
| 15-20 M☉ | 32 | 32 GB | 72 hours | 18 |

### Job Sizing (SLURM)

| Scenario | CPUs | Memory | Runtime | Notes |
|----------|------|--------|---------|-------|
| Single model | 8 | 16 GB | 24 hours | Testing, small studies |
| Job array | 8 | 16 GB | 24 hours | 10-50 models |
| Large grid | 8 | 16 GB | 48 hours | 100+ models, use throttling |
| Pre-compilation | 16 | 32 GB | 2 hours | One-time setup |

---

## Troubleshooting

### HTCondor: Jobs Held
```bash
condor_q -hold
condor_q -analyze <JOBID>
condor_release <JOBID>
```

### SLURM: Jobs Pending
```bash
squeue -u $USER --start  # See expected start time
squeue -u $USER --state=PD  # Pending jobs
scontrol show job <JOBID> | grep Reason
```

### Container Issues
```bash
# HTCondor: Check Docker
docker ps
docker logs <CONTAINER_ID>

# SLURM: Check Singularity
singularity --version
singularity exec /storage/containers/nudome_16.0.sif ls /home/user/mesa
```

### Storage Full
```bash
df -h /storage
du -sh /storage/results/*
# Clean up old results
```

---

## Support

**Documentation**:
- HTCondor: /storage/batch_examples/htcondor/README.md
- SLURM: /storage/batch_examples/slurm/README.md
- Infrastructure: /opt/nudocker/infrastructure/DEPLOYMENT_GUIDE.md

**Log Files**:
- HTCondor logs: Check .log, .out, .err files in job directory
- SLURM logs: Check logs/mesa_*.out and logs/mesa_*.err

**Cluster Admin Contact**: {{ admin_email | default('admin@hun-ren.cloud') }}
```

---

## Summary

This analysis identifies **5 major gaps** in the current infrastructure integration:

1. ❌ **SLURM not deployed** - Most critical gap
2. ❌ **Parameter grid generation missing** - Reduces flexibility
3. ❌ **Testing framework incomplete** - HTCondor lacks validation
4. ⚠️ **Documentation inconsistent** - Path mismatches, no unified guide
5. ⚠️ **Monitoring absent** - Limited observability

The proposed improvements would make the HUN-REN cloud implementation **complete and production-ready**, fully integrating both HTCondor and SLURM workflows from the demo repository.

**Recommended Next Step**: Implement **Priority 1 (SLURM Integration)** to achieve parity with the "htcondor-slurm-demo" repository name and intent.
