#!/bin/bash
#SBATCH --job-name=mesa-multi           # Job name
#SBATCH --partition=normal              # Partition name (adjust as needed)
#SBATCH --nodes=1                       # Number of nodes per task
#SBATCH --ntasks=1                      # Number of tasks
#SBATCH --cpus-per-task=8               # CPUs per task
#SBATCH --mem=16G                       # Memory per node
#SBATCH --time=48:00:00                 # Time limit (48 hours)
#SBATCH --output=logs/mesa_multi_%j.out # Standard output log
#SBATCH --error=logs/mesa_multi_%j.err  # Standard error log

################################################################################
# NuDocker Multiple Independent MESA Runs on HUN-REN SLURM Cluster
#
# This script submits multiple independent MESA jobs to the SLURM cluster
# Each job runs a different MESA version or test case in separate containers
#
# Usage:
#   1. Adjust paths and job configurations below
#   2. Submit: bash 03_multiple_independent.slurm
#   3. Monitor: squeue -u $USER
#
# Note: This script is designed to be run with bash, not sbatch
#       It submits multiple individual sbatch jobs
#
# Requirements:
#   - Singularity containers at: ~/nudocker/containers/
#   - MESA sources at: ~/nudocker/mesa/
#   - Output directory: ~/nudocker/runs/
################################################################################

# ============================================================================
# CONFIGURATION - ADJUST THESE PATHS FOR YOUR SETUP
# ============================================================================

# Base directories
CONTAINER_DIR=~/nudocker/containers
MESA_BASE_DIR=~/nudocker/mesa
RUN_BASE_DIR=~/nudocker/runs

# Define jobs to run (add/remove as needed)
# Format: "job_name:container:mesa_src:test_case:cpus:mem:time"
JOBS=(
    "mesa-r9575-7M:nudome_16.0.sif:mesa-r9575:star/test_suite/7M_prems_to_AGB:8:16G:24:00:00"
    "mesa-r9575-15M:nudome_16.0.sif:mesa-r9575:star/test_suite/15M_dynamo:8:32G:48:00:00"
    "mesa-r10398-1M:nudome_16.0.sif:mesa-r10398:star/test_suite/1M_pre_ms_to_wd:4:8G:12:00:00"
    "mesa-r12778-25M:nudome_20.031.sif:mesa-r12778:star/test_suite/25M_pre_ms_to_core_collapse:16:64G:72:00:00"
)

# ============================================================================
# JOB SUBMISSION - Usually no need to modify below
# ============================================================================

echo "========================================="
echo "NuDocker Multiple Independent Jobs"
echo "========================================="
echo "Submitting ${#JOBS[@]} jobs to SLURM cluster"
echo "Start time: $(date)"
echo "========================================="
echo ""

# Create logs directory if it doesn't exist
mkdir -p logs

# Track submitted job IDs
JOB_IDS=()

# Submit each job
for job_config in "${JOBS[@]}"; do
    # Parse job configuration
    IFS=':' read -r job_name container mesa_src test_case cpus mem time <<< "$job_config"

    echo "Submitting job: $job_name"
    echo "  Container: $container"
    echo "  MESA: $mesa_src"
    echo "  Test case: $test_case"
    echo "  Resources: ${cpus} CPUs, ${mem} memory, ${time} time"

    # Full paths
    CONTAINER_PATH="${CONTAINER_DIR}/${container}"
    MESA_SRC_PATH="${MESA_BASE_DIR}/${mesa_src}"
    WORK_DIR="${RUN_BASE_DIR}/${job_name}"

    # Create work directory
    mkdir -p "$WORK_DIR"

    # Create individual SLURM script for this job
    cat > "/tmp/slurm_${job_name}.sh" <<SLURM_SCRIPT
#!/bin/bash
#SBATCH --job-name=${job_name}
#SBATCH --partition=normal
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=${cpus}
#SBATCH --mem=${mem}
#SBATCH --time=${time}
#SBATCH --output=logs/${job_name}_%j.out
#SBATCH --error=logs/${job_name}_%j.err

echo "========================================="
echo "Job: ${job_name}"
echo "Job ID: \$SLURM_JOB_ID"
echo "Node: \$SLURM_NODELIST"
echo "Start time: \$(date)"
echo "========================================="

cd ${WORK_DIR}

singularity exec \\
    --bind ${MESA_SRC_PATH}:/home/user/mesa \\
    --bind ${WORK_DIR}:/home/user/work \\
    ${CONTAINER_PATH} \\
    bash <<'MESA_SCRIPT'
        # Source MESA SDK
        source /home/user/mesasdk/bin/mesasdk_init.sh

        # Set OMP threads
        export OMP_NUM_THREADS=${cpus}

        echo "MESA_DIR: \\\$MESA_DIR"
        echo "Test case: ${test_case}"
        echo "OMP_NUM_THREADS: \\\$OMP_NUM_THREADS"
        echo ""

        cd /home/user/mesa

        # Check if MESA is compiled
        if [ ! -f make/makefile ]; then
            echo "Compiling MESA..."
            ./install || exit 1
        fi

        # Navigate to test case
        cd ${test_case}

        echo "Copying test case to work directory..."
        cp -r * /home/user/work/
        cd /home/user/work

        # Compile
        echo "Compiling test case..."
        ./mk || exit 1

        # Run
        echo "Running simulation..."
        echo "Started at: \\\$(date)"
        ./rn

        RUN_STATUS=\\\$?
        echo "Finished at: \\\$(date)"

        if [ \\\$RUN_STATUS -eq 0 ]; then
            echo "SUCCESS: Simulation completed!"

            # Create summary
            cat > /home/user/work/summary.txt <<SUMMARY
MESA Run Summary: ${job_name}
================================
Job ID: \\\$SLURM_JOB_ID
MESA Version: \\\$(basename \\\$MESA_DIR)
Test Case: ${test_case}
CPUs: ${cpus}
Memory: ${mem}
Completed: \\\$(date)

Final Output:
SUMMARY
            tail -30 LOGS/out.txt >> /home/user/work/summary.txt 2>/dev/null || true
        else
            echo "ERROR: Simulation failed with exit code \\\$RUN_STATUS"
            exit \\\$RUN_STATUS
        fi
MESA_SCRIPT

SINGULARITY_STATUS=\$?

echo ""
echo "========================================="
if [ \$SINGULARITY_STATUS -eq 0 ]; then
    echo "Job ${job_name} completed successfully!"
    echo "Results: ${WORK_DIR}"
else
    echo "Job ${job_name} failed with exit code: \$SINGULARITY_STATUS"
fi
echo "Finished at: \$(date)"
echo "========================================="

exit \$SINGULARITY_STATUS
SLURM_SCRIPT

    # Submit the job
    JOB_ID=$(sbatch "/tmp/slurm_${job_name}.sh" | awk '{print $4}')
    JOB_IDS+=("$JOB_ID")

    echo "  Submitted: Job ID $JOB_ID"
    echo ""

    # Clean up temporary script
    rm "/tmp/slurm_${job_name}.sh"
done

echo "========================================="
echo "All jobs submitted!"
echo "========================================="
echo "Total jobs: ${#JOBS[@]}"
echo "Job IDs: ${JOB_IDS[*]}"
echo ""
echo "Monitor jobs with:"
echo "  squeue -u \$USER"
echo ""
echo "Cancel all jobs with:"
echo "  scancel ${JOB_IDS[*]}"
echo ""
echo "Check specific job:"
echo "  scontrol show job <JOB_ID>"
echo "========================================="

# Save job IDs to file for reference
echo "${JOB_IDS[*]}" > ~/nudocker/runs/submitted_jobs_$(date +%Y%m%d_%H%M%S).txt
echo "Job IDs saved to: ~/nudocker/runs/submitted_jobs_$(date +%Y%m%d_%H%M%S).txt"
