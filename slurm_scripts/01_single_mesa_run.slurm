#!/bin/bash
#SBATCH --job-name=mesa-single          # Job name
#SBATCH --partition=normal               # Partition name (adjust as needed)
#SBATCH --nodes=1                        # Number of nodes
#SBATCH --ntasks=1                       # Number of tasks
#SBATCH --cpus-per-task=8                # CPUs per task
#SBATCH --mem=16G                        # Memory per node
#SBATCH --time=24:00:00                  # Time limit (24 hours)
#SBATCH --output=logs/mesa_%j.out        # Standard output log
#SBATCH --error=logs/mesa_%j.err         # Standard error log

################################################################################
# NuDocker Single MESA Run on HUN-REN SLURM Cluster
#
# This script runs a single MESA simulation using NuDocker Singularity container
#
# Usage:
#   1. Adjust paths below for your setup
#   2. Submit: sbatch 01_single_mesa_run.slurm
#   3. Monitor: squeue -u $USER
#
# Requirements:
#   - Singularity container at: ~/nudocker/containers/nudome_XX.X.sif
#   - MESA source at: ~/nudocker/mesa/mesa-rXXXXX/
#   - Output directory: ~/nudocker/runs/
################################################################################

# ============================================================================
# CONFIGURATION - ADJUST THESE PATHS FOR YOUR SETUP
# ============================================================================

# Container path (choose your version)
CONTAINER=~/nudocker/containers/nudome_16.0.sif

# MESA source directory
MESA_SRC=~/nudocker/mesa/mesa-r9575

# Work directory for this job
WORK_DIR=~/nudocker/runs/mesa-job-${SLURM_JOB_ID}

# Test case to run (relative to MESA_SRC)
TEST_CASE="star/test_suite/7M_prems_to_AGB"

# ============================================================================
# JOB EXECUTION - Usually no need to modify below
# ============================================================================

echo "========================================="
echo "NuDocker MESA Single Run"
echo "========================================="
echo "Job ID: $SLURM_JOB_ID"
echo "Job name: $SLURM_JOB_NAME"
echo "Node: $SLURM_NODELIST"
echo "CPUs: $SLURM_CPUS_PER_TASK"
echo "Memory: ${SLURM_MEM_PER_NODE}MB"
echo "Start time: $(date)"
echo "========================================="

# Create work directory
mkdir -p $WORK_DIR
cd $WORK_DIR

# Display container info
echo "Container: $CONTAINER"
singularity --version
ls -lh $CONTAINER

echo ""
echo "Running MESA in container..."
echo ""

# Run Singularity container
singularity exec \
    --bind ${MESA_SRC}:/home/user/mesa \
    --bind ${WORK_DIR}:/home/user/work \
    ${CONTAINER} \
    bash <<'MESA_SCRIPT'
        # Source MESA SDK
        source /home/user/mesasdk/bin/mesasdk_init.sh

        # Set OMP threads from SLURM
        export OMP_NUM_THREADS=${SLURM_CPUS_PER_TASK:-8}

        echo "MESA_DIR: $MESA_DIR"
        echo "MESASDK_ROOT: $MESASDK_ROOT"
        echo "OMP_NUM_THREADS: $OMP_NUM_THREADS"
        echo ""

        cd /home/user/mesa

        # Check if MESA is compiled
        if [ ! -f make/makefile ]; then
            echo "MESA not compiled. Installing..."
            echo "This may take 10-30 minutes..."
            ./install

            if [ $? -ne 0 ]; then
                echo "ERROR: MESA installation failed!"
                exit 1
            fi
            echo "MESA installation complete!"
        else
            echo "MESA already compiled, skipping installation"
        fi

        # Navigate to test case
        cd ${TEST_CASE}

        if [ ! -d "$(pwd)" ]; then
            echo "ERROR: Test case directory not found: ${TEST_CASE}"
            exit 1
        fi

        echo ""
        echo "Running test case: ${TEST_CASE}"
        echo "Working directory: $(pwd)"
        echo ""

        # Compile test case
        echo "Compiling test case..."
        ./mk

        if [ $? -ne 0 ]; then
            echo "ERROR: Test case compilation failed!"
            exit 1
        fi

        # Run test case
        echo ""
        echo "Running simulation..."
        echo "Started at: $(date)"
        ./rn

        RUN_STATUS=$?
        echo "Finished at: $(date)"

        if [ $RUN_STATUS -eq 0 ]; then
            echo ""
            echo "SUCCESS: Simulation completed successfully!"

            # Copy results to work directory
            echo "Copying results to: /home/user/work/"
            cp -r LOGS /home/user/work/
            cp -r photos /home/user/work/ 2>/dev/null || echo "No photos directory"
            cp -r png /home/user/work/ 2>/dev/null || echo "No png directory"

            # Create summary
            echo "Creating result summary..."
            cat > /home/user/work/summary.txt <<SUMMARY
MESA Run Summary
================
Job ID: ${SLURM_JOB_ID}
MESA Version: $(basename $MESA_DIR)
Test Case: ${TEST_CASE}
Completed: $(date)
OMP Threads: $OMP_NUM_THREADS

Final Output:
SUMMARY
            tail -30 LOGS/out.txt >> /home/user/work/summary.txt
        else
            echo ""
            echo "ERROR: Simulation failed with exit code $RUN_STATUS"

            # Copy logs even on failure
            cp -r LOGS /home/user/work/ 2>/dev/null || echo "No LOGS to copy"

            exit $RUN_STATUS
        fi
MESA_SCRIPT

SINGULARITY_STATUS=$?

echo ""
echo "========================================="
if [ $SINGULARITY_STATUS -eq 0 ]; then
    echo "Job completed successfully!"
    echo "Results saved to: $WORK_DIR"
    echo ""
    echo "Result files:"
    ls -lh $WORK_DIR/
else
    echo "Job failed with exit code: $SINGULARITY_STATUS"
    echo "Check logs at: $WORK_DIR/LOGS/"
fi
echo "Finished at: $(date)"
echo "========================================="

exit $SINGULARITY_STATUS
