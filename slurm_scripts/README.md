# NuDocker SLURM Scripts for HUN-REN Cloud

**Complete collection of SLURM batch scripts for running MESA simulations using NuDocker Singularity containers on the HUN-REN Science Cloud cluster.**

---

## Overview

This directory contains ready-to-use SLURM scripts for various MESA workflow scenarios:

1. **Single job execution** - Run one MESA model
2. **Job arrays** - Run multiple models in parallel with parameter variations
3. **Multiple independent jobs** - Submit different MESA versions/test cases
4. **Large parameter grids** - Systematic parameter studies (100+ models)
5. **Pre-compilation** - Compile MESA once before large studies

All scripts use **Singularity containers** (converted from NuDocker Docker images) for reproducible MESA execution on HPC clusters.

---

## Quick Start

### 1. Prepare Environment

```bash
# On HUN-REN login node
mkdir -p ~/nudocker/{containers,mesa,runs,logs,config}
cd ~/nudocker

# Load Singularity/Apptainer
module load apptainer/1.2.2  # or singularity
```

### 2. Build Container

```bash
# Pull and convert Docker image to Singularity
cd ~/nudocker/containers
singularity pull nudome_16.0.sif docker://nugrid/nudome:16.0

# Verify
ls -lh nudome_16.0.sif
```

### 3. Download MESA

```bash
cd ~/nudocker/mesa
wget https://zenodo.org/records/2630796/files/mesa-r9575.zip
unzip mesa-r9575.zip
```

### 4. Copy Scripts

```bash
# From NuDocker repository
cp -r /path/to/NuDocker/slurm_scripts ~/nudocker/scripts
cd ~/nudocker/scripts
```

### 5. Run First Job

```bash
# Create logs directory
mkdir -p logs

# Edit script paths
vim 01_single_mesa_run.slurm
# Set: CONTAINER, MESA_SRC, WORK_DIR

# Submit
sbatch 01_single_mesa_run.slurm

# Monitor
squeue -u $USER
```

---

## Script Descriptions

### 01_single_mesa_run.slurm

**Purpose**: Run a single MESA test case or simulation

**Use Cases**:
- Testing setup before large runs
- Running single stellar evolution model
- Debugging MESA issues

**Configuration**:
```bash
CONTAINER=~/nudocker/containers/nudome_16.0.sif
MESA_SRC=~/nudocker/mesa/mesa-r9575
WORK_DIR=~/nudocker/runs/mesa-job-${SLURM_JOB_ID}
TEST_CASE="star/test_suite/7M_prems_to_AGB"
```

**Submit**:
```bash
sbatch 01_single_mesa_run.slurm
```

**Output**:
- `logs/mesa_<jobid>.out` - Standard output
- `logs/mesa_<jobid>.err` - Error log
- `~/nudocker/runs/mesa-job-<jobid>/` - Results directory
  - `LOGS/` - MESA output logs
  - `photos/` - Model snapshots
  - `summary.txt` - Run summary

---

### 02_array_mesa_run.slurm

**Purpose**: Run multiple MESA models with different parameters using SLURM job arrays

**Use Cases**:
- Parameter sensitivity studies (10-50 models)
- Testing different initial conditions
- Systematic variations of single parameter

**Configuration**:
```bash
CONTAINER=~/nudocker/containers/nudome_16.0.sif
MESA_SRC=~/nudocker/mesa/mesa-r9575
BASE_WORK_DIR=~/nudocker/runs
PARAMETER_FILE=~/nudocker/config/parameter_list.txt
#SBATCH --array=1-10  # Number of models
```

**Prepare Parameters**:
```bash
# Create parameter file (one set per line)
cat > ~/nudocker/config/parameter_list.txt <<EOF
initial_mass=7.0 Zbase=0.02
initial_mass=10.0 Zbase=0.02
initial_mass=15.0 Zbase=0.02
EOF
```

**Submit**:
```bash
# Adjust array range to match parameter file lines
# Edit: #SBATCH --array=1-3
sbatch 02_array_mesa_run.slurm
```

**Output**:
- Each array task creates separate directory:
  - `~/nudocker/runs/array-<jobid>-task-1/`
  - `~/nudocker/runs/array-<jobid>-task-2/`
  - ...

---

### 03_multiple_independent.slurm

**Purpose**: Submit multiple different MESA jobs (different versions, test cases) simultaneously

**Use Cases**:
- Running different MESA versions in parallel
- Testing multiple test cases
- Comparing different physics modules

**Configuration**:
Edit the `JOBS` array in the script:
```bash
JOBS=(
    "mesa-r9575-7M:nudome_16.0.sif:mesa-r9575:star/test_suite/7M_prems_to_AGB:8:16G:24:00:00"
    "mesa-r10398-15M:nudome_16.0.sif:mesa-r10398:star/test_suite/15M_dynamo:16:32G:48:00:00"
    "mesa-r12778-25M:nudome_20.031.sif:mesa-r12778:star/test_suite/25M_pre_ms_to_core_collapse:16:64G:72:00:00"
)
```

Format: `job_name:container:mesa_src:test_case:cpus:memory:time`

**Submit**:
```bash
# This script submits multiple sbatch jobs
bash 03_multiple_independent.slurm
```

**Output**:
- Creates separate directory for each job
- Tracks all submitted job IDs
- Saves job IDs to file for later reference

---

### 04_large_grid.slurm

**Purpose**: Large-scale parameter grid studies (100+ models) with job throttling

**Use Cases**:
- Comprehensive parameter surveys
- Population synthesis studies
- Systematic exploration of parameter space

**Features**:
- Job array with throttling (`--array=1-100%20` = max 20 running)
- Automatic parameter grid parsing
- Descriptive directory naming
- Progress tracking

**Configuration**:
```bash
CONTAINER=~/nudocker/containers/nudome_16.0.sif
MESA_SRC=~/nudocker/mesa/mesa-r9575  # Pre-compiled recommended!
GRID_BASE_DIR=~/nudocker/runs/grid_study
PARAMETER_GRID=~/nudocker/config/parameter_grid.txt
#SBATCH --array=1-150%20  # 150 models, max 20 running
```

**Generate Parameter Grid**:
```bash
# Use helper script
python3 generate_parameter_grid.py > ~/nudocker/config/parameter_grid.txt

# Or create manually:
cat > ~/nudocker/config/parameter_grid.txt <<EOF
initial_mass=1.0 Zbase=0.001 mixing_length_alpha=1.8
initial_mass=1.0 Zbase=0.001 mixing_length_alpha=2.0
initial_mass=1.0 Zbase=0.001 mixing_length_alpha=2.2
...
EOF
```

**Submit**:
```bash
# Pre-compile MESA first (recommended)
sbatch compile_mesa.slurm

# Then submit grid
sbatch 04_large_grid.slurm
```

**Output**:
- Organized by parameters: `grid_study/model_1_M7.0_Z0.02_a2.0/`
- Each model has metadata file: `model_parameters.txt`
- Final model states saved: `final_model_state.dat`

---

### compile_mesa.slurm

**Purpose**: Pre-compile MESA before large job submissions

**Benefits**:
- Compile once, use many times
- Skip 10-30 min compilation per job
- Faster job startup
- Reduced cluster load

**Configuration**:
```bash
CONTAINER=~/nudocker/containers/nudome_16.0.sif
MESA_SRC=~/nudocker/mesa/mesa-r9575  # Must have write access
#SBATCH --cpus-per-task=16  # More CPUs = faster compilation
#SBATCH --mem=32G           # Needs sufficient memory
```

**Submit**:
```bash
sbatch compile_mesa.slurm
```

**Typical Duration**: 10-30 minutes depending on:
- MESA version
- Number of CPUs
- Cluster load

**Output**:
- Compiled MESA in `${MESA_SRC}/make/` and `${MESA_SRC}/lib/`
- Compilation log: `logs/compile_mesa_<jobid>.out`
- Summary: `~/nudocker/logs/mesa_compilation_<jobid>.txt`

**When to Use**:
- Before submitting job arrays
- Before large parameter grids
- When running 10+ jobs with same MESA version

---

### generate_parameter_grid.py

**Purpose**: Generate parameter grid files for MESA studies

**Usage**:
```bash
# Generate default grid (150 models)
python3 generate_parameter_grid.py > parameter_grid.txt

# View statistics
python3 generate_parameter_grid.py 2>&1 | grep -A 20 "Parameter ranges"
```

**Customization**:
Edit the `generate_grid()` function in the script:

```python
# Small test grid (30 models)
masses = [1.0, 2.0, 5.0]
metallicities = [0.001, 0.02]
alphas = [1.8, 2.0, 2.2]
overshoot = [0.0, 0.1]

# Generate combinations
for mass, Z, alpha, ov in itertools.product(masses, metallicities, alphas, overshoot):
    params = {
        'initial_mass': mass,
        'Zbase': Z,
        'mixing_length_alpha': alpha,
        'overshoot_f_above_burn_h_core': ov
    }
    # ...
```

**Output Format**:
```
# Parameter grid for MESA studies
# Total models: 150
initial_mass=1.0 Zbase=0.001 mixing_length_alpha=1.8
initial_mass=1.0 Zbase=0.001 mixing_length_alpha=2.0
...
```

---

## Workflow Recommendations

### Workflow 1: Single Model Testing

**Goal**: Test MESA setup and run single model

```bash
# 1. Build container
singularity pull nudome_16.0.sif docker://nugrid/nudome:16.0

# 2. Download MESA
wget https://zenodo.org/records/2630796/files/mesa-r9575.zip && unzip mesa-r9575.zip

# 3. Edit and submit single job
vim 01_single_mesa_run.slurm
sbatch 01_single_mesa_run.slurm

# 4. Monitor
squeue -u $USER
tail -f logs/mesa_*.out
```

### Workflow 2: Small Parameter Study (10-50 models)

**Goal**: Test different initial conditions

```bash
# 1. Pre-compile MESA
sbatch compile_mesa.slurm
# Wait for completion

# 2. Create parameter file
cat > ~/nudocker/config/parameter_list.txt <<EOF
initial_mass=7.0 Zbase=0.02
initial_mass=10.0 Zbase=0.02
initial_mass=15.0 Zbase=0.02
EOF

# 3. Edit and submit array job
vim 02_array_mesa_run.slurm
# Set: --array=1-3
sbatch 02_array_mesa_run.slurm

# 4. Monitor all jobs
watch -n 10 'squeue -u $USER'
```

### Workflow 3: Large Parameter Grid (100+ models)

**Goal**: Comprehensive parameter survey

```bash
# 1. Pre-compile MESA (essential!)
sbatch compile_mesa.slurm
# Wait for completion (~15-30 min)

# 2. Generate parameter grid
python3 generate_parameter_grid.py > ~/nudocker/config/parameter_grid.txt
# Creates 150 models

# 3. Edit and submit grid job
vim 04_large_grid.slurm
# Set: --array=1-150%20  (max 20 running)
sbatch 04_large_grid.slurm

# 4. Monitor progress
squeue -u $USER | wc -l  # Running jobs
ls ~/nudocker/runs/grid_study/ | wc -l  # Completed models
```

### Workflow 4: Multiple MESA Versions

**Goal**: Compare different MESA versions

```bash
# 1. Download multiple MESA versions
cd ~/nudocker/mesa
wget https://zenodo.org/records/2630796/files/mesa-r9575.zip && unzip mesa-r9575.zip
wget https://zenodo.org/records/3473377/files/mesa-r10398.zip && unzip mesa-r10398.zip

# 2. Build multiple containers
cd ~/nudocker/containers
singularity pull nudome_16.0.sif docker://nugrid/nudome:16.0
singularity pull nudome_18.0.sif docker://nugrid/nudome:18.0

# 3. Pre-compile each MESA version
# Edit compile_mesa.slurm for r9575
sbatch compile_mesa.slurm
# Edit for r10398
sbatch compile_mesa.slurm

# 4. Submit multiple independent jobs
vim 03_multiple_independent.slurm
# Configure JOBS array
bash 03_multiple_independent.slurm
```

---

## SLURM Commands Reference

### Job Submission

```bash
sbatch script.slurm              # Submit job
sbatch --array=1-10 script.slurm # Submit array
bash script.slurm                # For 03_multiple (not sbatch)
```

### Job Monitoring

```bash
squeue -u $USER                  # Your jobs
squeue -j <jobid>                # Specific job
scontrol show job <jobid>        # Detailed info
sacct -j <jobid>                 # Accounting info
```

### Job Control

```bash
scancel <jobid>                  # Cancel job
scancel -u $USER                 # Cancel all your jobs
scancel --name=mesa-grid         # Cancel by name
scontrol hold <jobid>            # Hold job
scontrol release <jobid>         # Release job
```

### Job Arrays

```bash
squeue -u $USER | grep "_"       # Show array tasks
scancel <jobid>_5                # Cancel specific task
scancel <jobid>_[10-20]          # Cancel range
```

### Resource Info

```bash
sinfo                            # Partition info
sinfo -Nel                       # Node list
scontrol show partition          # Partition details
```

---

## Troubleshooting

### Problem: Job pending for long time

```bash
# Check reason
squeue -u $USER -o "%.18i %.9P %.8j %.8u %.2t %.10M %.6D %R"

# Common reasons:
# - QOSMaxJobsPerUserLimit: Too many jobs running
# - Resources: Waiting for nodes/memory
# - Priority: Other users have higher priority

# Solution:
# - Reduce concurrent jobs: --array=1-100%10 (max 10)
# - Request fewer resources
# - Split large jobs into smaller batches
```

### Problem: Out of memory

```bash
# Check memory usage
sacct -j <jobid> --format=JobID,JobName,MaxRSS,Elapsed

# Solution:
# Edit SLURM script:
#SBATCH --mem=32G  # Increase memory
#SBATCH --mem=64G  # For large MESA runs
```

### Problem: Time limit exceeded

```bash
# Check runtime
sacct -j <jobid> --format=JobID,JobName,Elapsed,State

# Solution:
# Edit SLURM script:
#SBATCH --time=48:00:00  # Increase time limit
#SBATCH --time=72:00:00  # For long runs
```

### Problem: MESA not compiled

```bash
# Pre-compile MESA
sbatch compile_mesa.slurm

# Or increase job time to include compilation:
#SBATCH --time=24:00:00  # 30 min compile + run time
```

### Problem: Container not found

```bash
# Check container path
ls -lh ~/nudocker/containers/

# Pull container if missing
cd ~/nudocker/containers
singularity pull nudome_16.0.sif docker://nugrid/nudome:16.0
```

### Problem: Permission denied on MESA files

```bash
# Fix permissions
chmod -R u+w ~/nudocker/mesa/mesa-r9575/

# Check write access
touch ~/nudocker/mesa/mesa-r9575/test_write && rm ~/nudocker/mesa/mesa-r9575/test_write
```

---

## Best Practices

### 1. Pre-compile MESA

Always pre-compile MESA before submitting large job arrays:
```bash
sbatch compile_mesa.slurm  # Wait for completion
sbatch 04_large_grid.slurm  # Then submit grid
```

### 2. Use Job Throttling

Limit concurrent jobs to avoid overwhelming the cluster:
```bash
#SBATCH --array=1-100%20  # Max 20 running at once
```

### 3. Organize Output

Use descriptive directory names and organize results:
```bash
~/nudocker/runs/
├── grid_study/
│   ├── model_1_M7.0_Z0.02/
│   ├── model_2_M10.0_Z0.02/
│   └── ...
├── single_jobs/
└── test_runs/
```

### 4. Monitor Disk Usage

MESA runs can generate large files:
```bash
# Check disk usage
du -sh ~/nudocker/runs/*

# Clean old runs
rm -rf ~/nudocker/runs/test_runs/*
```

### 5. Archive Results

Transfer important results off cluster:
```bash
# Tar and compress
cd ~/nudocker/runs
tar czf grid_study_$(date +%Y%m%d).tar.gz grid_study/

# Transfer (from local machine)
scp user@hunren.cloud:~/nudocker/runs/grid_study_*.tar.gz .
```

### 6. Test First

Always test with small jobs before large submissions:
```bash
# Test single job
sbatch 01_single_mesa_run.slurm

# Test small array (3 models)
sbatch --array=1-3 02_array_mesa_run.slurm

# Then submit full grid
sbatch --array=1-150%20 04_large_grid.slurm
```

---

## Resource Guidelines

### CPU and Memory Requirements

| MESA Run Type | CPUs | Memory | Time | Notes |
|---------------|------|--------|------|-------|
| Small test case | 4-8 | 8-16 GB | 1-6 hours | Low mass, simple physics |
| Standard run | 8-16 | 16-32 GB | 6-24 hours | 1-15 Msun, standard physics |
| Large model | 16-32 | 32-64 GB | 24-72 hours | >15 Msun, complex physics |

### Disk Space Requirements

- MESA source (uncompiled): ~200-500 MB
- MESA compiled: ~1-3 GB
- Single run output: ~100 MB - 5 GB (depends on save frequency)
- Parameter grid (100 models): ~50-500 GB

### Recommended Job Limits

- Single jobs: No special limits
- Job arrays: Limit to 50 concurrent tasks (`--array=1-100%50`)
- Large grids: Limit to 20-30 concurrent tasks (`--array=1-500%25`)

---

## Additional Resources

### HUN-REN Documentation

- SLURM documentation: https://docs.slurm.science-cloud.hu
- Singularity guide: (check cluster documentation)
- Support: (contact HUN-REN support)

### MESA Resources

- MESA website: http://mesa.sourceforge.net
- MESA forums: http://mesastar.org
- Test suites: `$MESA_DIR/star/test_suite/`

### NuDocker Resources

- NuDocker repository: https://github.com/NuGrid/NuDocker
- Docker images: https://hub.docker.com/r/nugrid/nudome
- Complete guide: `../HUN-REN_SLURM_GUIDE.md`

---

## Quick Command Reference Card

```bash
# SETUP
module load apptainer
singularity pull nudome_16.0.sif docker://nugrid/nudome:16.0
wget https://zenodo.org/records/2630796/files/mesa-r9575.zip && unzip mesa-r9575.zip

# SUBMIT JOBS
sbatch 01_single_mesa_run.slurm                    # Single job
sbatch 02_array_mesa_run.slurm                     # Array (edit --array)
bash 03_multiple_independent.slurm                 # Multiple jobs
sbatch 04_large_grid.slurm                         # Large grid
sbatch compile_mesa.slurm                          # Pre-compile

# MONITOR
squeue -u $USER                                    # Your jobs
squeue -u $USER -o "%.18i %.9P %.8j %.2t %.10M"   # Compact view
watch -n 10 'squeue -u $USER'                      # Auto-refresh

# CONTROL
scancel <jobid>                                    # Cancel job
scancel -u $USER                                   # Cancel all
scontrol show job <jobid>                          # Job details

# RESULTS
tail -f logs/mesa_*.out                            # Follow output
ls ~/nudocker/runs/                                # List results
du -sh ~/nudocker/runs/*                           # Check sizes
```

---

**Version**: 1.0
**Date**: 2025-11-18
**License**: BSD 3-Clause
**Maintainer**: NuGrid Team
