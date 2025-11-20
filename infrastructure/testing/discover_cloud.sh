#!/bin/bash
# HUN-REN Cloud Discovery Script
# Generates comprehensive report of cloud capabilities and current usage
#
# Usage:
#   1. Source your OpenRC file: source app-cred-bridge-openrc.sh
#   2. Run this script: ./discover_cloud.sh
#   3. Results saved to: hun-ren-cloud-report_TIMESTAMP.txt

set -e

REPORT_FILE="hun-ren-cloud-report_$(date +%Y%m%d_%H%M%S).txt"

echo "========================================="
echo "HUN-REN Cloud Discovery"
echo "========================================="
echo "Starting cloud environment discovery..."
echo "Report will be saved to: $REPORT_FILE"
echo ""

# Check if OpenStack CLI is available
if ! command -v openstack &> /dev/null; then
    echo "ERROR: OpenStack CLI not found"
    echo "Please install: pip install python-openstackclient"
    exit 1
fi

# Check if authenticated
if ! openstack token issue &> /dev/null; then
    echo "ERROR: Not authenticated with OpenStack"
    echo "Please source your OpenRC file first:"
    echo "  source app-cred-bridge-openrc.sh"
    exit 1
fi

echo "✓ OpenStack CLI available"
echo "✓ Authentication successful"
echo ""

# Start building report
cat > "$REPORT_FILE" << 'EOF'
================================================================================
HUN-REN CLOUD ENVIRONMENT DISCOVERY REPORT
================================================================================
Generated: $(date '+%Y-%m-%d %H:%M:%S')

This report provides a comprehensive overview of your HUN-REN cloud project:
- Available compute flavors (VM sizes)
- Current quota limits and usage
- Available VM images
- Network configuration
- Storage capabilities
- Available services

================================================================================
1. PROJECT INFORMATION
================================================================================
EOF

echo "Gathering project information..."

# Get project info
PROJECT_INFO=$(openstack project show -f yaml $(openstack token issue -f value -c project_id) 2>/dev/null || echo "N/A")
echo "$PROJECT_INFO" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

cat >> "$REPORT_FILE" << 'EOF'
================================================================================
2. QUOTA LIMITS AND CURRENT USAGE
================================================================================

This shows your project limits and how much you're currently using.
Important for planning cluster size.

EOF

echo "Checking quotas and usage..."

# Compute quota
echo "2.1 COMPUTE QUOTA" >> "$REPORT_FILE"
echo "----------------" >> "$REPORT_FILE"
openstack quota show -f yaml 2>/dev/null | grep -E "(cores|instances|ram)" >> "$REPORT_FILE" 2>/dev/null || echo "Could not retrieve compute quota" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# Current compute usage
echo "2.2 CURRENT COMPUTE USAGE" >> "$REPORT_FILE"
echo "-------------------------" >> "$REPORT_FILE"
INSTANCE_COUNT=$(openstack server list -f value | wc -l)
echo "Running instances: $INSTANCE_COUNT" >> "$REPORT_FILE"

# Get usage details if available
if command -v openstack &> /dev/null; then
    openstack usage show -f yaml 2>/dev/null | head -20 >> "$REPORT_FILE" 2>/dev/null || echo "Detailed usage not available" >> "$REPORT_FILE"
fi
echo "" >> "$REPORT_FILE"

# Network quota
echo "2.3 NETWORK QUOTA" >> "$REPORT_FILE"
echo "-----------------" >> "$REPORT_FILE"
openstack quota show -f yaml 2>/dev/null | grep -E "(network|subnet|port|floatingip|security_group)" >> "$REPORT_FILE" 2>/dev/null || echo "Could not retrieve network quota" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# Volume quota
echo "2.4 VOLUME/STORAGE QUOTA" >> "$REPORT_FILE"
echo "------------------------" >> "$REPORT_FILE"
openstack quota show -f yaml 2>/dev/null | grep -E "(gigabytes|volumes|snapshots)" >> "$REPORT_FILE" 2>/dev/null || echo "Could not retrieve volume quota" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

cat >> "$REPORT_FILE" << 'EOF'
================================================================================
3. AVAILABLE COMPUTE FLAVORS (VM SIZES)
================================================================================

Flavors define VM specifications (CPU, RAM, disk).
For NuDocker testing stages, you'll need:
  - Stage 1: ≥2 vCPU, ≥4GB RAM  → Recommended: m2.medium or r2.medium
  - Stage 2: ≥4 vCPU, ≥8GB RAM  → Recommended: m2.large or r2.large
  - Stage 3: ≥4 vCPU, ≥8GB RAM  → Recommended: m2.large or r2.large
  - Stage 4: 2 VMs (≥2+4 vCPU)  → Recommended: m2.medium + m2.large

EOF

echo "Listing compute flavors..."

openstack flavor list -f table --sort-column VCPUs >> "$REPORT_FILE" 2>/dev/null
echo "" >> "$REPORT_FILE"

# Detailed flavor info
echo "3.1 FLAVOR DETAILS (for planning)" >> "$REPORT_FILE"
echo "----------------------------------" >> "$REPORT_FILE"
while IFS= read -r flavor_id; do
    if [ -n "$flavor_id" ]; then
        openstack flavor show "$flavor_id" -f yaml 2>/dev/null | grep -E "(name|vcpus|ram|disk)" >> "$REPORT_FILE" 2>/dev/null
        echo "---" >> "$REPORT_FILE"
    fi
done < <(openstack flavor list -f value -c ID)
echo "" >> "$REPORT_FILE"

cat >> "$REPORT_FILE" << 'EOF'
================================================================================
4. AVAILABLE VM IMAGES
================================================================================

Images are base operating systems for VMs.
NuDocker requires Ubuntu 22.04 (or 20.04) for compatibility.

EOF

echo "Listing available images..."

openstack image list -f table --sort-column Name >> "$REPORT_FILE" 2>/dev/null
echo "" >> "$REPORT_FILE"

# Find Ubuntu images specifically
echo "4.1 UBUNTU IMAGES (recommended for NuDocker)" >> "$REPORT_FILE"
echo "---------------------------------------------" >> "$REPORT_FILE"
openstack image list -f table 2>/dev/null | grep -i ubuntu >> "$REPORT_FILE" || echo "No Ubuntu images found" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

cat >> "$REPORT_FILE" << 'EOF'
================================================================================
5. NETWORK CONFIGURATION
================================================================================

Networks are required for VM connectivity.
You need both internal networks and external networks (for floating IPs).

EOF

echo "Gathering network information..."

echo "5.1 ALL NETWORKS" >> "$REPORT_FILE"
echo "----------------" >> "$REPORT_FILE"
openstack network list -f table >> "$REPORT_FILE" 2>/dev/null
echo "" >> "$REPORT_FILE"

echo "5.2 EXTERNAL NETWORKS (for floating IPs)" >> "$REPORT_FILE"
echo "-----------------------------------------" >> "$REPORT_FILE"
openstack network list --external -f table >> "$REPORT_FILE" 2>/dev/null || echo "No external networks found" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

echo "5.3 SUBNETS" >> "$REPORT_FILE"
echo "-----------" >> "$REPORT_FILE"
openstack subnet list -f table >> "$REPORT_FILE" 2>/dev/null
echo "" >> "$REPORT_FILE"

echo "5.4 ROUTERS" >> "$REPORT_FILE"
echo "-----------" >> "$REPORT_FILE"
openstack router list -f table >> "$REPORT_FILE" 2>/dev/null
echo "" >> "$REPORT_FILE"

cat >> "$REPORT_FILE" << 'EOF'
================================================================================
6. SECURITY GROUPS
================================================================================

Current security groups in your project.

EOF

echo "Listing security groups..."

openstack security group list -f table >> "$REPORT_FILE" 2>/dev/null
echo "" >> "$REPORT_FILE"

cat >> "$REPORT_FILE" << 'EOF'
================================================================================
7. SSH KEY PAIRS
================================================================================

Key pairs registered for VM access.
You need at least one key pair for SSH access to VMs.

EOF

echo "Checking key pairs..."

openstack keypair list -f table >> "$REPORT_FILE" 2>/dev/null
echo "" >> "$REPORT_FILE"

cat >> "$REPORT_FILE" << 'EOF'
================================================================================
8. CURRENT RUNNING INSTANCES
================================================================================

VMs currently running in your project.

EOF

echo "Listing current instances..."

INSTANCE_COUNT=$(openstack server list -f value | wc -l)
if [ "$INSTANCE_COUNT" -gt 0 ]; then
    openstack server list -f table >> "$REPORT_FILE" 2>/dev/null
    echo "" >> "$REPORT_FILE"

    echo "8.1 INSTANCE DETAILS" >> "$REPORT_FILE"
    echo "--------------------" >> "$REPORT_FILE"
    while IFS= read -r server_id; do
        if [ -n "$server_id" ]; then
            echo "Instance: $(openstack server show "$server_id" -f value -c name)" >> "$REPORT_FILE"
            openstack server show "$server_id" -f yaml 2>/dev/null | grep -E "(flavor|image|status|addresses)" >> "$REPORT_FILE"
            echo "---" >> "$REPORT_FILE"
        fi
    done < <(openstack server list -f value -c ID)
else
    echo "No running instances" >> "$REPORT_FILE"
fi
echo "" >> "$REPORT_FILE"

cat >> "$REPORT_FILE" << 'EOF'
================================================================================
9. FLOATING IPs
================================================================================

External IP addresses for VM access from outside the cloud.

EOF

echo "Checking floating IPs..."

FIP_COUNT=$(openstack floating ip list -f value | wc -l)
if [ "$FIP_COUNT" -gt 0 ]; then
    openstack floating ip list -f table >> "$REPORT_FILE" 2>/dev/null
else
    echo "No floating IPs currently allocated" >> "$REPORT_FILE"
fi
echo "" >> "$REPORT_FILE"

cat >> "$REPORT_FILE" << 'EOF'
================================================================================
10. VOLUMES (BLOCK STORAGE)
================================================================================

Persistent storage volumes in your project.

EOF

echo "Checking volumes..."

VOLUME_COUNT=$(openstack volume list -f value 2>/dev/null | wc -l)
if [ "$VOLUME_COUNT" -gt 0 ]; then
    openstack volume list -f table 2>/dev/null >> "$REPORT_FILE"
else
    echo "No volumes currently created" >> "$REPORT_FILE"
fi
echo "" >> "$REPORT_FILE"

cat >> "$REPORT_FILE" << 'EOF'
================================================================================
11. AVAILABLE SERVICES
================================================================================

OpenStack services available in your cloud.

EOF

echo "Checking available services..."

openstack catalog list -f table >> "$REPORT_FILE" 2>/dev/null || echo "Could not retrieve service catalog" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

cat >> "$REPORT_FILE" << 'EOF'
================================================================================
12. AVAILABILITY ZONES
================================================================================

Zones where you can deploy resources.

EOF

echo "Checking availability zones..."

openstack availability zone list -f table >> "$REPORT_FILE" 2>/dev/null || echo "Could not retrieve availability zones" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

cat >> "$REPORT_FILE" << 'EOF'
================================================================================
13. RECOMMENDATIONS FOR NUDOCKER TESTING
================================================================================

Based on your cloud environment, here are recommendations for the testing stages:

REQUIRED RESOURCES FOR TESTING:
--------------------------------
Stage 0: Prerequisites
  - No cloud resources needed

Stage 1: Basic VM Provisioning
  - 1 VM with m2.medium (2 vCPU, 4GB RAM) or r2.medium (2 vCPU, 8GB RAM)
  - 1 Floating IP
  - Duration: 15 minutes

Stage 2: Packer Image Build
  - 1 VM with m2.large (4 vCPU, 8GB RAM) or r2.large (4 vCPU, 16GB RAM)
  - Temporary (auto-deleted after build)
  - 1 Floating IP (temporary)
  - Duration: 30-45 minutes
  - Creates 1 custom image (~3-4 GB)

Stage 3: Single-Node HTCondor
  - 1 VM with m2.large (4 vCPU, 8GB RAM)
  - 1 Floating IP
  - Duration: 30 minutes

Stage 4: Multi-Node Cluster
  - 1 VM with m2.medium (2 vCPU, 4GB RAM) - Central Manager
  - 1 VM with m2.large (4 vCPU, 8GB RAM) - Execute Node
  - 1 Floating IP (for central manager)
  - Duration: 45 minutes

TOTAL QUOTA NEEDED FOR TESTING:
--------------------------------
Peak usage (Stage 4):
  - 6 vCPUs
  - 12 GB RAM
  - ~80 GB disk (40GB per VM)
  - 2 instances
  - 1 floating IP
  - 1 custom image (~4 GB)

RECOMMENDED CONFIGURATIONS:
---------------------------
EOF

# Add specific recommendations based on detected resources
echo "" >> "$REPORT_FILE"
echo "Detected flavors suitable for NuDocker testing:" >> "$REPORT_FILE"
openstack flavor list -f value 2>/dev/null | grep -E "m2\.(tiny|small|medium|large)|r2\.(medium|large)" | \
    awk '{printf "  - %s (%s vCPU, %s MB RAM)\n", $2, $6, $4}' >> "$REPORT_FILE" || echo "  Check flavor list above" >> "$REPORT_FILE"

echo "" >> "$REPORT_FILE"
echo "Detected Ubuntu images:" >> "$REPORT_FILE"
openstack image list -f value 2>/dev/null | grep -i ubuntu | \
    awk '{printf "  - %s\n", $2}' >> "$REPORT_FILE" || echo "  Check image list above" >> "$REPORT_FILE"

echo "" >> "$REPORT_FILE"
echo "Detected networks:" >> "$REPORT_FILE"
openstack network list -f value 2>/dev/null | grep -v external | \
    awk '{printf "  - Internal: %s\n", $2}' >> "$REPORT_FILE"
openstack network list --external -f value 2>/dev/null | \
    awk '{printf "  - External: %s (for floating IPs)\n", $2}' >> "$REPORT_FILE"

cat >> "$REPORT_FILE" << 'EOF'

NEXT STEPS:
-----------
1. Review this report to understand your cloud resources
2. Ensure you have sufficient quota for testing
3. Note the recommended flavors, images, and networks
4. Update testing configuration files with these values
5. Start with Stage 0: Prerequisites verification

CONFIGURATION VALUES TO USE:
----------------------------
Copy these values into your terraform.tfvars files:

# Network configuration
network_name = "<your-internal-network-name>"  # From section 5.1
external_network_name = "<your-external-network-name>"  # From section 5.2

# Compute flavors
flavor_name = "m2.medium"  # For Stage 1 (or r2.medium)
central_flavor = "m2.medium"  # For Stage 4 central manager
execute_flavor = "m2.large"  # For Stage 4 execute node

# Image
source_image_name = "<ubuntu-22.04-image-name>"  # From section 4.1

# SSH key
key_pair_name = "<your-keypair-name>"  # From section 7

================================================================================
END OF REPORT
================================================================================

To share this report:
  1. Open the file: cat hun-ren-cloud-report_*.txt
  2. Copy the contents
  3. Paste into a message or upload the file

For questions about quota increases, contact HUN-REN cloud support.
EOF

echo ""
echo "========================================="
echo "Discovery Complete!"
echo "========================================="
echo ""
echo "Report saved to: $REPORT_FILE"
echo ""
echo "Next steps:"
echo "  1. Review the report: cat $REPORT_FILE"
echo "  2. Check section 13 for NuDocker-specific recommendations"
echo "  3. Share this file if you need help interpreting results"
echo ""
echo "To share with Claude:"
echo "  - Upload the file: $REPORT_FILE"
echo "  - Or copy/paste the contents in a message"
echo ""
