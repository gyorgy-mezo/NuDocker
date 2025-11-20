#!/bin/bash
# Quick Quota Check for NuDocker Testing
# Verifies you have sufficient quota for each testing stage
#
# Usage:
#   source app-cred-bridge-openrc.sh
#   ./check_quota.sh

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "========================================="
echo "NuDocker Testing - Quota Check"
echo "========================================="
echo ""

# Check authentication
if ! openstack token issue &> /dev/null; then
    echo -e "${RED}ERROR: Not authenticated${NC}"
    echo "Please source your OpenRC file:"
    echo "  source app-cred-bridge-openrc.sh"
    exit 1
fi

echo -e "${GREEN}✓ Authenticated with OpenStack${NC}"
echo ""

# Get quota information
echo "Retrieving quota information..."
QUOTA_OUTPUT=$(openstack quota show -f yaml 2>/dev/null)

# Parse quota values
CORES_LIMIT=$(echo "$QUOTA_OUTPUT" | grep "^cores:" | awk '{print $2}')
INSTANCES_LIMIT=$(echo "$QUOTA_OUTPUT" | grep "^instances:" | awk '{print $2}')
RAM_LIMIT=$(echo "$QUOTA_OUTPUT" | grep "^ram:" | awk '{print $2}')
FLOATINGIP_LIMIT=$(echo "$QUOTA_OUTPUT" | grep "^floatingips:" | awk '{print $2}')

# Get current usage
INSTANCES_USED=$(openstack server list -f value | wc -l)
CORES_USED=$(openstack server list -f value -c Flavor | while read flavor; do openstack flavor show "$flavor" -f value -c vcpus 2>/dev/null || echo 0; done | awk '{sum+=$1} END {print sum}')
# RAM calculation is complex, using approximate based on instances
FLOATINGIP_USED=$(openstack floating ip list -f value | wc -l)

# Calculate available
CORES_AVAILABLE=$((CORES_LIMIT - CORES_USED))
INSTANCES_AVAILABLE=$((INSTANCES_LIMIT - INSTANCES_USED))
FLOATINGIP_AVAILABLE=$((FLOATINGIP_LIMIT - FLOATINGIP_USED))

echo "========================================="
echo "Current Quota Status"
echo "========================================="
echo ""
printf "%-20s %10s %10s %10s\n" "Resource" "Limit" "Used" "Available"
printf "%-20s %10s %10s %10s\n" "--------" "-----" "----" "---------"
printf "%-20s %10d %10d %10d\n" "vCPUs" "$CORES_LIMIT" "$CORES_USED" "$CORES_AVAILABLE"
printf "%-20s %10d %10d %10d\n" "Instances" "$INSTANCES_LIMIT" "$INSTANCES_USED" "$INSTANCES_AVAILABLE"
printf "%-20s %10d %10s %10d\n" "RAM (MB)" "$RAM_LIMIT" "N/A" "N/A"
printf "%-20s %10d %10d %10d\n" "Floating IPs" "$FLOATINGIP_LIMIT" "$FLOATINGIP_USED" "$FLOATINGIP_AVAILABLE"
echo ""

# Testing stage requirements
echo "========================================="
echo "Testing Stage Requirements"
echo "========================================="
echo ""

check_stage() {
    local stage_name="$1"
    local cores_needed="$2"
    local instances_needed="$3"
    local fip_needed="$4"
    local duration="$5"

    echo "Stage: $stage_name"
    echo "  Duration: ~$duration"
    echo "  Requirements:"

    local all_ok=true

    # Check cores
    if [ "$CORES_AVAILABLE" -ge "$cores_needed" ]; then
        echo -e "    ${GREEN}✓${NC} vCPUs: $cores_needed (available: $CORES_AVAILABLE)"
    else
        echo -e "    ${RED}✗${NC} vCPUs: $cores_needed (available: $CORES_AVAILABLE) - INSUFFICIENT"
        all_ok=false
    fi

    # Check instances
    if [ "$INSTANCES_AVAILABLE" -ge "$instances_needed" ]; then
        echo -e "    ${GREEN}✓${NC} Instances: $instances_needed (available: $INSTANCES_AVAILABLE)"
    else
        echo -e "    ${RED}✗${NC} Instances: $instances_needed (available: $INSTANCES_AVAILABLE) - INSUFFICIENT"
        all_ok=false
    fi

    # Check floating IPs
    if [ "$FLOATINGIP_AVAILABLE" -ge "$fip_needed" ]; then
        echo -e "    ${GREEN}✓${NC} Floating IPs: $fip_needed (available: $FLOATINGIP_AVAILABLE)"
    else
        echo -e "    ${RED}✗${NC} Floating IPs: $fip_needed (available: $FLOATINGIP_AVAILABLE) - INSUFFICIENT"
        all_ok=false
    fi

    if [ "$all_ok" = true ]; then
        echo -e "  Status: ${GREEN}✓ CAN RUN${NC}"
    else
        echo -e "  Status: ${RED}✗ INSUFFICIENT QUOTA${NC}"
    fi
    echo ""
}

# Check each stage
check_stage "Stage 0: Prerequisites" 0 0 0 "10 min"
check_stage "Stage 1: Basic VM" 2 1 1 "15 min"
check_stage "Stage 2: Packer Build" 4 1 1 "45 min"
check_stage "Stage 3: Single-Node HTCondor" 4 1 1 "30 min"
check_stage "Stage 4: Multi-Node Cluster" 6 2 1 "45 min"

echo "========================================="
echo "Summary"
echo "========================================="
echo ""

# Overall assessment
if [ "$CORES_AVAILABLE" -ge 6 ] && [ "$INSTANCES_AVAILABLE" -ge 2 ] && [ "$FLOATINGIP_AVAILABLE" -ge 1 ]; then
    echo -e "${GREEN}✓ You have sufficient quota for all testing stages!${NC}"
    echo ""
    echo "You can proceed with the complete testing plan."
else
    echo -e "${YELLOW}⚠ Limited quota available${NC}"
    echo ""
    echo "Recommendations:"

    if [ "$CORES_AVAILABLE" -lt 6 ]; then
        echo "  - You may need to delete existing VMs to free up vCPUs"
        echo "  - Current VMs: $INSTANCES_USED (using ~$CORES_USED vCPUs)"
    fi

    if [ "$INSTANCES_AVAILABLE" -lt 2 ]; then
        echo "  - Stage 4 requires 2 instances"
        echo "  - Delete existing VMs or request quota increase"
    fi

    if [ "$FLOATINGIP_AVAILABLE" -lt 1 ]; then
        echo "  - No floating IPs available"
        echo "  - Release unused floating IPs or request quota increase"
    fi
fi

echo ""
echo "To free up resources:"
echo "  - List VMs: openstack server list"
echo "  - Delete VM: openstack server delete <vm-name>"
echo "  - List floating IPs: openstack floating ip list"
echo "  - Delete floating IP: openstack floating ip delete <ip-address>"
echo ""
echo "To request quota increase:"
echo "  - Contact HUN-REN cloud support"
echo "  - Specify required resources (see above)"
echo ""
