#!/bin/bash
# Stage 2: Image Verification Script
# Tests the Packer-built image by launching a VM from it
# Run after: packer build

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configuration (edit these)
CLOUD_NAME="${CLOUD_NAME:-hun-ren-cloud}"
IMAGE_PREFIX="nudocker-test-stage2"
FLAVOR="m1.small"  # 2 vCPU, 4 GB RAM for testing
NETWORK_NAME="${NETWORK_NAME:-private}"
KEY_PAIR_NAME="${KEY_PAIR_NAME:-my-keypair}"
SSH_KEY_PATH="${SSH_KEY_PATH:-~/.ssh/id_rsa}"

echo "========================================="
echo "Stage 2: Image Verification"
echo "========================================="
echo "Date: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# Find the most recent image
echo "Finding most recent image..."
IMAGE_NAME=$(openstack --os-cloud "$CLOUD_NAME" image list -f value -c Name | grep "^${IMAGE_PREFIX}" | sort -r | head -1)

if [ -z "$IMAGE_NAME" ]; then
    echo -e "${RED}✗ ERROR: No image found with prefix '${IMAGE_PREFIX}'${NC}"
    echo "Run 'packer build' first to create the image"
    exit 1
fi

echo -e "${GREEN}✓ Found image: $IMAGE_NAME${NC}"
echo ""

# Get image details
echo "Image details:"
openstack --os-cloud "$CLOUD_NAME" image show "$IMAGE_NAME" -f yaml | grep -E "(name|status|size|created_at)" | sed 's/^/  /'
echo ""

# Create test VM from image
TEST_VM_NAME="${IMAGE_PREFIX}-verify-$(date +%Y%m%d-%H%M%S)"
echo "Creating test VM: $TEST_VM_NAME"
echo "Using flavor: $FLAVOR"
echo "Using network: $NETWORK_NAME"
echo ""

openstack --os-cloud "$CLOUD_NAME" server create \
  --image "$IMAGE_NAME" \
  --flavor "$FLAVOR" \
  --network "$NETWORK_NAME" \
  --key-name "$KEY_PAIR_NAME" \
  --wait \
  "$TEST_VM_NAME" >/dev/null

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ VM created successfully${NC}"
else
    echo -e "${RED}✗ VM creation failed${NC}"
    exit 1
fi

# Get VM details
VM_ID=$(openstack --os-cloud "$CLOUD_NAME" server show "$TEST_VM_NAME" -f value -c id)
INTERNAL_IP=$(openstack --os-cloud "$CLOUD_NAME" server show "$TEST_VM_NAME" -f value -c addresses | cut -d'=' -f2)

echo "VM ID: $VM_ID"
echo "Internal IP: $INTERNAL_IP"
echo ""

# Allocate floating IP
echo "Allocating floating IP..."
FLOATING_IP=$(openstack --os-cloud "$CLOUD_NAME" floating ip create -f value -c floating_ip_address public)

if [ -z "$FLOATING_IP" ]; then
    echo -e "${RED}✗ Failed to allocate floating IP${NC}"
    openstack --os-cloud "$CLOUD_NAME" server delete "$TEST_VM_NAME"
    exit 1
fi

echo -e "${GREEN}✓ Floating IP allocated: $FLOATING_IP${NC}"

# Associate floating IP
openstack --os-cloud "$CLOUD_NAME" server add floating ip "$TEST_VM_NAME" "$FLOATING_IP"
sleep 5

echo ""

# Wait for SSH
echo "Waiting for SSH to become available (up to 60 seconds)..."
MAX_ATTEMPTS=12
ATTEMPT=1
SSH_SUCCESS=false

while [ $ATTEMPT -le $MAX_ATTEMPTS ]; do
    if ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no -o ConnectTimeout=5 \
           ubuntu@"$FLOATING_IP" 'exit' >/dev/null 2>&1; then
        echo -e "${GREEN}✓ SSH connection successful${NC}"
        SSH_SUCCESS=true
        break
    fi
    echo "  Attempt $ATTEMPT/$MAX_ATTEMPTS..."
    sleep 5
    ATTEMPT=$((ATTEMPT + 1))
done

if [ "$SSH_SUCCESS" != "true" ]; then
    echo -e "${RED}✗ SSH connection failed${NC}"
    echo "Cleaning up..."
    openstack --os-cloud "$CLOUD_NAME" server delete "$TEST_VM_NAME"
    openstack --os-cloud "$CLOUD_NAME" floating ip delete "$FLOATING_IP"
    exit 1
fi

echo ""

# Run verification tests
echo "Running verification tests..."
echo "------------------------------"

TESTS_PASSED=0
TESTS_FAILED=0

# Test 1: HTCondor
echo "Test 1: HTCondor installation"
if ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no ubuntu@"$FLOATING_IP" \
       'condor_version' >/dev/null 2>&1; then
    CONDOR_VERSION=$(ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no ubuntu@"$FLOATING_IP" 'condor_version | head -1')
    echo -e "${GREEN}✓ PASS: HTCondor installed${NC}"
    echo "  Version: $CONDOR_VERSION"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗ FAIL: HTCondor not found${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Test 2: Docker
echo "Test 2: Docker installation"
if ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no ubuntu@"$FLOATING_IP" \
       'sudo docker --version' >/dev/null 2>&1; then
    DOCKER_VERSION=$(ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no ubuntu@"$FLOATING_IP" 'sudo docker --version')
    echo -e "${GREEN}✓ PASS: Docker installed${NC}"
    echo "  Version: $DOCKER_VERSION"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗ FAIL: Docker not found${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Test 3: Singularity
echo "Test 3: Singularity installation"
if ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no ubuntu@"$FLOATING_IP" \
       'singularity --version' >/dev/null 2>&1; then
    SINGULARITY_VERSION=$(ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no ubuntu@"$FLOATING_IP" 'singularity --version')
    echo -e "${GREEN}✓ PASS: Singularity installed${NC}"
    echo "  Version: $SINGULARITY_VERSION"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗ FAIL: Singularity not found${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Test 4: Munge (SLURM dependency)
echo "Test 4: Munge installation"
if ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no ubuntu@"$FLOATING_IP" \
       'dpkg -l | grep munge' >/dev/null 2>&1; then
    echo -e "${GREEN}✓ PASS: Munge installed${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗ FAIL: Munge not found${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Test 5: NFS client
echo "Test 5: NFS client tools"
if ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no ubuntu@"$FLOATING_IP" \
       'which mount.nfs' >/dev/null 2>&1; then
    echo -e "${GREEN}✓ PASS: NFS client installed${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗ FAIL: NFS client not found${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Test 6: Directory structure
echo "Test 6: Directory structure"
MISSING_DIRS=0
for dir in /storage /opt/nudocker; do
    if ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no ubuntu@"$FLOATING_IP" \
           "[ -d $dir ]" 2>/dev/null; then
        echo -e "${GREEN}  ✓ $dir exists${NC}"
    else
        echo -e "${RED}  ✗ $dir missing${NC}"
        MISSING_DIRS=$((MISSING_DIRS + 1))
    fi
done

if [ $MISSING_DIRS -eq 0 ]; then
    echo -e "${GREEN}✓ PASS: All directories exist${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗ FAIL: $MISSING_DIRS directories missing${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Test 7: Build info file
echo "Test 7: Build info file"
if ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no ubuntu@"$FLOATING_IP" \
       '[ -f /etc/nudocker-image-info.txt ]' 2>/dev/null; then
    echo -e "${GREEN}✓ PASS: Build info file exists${NC}"
    echo "  Contents:"
    ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no ubuntu@"$FLOATING_IP" \
        'cat /etc/nudocker-image-info.txt' 2>/dev/null | sed 's/^/    /'
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗ FAIL: Build info file missing${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

echo ""
echo "========================================="
echo "Test Summary"
echo "========================================="
echo "Tests passed: $TESTS_PASSED"
echo "Tests failed: $TESTS_FAILED"
echo "========================================="
echo ""

# Cleanup
echo "Cleaning up test VM..."
openstack --os-cloud "$CLOUD_NAME" server delete "$TEST_VM_NAME" --wait
openstack --os-cloud "$CLOUD_NAME" floating ip delete "$FLOATING_IP"
echo -e "${GREEN}✓ Cleanup complete${NC}"
echo ""

# Generate result report
RESULT_FILE="../results/stage2_results_$(date +%Y%m%d_%H%M%S).txt"
mkdir -p ../results

cat > "$RESULT_FILE" << EOF
STAGE 2: PACKER BASE IMAGE BUILD TEST
======================================
Date: $(date '+%Y-%m-%d %H:%M:%S')
Duration: ~30-45 minutes (build) + ~5 minutes (verification)

IMAGE DETAILS:
--------------
Image Name: $IMAGE_NAME
Base Image: Ubuntu 22.04 LTS
Build Method: Packer

VERIFICATION RESULTS:
---------------------
Tests Passed: $TESTS_PASSED / 7
Tests Failed: $TESTS_FAILED / 7

✓ HTCondor: $CONDOR_VERSION
✓ Docker: $DOCKER_VERSION
✓ Singularity: $SINGULARITY_VERSION
✓ Munge: Installed
✓ NFS client: Installed
✓ Directories: /storage, /opt/nudocker
✓ Build info: /etc/nudocker-image-info.txt

STATUS: $(if [ $TESTS_FAILED -eq 0 ]; then echo "✓ STAGE 2 PASSED"; else echo "✗ STAGE 2 FAILED"; fi)

NEXT STEPS:
-----------
EOF

if [ $TESTS_FAILED -eq 0 ]; then
    cat >> "$RESULT_FILE" << EOF
✓ Packer successfully built custom image
✓ All required components installed and verified
✓ Image ready for use in cluster deployment

→ Proceed to Stage 3: Single-Node HTCondor Test
→ Command: cd ../stage3 && terraform init

IMAGE AVAILABLE:
The image '$IMAGE_NAME' is now available in your OpenStack project.
You can use it for subsequent stages and production deployment.

CLEANUP:
To remove the test image (optional):
  openstack --os-cloud $CLOUD_NAME image delete '$IMAGE_NAME'

Keep this image for Stages 3-7 to avoid rebuilding.
EOF
    echo -e "${GREEN}✓ All verification tests passed!${NC}"
    EXIT_CODE=0
else
    cat >> "$RESULT_FILE" << EOF
✗ Image verification failed
→ Review Packer build logs for errors
→ Check provisioner scripts in nudocker-test.pkr.hcl
→ Rebuild with: packer build -var-file=variables.pkrvars.hcl nudocker-test.pkr.hcl

TROUBLESHOOTING:
- Check Packer build output for failed provisioners
- Verify all repositories are accessible during build
- Ensure build VM has sufficient resources (4 vCPU, 8 GB RAM)
EOF
    echo -e "${RED}✗ Verification failed - see results for details${NC}"
    EXIT_CODE=1
fi

echo ""
echo "Result saved to: $RESULT_FILE"
echo ""

exit $EXIT_CODE
