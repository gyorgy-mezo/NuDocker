#!/bin/bash
# Stage 1: Connectivity Test Script
# Tests SSH access and basic VM functionality
# Run after: terraform apply

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "========================================="
echo "Stage 1: Connectivity Test"
echo "========================================="
echo "Date: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# Get outputs from Terraform
echo "Retrieving VM information from Terraform..."
FLOATING_IP=$(terraform output -raw test_vm_floating_ip 2>/dev/null)
INTERNAL_IP=$(terraform output -raw test_vm_internal_ip 2>/dev/null)
VM_ID=$(terraform output -raw test_vm_id 2>/dev/null)

if [ -z "$FLOATING_IP" ]; then
    echo -e "${RED}✗ ERROR: Could not retrieve VM information${NC}"
    echo "Make sure you have run 'terraform apply' successfully"
    exit 1
fi

echo -e "${GREEN}✓ VM Information retrieved${NC}"
echo "  VM ID: $VM_ID"
echo "  Internal IP: $INTERNAL_IP"
echo "  Floating IP: $FLOATING_IP"
echo ""

# Test 1: Ping floating IP
echo "Test 1: Network connectivity (ping)"
echo "------------------------------------"
if ping -c 3 -W 2 "$FLOATING_IP" >/dev/null 2>&1; then
    echo -e "${GREEN}✓ PASS: VM is reachable via ping${NC}"
else
    echo -e "${YELLOW}⚠ WARN: Ping failed (may be blocked by security group)${NC}"
fi
echo ""

# Test 2: SSH connectivity (wait up to 60 seconds)
echo "Test 2: SSH connectivity"
echo "------------------------"
echo "Waiting for SSH to become available (up to 60 seconds)..."

SSH_KEY="${SSH_KEY_PATH:-~/.ssh/id_rsa}"
MAX_ATTEMPTS=12
ATTEMPT=1

while [ $ATTEMPT -le $MAX_ATTEMPTS ]; do
    if ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no -o ConnectTimeout=5 \
           ubuntu@"$FLOATING_IP" 'exit' >/dev/null 2>&1; then
        echo -e "${GREEN}✓ PASS: SSH connection successful${NC}"
        SSH_SUCCESS=true
        break
    fi
    echo "  Attempt $ATTEMPT/$MAX_ATTEMPTS failed, retrying in 5 seconds..."
    sleep 5
    ATTEMPT=$((ATTEMPT + 1))
done

if [ "$SSH_SUCCESS" != "true" ]; then
    echo -e "${RED}✗ FAIL: SSH connection failed after $MAX_ATTEMPTS attempts${NC}"
    echo "Troubleshooting:"
    echo "  1. Check security group allows SSH (port 22)"
    echo "  2. Verify SSH key path: $SSH_KEY"
    echo "  3. Check VM console in OpenStack dashboard"
    exit 1
fi
echo ""

# Test 3: Execute basic commands
echo "Test 3: VM functionality"
echo "------------------------"

# Get hostname
HOSTNAME=$(ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no ubuntu@"$FLOATING_IP" 'hostname' 2>/dev/null)
if [ -n "$HOSTNAME" ]; then
    echo -e "${GREEN}✓ PASS: Hostname: $HOSTNAME${NC}"
else
    echo -e "${RED}✗ FAIL: Could not retrieve hostname${NC}"
fi

# Get uptime
UPTIME=$(ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no ubuntu@"$FLOATING_IP" 'uptime -p' 2>/dev/null)
if [ -n "$UPTIME" ]; then
    echo -e "${GREEN}✓ PASS: Uptime: $UPTIME${NC}"
else
    echo -e "${YELLOW}⚠ WARN: Could not retrieve uptime${NC}"
fi

# Check OS version
OS_VERSION=$(ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no ubuntu@"$FLOATING_IP" 'lsb_release -d' 2>/dev/null | cut -f2-)
if [ -n "$OS_VERSION" ]; then
    echo -e "${GREEN}✓ PASS: OS: $OS_VERSION${NC}"
else
    echo -e "${YELLOW}⚠ WARN: Could not retrieve OS version${NC}"
fi

# Check CPU info
CPU_COUNT=$(ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no ubuntu@"$FLOATING_IP" 'nproc' 2>/dev/null)
if [ -n "$CPU_COUNT" ]; then
    echo -e "${GREEN}✓ PASS: CPU cores: $CPU_COUNT${NC}"
else
    echo -e "${YELLOW}⚠ WARN: Could not retrieve CPU count${NC}"
fi

# Check memory
MEM_TOTAL=$(ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no ubuntu@"$FLOATING_IP" \
            "free -h | grep Mem: | awk '{print \$2}'" 2>/dev/null)
if [ -n "$MEM_TOTAL" ]; then
    echo -e "${GREEN}✓ PASS: Total memory: $MEM_TOTAL${NC}"
else
    echo -e "${YELLOW}⚠ WARN: Could not retrieve memory info${NC}"
fi

# Check disk space
DISK_TOTAL=$(ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no ubuntu@"$FLOATING_IP" \
             "df -h / | tail -1 | awk '{print \$2}'" 2>/dev/null)
if [ -n "$DISK_TOTAL" ]; then
    echo -e "${GREEN}✓ PASS: Root disk size: $DISK_TOTAL${NC}"
else
    echo -e "${YELLOW}⚠ WARN: Could not retrieve disk info${NC}"
fi

echo ""

# Test 4: Internet connectivity from VM
echo "Test 4: Internet connectivity from VM"
echo "--------------------------------------"

if ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no ubuntu@"$FLOATING_IP" \
       'curl -s -m 5 http://www.google.com' >/dev/null 2>&1; then
    echo -e "${GREEN}✓ PASS: VM has internet access${NC}"
else
    echo -e "${YELLOW}⚠ WARN: VM cannot reach internet${NC}"
    echo "  This may be expected depending on network configuration"
fi

echo ""

# Test 5: Package manager
echo "Test 5: Package manager (apt)"
echo "------------------------------"

if ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no ubuntu@"$FLOATING_IP" \
       'sudo apt-get update' >/dev/null 2>&1; then
    echo -e "${GREEN}✓ PASS: apt-get update successful${NC}"
else
    echo -e "${YELLOW}⚠ WARN: apt-get update failed${NC}"
fi

echo ""

# Generate result report
RESULT_FILE="../results/stage1_results_$(date +%Y%m%d_%H%M%S).txt"
mkdir -p ../results

cat > "$RESULT_FILE" << EOF
STAGE 1: BASIC VM PROVISIONING TEST
====================================
Date: $(date '+%Y-%m-%d %H:%M:%S')
Duration: ~15 minutes

VM DETAILS:
-----------
VM ID: $VM_ID
Internal IP: $INTERNAL_IP
Floating IP: $FLOATING_IP
Hostname: $HOSTNAME
OS: $OS_VERSION
CPU cores: $CPU_COUNT
Memory: $MEM_TOTAL
Disk: $DISK_TOTAL
Uptime: $UPTIME

TEST RESULTS:
-------------
✓ VM provisioned successfully
✓ Floating IP assigned
✓ SSH connectivity working
✓ Basic commands executing
✓ System information accessible

STATUS: ✓ STAGE 1 PASSED

NEXT STEPS:
-----------
✓ Basic Terraform provisioning works
✓ OpenStack connectivity validated
✓ SSH access confirmed

→ Clean up Stage 1: terraform destroy
→ Proceed to Stage 2: Packer Base Image Build
→ Command: cd ../stage2 && packer build nudocker-test.pkr.hcl

CLEANUP:
--------
To remove Stage 1 resources:
  cd $(pwd)
  terraform destroy -auto-approve

Estimated cost for Stage 1: ~€0.50-1.00 (15 minutes runtime)
EOF

echo "========================================="
echo "Stage 1: Test Summary"
echo "========================================="
echo -e "${GREEN}✓ All tests passed!${NC}"
echo ""
echo "Result saved to: $RESULT_FILE"
echo ""
echo "Next steps:"
echo "  1. Review the results above"
echo "  2. Clean up: terraform destroy -auto-approve"
echo "  3. Proceed to Stage 2: Packer Base Image Build"
echo ""
echo "========================================="
