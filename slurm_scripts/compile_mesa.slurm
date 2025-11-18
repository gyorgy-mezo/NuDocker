#!/bin/bash
#SBATCH --job-name=mesa-compile         # Job name
#SBATCH --partition=normal              # Partition name (adjust as needed)
#SBATCH --nodes=1                       # Number of nodes
#SBATCH --ntasks=1                      # Number of tasks
#SBATCH --cpus-per-task=16              # CPUs for parallel compilation
#SBATCH --mem=32G                       # Memory for compilation
#SBATCH --time=02:00:00                 # Time limit (2 hours - usually enough)
#SBATCH --output=logs/compile_mesa_%j.out  # Standard output log
#SBATCH --error=logs/compile_mesa_%j.err   # Standard error log

################################################################################
# NuDocker MESA Pre-Compilation on HUN-REN SLURM Cluster
#
# This script pre-compiles MESA in a Singularity container to speed up
# subsequent job submissions. Recommended before large parameter studies.
#
# Usage:
#   1. Adjust paths below for your setup
#   2. Submit: sbatch compile_mesa.slurm
#   3. Wait for completion (10-30 minutes)
#   4. Use pre-compiled MESA in subsequent jobs
#
# Benefits:
#   - Compile once, run many times
#   - Faster job startup (skip 10-30 min compilation)
#   - Reduce cluster load
#   - Essential for large job arrays
#
# Requirements:
#   - Singularity container at: ~/nudocker/containers/nudome_XX.X.sif
#   - MESA source at: ~/nudocker/mesa/mesa-rXXXXX/ (uncompiled)
#   - Write access to MESA source directory
################################################################################

# ============================================================================
# CONFIGURATION - ADJUST THESE PATHS FOR YOUR SETUP
# ============================================================================

# Container path (choose your version)
CONTAINER=~/nudocker/containers/nudome_16.0.sif

# MESA source directory (must have write access)
MESA_SRC=~/nudocker/mesa/mesa-r9575

# Compilation log directory
LOG_DIR=~/nudocker/logs

# ============================================================================
# COMPILATION - Usually no need to modify below
# ============================================================================

echo "========================================="
echo "NuDocker MESA Pre-Compilation"
echo "========================================="
echo "Job ID: $SLURM_JOB_ID"
echo "Job name: $SLURM_JOB_NAME"
echo "Node: $SLURM_NODELIST"
echo "CPUs: $SLURM_CPUS_PER_TASK"
echo "Memory: ${SLURM_MEM_PER_NODE}MB"
echo "Start time: $(date)"
echo "========================================="

# Create log directory
mkdir -p "$LOG_DIR"

# Verify container exists
if [[ ! -f "$CONTAINER" ]]; then
    echo "ERROR: Container not found: $CONTAINER"
    echo ""
    echo "Please build the container first:"
    echo "  singularity pull nudome_16.0.sif docker://nugrid/nudome:16.0"
    exit 1
fi

# Verify MESA source exists
if [[ ! -d "$MESA_SRC" ]]; then
    echo "ERROR: MESA source directory not found: $MESA_SRC"
    echo ""
    echo "Please download MESA first:"
    echo "  wget https://zenodo.org/records/2630796/files/mesa-r9575.zip"
    echo "  unzip mesa-r9575.zip"
    exit 1
fi

# Check if MESA is already compiled
if [[ -f "${MESA_SRC}/make/makefile" ]]; then
    echo "WARNING: MESA appears to be already compiled"
    echo "Directory: ${MESA_SRC}/make/"
    read -p "Re-compile anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Compilation cancelled"
        exit 0
    fi
    echo "Cleaning previous compilation..."
    rm -rf "${MESA_SRC}/make"
fi

echo ""
echo "Container: $CONTAINER"
singularity --version
ls -lh "$CONTAINER"

echo ""
echo "MESA source: $MESA_SRC"
ls -lh "$MESA_SRC"

echo ""
echo "========================================="
echo "Starting MESA compilation"
echo "This may take 10-30 minutes depending on:"
echo "  - MESA version"
echo "  - Number of CPUs (${SLURM_CPUS_PER_TASK})"
echo "  - Cluster load"
echo "========================================="
echo ""

# Record start time
START_TIME=$(date +%s)

# Run compilation in Singularity container
singularity exec \
    --bind ${MESA_SRC}:/home/user/mesa \
    ${CONTAINER} \
    bash <<'COMPILE_SCRIPT'
        # Source MESA SDK
        source /home/user/mesasdk/bin/mesasdk_init.sh

        # Set number of parallel make jobs
        export OMP_NUM_THREADS=${SLURM_CPUS_PER_TASK:-16}

        echo "========================================="
        echo "Compilation Environment"
        echo "========================================="
        echo "MESA_DIR: $MESA_DIR"
        echo "MESASDK_ROOT: $MESASDK_ROOT"
        echo "OMP_NUM_THREADS: $OMP_NUM_THREADS"
        echo "Compiler: $(which gfortran)"
        echo "Gfortran version:"
        gfortran --version | head -n1
        echo "========================================="
        echo ""

        # Navigate to MESA directory
        cd /home/user/mesa

        # Display MESA version info
        if [[ -f docs/version_number ]]; then
            echo "MESA Version: $(cat docs/version_number)"
        else
            echo "MESA Version: $(basename $MESA_DIR)"
        fi
        echo ""

        # Run installation
        echo "Running ./install..."
        echo "Start time: $(date)"
        echo ""

        ./install

        INSTALL_STATUS=$?

        echo ""
        echo "Compilation finished at: $(date)"
        echo "Exit status: $INSTALL_STATUS"

        if [ $INSTALL_STATUS -eq 0 ]; then
            echo ""
            echo "========================================="
            echo "SUCCESS: MESA compiled successfully!"
            echo "========================================="
            echo ""
            echo "Verification:"

            # Check key directories
            if [[ -d "make" ]]; then
                echo "✓ make/ directory created"
                echo "  Files: $(ls make | wc -l)"
            else
                echo "✗ make/ directory not found"
            fi

            if [[ -d "lib" ]]; then
                echo "✓ lib/ directory created"
                echo "  Libraries: $(ls lib/*.a 2>/dev/null | wc -l)"
            else
                echo "✗ lib/ directory not found"
            fi

            # Check if star module compiled
            if [[ -f "star/make/makefile" ]]; then
                echo "✓ star module compiled"
            else
                echo "✗ star module not compiled"
            fi

            # Display directory sizes
            echo ""
            echo "Directory sizes:"
            du -sh /home/user/mesa/make /home/user/mesa/lib 2>/dev/null || true

        else
            echo ""
            echo "========================================="
            echo "ERROR: MESA compilation failed!"
            echo "========================================="
            echo "Exit code: $INSTALL_STATUS"
            echo ""
            echo "Common issues:"
            echo "  - Insufficient memory (need 16-32 GB)"
            echo "  - Incompatible MESA SDK version"
            echo "  - Disk space issues"
            echo "  - Network problems (if MESA downloads dependencies)"
            echo ""
            echo "Check the full log for details"

            exit $INSTALL_STATUS
        fi
COMPILE_SCRIPT

SINGULARITY_STATUS=$?

# Record end time
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
MINUTES=$((DURATION / 60))
SECONDS=$((DURATION % 60))

echo ""
echo "========================================="
echo "Compilation Summary"
echo "========================================="
echo "Status: $([ $SINGULARITY_STATUS -eq 0 ] && echo 'SUCCESS ✓' || echo 'FAILED ✗')"
echo "Exit code: $SINGULARITY_STATUS"
echo "Duration: ${MINUTES}m ${SECONDS}s"
echo "MESA location: ${MESA_SRC}"
echo "Finished at: $(date)"
echo "========================================="

if [ $SINGULARITY_STATUS -eq 0 ]; then
    echo ""
    echo "MESA is now compiled and ready to use!"
    echo ""
    echo "Next steps:"
    echo "  1. Submit job arrays without waiting for compilation"
    echo "  2. Jobs will use pre-compiled MESA (much faster)"
    echo "  3. Example:"
    echo "     sbatch 02_array_mesa_run.slurm"
    echo "     sbatch 04_large_grid.slurm"
    echo ""

    # Save compilation info
    cat > "${LOG_DIR}/mesa_compilation_${SLURM_JOB_ID}.txt" <<INFO
MESA Compilation Success
========================
Job ID: ${SLURM_JOB_ID}
Container: ${CONTAINER}
MESA Source: ${MESA_SRC}
CPUs Used: ${SLURM_CPUS_PER_TASK}
Memory Allocated: ${SLURM_MEM_PER_NODE}MB
Start Time: $(date -d @${START_TIME})
End Time: $(date -d @${END_TIME})
Duration: ${MINUTES}m ${SECONDS}s
Node: ${SLURM_NODELIST}

Status: SUCCESS
Exit Code: 0

Pre-compiled MESA ready for use in subsequent jobs.
INFO

    echo "Compilation info saved to:"
    echo "  ${LOG_DIR}/mesa_compilation_${SLURM_JOB_ID}.txt"

else
    echo ""
    echo "Compilation failed!"
    echo "Check the error log:"
    echo "  logs/compile_mesa_${SLURM_JOB_ID}.err"
    echo ""
    echo "Troubleshooting:"
    echo "  1. Check MESA/SDK version compatibility"
    echo "  2. Verify sufficient memory (32GB recommended)"
    echo "  3. Check disk space: df -h ${MESA_SRC}"
    echo "  4. Try with more CPUs: --cpus-per-task=32"
    echo ""

    # Save failure info
    cat > "${LOG_DIR}/mesa_compilation_${SLURM_JOB_ID}.txt" <<INFO
MESA Compilation Failed
=======================
Job ID: ${SLURM_JOB_ID}
Container: ${CONTAINER}
MESA Source: ${MESA_SRC}
CPUs Used: ${SLURM_CPUS_PER_TASK}
Memory Allocated: ${SLURM_MEM_PER_NODE}MB
Start Time: $(date -d @${START_TIME})
End Time: $(date -d @${END_TIME})
Duration: ${MINUTES}m ${SECONDS}s
Node: ${SLURM_NODELIST}

Status: FAILED
Exit Code: ${SINGULARITY_STATUS}

Check error log: logs/compile_mesa_${SLURM_JOB_ID}.err
INFO

fi

exit $SINGULARITY_STATUS
