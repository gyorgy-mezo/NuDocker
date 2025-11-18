#!/bin/bash
################################################################################
# MESA Model Execution Wrapper for HTCondor
#
# This script runs a single MESA stellar evolution model inside a NuDocker
# container on an HTCondor compute node.
#
# Arguments:
#   $1 - Model ID (job process number)
#   $2 - Initial mass (solar masses)
#   $3 - Metallicity (Z)
#   $4 - Mixing length alpha
#
# Environment:
#   OMP_NUM_THREADS - Number of OpenMP threads
#   MESA_DIR - MESA installation directory
#
# Inputs (transferred by HTCondor):
#   mesa_work_template.tar.gz - MESA work directory template
#   parameter_grid_*.txt - Parameter grid file
#
# Outputs (transferred back by HTCondor):
#   results_${MODEL_ID}.tar.gz - Compressed results
#
################################################################################

set -e  # Exit on error
set -u  # Exit on undefined variable
set -o pipefail  # Pipe failures propagate

# ============================================================================
# Parse Arguments
# ============================================================================

MODEL_ID=${1:-0}
INITIAL_MASS=${2:-5.0}
METALLICITY=${3:-0.02}
MIXING_ALPHA=${4:-2.0}

echo "========================================="
echo "NuDocker MESA Model Execution"
echo "========================================="
echo "Model ID: ${MODEL_ID}"
echo "Initial mass: ${INITIAL_MASS} M☉"
echo "Metallicity: Z = ${METALLICITY}"
echo "Mixing length alpha: ${MIXING_ALPHA}"
echo "OMP threads: ${OMP_NUM_THREADS:-8}"
echo "Start time: $(date)"
echo "Hostname: $(hostname)"
echo "========================================="
echo ""

# ============================================================================
# Setup Working Directory
# ============================================================================

# Create work directory
WORK_DIR="mesa_work_${MODEL_ID}"
mkdir -p "${WORK_DIR}"
cd "${WORK_DIR}"

echo "[INFO] Extracting MESA work template..."
tar xzf ../mesa_work_template.tar.gz
echo "[INFO] Work directory setup complete"
echo ""

# ============================================================================
# Configure MESA Inlists
# ============================================================================

echo "[INFO] Configuring MESA inlists for this model..."

# Modify inlist_project with model parameters
# This assumes inlist_project exists in the template

if [[ -f "inlist_project" ]]; then
    # Set initial mass
    if grep -q "^\s*initial_mass\s*=" inlist_project; then
        sed -i "s/^\s*initial_mass\s*=.*/  initial_mass = ${INITIAL_MASS}/" inlist_project
    else
        sed -i "/&star_job/a\\  initial_mass = ${INITIAL_MASS}" inlist_project
    fi

    # Set metallicity
    if grep -q "^\s*initial_z\s*=" inlist_project; then
        sed -i "s/^\s*initial_z\s*=.*/  initial_z = ${METALLICITY}/" inlist_project
    else
        sed -i "/&star_job/a\\  initial_z = ${METALLICITY}" inlist_project
    fi

    # Set mixing length alpha
    if grep -q "^\s*mixing_length_alpha\s*=" inlist_project; then
        sed -i "s/^\s*mixing_length_alpha\s*=.*/  mixing_length_alpha = ${MIXING_ALPHA}/" inlist_project
    else
        sed -i "/&controls/a\\  mixing_length_alpha = ${MIXING_ALPHA}" inlist_project
    fi

    echo "[INFO] Inlist parameters set:"
    echo "  initial_mass = ${INITIAL_MASS}"
    echo "  initial_z = ${METALLICITY}"
    echo "  mixing_length_alpha = ${MIXING_ALPHA}"
else
    echo "[WARNING] inlist_project not found, using template defaults"
fi

echo ""

# ============================================================================
# Check MESA Installation
# ============================================================================

echo "[INFO] Checking MESA installation..."

# MESA should be at /home/user/mesa in the container
if [[ ! -d "${MESA_DIR}" ]]; then
    echo "[ERROR] MESA directory not found: ${MESA_DIR}"
    exit 1
fi

# Source MESA SDK
if [[ -f "${HOME}/mesasdk/bin/mesasdk_init.sh" ]]; then
    source "${HOME}/mesasdk/bin/mesasdk_init.sh"
    echo "[INFO] MESA SDK initialized"
else
    echo "[WARNING] MESA SDK init script not found"
fi

# Check if MESA is compiled
if [[ ! -f "${MESA_DIR}/make/makefile" ]]; then
    echo "[ERROR] MESA not compiled! Please pre-compile MESA before submitting jobs."
    echo "[ERROR] Expected: ${MESA_DIR}/make/makefile"
    exit 1
fi

echo "[INFO] MESA installation verified"
echo ""

# ============================================================================
# Compile Work Directory
# ============================================================================

echo "[INFO] Compiling work directory..."
echo ""

./mk

if [[ $? -ne 0 ]]; then
    echo "[ERROR] Work directory compilation failed!"
    exit 1
fi

echo ""
echo "[INFO] Compilation successful"
echo ""

# ============================================================================
# Run MESA Model
# ============================================================================

echo "========================================="
echo "Starting MESA Evolution"
echo "========================================="
echo "Model: ${INITIAL_MASS} M☉, Z=${METALLICITY}, α=${MIXING_ALPHA}"
echo "Started at: $(date)"
echo ""

# Run the model
./rn

RUN_STATUS=$?

echo ""
echo "========================================="
echo "MESA Evolution Complete"
echo "========================================="
echo "Finished at: $(date)"
echo "Exit status: ${RUN_STATUS}"
echo ""

if [[ ${RUN_STATUS} -ne 0 ]]; then
    echo "[ERROR] MESA run failed with exit code: ${RUN_STATUS}"

    # Still package up what we have for debugging
    echo "[INFO] Packaging partial results for debugging..."
else
    echo "[SUCCESS] MESA run completed successfully!"
fi

# ============================================================================
# Package Results
# ============================================================================

echo "[INFO] Packaging results..."

# Create results directory
RESULTS_DIR="results_${MODEL_ID}"
mkdir -p "${RESULTS_DIR}"

# Create metadata file
cat > "${RESULTS_DIR}/model_info.txt" <<EOF
NuGrid Parameter Study - Model ${MODEL_ID}
==========================================

Parameters:
-----------
Initial Mass:        ${INITIAL_MASS} M☉
Metallicity:         Z = ${METALLICITY}
Mixing Length Alpha: ${MIXING_ALPHA}

Execution:
----------
Job ID:              ${MODEL_ID}
Hostname:            $(hostname)
Start Time:          ${START_TIME:-unknown}
End Time:            $(date)
OMP Threads:         ${OMP_NUM_THREADS:-8}
Exit Status:         ${RUN_STATUS}

MESA Version:        $(basename ${MESA_DIR})
MESASDK Root:        ${MESASDK_ROOT:-not set}

Output Files:
-------------
EOF

# Copy important outputs
if [[ -f "LOGS/history.data" ]]; then
    cp LOGS/history.data "${RESULTS_DIR}/"
    ls -lh LOGS/history.data >> "${RESULTS_DIR}/model_info.txt"
fi

if [[ -d "LOGS/profiles" ]]; then
    mkdir -p "${RESULTS_DIR}/profiles"
    cp LOGS/profiles/*.data "${RESULTS_DIR}/profiles/" 2>/dev/null || true
fi

if [[ -f "LOGS/out.txt" ]]; then
    # Keep last 1000 lines of output
    tail -1000 LOGS/out.txt > "${RESULTS_DIR}/out_tail.txt"
fi

# Copy final photo for potential restart
if [[ -d "photos" ]]; then
    LAST_PHOTO=$(ls -t photos/*.photo 2>/dev/null | head -1)
    if [[ -n "${LAST_PHOTO}" ]]; then
        cp "${LAST_PHOTO}" "${RESULTS_DIR}/"
    fi
fi

# Copy inlist for reproducibility
cp inlist* "${RESULTS_DIR}/" 2>/dev/null || true

# Create summary
if [[ -f "LOGS/history.data" ]]; then
    echo "" >> "${RESULTS_DIR}/model_info.txt"
    echo "Final Model State:" >> "${RESULTS_DIR}/model_info.txt"
    echo "-----------------" >> "${RESULTS_DIR}/model_info.txt"
    tail -1 LOGS/history.data >> "${RESULTS_DIR}/model_info.txt"
fi

# Compress results
cd ..
tar czf "results_${MODEL_ID}.tar.gz" "${WORK_DIR}/${RESULTS_DIR}"

if [[ $? -eq 0 ]]; then
    echo "[INFO] Results packaged: results_${MODEL_ID}.tar.gz"
    ls -lh "results_${MODEL_ID}.tar.gz"
else
    echo "[ERROR] Failed to package results!"
    exit 1
fi

# ============================================================================
# Cleanup
# ============================================================================

echo ""
echo "[INFO] Cleaning up work directory..."
# Keep only the compressed results
rm -rf "${WORK_DIR}"

echo ""
echo "========================================="
echo "Job Complete"
echo "========================================="
echo "Model ID: ${MODEL_ID}"
echo "Status: $([ ${RUN_STATUS} -eq 0 ] && echo 'SUCCESS ✓' || echo 'FAILED ✗')"
echo "Results: results_${MODEL_ID}.tar.gz"
echo "========================================="

exit ${RUN_STATUS}
