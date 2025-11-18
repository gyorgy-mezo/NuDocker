#!/bin/bash
#SBATCH --job-name=mesa-array          # Job name
#SBATCH --partition=normal              # Partition name (adjust as needed)
#SBATCH --nodes=1                       # Number of nodes per task
#SBATCH --ntasks=1                      # Number of tasks
#SBATCH --cpus-per-task=8               # CPUs per task
#SBATCH --mem=16G                       # Memory per node
#SBATCH --time=24:00:00                 # Time limit (24 hours)
#SBATCH --array=1-10                    # Array range (1-10 jobs)
#SBATCH --output=logs/mesa_array_%A_%a.out   # Standard output log
#SBATCH --error=logs/mesa_array_%A_%a.err    # Standard error log

################################################################################
# NuDocker MESA Job Array on HUN-REN SLURM Cluster
#
# This script runs multiple MESA simulations in parallel using SLURM job arrays
#
# Usage:
#   1. Adjust paths and parameters below
#   2. Create parameter_list.txt with one parameter set per line
#   3. Submit: sbatch 02_array_mesa_run.slurm
#   4. Monitor: squeue -u $USER
#
# Requirements:
#   - Singularity container at: ~/nudocker/containers/nudome_XX.X.sif
#   - MESA source at: ~/nudocker/mesa/mesa-rXXXXX/
#   - Parameter file: ~/nudocker/config/parameter_list.txt
#   - Output directory: ~/nudocker/runs/
################################################################################

# ============================================================================
# CONFIGURATION - ADJUST THESE PATHS FOR YOUR SETUP
# ============================================================================

# Container path (choose your version)
CONTAINER=~/nudocker/containers/nudome_16.0.sif

# MESA source directory
MESA_SRC=~/nudocker/mesa/mesa-r9575

# Base work directory for all jobs
BASE_WORK_DIR=~/nudocker/runs

# Parameter file (one parameter set per line, indexed by array task ID)
PARAMETER_FILE=~/nudocker/config/parameter_list.txt

# Test case to run (relative to MESA_SRC)
TEST_CASE="star/test_suite/7M_prems_to_AGB"

# ============================================================================
# JOB ARRAY EXECUTION - Usually no need to modify below
# ============================================================================

echo "========================================="
echo "NuDocker MESA Job Array"
echo "========================================="
echo "Job ID: $SLURM_JOB_ID"
echo "Array Job ID: $SLURM_ARRAY_JOB_ID"
echo "Array Task ID: $SLURM_ARRAY_TASK_ID"
echo "Job name: $SLURM_JOB_NAME"
echo "Node: $SLURM_NODELIST"
echo "CPUs: $SLURM_CPUS_PER_TASK"
echo "Memory: ${SLURM_MEM_PER_NODE}MB"
echo "Start time: $(date)"
echo "========================================="

# Create work directory for this specific array task
WORK_DIR=${BASE_WORK_DIR}/array-${SLURM_ARRAY_JOB_ID}-task-${SLURM_ARRAY_TASK_ID}
mkdir -p $WORK_DIR
cd $WORK_DIR

# Read parameters for this array task (line number = array task ID)
if [[ -f "$PARAMETER_FILE" ]]; then
    PARAMS=$(sed -n "${SLURM_ARRAY_TASK_ID}p" "$PARAMETER_FILE")
    echo "Parameters for task ${SLURM_ARRAY_TASK_ID}: $PARAMS"
else
    echo "WARNING: Parameter file not found: $PARAMETER_FILE"
    echo "Using default parameters"
    PARAMS=""
fi

# Display container info
echo ""
echo "Container: $CONTAINER"
singularity --version
ls -lh $CONTAINER

echo ""
echo "Running MESA in container (array task ${SLURM_ARRAY_TASK_ID})..."
echo ""

# Run Singularity container
singularity exec \
    --bind ${MESA_SRC}:/home/user/mesa \
    --bind ${WORK_DIR}:/home/user/work \
    ${CONTAINER} \
    bash <<MESA_SCRIPT
        # Source MESA SDK
        source /home/user/mesasdk/bin/mesasdk_init.sh

        # Set OMP threads from SLURM
        export OMP_NUM_THREADS=${SLURM_CPUS_PER_TASK:-8}

        echo "MESA_DIR: \$MESA_DIR"
        echo "MESASDK_ROOT: \$MESASDK_ROOT"
        echo "OMP_NUM_THREADS: \$OMP_NUM_THREADS"
        echo "Array Task ID: ${SLURM_ARRAY_TASK_ID}"
        echo "Parameters: ${PARAMS}"
        echo ""

        cd /home/user/mesa

        # Check if MESA is compiled
        if [ ! -f make/makefile ]; then
            echo "MESA not compiled. Installing..."
            echo "This may take 10-30 minutes..."
            ./install

            if [ \$? -ne 0 ]; then
                echo "ERROR: MESA installation failed!"
                exit 1
            fi
            echo "MESA installation complete!"
        else
            echo "MESA already compiled, skipping installation"
        fi

        # Navigate to test case
        cd ${TEST_CASE}

        if [ ! -d "\$(pwd)" ]; then
            echo "ERROR: Test case directory not found: ${TEST_CASE}"
            exit 1
        fi

        echo ""
        echo "Running test case: ${TEST_CASE}"
        echo "Working directory: \$(pwd)"
        echo "Array task: ${SLURM_ARRAY_TASK_ID}"
        echo ""

        # Copy test case to work directory
        cp -r * /home/user/work/

        cd /home/user/work

        # Apply parameters if provided
        if [[ -n "${PARAMS}" ]]; then
            echo "Applying parameters: ${PARAMS}"
            # Parse parameters and modify inlist files
            # Example: PARAMS="initial_mass=7.0 Zbase=0.02"
            for param in ${PARAMS}; do
                key=\${param%%=*}
                value=\${param#*=}
                echo "  Setting \$key = \$value"
                # Modify inlist (adjust pattern as needed for your setup)
                sed -i "s/^\s*\$key\s*=.*/  \$key = \$value/" inlist_project 2>/dev/null || true
            done
        fi

        # Compile test case
        echo ""
        echo "Compiling test case..."
        ./mk

        if [ \$? -ne 0 ]; then
            echo "ERROR: Test case compilation failed!"
            exit 1
        fi

        # Run test case
        echo ""
        echo "Running simulation..."
        echo "Started at: \$(date)"
        ./rn

        RUN_STATUS=\$?
        echo "Finished at: \$(date)"

        if [ \$RUN_STATUS -eq 0 ]; then
            echo ""
            echo "SUCCESS: Simulation completed successfully!"

            # Create summary
            echo "Creating result summary..."
            cat > /home/user/work/summary.txt <<SUMMARY
MESA Run Summary (Array Task ${SLURM_ARRAY_TASK_ID})
======================================================
Job ID: ${SLURM_JOB_ID}
Array Job ID: ${SLURM_ARRAY_JOB_ID}
Array Task ID: ${SLURM_ARRAY_TASK_ID}
MESA Version: \$(basename \$MESA_DIR)
Test Case: ${TEST_CASE}
Parameters: ${PARAMS}
Completed: \$(date)
OMP Threads: \$OMP_NUM_THREADS

Final Output:
SUMMARY
            tail -30 LOGS/out.txt >> /home/user/work/summary.txt 2>/dev/null || true
        else
            echo ""
            echo "ERROR: Simulation failed with exit code \$RUN_STATUS"
            exit \$RUN_STATUS
        fi
MESA_SCRIPT

SINGULARITY_STATUS=$?

echo ""
echo "========================================="
if [ $SINGULARITY_STATUS -eq 0 ]; then
    echo "Array task ${SLURM_ARRAY_TASK_ID} completed successfully!"
    echo "Results saved to: $WORK_DIR"
    echo ""
    echo "Result files:"
    ls -lh $WORK_DIR/
else
    echo "Array task ${SLURM_ARRAY_TASK_ID} failed with exit code: $SINGULARITY_STATUS"
    echo "Check logs at: $WORK_DIR/LOGS/"
fi
echo "Finished at: $(date)"
echo "========================================="

exit $SINGULARITY_STATUS
