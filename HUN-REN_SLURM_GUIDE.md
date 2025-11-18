# NuDocker on HUN-REN Cloud SLURM Cluster

**Complete guide for running NuDocker on HUN-REN Science Cloud with Singularity**

Last Updated: 2025-11-18

---

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Building Singularity Containers](#building-singularity-containers)
- [Single Job Submission](#single-job-submission)
- [Running Multiple Containers](#running-multiple-containers)
- [Parameter Studies](#parameter-studies)
- [Data Management](#data-management)
- [Best Practices](#best-practices)
- [Troubleshooting](#troubleshooting)
- [Complete Examples](#complete-examples)

---

## Overview

### What is HUN-REN Science Cloud?

HUN-REN Science Cloud provides SLURM (Simple Linux Utility for Resource Management) as a Platform-as-a-Service (PaaS) for high-performance computing. It supports:
- **Singularity/Apptainer containers** for reproducible computing
- **GPU resources** (NVIDIA GRID 550.144.03, CUDA 11.8)
- **FIFO job scheduling** across compute nodes
- **7-day resource allocations**

### Why NuDocker on HUN-REN?

✅ **Perfect for MESA research**:
- Run multiple MESA versions in parallel
- Reproducible stellar evolution calculations
- Parameter studies across many models
- Preserve computational environments

✅ **Benefits of this setup**:
- No Docker installation needed (uses Singularity)
- Scalable to hundreds of parallel jobs
- Shared file system for results
- Professional HPC environment

---

## Prerequisites

### 1. HUN-REN Cloud Access

**Get access**:
```bash
# Contact for access
Email: info@science-cloud.hu
Purpose: MESA stellar evolution calculations
Duration: Specify required time
```

**Login to cluster**:
```bash
ssh username@slurm.science-cloud.hu
# (Replace with actual hostname provided)
```

### 2. Required Software

Already available on HUN-REN:
- ✅ Singularity/Apptainer
- ✅ SLURM workload manager
- ✅ CUDA 11.8 (for GPU jobs)

### 3. Directory Structure

Create organized workspace:
```bash
# On HUN-REN cluster
mkdir -p ~/nudocker
mkdir -p ~/nudocker/containers    # Singularity images
mkdir -p ~/nudocker/mesa          # MESA source code
mkdir -p ~/nudocker/runs          # Simulation runs
mkdir -p ~/nudocker/scripts       # SLURM batch scripts
mkdir -p ~/nudocker/logs          # Job logs

cd ~/nudocker
```

---

## Building Singularity Containers

### Method 1: Pull from Docker Hub (Recommended)

**Pull NuDocker image**:
```bash
# On HUN-REN cluster login node
cd ~/nudocker/containers

# Pull specific NuDocker version
singularity pull nudome_16.0.sif docker://nugrid/nudome:16.0
singularity pull nudome_18.0.sif docker://nugrid/nudome:18.0
singularity pull nudome_20.031.sif docker://nugrid/nudome:20.031
singularity pull nudome_20.1.sif docker://nugrid/nudome:20.1

# Wait 5-15 minutes for download and conversion
```

**Verify image**:
```bash
singularity inspect nudome_16.0.sif
ls -lh *.sif
# Should show ~1-3 GB per image
```

### Method 2: Build from Definition File (Advanced)

**Create definition file** (`nudome_custom.def`):
```singularity
Bootstrap: docker
From: nugrid/nudome:20.1

%post
    # Add custom packages or configurations
    # Example: additional Python packages
    pip3 install matplotlib numpy scipy

%environment
    export MESA_DIR=/home/user/mesa
    export MESASDK_ROOT=/home/user/mesasdk
    export OMP_NUM_THREADS=4

%runscript
    #!/bin/bash
    source $MESASDK_ROOT/bin/mesasdk_init.sh
    cd $MESA_DIR
    exec bash "$@"

%help
    Custom NuDocker container for HUN-REN SLURM cluster
    Based on nugrid/nudome:20.1

    Usage:
        singularity run nudome_custom.sif
```

**Build container** (if you have fakeroot or sudo):
```bash
# With fakeroot (if available)
singularity build --fakeroot nudome_custom.sif nudome_custom.def

# Or request build on login node
singularity build nudome_custom.sif nudome_custom.def
```

---

## Single Job Submission

### Prepare MESA Source Code

```bash
# Download MESA on cluster
cd ~/nudocker/mesa
wget https://zenodo.org/records/2630796/files/mesa-r9575.zip
unzip mesa-r9575.zip

# Or transfer from local machine
scp mesa-r9575.zip username@slurm.science-cloud.hu:~/nudocker/mesa/
```

### Basic SLURM Job Script

**Create** `submit_single_mesa.slurm`:
```bash
#!/bin/bash
#SBATCH --job-name=mesa-r9575          # Job name
#SBATCH --partition=normal              # Partition (check available)
#SBATCH --nodes=1                       # Number of nodes
#SBATCH --ntasks=1                      # Number of tasks
#SBATCH --cpus-per-task=8               # CPUs per task
#SBATCH --mem=16G                       # Memory per node
#SBATCH --time=24:00:00                 # Time limit (24 hours)
#SBATCH --output=logs/mesa_%j.out       # Standard output log
#SBATCH --error=logs/mesa_%j.err        # Standard error log

# Job information
echo "========================================="
echo "Job ID: $SLURM_JOB_ID"
echo "Job name: $SLURM_JOB_NAME"
echo "Node: $SLURM_NODELIST"
echo "Start time: $(date)"
echo "========================================="

# Paths
CONTAINER=~/nudocker/containers/nudome_16.0.sif
MESA_SRC=~/nudocker/mesa/mesa-r9575
WORK_DIR=~/nudocker/runs/mesa-r9575-job-${SLURM_JOB_ID}

# Create work directory
mkdir -p $WORK_DIR
cd $WORK_DIR

# Run Singularity container
singularity exec \
    --bind ${MESA_SRC}:/home/user/mesa \
    --bind ${WORK_DIR}:/home/user/work \
    ${CONTAINER} \
    bash -c "
        source /home/user/mesasdk/bin/mesasdk_init.sh
        export OMP_NUM_THREADS=${SLURM_CPUS_PER_TASK}
        cd /home/user/mesa

        # Compile MESA if not already compiled
        if [ ! -f make/makefile ]; then
            echo 'Installing MESA...'
            ./install
        fi

        # Run test case
        cd /home/user/mesa/star/test_suite/7M_prems_to_AGB
        ./mk
        ./rn

        # Copy results to work directory
        cp -r LOGS /home/user/work/
        cp -r photos /home/user/work/ 2>/dev/null || true
    "

echo "========================================="
echo "Job finished at: $(date)"
echo "Results in: $WORK_DIR"
echo "========================================="
```

**Submit job**:
```bash
cd ~/nudocker/scripts
sbatch submit_single_mesa.slurm
```

**Monitor job**:
```bash
# Check job status
squeue -u $USER

# Check job details
scontrol show job <job_id>

# View output
tail -f ~/nudocker/logs/mesa_<job_id>.out

# Cancel job if needed
scancel <job_id>
```

---

## Running Multiple Containers

### Method 1: Job Arrays (Recommended for Parameter Studies)

**Create** `submit_array_mesa.slurm`:
```bash
#!/bin/bash
#SBATCH --job-name=mesa-array           # Job name
#SBATCH --array=1-10                    # Array indices (10 jobs)
#SBATCH --partition=normal
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=8G
#SBATCH --time=12:00:00
#SBATCH --output=logs/mesa_array_%A_%a.out
#SBATCH --error=logs/mesa_array_%A_%a.err

echo "========================================="
echo "Array Job ID: $SLURM_ARRAY_JOB_ID"
echo "Array Task ID: $SLURM_ARRAY_TASK_ID"
echo "Node: $SLURM_NODELIST"
echo "========================================="

# Paths
CONTAINER=~/nudocker/containers/nudome_20.1.sif
MESA_SRC=~/nudocker/mesa/mesa-r15140
WORK_DIR=~/nudocker/runs/array-job-${SLURM_ARRAY_JOB_ID}/task-${SLURM_ARRAY_TASK_ID}

# Parameter file (define different parameters for each task)
PARAM_FILE=~/nudocker/scripts/parameters.txt
PARAMS=$(sed -n "${SLURM_ARRAY_TASK_ID}p" $PARAM_FILE)

# Parse parameters (e.g., "1.5 0.02" for mass and metallicity)
MASS=$(echo $PARAMS | awk '{print $1}')
METALLICITY=$(echo $PARAMS | awk '{print $2}')

echo "Running with:"
echo "  Mass: $MASS M☉"
echo "  Metallicity: $METALLICITY"

mkdir -p $WORK_DIR
cd $WORK_DIR

# Run simulation
singularity exec \
    --bind ${MESA_SRC}:/home/user/mesa \
    --bind ${WORK_DIR}:/home/user/work \
    ${CONTAINER} \
    bash -c "
        source /home/user/mesasdk/bin/mesasdk_init.sh
        export OMP_NUM_THREADS=${SLURM_CPUS_PER_TASK}

        # Create run directory
        cd /home/user/work
        cp -r /home/user/mesa/star/work/* .

        # Modify inlists with parameters
        sed -i 's/initial_mass.*/initial_mass = ${MASS}/' inlist_project
        sed -i 's/initial_z.*/initial_z = ${METALLICITY}/' inlist_project

        # Run MESA
        ./mk
        ./rn

        echo 'Simulation complete!'
    "

echo "Results saved to: $WORK_DIR"
```

**Create parameter file** (`parameters.txt`):
```bash
# Each line: mass metallicity
1.0 0.02
1.5 0.02
2.0 0.02
2.5 0.02
3.0 0.02
1.0 0.01
1.5 0.01
2.0 0.01
2.5 0.01
3.0 0.01
```

**Submit array job**:
```bash
sbatch submit_array_mesa.slurm
```

**Monitor array jobs**:
```bash
# Check all tasks
squeue -u $USER

# Check specific array job
squeue -j <array_job_id>

# Check individual task
squeue -j <array_job_id>_<task_id>
```

### Method 2: Multiple Independent Jobs

**Submit multiple jobs in parallel**:
```bash
#!/bin/bash
# submit_multiple.sh - Submit multiple independent MESA runs

for mass in 1.0 1.5 2.0 2.5 3.0; do
    for Z in 0.01 0.02 0.03; do
        # Create job-specific script
        cat > submit_m${mass}_z${Z}.slurm << EOF
#!/bin/bash
#SBATCH --job-name=mesa-m${mass}-z${Z}
#SBATCH --partition=normal
#SBATCH --nodes=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=8G
#SBATCH --time=12:00:00
#SBATCH --output=logs/mesa_m${mass}_z${Z}_%j.out

# Run simulation for mass=${mass}, Z=${Z}
singularity exec \\
    --bind ~/nudocker/mesa/mesa-r15140:/home/user/mesa \\
    --bind ~/nudocker/runs/m${mass}_z${Z}:/home/user/work \\
    ~/nudocker/containers/nudome_20.1.sif \\
    bash -c "
        source /home/user/mesasdk/bin/mesasdk_init.sh
        export OMP_NUM_THREADS=4
        cd /home/user/work
        cp -r /home/user/mesa/star/work/* .
        sed -i 's/initial_mass.*/initial_mass = ${mass}/' inlist_project
        sed -i 's/initial_z.*/initial_z = ${Z}/' inlist_project
        ./mk && ./rn
    "
EOF

        # Submit job
        sbatch submit_m${mass}_z${Z}.slurm

        # Brief pause to avoid overwhelming scheduler
        sleep 1
    done
done

echo "Submitted $(( 5 * 3 )) jobs"
```

**Execute**:
```bash
chmod +x submit_multiple.sh
./submit_multiple.sh
```

---

## Parameter Studies

### Large-Scale Parameter Exploration

**Example: 100 models with varying mass and metallicity**

**Create parameter file** (`param_grid.txt`):
```bash
# Generate 100 parameter combinations
python3 << 'EOF'
import numpy as np

masses = np.linspace(0.8, 8.0, 10)  # 10 masses
metallicities = np.logspace(-4, -1, 10)  # 10 metallicities

with open('param_grid.txt', 'w') as f:
    for m in masses:
        for z in metallicities:
            f.write(f"{m:.3f} {z:.6f}\n")
EOF

# Verify
wc -l param_grid.txt  # Should show 100
```

**Submit as job array**:
```bash
#!/bin/bash
#SBATCH --array=1-100%20   # 100 jobs, max 20 running simultaneously
#SBATCH --job-name=mesa-grid
#SBATCH --cpus-per-task=4
#SBATCH --mem=8G
#SBATCH --time=24:00:00

# ... rest of array job script
```

**The `%20` limits concurrent jobs to 20** to avoid overwhelming the scheduler.

---

## Data Management

### File Organization

**Recommended structure**:
```
~/nudocker/
├── containers/
│   ├── nudome_16.0.sif       # ~1.5 GB
│   ├── nudome_18.0.sif
│   └── nudome_20.1.sif
├── mesa/
│   ├── mesa-r9575/           # Source code
│   ├── mesa-r15140/
│   └── compiled/             # Pre-compiled versions
├── runs/
│   ├── job-12345/            # Individual job results
│   ├── array-job-67890/
│   │   ├── task-1/
│   │   ├── task-2/
│   │   └── ...
│   └── parameter-study-2025/
├── scripts/
│   ├── submit_single.slurm
│   ├── submit_array.slurm
│   └── parameters.txt
└── logs/
    ├── mesa_12345.out
    └── mesa_12345.err
```

### Data Transfer

**From cluster to local machine**:
```bash
# On local machine
# Transfer specific results
scp -r username@slurm.science-cloud.hu:~/nudocker/runs/job-12345/LOGS ./

# Transfer all results
rsync -avz --progress \
    username@slurm.science-cloud.hu:~/nudocker/runs/ \
    ./hun-ren-results/

# Compress before transfer (saves bandwidth)
ssh username@slurm.science-cloud.hu \
    "cd ~/nudocker/runs && tar czf results.tar.gz job-12345/"
scp username@slurm.science-cloud.hu:~/nudocker/runs/results.tar.gz ./
```

**Automated result collection**:
```bash
# Add to end of SLURM script
# Archive results
cd $WORK_DIR/..
tar czf task-${SLURM_ARRAY_TASK_ID}.tar.gz task-${SLURM_ARRAY_TASK_ID}/

# Copy to shared archive location
cp task-${SLURM_ARRAY_TASK_ID}.tar.gz ~/nudocker/archive/
```

### Storage Quotas

Check your usage:
```bash
# Check disk usage
du -sh ~/nudocker/*

# Check quota (if quota system enabled)
quota -s

# Clean up old jobs
find ~/nudocker/runs -name "*.tar.gz" -mtime +30 -delete
```

---

## Best Practices

### 1. Resource Allocation

**CPU allocation**:
```bash
# Set OMP_NUM_THREADS to match requested CPUs
#SBATCH --cpus-per-task=8
export OMP_NUM_THREADS=8  # or ${SLURM_CPUS_PER_TASK}
```

**Memory estimation**:
- MESA compilation: 4-8 GB
- MESA run (typical): 2-4 GB per CPU
- Safety factor: Request 20% more

**Time limits**:
```bash
# Test run: 1-2 hours
#SBATCH --time=02:00:00

# Full production run: 24-72 hours
#SBATCH --time=48:00:00

# Very long run: use checkpointing
```

### 2. Checkpointing

**Enable MESA checkpointing**:
```fortran
! In inlist_controls
&controls
    ! Save photos for restart
    photo_interval = 100
    photo_directory = 'photos'

    ! Restart from photo
    load_saved_photo = .true.
    saved_photo_name = 'photo_100'
&end
```

**SLURM restart script**:
```bash
#!/bin/bash
# submit_with_restart.slurm
#SBATCH --time=24:00:00

# Check if photo exists to restart
if [ -f photos/photo_latest ]; then
    echo "Restarting from checkpoint"
    RESTART="--restart"
else
    echo "Starting new run"
    RESTART=""
fi

# Run MESA (with automatic restart if time limit reached)
```

### 3. Pre-compile MESA

**Compile once, use many times**:
```bash
# Dedicated compilation job
sbatch compile_mesa.slurm

# In compile_mesa.slurm:
singularity exec \
    --bind ~/nudocker/mesa/mesa-r15140:/home/user/mesa \
    ~/nudocker/containers/nudome_20.1.sif \
    bash -c "
        source /home/user/mesasdk/bin/mesasdk_init.sh
        cd /home/user/mesa
        ./install
    "

# Then in run jobs, skip compilation
```

### 4. GPU Usage (if available)

**Request GPU**:
```bash
#SBATCH --gres=gpu:nvidia:1
#SBATCH --partition=gpu  # Use GPU partition if available

# HUN-REN supports CUDA 11.8
# Container automatically uses --nv flag
```

### 5. Efficient Job Submission

**Don't overwhelm scheduler**:
```bash
# Good: Use job arrays
#SBATCH --array=1-100%20  # Max 20 concurrent

# Bad: Submit 100 individual jobs at once
```

**Test before large runs**:
```bash
# Quick test with 1 model
#SBATCH --array=1

# Then scale up
#SBATCH --array=1-100%20
```

---

## Troubleshooting

### Issue: Singularity not found

**Solution**:
```bash
# Load Singularity module (if needed)
module load singularity

# Or use full path
/usr/bin/singularity exec ...
```

### Issue: Container fails to start

**Check**:
```bash
# Test container locally
singularity shell nudome_16.0.sif

# Check bindings
ls /home/user/mesa  # Should show MESA files
```

**Debug**:
```bash
# Run with verbose output
singularity --debug exec ...
```

### Issue: Out of memory

**Solution**:
```bash
# Increase memory request
#SBATCH --mem=32G  # Was 16G

# Or reduce OMP_NUM_THREADS
export OMP_NUM_THREADS=4  # Was 8
```

### Issue: Job time limit

**Solutions**:
```bash
# 1. Increase time limit
#SBATCH --time=72:00:00

# 2. Use checkpointing (see above)

# 3. Split into multiple jobs
```

### Issue: Disk quota exceeded

**Clean up**:
```bash
# Remove old logs
find ~/nudocker/logs -name "*.out" -mtime +7 -delete

# Archive and compress results
cd ~/nudocker/runs
for dir in job-*; do
    tar czf ${dir}.tar.gz $dir/ && rm -rf $dir/
done

# Transfer to local storage
```

### Issue: MESA compilation fails

**Check**:
```bash
# Verify MESA SDK is sourced
echo $MESASDK_ROOT  # Should be /home/user/mesasdk

# Check MESA version compatibility
# Use correct container for MESA version
```

---

## Complete Examples

### Example 1: Single MESA Run (Test Case)

**Full workflow**:
```bash
# 1. Setup on HUN-REN
ssh username@slurm.science-cloud.hu
mkdir -p ~/nudocker/{containers,mesa,runs,scripts,logs}

# 2. Get container
cd ~/nudocker/containers
singularity pull nudome_16.0.sif docker://nugrid/nudome:16.0

# 3. Get MESA
cd ~/nudocker/mesa
wget https://zenodo.org/records/2630796/files/mesa-r9575.zip
unzip mesa-r9575.zip

# 4. Create job script
cd ~/nudocker/scripts
cat > test_run.slurm << 'EOF'
#!/bin/bash
#SBATCH --job-name=mesa-test
#SBATCH --cpus-per-task=4
#SBATCH --mem=8G
#SBATCH --time=04:00:00
#SBATCH --output=../logs/test_%j.out

singularity exec \
    --bind ~/nudocker/mesa/mesa-r9575:/home/user/mesa \
    --bind ~/nudocker/runs/test-$SLURM_JOB_ID:/home/user/work \
    ~/nudocker/containers/nudome_16.0.sif \
    bash -c "
        source /home/user/mesasdk/bin/mesasdk_init.sh
        export OMP_NUM_THREADS=4
        cd /home/user/mesa
        ./install
        cd star/test_suite/7M_prems_to_AGB
        ./mk && ./rn
        cp -r LOGS /home/user/work/
    "
EOF

# 5. Submit
sbatch test_run.slurm

# 6. Monitor
squeue -u $USER
tail -f ../logs/test_*.out
```

### Example 2: Parameter Study (10 Models)

**Full workflow**:
```bash
# 1. Create parameter file
cd ~/nudocker/scripts
cat > params.txt << 'EOF'
1.0 0.02
1.5 0.02
2.0 0.02
2.5 0.02
3.0 0.02
1.0 0.01
1.5 0.01
2.0 0.01
2.5 0.01
3.0 0.01
EOF

# 2. Create array job
cat > param_study.slurm << 'EOF'
#!/bin/bash
#SBATCH --job-name=param-study
#SBATCH --array=1-10
#SBATCH --cpus-per-task=4
#SBATCH --mem=8G
#SBATCH --time=12:00:00
#SBATCH --output=../logs/study_%A_%a.out

# Get parameters for this task
PARAMS=$(sed -n "${SLURM_ARRAY_TASK_ID}p" params.txt)
MASS=$(echo $PARAMS | awk '{print $1}')
METALLICITY=$(echo $PARAMS | awk '{print $2}')

WORK_DIR=~/nudocker/runs/study-${SLURM_ARRAY_JOB_ID}/m${MASS}_z${METALLICITY}
mkdir -p $WORK_DIR

singularity exec \
    --bind ~/nudocker/mesa/mesa-r15140:/home/user/mesa \
    --bind ${WORK_DIR}:/home/user/work \
    ~/nudocker/containers/nudome_20.1.sif \
    bash -c "
        source /home/user/mesasdk/bin/mesasdk_init.sh
        export OMP_NUM_THREADS=4
        cd /home/user/work
        cp -r /home/user/mesa/star/work/* .

        # Set parameters
        sed -i \"s/initial_mass.*/initial_mass = ${MASS}/\" inlist_project
        sed -i \"s/initial_z.*/initial_z = ${METALLICITY}/\" inlist_project

        ./mk && ./rn

        # Archive results
        tar czf results.tar.gz LOGS photos
    "
EOF

# 3. Submit
sbatch param_study.slurm

# 4. Monitor all tasks
watch -n 10 'squeue -u $USER'

# 5. Collect results when done
cd ~/nudocker/runs
tar czf parameter_study_results.tar.gz study-*/
scp parameter_study_results.tar.gz user@local:~/
```

### Example 3: Large-Scale Grid (100 Models)

**Complete script** (`massive_grid.sh`):
```bash
#!/bin/bash
# Run 100-model parameter grid on HUN-REN

# Generate parameters
python3 << 'PYEOF'
import numpy as np
masses = np.linspace(0.8, 8.0, 10)
metallicities = np.logspace(-4, -1, 10)
with open('grid_params.txt', 'w') as f:
    for m in masses:
        for z in metallicities:
            f.write(f"{m:.3f} {z:.6f}\n")
PYEOF

# Create job script
cat > grid_job.slurm << 'EOF'
#!/bin/bash
#SBATCH --job-name=mesa-grid
#SBATCH --array=1-100%20        # Max 20 concurrent jobs
#SBATCH --cpus-per-task=4
#SBATCH --mem=8G
#SBATCH --time=24:00:00
#SBATCH --output=logs/grid_%A_%a.out

PARAMS=$(sed -n "${SLURM_ARRAY_TASK_ID}p" grid_params.txt)
MASS=$(echo $PARAMS | awk '{print $1}')
Z=$(echo $PARAMS | awk '{print $2}')

WORK_DIR=~/nudocker/runs/grid-${SLURM_ARRAY_JOB_ID}/model_${SLURM_ARRAY_TASK_ID}
mkdir -p $WORK_DIR

echo "Running model ${SLURM_ARRAY_TASK_ID}: M=${MASS}, Z=${Z}"

singularity exec \
    --bind ~/nudocker/mesa/mesa-r15140:/home/user/mesa \
    --bind ${WORK_DIR}:/home/user/work \
    ~/nudocker/containers/nudome_20.1.sif \
    bash -c "
        source /home/user/mesasdk/bin/mesasdk_init.sh
        export OMP_NUM_THREADS=${SLURM_CPUS_PER_TASK}
        cd /home/user/work
        cp -r /home/user/mesa/star/work/* .
        sed -i \"s/initial_mass.*/initial_mass = ${MASS}/\" inlist_project
        sed -i \"s/initial_z.*/initial_z = ${Z}/\" inlist_project
        ./mk && ./rn

        # Save summary
        echo \"Model ${SLURM_ARRAY_TASK_ID}: M=${MASS} Z=${Z}\" > summary.txt
        tail -20 LOGS/out.txt >> summary.txt

        # Compress
        tar czf model_${SLURM_ARRAY_TASK_ID}.tar.gz LOGS summary.txt
    "

echo "Model ${SLURM_ARRAY_TASK_ID} complete"
EOF

# Submit
sbatch grid_job.slurm

echo "Submitted 100-model grid"
echo "Monitor with: squeue -u $USER"
echo "Results will be in: ~/nudocker/runs/grid-*/"
```

---

## Summary

### Can You Run Many NuDocker Containers?

**Yes! HUN-REN SLURM cluster is perfect for running many NuDocker containers in parallel.**

✅ **Scalability**:
- Run 10s to 100s of containers simultaneously
- Job arrays handle parameter studies elegantly
- SLURM manages resource allocation automatically

✅ **Efficiency**:
- Singularity containers start in seconds
- Shared MESA installation across jobs
- Parallel execution on multiple compute nodes

✅ **Flexibility**:
- Different MESA versions for different jobs
- Mix CPU-only and GPU jobs
- Independent or coupled simulations

### Recommended Workflow

1. **Prepare**: Pull Singularity images, download MESA
2. **Test**: Run single job to verify setup
3. **Scale**: Submit job array for parameter study
4. **Monitor**: Use `squeue` and log files
5. **Collect**: Transfer results to local machine

### Performance Expectations

| Job Type | Setup Time | Run Time | Scalability |
|----------|------------|----------|-------------|
| Single test | 5 min | 1-4 hours | N/A |
| 10 models | 5 min | 12-24 hours | Linear |
| 100 models | 10 min | 24-72 hours | ~20 concurrent |
| 1000 models | 15 min | 3-7 days | ~50 concurrent |

### Key Advantages

1. **No local resources needed** - Run on HUN-REN hardware
2. **Reproducible** - Singularity ensures consistent environment
3. **Scalable** - From 1 to 100+ parallel jobs
4. **Professional** - HPC-grade infrastructure
5. **Cost-effective** - Shared resource platform

---

**You are now ready to run NuDocker on HUN-REN Cloud SLURM cluster!** 🚀

For questions or issues:
- HUN-REN support: info@science-cloud.hu
- NuDocker issues: https://github.com/NuGrid/NuDocker/issues
- MESA support: http://mesastar.org

*Last updated: 2025-11-18*
