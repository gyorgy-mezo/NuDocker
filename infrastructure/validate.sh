#!/bin/bash
# Validation script for NuDocker HTCondor Infrastructure
# Tests cluster functionality and readiness

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASSED=0
FAILED=0
WARNINGS=0

# Test result tracking
print_result() {
    local test_name=$1
    local result=$2
    local message=$3

    if [ "$result" = "PASS" ]; then
        echo -e "${GREEN}✓${NC} $test_name: PASSED"
        ((PASSED++))
    elif [ "$result" = "FAIL" ]; then
        echo -e "${RED}✗${NC} $test_name: FAILED - $message"
        ((FAILED++))
    else
        echo -e "${YELLOW}⚠${NC} $test_name: WARNING - $message"
        ((WARNINGS++))
    fi
}

# Check Terraform state
test_terraform_state() {
    echo "=== Testing Terraform State ==="

    if [ -f terraform/terraform.tfstate ]; then
        print_result "Terraform state exists" "PASS"
    else
        print_result "Terraform state exists" "FAIL" "terraform.tfstate not found"
        return 1
    fi

    cd terraform

    # Get outputs
    if CENTRAL_IP=$(terraform output -raw central_manager_floating_ip 2>/dev/null); then
        print_result "Central manager IP available" "PASS"
        echo "   IP: $CENTRAL_IP"
    else
        print_result "Central manager IP available" "FAIL" "Cannot get floating IP"
        cd ..
        return 1
    fi

    # Count execute nodes
    EXECUTE_IPS=$(terraform output -json execute_node_ips 2>/dev/null | jq -r '.[]' | wc -l)
    if [ "$EXECUTE_IPS" -ge 5 ]; then
        print_result "Execute nodes deployed" "PASS"
        echo "   Count: $EXECUTE_IPS nodes"
    else
        print_result "Execute nodes deployed" "FAIL" "Expected 5, got $EXECUTE_IPS"
    fi

    cd ..
}

# Test SSH connectivity
test_ssh_connectivity() {
    echo ""
    echo "=== Testing SSH Connectivity ==="

    CENTRAL_IP=$(cd terraform && terraform output -raw central_manager_floating_ip 2>/dev/null)

    if ssh -i ~/.ssh/id_rsa -o ConnectTimeout=10 -o StrictHostKeyChecking=no ubuntu@$CENTRAL_IP "exit" 2>/dev/null; then
        print_result "SSH to central manager" "PASS"
    else
        print_result "SSH to central manager" "FAIL" "Cannot connect"
        return 1
    fi
}

# Test HTCondor pool
test_htcondor_pool() {
    echo ""
    echo "=== Testing HTCondor Pool ==="

    CENTRAL_IP=$(cd terraform && terraform output -raw central_manager_floating_ip 2>/dev/null)

    # Check HTCondor is running
    if ssh -i ~/.ssh/id_rsa -o StrictHostKeyChecking=no ubuntu@$CENTRAL_IP "systemctl is-active condor" 2>/dev/null | grep -q "active"; then
        print_result "HTCondor service running" "PASS"
    else
        print_result "HTCondor service running" "FAIL" "Service not active"
        return 1
    fi

    # Check pool status
    TOTAL_SLOTS=$(ssh -i ~/.ssh/id_rsa -o StrictHostKeyChecking=no ubuntu@$CENTRAL_IP \
        "condor_status -total 2>/dev/null | grep Total | awk '{print \$4}'" | tr -d '[:space:]')

    if [ "$TOTAL_SLOTS" -ge 40 ]; then
        print_result "HTCondor slots available" "PASS"
        echo "   Slots: $TOTAL_SLOTS"
    elif [ "$TOTAL_SLOTS" -gt 0 ]; then
        print_result "HTCondor slots available" "WARN" "Expected 40, got $TOTAL_SLOTS"
    else
        print_result "HTCondor slots available" "FAIL" "No slots available"
    fi

    # Check execute nodes registered
    NODE_COUNT=$(ssh -i ~/.ssh/id_rsa -o StrictHostKeyChecking=no ubuntu@$CENTRAL_IP \
        "condor_status -af Name 2>/dev/null | grep execute | wc -l" | tr -d '[:space:]')

    if [ "$NODE_COUNT" -ge 5 ]; then
        print_result "Execute nodes registered" "PASS"
        echo "   Nodes: $NODE_COUNT"
    else
        print_result "Execute nodes registered" "FAIL" "Expected 5, got $NODE_COUNT"
    fi
}

# Test NFS storage
test_nfs_storage() {
    echo ""
    echo "=== Testing NFS Storage ==="

    CENTRAL_IP=$(cd terraform && terraform output -raw central_manager_floating_ip 2>/dev/null)

    # Check NFS mount on central
    if ssh -i ~/.ssh/id_rsa -o StrictHostKeyChecking=no ubuntu@$CENTRAL_IP \
        "mount | grep -q '/storage'" 2>/dev/null; then
        print_result "NFS mounted on central manager" "PASS"
    else
        print_result "NFS mounted on central manager" "FAIL" "Not mounted"
    fi

    # Check directory structure
    if ssh -i ~/.ssh/id_rsa -o StrictHostKeyChecking=no ubuntu@$CENTRAL_IP \
        "[ -d /storage/mesa ] && [ -d /storage/containers ] && [ -d /storage/results ]" 2>/dev/null; then
        print_result "NFS directory structure" "PASS"
    else
        print_result "NFS directory structure" "FAIL" "Missing directories"
    fi

    # Check available space
    STORAGE_GB=$(ssh -i ~/.ssh/id_rsa -o StrictHostKeyChecking=no ubuntu@$CENTRAL_IP \
        "df -BG /storage | tail -1 | awk '{print \$2}'" | tr -d 'G[:space:]')

    if [ "$STORAGE_GB" -ge 400 ]; then
        print_result "NFS storage capacity" "PASS"
        echo "   Size: ${STORAGE_GB}GB"
    else
        print_result "NFS storage capacity" "WARN" "Expected 500GB, got ${STORAGE_GB}GB"
    fi
}

# Test Docker
test_docker() {
    echo ""
    echo "=== Testing Docker ==="

    CENTRAL_IP=$(cd terraform && terraform output -raw central_manager_floating_ip 2>/dev/null)

    # Check Docker is running
    if ssh -i ~/.ssh/id_rsa -o StrictHostKeyChecking=no ubuntu@$CENTRAL_IP \
        "docker ps" &>/dev/null; then
        print_result "Docker service running" "PASS"
    else
        print_result "Docker service running" "FAIL" "Cannot run docker ps"
        return 1
    fi

    # Check for NuDocker images
    IMAGE_COUNT=$(ssh -i ~/.ssh/id_rsa -o StrictHostKeyChecking=no ubuntu@$CENTRAL_IP \
        "docker images | grep nugrid/nudome | wc -l" | tr -d '[:space:]')

    if [ "$IMAGE_COUNT" -ge 3 ]; then
        print_result "NuDocker images available" "PASS"
        echo "   Images: $IMAGE_COUNT"
    else
        print_result "NuDocker images available" "WARN" "Expected 4, got $IMAGE_COUNT"
    fi
}

# Test Singularity
test_singularity() {
    echo ""
    echo "=== Testing Singularity ==="

    CENTRAL_IP=$(cd terraform && terraform output -raw central_manager_floating_ip 2>/dev/null)

    # Check Singularity installed
    if ssh -i ~/.ssh/id_rsa -o StrictHostKeyChecking=no ubuntu@$CENTRAL_IP \
        "which singularity" &>/dev/null; then
        VERSION=$(ssh -i ~/.ssh/id_rsa -o StrictHostKeyChecking=no ubuntu@$CENTRAL_IP \
            "singularity --version" 2>/dev/null)
        print_result "Singularity installed" "PASS"
        echo "   Version: $VERSION"
    else
        print_result "Singularity installed" "FAIL" "Not found"
        return 1
    fi

    # Check for .sif files
    SIF_COUNT=$(ssh -i ~/.ssh/id_rsa -o StrictHostKeyChecking=no ubuntu@$CENTRAL_IP \
        "ls /storage/containers/*.sif 2>/dev/null | wc -l" | tr -d '[:space:]')

    if [ "$SIF_COUNT" -ge 2 ]; then
        print_result "Singularity images available" "PASS"
        echo "   Images: $SIF_COUNT"
    else
        print_result "Singularity images available" "WARN" "Expected 4, got $SIF_COUNT"
    fi
}

# Test job submission
test_job_submission() {
    echo ""
    echo "=== Testing Job Submission ==="

    CENTRAL_IP=$(cd terraform && terraform output -raw central_manager_floating_ip 2>/dev/null)

    # Create test job
    ssh -i ~/.ssh/id_rsa -o StrictHostKeyChecking=no ubuntu@$CENTRAL_IP <<'ENDSSH' &>/dev/null
cat > /tmp/validation_test.sub <<'EOF'
universe     = vanilla
executable   = /bin/echo
arguments    = "HTCondor validation test successful"
output       = /tmp/validation_test.out
error        = /tmp/validation_test.err
log          = /tmp/validation_test.log
request_cpus = 1
request_memory = 512MB
queue
EOF
ENDSSH

    # Submit job
    if ssh -i ~/.ssh/id_rsa -o StrictHostKeyChecking=no ubuntu@$CENTRAL_IP \
        "condor_submit /tmp/validation_test.sub" &>/dev/null; then
        print_result "Job submission" "PASS"
    else
        print_result "Job submission" "FAIL" "condor_submit failed"
        return 1
    fi

    # Wait for job to complete (max 60 seconds)
    echo "   Waiting for test job to complete..."
    for i in {1..30}; do
        IDLE=$(ssh -i ~/.ssh/id_rsa -o StrictHostKeyChecking=no ubuntu@$CENTRAL_IP \
            "condor_q -totals 2>/dev/null | grep -oP '\d+ jobs' | grep -oP '\d+'" | tr -d '[:space:]')

        if [ -z "$IDLE" ] || [ "$IDLE" = "0" ]; then
            break
        fi
        sleep 2
    done

    # Check output
    if ssh -i ~/.ssh/id_rsa -o StrictHostKeyChecking=no ubuntu@$CENTRAL_IP \
        "grep -q 'successful' /tmp/validation_test.out 2>/dev/null"; then
        print_result "Job execution" "PASS"
    else
        print_result "Job execution" "FAIL" "Job did not complete successfully"
    fi

    # Cleanup
    ssh -i ~/.ssh/id_rsa -o StrictHostKeyChecking=no ubuntu@$CENTRAL_IP \
        "rm -f /tmp/validation_test.*" &>/dev/null
}

# Test NuDocker scripts
test_nudocker_scripts() {
    echo ""
    echo "=== Testing NuDocker Installation ==="

    CENTRAL_IP=$(cd terraform && terraform output -raw central_manager_floating_ip 2>/dev/null)

    # Check NuDocker repository cloned
    if ssh -i ~/.ssh/id_rsa -o StrictHostKeyChecking=no ubuntu@$CENTRAL_IP \
        "[ -d /storage/nudocker ]" 2>/dev/null; then
        print_result "NuDocker repository cloned" "PASS"
    else
        print_result "NuDocker repository cloned" "FAIL" "Directory not found"
    fi

    # Check batch examples
    if ssh -i ~/.ssh/id_rsa -o StrictHostKeyChecking=no ubuntu@$CENTRAL_IP \
        "[ -f /storage/batch_examples/nudocker_study.dag ]" 2>/dev/null; then
        print_result "HTCondor job templates deployed" "PASS"
    else
        print_result "HTCondor job templates deployed" "FAIL" "Templates not found"
    fi
}

# Main validation
main() {
    echo "=========================================="
    echo "NuDocker HTCondor Infrastructure Validation"
    echo "=========================================="
    echo ""

    # Check if Terraform state exists
    if [ ! -f terraform/terraform.tfstate ]; then
        echo -e "${RED}ERROR:${NC} No Terraform state found"
        echo "Run './deploy.sh terraform' first"
        exit 1
    fi

    # Run tests
    test_terraform_state || true
    test_ssh_connectivity || true
    test_htcondor_pool || true
    test_nfs_storage || true
    test_docker || true
    test_singularity || true
    test_job_submission || true
    test_nudocker_scripts || true

    # Summary
    echo ""
    echo "=========================================="
    echo "Validation Summary"
    echo "=========================================="
    echo -e "${GREEN}Passed:${NC}   $PASSED"
    echo -e "${YELLOW}Warnings:${NC} $WARNINGS"
    echo -e "${RED}Failed:${NC}   $FAILED"
    echo ""

    if [ $FAILED -eq 0 ]; then
        echo -e "${GREEN}✓ All critical tests passed${NC}"
        echo "Cluster is ready for production use"
        exit 0
    else
        echo -e "${RED}✗ Some tests failed${NC}"
        echo "Review failures above and check DEPLOYMENT_GUIDE.md troubleshooting section"
        exit 1
    fi
}

# Run validation
main
