#!/bin/bash
#SBATCH --job-name=mesa-grid            # Job name
#SBATCH --partition=normal              # Partition name (adjust as needed)
#SBATCH --nodes=1                       # Number of nodes per task
#SBATCH --ntasks=1                      # Number of tasks
#SBATCH --cpus-per-task=8               # CPUs per task
#SBATCH --mem=16G                       # Memory per node
#SBATCH --time=48:00:00                 # Time limit (48 hours)
#SBATCH --array=1-100%20                # Array range (1-100, max 20 running)
#SBATCH --output=logs/mesa_grid_%A_%a.out   # Standard output log
#SBATCH --error=logs/mesa_grid_%A_%a.err    # Standard error log

################################################################################
# NuDocker Large Parameter Grid on HUN-REN SLURM Cluster
#
# This script runs a large parameter grid study (100+ models) using job arrays
# with throttling to avoid overwhelming the cluster
#
# Usage:
#   1. Generate parameter grid file with generate_grid.py
#   2. Adjust paths below for your setup
#   3. Submit: sbatch 04_large_grid.slurm
#   4. Monitor: squeue -u $USER
#
# Features:
#   - Job array with throttling (%20 = max 20 running simultaneously)
#   - Automatic parameter grid parsing
#   - Result organization by parameter combination
#   - Progress tracking and summary generation
#
# Requirements:
#   - Singularity container at: ~/nudocker/containers/nudome_XX.X.sif
#   - MESA source at: ~/nudocker/mesa/mesa-rXXXXX/
#   - Parameter grid file: ~/nudocker/config/parameter_grid.txt
#   - Output directory: ~/nudocker/runs/grid_study/
################################################################################

# ============================================================================
# CONFIGURATION - ADJUST THESE PATHS FOR YOUR SETUP
# ============================================================================

# Container path (choose your version)
CONTAINER=~/nudocker/containers/nudome_16.0.sif

# MESA source directory (pre-compiled recommended for large grids)
MESA_SRC=~/nudocker/mesa/mesa-r9575

# Grid study base directory
GRID_BASE_DIR=~/nudocker/runs/grid_study

# Parameter grid file (generated with generate_grid.py or manually)
# Format: Each line contains space-separated key=value pairs
# Example: initial_mass=7.0 Zbase=0.02 mixing_length_alpha=2.0
PARAMETER_GRID=~/nudocker/config/parameter_grid.txt

# Work directory template (from MESA)
WORK_TEMPLATE="star/work"

# ============================================================================
# PARAMETER GRID GENERATION (if needed)
# ============================================================================
# You can create the parameter grid file with a Python script like this:
#
# #!/usr/bin/env python3
# import itertools
#
# # Define parameter ranges
# masses = [1.0, 1.5, 2.0, 2.5, 3.0, 4.0, 5.0, 7.0, 10.0, 15.0]
# metallicities = [0.001, 0.004, 0.008, 0.014, 0.02]
# alphas = [1.8, 2.0, 2.2]
#
# # Generate all combinations
# with open('parameter_grid.txt', 'w') as f:
#     for mass, Z, alpha in itertools.product(masses, metallicities, alphas):
#         f.write(f"initial_mass={mass} Zbase={Z} mixing_length_alpha={alpha}\n")
#
# This creates 10 * 5 * 3 = 150 models
# ============================================================================

# ============================================================================
# JOB ARRAY EXECUTION - Usually no need to modify below
# ============================================================================

echo "========================================="
echo "NuDocker Large Parameter Grid Study"
echo "========================================="
echo "Job ID: $SLURM_JOB_ID"
echo "Array Job ID: $SLURM_ARRAY_JOB_ID"
echo "Array Task ID: $SLURM_ARRAY_TASK_ID"
echo "Node: $SLURM_NODELIST"
echo "CPUs: $SLURM_CPUS_PER_TASK"
echo "Memory: ${SLURM_MEM_PER_NODE}MB"
echo "Start time: $(date)"
echo "========================================="

# Read parameters for this array task
if [[ ! -f "$PARAMETER_GRID" ]]; then
    echo "ERROR: Parameter grid file not found: $PARAMETER_GRID"
    echo ""
    echo "Please create a parameter grid file with format:"
    echo "  initial_mass=7.0 Zbase=0.02 mixing_length_alpha=2.0"
    echo "  initial_mass=10.0 Zbase=0.02 mixing_length_alpha=2.0"
    echo "  ..."
    exit 1
fi

# Get total number of models
TOTAL_MODELS=$(wc -l < "$PARAMETER_GRID")
echo "Total models in grid: $TOTAL_MODELS"

if [[ $SLURM_ARRAY_TASK_ID -gt $TOTAL_MODELS ]]; then
    echo "ERROR: Task ID $SLURM_ARRAY_TASK_ID exceeds grid size $TOTAL_MODELS"
    exit 1
fi

# Read parameters for this specific model
PARAMS=$(sed -n "${SLURM_ARRAY_TASK_ID}p" "$PARAMETER_GRID")
echo "Parameters for model ${SLURM_ARRAY_TASK_ID}:"
echo "  $PARAMS"
echo ""

# Parse parameters to create descriptive directory name
MODEL_NAME="model_${SLURM_ARRAY_TASK_ID}"
for param in $PARAMS; do
    key=${param%%=*}
    value=${param#*=}
    # Abbreviate common parameter names
    case $key in
        initial_mass) MODEL_NAME="${MODEL_NAME}_M${value}" ;;
        Zbase) MODEL_NAME="${MODEL_NAME}_Z${value}" ;;
        mixing_length_alpha) MODEL_NAME="${MODEL_NAME}_a${value}" ;;
        *) MODEL_NAME="${MODEL_NAME}_${key}${value}" ;;
    esac
done

# Create work directory for this model
WORK_DIR="${GRID_BASE_DIR}/${MODEL_NAME}"
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

echo "Model directory: $WORK_DIR"
echo ""

# Display container info
echo "Container: $CONTAINER"
singularity --version
ls -lh "$CONTAINER"

echo ""
echo "Running MESA simulation for model ${SLURM_ARRAY_TASK_ID}/${TOTAL_MODELS}..."
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
        echo "Model: ${MODEL_NAME}"
        echo ""

        cd /home/user/mesa

        # Check if MESA is compiled
        if [ ! -f make/makefile ]; then
            echo "WARNING: MESA not compiled!"
            echo "For large grids, pre-compile MESA before submitting jobs"
            echo "Compiling now (this will take 10-30 minutes)..."
            ./install

            if [ \$? -ne 0 ]; then
                echo "ERROR: MESA installation failed!"
                exit 1
            fi
        else
            echo "MESA already compiled ✓"
        fi

        # Copy work template to work directory
        echo "Setting up work directory..."
        cd /home/user/mesa/${WORK_TEMPLATE}
        cp -r * /home/user/work/
        cd /home/user/work

        # Apply parameters from grid
        echo ""
        echo "Applying parameters:"
        for param in ${PARAMS}; do
            key=\${param%%=*}
            value=\${param#*=}
            echo "  \$key = \$value"

            # Modify inlist_project (adjust pattern for your inlist structure)
            if grep -q "^\s*\$key\s*=" inlist_project 2>/dev/null; then
                sed -i "s/^\s*\$key\s*=.*/  \$key = \$value/" inlist_project
            else
                # If parameter doesn't exist, add it to the &star_job section
                sed -i "/&star_job/a\\  \$key = \$value" inlist_project
            fi
        done

        # Save parameters to metadata file
        cat > model_parameters.txt <<PARAMS_FILE
Model: ${MODEL_NAME}
Array Task ID: ${SLURM_ARRAY_TASK_ID}
Job ID: ${SLURM_JOB_ID}
MESA Version: \$(basename \$MESA_DIR)
Start Time: \$(date)

Parameters:
${PARAMS}
PARAMS_FILE

        # Compile work directory
        echo ""
        echo "Compiling work directory..."
        ./mk

        if [ \$? -ne 0 ]; then
            echo "ERROR: Work directory compilation failed!"
            exit 1
        fi

        # Run simulation
        echo ""
        echo "========================================="
        echo "Starting MESA simulation"
        echo "Model: ${MODEL_NAME}"
        echo "Task: ${SLURM_ARRAY_TASK_ID}/${TOTAL_MODELS}"
        echo "Started at: \$(date)"
        echo "========================================="
        ./rn

        RUN_STATUS=\$?
        echo ""
        echo "========================================="
        echo "Finished at: \$(date)"
        echo "========================================="

        if [ \$RUN_STATUS -eq 0 ]; then
            echo ""
            echo "SUCCESS: Model ${MODEL_NAME} completed!"

            # Create comprehensive summary
            cat >> model_parameters.txt <<SUMMARY

Completion Status: SUCCESS
End Time: \$(date)
Run Duration: \$SECONDS seconds

Final Model State:
SUMMARY

            # Add final model properties from LOGS
            if [ -f LOGS/out.txt ]; then
                echo "" >> model_parameters.txt
                echo "Final Output (last 30 lines):" >> model_parameters.txt
                tail -30 LOGS/out.txt >> model_parameters.txt
            fi

            # Extract key results (adjust for your specific outputs)
            if [ -f LOGS/history.data ]; then
                # Get final values from history
                tail -1 LOGS/history.data > final_model_state.dat
                echo "Final model state saved to: final_model_state.dat"
            fi

            echo ""
            echo "Results saved to: /home/user/work/"
            ls -lh /home/user/work/

        else
            echo ""
            echo "ERROR: Model ${MODEL_NAME} failed with exit code \$RUN_STATUS"

            # Save failure information
            cat >> model_parameters.txt <<FAILURE
Completion Status: FAILED
Exit Code: \$RUN_STATUS
End Time: \$(date)
FAILURE

            # Copy error logs
            if [ -f LOGS/out.txt ]; then
                cp LOGS/out.txt failure_log.txt
            fi

            exit \$RUN_STATUS
        fi
MESA_SCRIPT

SINGULARITY_STATUS=$?

echo ""
echo "========================================="
if [ $SINGULARITY_STATUS -eq 0 ]; then
    echo "Model ${MODEL_NAME} completed successfully!"
    echo "Results saved to: $WORK_DIR"
    echo ""
    echo "Summary:"
    cat "$WORK_DIR/model_parameters.txt" 2>/dev/null || echo "  (summary file not found)"
else
    echo "Model ${MODEL_NAME} FAILED with exit code: $SINGULARITY_STATUS"
    echo "Check logs at: $WORK_DIR/"
fi
echo ""
echo "Progress: ${SLURM_ARRAY_TASK_ID}/${TOTAL_MODELS} models"
echo "Finished at: $(date)"
echo "========================================="

exit $SINGULARITY_STATUS
