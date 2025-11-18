# NuGrid Parameter Study for HTCondor

**Complete HTCondor submission package for running the NuGrid stellar evolution parameter study using NuDocker containers.**

---

## Table of Contents

- [Overview](#overview)
- [Parameter Study Description](#parameter-study-description)
- [HTCondor Suitability](#htcondor-suitability)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [File Descriptions](#file-descriptions)
- [Detailed Usage](#detailed-usage)
- [Resource Requirements](#resource-requirements)
- [Monitoring and Management](#monitoring-and-management)
- [Troubleshooting](#troubleshooting)
- [HTCondor vs SLURM](#htcondor-vs-slurm)

---

## Overview

This directory contains a complete HTCondor submission package for running a 54-model stellar evolution parameter study based on the **NuGrid Stellar Data Set II** ([Pignatari et al. 2016, arXiv:1709.08677](https://arxiv.org/abs/1709.08677)).

### Parameter Space

- **Stellar Masses**: 1, 2, 5, 10, 15, 20 M☉
- **Metallicities**: Z = 0.02, 0.01, 0.001
- **Mixing Length Alpha**: α = 1.8, 2.0, 2.2
- **Total Models**: 6 × 3 × 3 = **54 stellar evolution models**

### Computational Approach

- **Parallelization**: OpenMP (shared-memory), **NOT MPI**
- **Independence**: Each model runs completely independently
- **Container**: NuDocker images (nugrid/nudome:16.0)
- **Scheduler**: HTCondor with DAGMan workflow management

---

## Parameter Study Description

### Scientific Goals

1. Understand nucleosynthesis across different stellar masses and metallicities
2. Map out stellar evolution tracks in the HR diagram
3. Determine main sequence lifetimes as function of mass and metallicity
4. Calculate element production (yields) for galactic chemical evolution models

### Model Categories

#### Low-Mass Models (1-2 M☉)
- **Number**: 18 models
- **Evolution**: Main sequence → RGB → AGB → White Dwarf
- **Runtime**: 2-6 hours
- **Resources**: 8 CPUs, 8 GB memory
- **Output**: ~750 MB per model

#### Medium-Mass Models (5-10 M☉)
- **Number**: 18 models
- **Evolution**: Main sequence → RGB → AGB → (varies)
- **Runtime**: 6-24 hours
- **Resources**: 16 CPUs, 16 GB memory
- **Output**: ~2 GB per model

#### High-Mass Models (15-20 M☉)
- **Number**: 18 models
- **Evolution**: Main sequence → Core collapse (supernova)
- **Runtime**: 24-72 hours
- **Resources**: 32 CPUs, 32 GB memory
- **Output**: ~5 GB per model

---

## HTCondor Suitability

### ✅ Why HTCondor is Perfect for This

**MESA uses OpenMP, NOT MPI**:
- Each stellar model runs on a **single node**
- No inter-process communication needed
- **Embarrassingly parallel** workload

**Heterogeneous Resource Requirements**:
- Low-mass: 8 CPUs, 8 GB, 6 hours
- Medium-mass: 16 CPUs, 16 GB, 24 hours
- High-mass: 32 CPUs, 32 GB, 72 hours
- HTCondor's **matchmaking** handles this naturally

**Independent Jobs**:
- No dependencies between models
- Can run in any order
- Perfect for HTCondor's opportunistic scheduling

**Long Runtimes with Checkpointing**:
- MESA supports checkpointing via "photos"
- HTCondor handles preemption gracefully
- Jobs can resume from checkpoints

### Suitability Score: ✅ **EXCELLENT (9/10)**

| Criterion | Score | Notes |
|-----------|-------|-------|
| MPI Requirement | 10/10 | Not needed (OpenMP only) |
| Memory Requirements | 9/10 | 4-32 GB (well within limits) |
| Job Independence | 10/10 | Completely independent |
| Heterogeneity | 10/10 | HTCondor advantage |
| Checkpointing | 9/10 | MESA supports it |
| Long Runtimes | 8/10 | 72 hours maximum |
| Docker Support | 10/10 | Native support |

---

## Prerequisites

### 1. HTCondor Access

- HTCondor pool with Docker support
- Submit access to HTCondor scheduler
- Sufficient allocation for ~5,000 CPU-hours

### 2. Software Requirements

- **HTCondor**: v8.9 or later (with Docker universe support)
- **Docker**: Available on execute nodes
- **NuDocker Image**: `nugrid/nudome:16.0` (pulled automatically)

### 3. MESA Installation

**Pre-compiled MESA required**:
```bash
# On a node with Docker:
docker run -it -v $(pwd)/mesa-r9575:/home/user/mesa nugrid/nudome:16.0
cd mesa
./install  # Takes 10-30 minutes
exit
```

**Why pre-compile?**:
- Compilation takes 10-30 minutes per model
- 54 models × 20 min = 18 hours wasted on compilation
- Compile once, use 54 times

### 4. Disk Space

- **Submit node**: ~5 GB (templates and scripts)
- **Storage for results**: ~150-300 GB
- **Shared filesystem**: Recommended for result storage

---

## Quick Start

### Step 1: Clone Repository

```bash
git clone https://github.com/NuGrid/NuDocker.git
cd NuDocker/htcondor_scripts
```

### Step 2: Prepare MESA Template

```bash
# Create MESA work template directory
mkdir -p mesa_work_template
cd mesa_work_template

# Copy MESA work directory (from pre-compiled MESA)
cp -r /path/to/mesa-r9575/star/work/* .

# Modify inlists for parameter study
# (Set placeholders for initial_mass, initial_z, mixing_length_alpha)

# Return to htcondor_scripts directory
cd ..

# Compress template
tar czf mesa_work_template.tar.gz mesa_work_template/
```

### Step 3: Create Logs Directory

```bash
mkdir -p logs
```

### Step 4: Submit DAG

```bash
# Submit complete parameter study (54 models)
condor_submit_dag nugrid_study.dag

# Or submit individual mass groups:
condor_submit nugrid_lowmass.sub      # 18 low-mass models
condor_submit nugrid_mediummass.sub   # 18 medium-mass models
condor_submit nugrid_highmass.sub     # 18 high-mass models
```

### Step 5: Monitor Progress

```bash
# Check job status
condor_q

# Watch in real-time
condor_watch_q

# View DAG progress
tail -f nugrid_study.dag.dagman.out

# Check specific job output
tail -f logs/lowmass_<cluster>_<process>.out
```

---

## File Descriptions

### Submit Files

#### `nugrid_lowmass.sub` (18 jobs)
**Purpose**: Low-mass stellar models (1-2 M☉)

**Key Settings**:
- `request_cpus = 8`
- `request_memory = 8 GB`
- `+MaxRuntime = 21600` (6 hours)
- Docker image: `nugrid/nudome:16.0`

**Jobs**: 18 models (2 masses × 3 metallicities × 3 alphas)

#### `nugrid_mediummass.sub` (18 jobs)
**Purpose**: Medium-mass stellar models (5-10 M☉)

**Key Settings**:
- `request_cpus = 16`
- `request_memory = 16 GB`
- `+MaxRuntime = 86400` (24 hours)

**Jobs**: 18 models

#### `nugrid_highmass.sub` (18 jobs)
**Purpose**: High-mass stellar models (15-20 M☉)

**Key Settings**:
- `request_cpus = 32`
- `request_memory = 32 GB`
- `+MaxRuntime = 259200` (72 hours)

**Jobs**: 18 models

### Workflow Management

#### `nugrid_study.dag`
**Purpose**: DAGMan workflow coordinating all jobs

**Features**:
- Parallel execution of mass groups
- Automatic retries (2 attempts)
- Result aggregation after completion
- Progress tracking

**Usage**:
```bash
condor_submit_dag nugrid_study.dag
```

#### `nugrid_study.config`
**Purpose**: DAGMan configuration

**Settings**:
- Job throttling (max 50 concurrent)
- Retry limits
- Logging configuration

### Execution Scripts

#### `run_mesa_model.sh`
**Purpose**: Wrapper script that runs MESA in container

**Functionality**:
1. Extract MESA work template
2. Configure inlists with parameters
3. Compile work directory
4. Run MESA evolution
5. Package results

**Inputs**: Model ID, mass, metallicity, alpha
**Outputs**: `results_<id>.tar.gz`

### Support Files

#### `mesa_work_template.tar.gz` (you create this)
**Purpose**: Template MESA work directory

**Contents**:
- Inlist files (with placeholders)
- Source code (if custom)
- Run/compile scripts

#### `parameter_grid_*.txt` (optional)
**Purpose**: Parameter grid definitions

**Format**: One parameter set per line

---

## Detailed Usage

### Creating MESA Work Template

The template should be a standard MESA work directory with:

**Required Files**:
- `inlist` - Main inlist
- `inlist_project` - Project-specific parameters
- `src/` - Source code (if modified)
- `make/` - Makefile

**Parameter Placeholders**:

In `inlist_project`, use values that will be replaced:
```fortran
&star_job
  initial_mass = 5.0    ! Will be replaced
  initial_z = 0.02      ! Will be replaced
/ ! end of star_job namelist

&controls
  mixing_length_alpha = 2.0  ! Will be replaced

  ! Evolution controls
  max_age = 1d10

  ! Output controls
  history_interval = 1
  profile_interval = 50
  photo_interval = 100
/ ! end of controls namelist
```

**Prepare Template**:
```bash
# Start from MESA work directory
cd /path/to/mesa-r9575/star/work

# Copy to template directory
cp -r . ~/mesa_work_template/

# Clean compiled files (if any)
cd ~/mesa_work_template
./clean

# Compress
tar czf mesa_work_template.tar.gz *
mv mesa_work_template.tar.gz ~/NuDocker/htcondor_scripts/
```

### Submitting Jobs

#### Option 1: Submit Complete DAG
```bash
condor_submit_dag nugrid_study.dag
```

**Advantages**:
- Coordinated workflow
- Automatic result aggregation
- Better monitoring

#### Option 2: Submit Individual Mass Groups
```bash
# Submit separately for more control
condor_submit nugrid_lowmass.sub
condor_submit nugrid_mediummass.sub
condor_submit nugrid_highmass.sub
```

**Advantages**:
- Finer control over submission
- Can stagger submissions
- Test one group first

#### Option 3: Test with Single Job
```bash
# Edit submit file to queue only one job
# Comment out all but one "queue" statement
condor_submit nugrid_lowmass.sub
```

### Customizing Resource Requests

Edit submit files to adjust resources:

```bash
# In nugrid_lowmass.sub
request_cpus = 8        # Increase/decrease CPUs
request_memory = 8 GB   # Adjust memory
+MaxRuntime = 21600     # Adjust time limit (seconds)
```

**Guidelines**:
- More CPUs = faster evolution (OpenMP scaling)
- Memory should be ~1 GB per CPU minimum
- Time limits should be generous (add 50% buffer)

---

## Resource Requirements

### Per-Model Estimates

| Mass Range | CPUs | Memory | Time | Disk | Notes |
|------------|------|--------|------|------|-------|
| 1-2 M☉ | 8 | 8 GB | 2-6 hr | 750 MB | Low-mass |
| 5-10 M☉ | 16 | 16 GB | 6-24 hr | 2 GB | Medium |
| 15-20 M☉ | 32 | 32 GB | 24-72 hr | 5 GB | High-mass |

### Total Study (54 models)

**CPU-hours**:
- Low-mass: 18 × 8 × 4 = 576 CPU-hours
- Medium-mass: 18 × 16 × 15 = 4,320 CPU-hours
- High-mass: 18 × 32 × 48 = 27,648 CPU-hours
- **Total**: ~32,500 CPU-hours (optimistic)
- **Realistic**: ~40,000 CPU-hours (with overhead)

**Peak Memory**: 32 GB (high-mass jobs)

**Total Disk**: ~150-300 GB (all results)

**Wallclock Time** (with 50 concurrent jobs):
- Optimistic: 24-36 hours
- Realistic: 48-72 hours
- Conservative: 72-96 hours

---

## Monitoring and Management

### Check Job Status

```bash
# All jobs
condor_q

# Your jobs only
condor_q $USER

# Specific job details
condor_q -better-analyze <jobid>

# Long format
condor_q -long <jobid>
```

### Monitor DAG Progress

```bash
# DAG status
condor_q -dag

# DAG log
tail -f nugrid_study.dag.dagman.out

# DAG status file
cat nugrid_study.status

# Graphical representation
dot -Tpng nugrid_study.dot -o dag_status.png
```

### View Job Output

```bash
# Real-time output
tail -f logs/lowmass_<cluster>_<process>.out

# Error output
tail -f logs/lowmass_<cluster>_<process>.err

# All output for a cluster
tail -f logs/lowmass_<cluster>_*.out
```

### Job Control

```bash
# Remove specific job
condor_rm <jobid>

# Remove all your jobs
condor_rm $USER

# Remove DAG and all jobs
condor_rm <dagman_jobid>

# Hold job (pause)
condor_hold <jobid>

# Release held job (resume)
condor_release <jobid>
```

### Resource Usage

```bash
# Historical usage
condor_history $USER -limit 100

# Detailed resource usage
condor_history <jobid> -long | grep -i "^Memory\|^Disk\|^Cpus"

# Summary of completed jobs
condor_history $USER -format "%d\n" ClusterId | wc -l
```

---

## Troubleshooting

### Problem: Jobs stay idle

**Check why**:
```bash
condor_q -better-analyze <jobid>
```

**Common reasons**:
- No machines match requirements
- Priority too low
- Resource request too high
- Docker not available on execute nodes

**Solutions**:
```bash
# Check machine availability
condor_status -avail

# Check Docker support
condor_status -constraint 'HasDocker=?=True'

# Lower resource requirements (if appropriate)
# Edit submit file: request_cpus, request_memory
```

### Problem: Jobs held

**Check hold reason**:
```bash
condor_q -hold
```

**Release if appropriate**:
```bash
condor_release <jobid>
```

### Problem: Jobs fail immediately

**Check error log**:
```bash
cat logs/lowmass_<cluster>_<process>.err
```

**Common issues**:
- MESA not pre-compiled
- Template not found
- Inlist syntax error
- Memory exceeded

**Solution**: Fix issue and resubmit

### Problem: Out of memory

**Symptoms**: Job held with "memory exceeded"

**Check actual usage**:
```bash
condor_history <jobid> -long | grep Memory
```

**Solution**: Increase memory request
```bash
# Edit submit file
request_memory = 16 GB  # Increase as needed
```

### Problem: Time limit exceeded

**Symptoms**: Job evicted after MaxRuntime

**Solution**: Increase time limit
```bash
# Edit submit file
+MaxRuntime = 86400  # Increase (in seconds)
```

Or use checkpointing:
- MESA saves "photos" automatically
- Modify `run_mesa_model.sh` to resume from last photo

### Problem: Results not transferred

**Check**:
```bash
ls -lh results_*.tar.gz
```

**Common causes**:
- Job still running
- Transfer failed
- File too large

**Solution**:
- Wait for job completion
- Check file size limits
- Use shared filesystem instead

---

## HTCondor vs SLURM

### When to Use HTCondor

✅ **Better for**:
- Heterogeneous resource requirements
- Opportunistic scheduling
- Non-HPC environments
- Flexible priorities
- Backfill computing

### When to Use SLURM

✅ **Better for**:
- Traditional HPC clusters
- Uniform resource allocations
- Dedicated time slots
- MPI applications
- Simpler submission

### For This Study

**HTCondor Advantages**:
- Different resource needs per model
- Intelligent matchmaking
- Preemption handling
- No MPI needed

**SLURM Advantages**:
- More common on HPC clusters
- Simpler for beginners
- Better documentation
- Easier debugging

**Recommendation**: Both work well! Choose based on available infrastructure.

---

## Advanced Topics

### Prioritizing Jobs

```bash
# Set priority in submit file
priority = 10  # Higher = more important (-20 to +20)
```

### Using Shared Filesystem

```bash
# Mount shared FS instead of transferring files
should_transfer_files = NO
initialdir = /shared/nugrid_study/run_$(Process)
```

### Checkpointing

MESA's photo files can be used for checkpointing:

```bash
# In inlist_project
photo_interval = 100  # Save every 100 steps

# To resume from checkpoint:
# Modify run_mesa_model.sh to:
./re x100  # Resume from photo x100
```

### Result Aggregation

Create `aggregate_results.sub`:
```bash
universe = vanilla
executable = aggregate.sh
arguments = results_*.tar.gz
should_transfer_files = YES
when_to_transfer_output = ON_EXIT
queue
```

---

## References

1. Pignatari et al. (2016). "NuGrid Stellar Data Set. II." MNRAS, 480(1), 538-571. [arXiv:1709.08677]
2. HTCondor Manual: https://htcondor.readthedocs.io
3. MESA Documentation: https://docs.mesastar.org
4. NuDocker Repository: https://github.com/NuGrid/NuDocker

---

## Support

**Questions?**
- NuDocker: https://github.com/NuGrid/NuDocker/issues
- HTCondor: htcondor-users@cs.wisc.edu
- MESA: http://mesastar.org

---

**Version**: 1.0
**Date**: 2025-11-18
**Status**: Production-Ready
**License**: BSD 3-Clause
