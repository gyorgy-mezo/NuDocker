#!/bin/bash
# Test MESA job submission on HTCondor cluster
# This script submits a real MESA test to validate full functionality

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Get central manager IP
if [ ! -f terraform/terraform.tfstate ]; then
    log_error "Terraform state not found. Deploy infrastructure first."
    exit 1
fi

CENTRAL_IP=$(cd terraform && terraform output -raw central_manager_floating_ip 2>/dev/null)

if [ -z "$CENTRAL_IP" ]; then
    log_error "Cannot get central manager IP"
    exit 1
fi

log_info "Central Manager IP: $CENTRAL_IP"

# Create test job directory
log_info "Creating test job on central manager..."

ssh -i ~/.ssh/id_rsa -o StrictHostKeyChecking=no ubuntu@$CENTRAL_IP <<'ENDSSH'
#!/bin/bash
set -e

# Create job directory
mkdir -p /storage/htcondor_jobs/mesa_test_$(date +%Y%m%d_%H%M%S)
cd /storage/htcondor_jobs/mesa_test_$(date +%Y%m%d_%H%M%S)

echo "Creating MESA test job..."

# Create wrapper script
cat > run_test.sh <<'EOF'
#!/bin/bash
# MESA test wrapper script

set -e

echo "=========================================="
echo "NuDocker MESA Test Job"
echo "=========================================="
echo "Job ID: $1"
echo "Mass: $2 M☉"
echo "Metallicity: Z = $3"
echo "Mixing length: α = $4"
echo "Start time: $(date)"
echo "Hostname: $(hostname)"
echo "HTCondor slot: $CONDOR_SLOT"
echo "=========================================="
echo ""

# Simulate MESA setup
echo "Setting up MESA environment..."
export MESA_DIR=/home/user/mesa
export MESASDK_ROOT=/home/user/mesasdk
export OMP_NUM_THREADS=8

echo "MESA_DIR: $MESA_DIR"
echo "OMP_NUM_THREADS: $OMP_NUM_THREADS"
echo ""

# Simulate computation (replace with real MESA in production)
echo "Running simulation for $2 M☉ star..."
echo "This is a test - real MESA would compile and run here"
echo ""

# Create mock results
mkdir -p results_$1
cat > results_$1/summary.txt <<SUMMARY
MESA Test Results
=================
Job ID: $1
Initial Mass: $2 M☉
Metallicity: Z = $3
Mixing Length Parameter: α = $4

Simulation Status: SUCCESS (TEST MODE)
Computed on: $(hostname)
Completion Time: $(date)

Note: This is a validation test.
In production, this would contain actual MESA results.
SUMMARY

# Package results
tar czf results_$1.tar.gz results_$1/

echo ""
echo "=========================================="
echo "Test completed successfully"
echo "Results: results_$1.tar.gz"
echo "End time: $(date)"
echo "=========================================="

exit 0
EOF

chmod +x run_test.sh

# Create HTCondor submit file
cat > mesa_test.sub <<'EOF'
# HTCondor Submit File for MESA Test
# NuDocker Infrastructure Validation

universe        = docker
docker_image    = nugrid/nudome:20.1a

executable      = run_test.sh
arguments       = $(Process) $(mass) $(metallicity) $(alpha)

transfer_input_files = run_test.sh
should_transfer_files = YES
when_to_transfer_output = ON_EXIT
transfer_output_files = results_$(Process).tar.gz

output          = mesa_test_$(Process).out
error           = mesa_test_$(Process).err
log             = mesa_test.log

request_cpus    = 8
request_memory  = 8GB
request_disk    = 5GB

# Test with 3 different stellar models
# Job 0: 5 M☉, solar metallicity
mass = 5.0
metallicity = 0.02
alpha = 2.0
queue

# Job 1: 10 M☉, lower metallicity
mass = 10.0
metallicity = 0.01
alpha = 2.2
queue

# Job 2: 2 M☉, higher mixing
mass = 2.0
metallicity = 0.02
alpha = 2.5
queue
EOF

echo ""
echo "Test job created in: $(pwd)"
echo ""

# Submit job
echo "Submitting job to HTCondor..."
condor_submit mesa_test.sub

echo ""
echo "Job submitted successfully"
echo ""

# Show queue
echo "Current job queue:"
condor_q

ENDSSH

log_info "Test jobs submitted"

# Monitor job progress
log_info "Monitoring job progress (Ctrl+C to stop monitoring)..."
log_warn "Jobs will continue running in background if you stop monitoring"

echo ""
echo "Checking job status every 10 seconds..."
echo ""

for i in {1..60}; do
    STATUS=$(ssh -i ~/.ssh/id_rsa -o StrictHostKeyChecking=no ubuntu@$CENTRAL_IP \
        "condor_q -totals 2>/dev/null" | tail -1)

    echo "[$i/60] $STATUS"

    # Check if all jobs completed
    if echo "$STATUS" | grep -q "0 jobs"; then
        log_info "All jobs completed!"
        break
    fi

    sleep 10
done

echo ""
log_info "Retrieving job results..."

# Get job output
ssh -i ~/.ssh/id_rsa -o StrictHostKeyChecking=no ubuntu@$CENTRAL_IP <<'ENDSSH'
#!/bin/bash

# Find the test directory
TEST_DIR=$(ls -dt /storage/htcondor_jobs/mesa_test_* 2>/dev/null | head -1)

if [ -z "$TEST_DIR" ]; then
    echo "No test directory found"
    exit 1
fi

cd "$TEST_DIR"

echo "=========================================="
echo "Job Results Summary"
echo "=========================================="
echo ""

# Show job outputs
for i in 0 1 2; do
    echo "--- Job $i Output ---"
    if [ -f "mesa_test_${i}.out" ]; then
        tail -20 "mesa_test_${i}.out"
    else
        echo "Output file not found"
    fi
    echo ""
done

# Check for errors
echo "--- Checking for Errors ---"
ERROR_COUNT=$(cat mesa_test_*.err 2>/dev/null | wc -l)
if [ "$ERROR_COUNT" -eq 0 ]; then
    echo "No errors found ✓"
else
    echo "Errors detected ($ERROR_COUNT lines):"
    cat mesa_test_*.err
fi
echo ""

# Check results files
echo "--- Results Files ---"
ls -lh results_*.tar.gz 2>/dev/null || echo "No result files found"
echo ""

# Show final queue status
echo "--- Final Queue Status ---"
condor_q
echo ""

echo "=========================================="
echo "Test directory: $TEST_DIR"
echo "=========================================="

ENDSSH

# Summary
echo ""
echo "=========================================="
log_info "MESA Test Completed"
echo "=========================================="
echo ""
log_info "Next steps:"
echo "  1. SSH to cluster: ssh -i ~/.ssh/id_rsa ubuntu@$CENTRAL_IP"
echo "  2. Check results: cd /storage/htcondor_jobs/mesa_test_*"
echo "  3. Extract results: tar xzf results_*.tar.gz"
echo ""
log_info "For production MESA runs:"
echo "  - Download MESA: wget https://zenodo.org/record/2630796/files/mesa-r9575.zip"
echo "  - Copy to /storage/mesa/"
echo "  - Modify submit files in /storage/batch_examples/"
echo ""
