#!/bin/bash
# Comprehensive HUN-REN Cloud Resource Collection
# Collects ALL information needed to design optimized HTCondor cluster
# for NuDocker MESA simulations (Pignatari article reproduction)
#
# Usage:
#   source app-cred-bridge-openrc.sh
#   ./collect_cloud_resources.sh

set -e

OUTPUT_DIR="cloud_resources_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$OUTPUT_DIR"

echo "========================================="
echo "HUN-REN Cloud Resource Collection"
echo "========================================="
echo "Purpose: Design optimized HTCondor cluster for NuDocker/MESA"
echo "Output directory: $OUTPUT_DIR"
echo ""

# Check authentication
if ! openstack token issue &> /dev/null; then
    echo "ERROR: Not authenticated. Please run: source app-cred-bridge-openrc.sh"
    exit 1
fi

echo "✓ Authenticated with OpenStack"
echo ""

# ============================================================================
# 1. PROJECT INFORMATION
# ============================================================================
echo "[1/15] Collecting project information..."

openstack project show $(openstack token issue -f value -c project_id) -f yaml > "$OUTPUT_DIR/01_project_info.yaml" 2>/dev/null
openstack token issue -f yaml > "$OUTPUT_DIR/01_token_info.yaml" 2>/dev/null

# ============================================================================
# 2. QUOTA INFORMATION
# ============================================================================
echo "[2/15] Collecting quota limits..."

openstack quota show -f yaml > "$OUTPUT_DIR/02_quota.yaml" 2>/dev/null
openstack quota show -f table > "$OUTPUT_DIR/02_quota.txt" 2>/dev/null

# Calculate available resources
cat > "$OUTPUT_DIR/02_quota_analysis.txt" << 'EOF'
QUOTA ANALYSIS FOR HTCONDOR CLUSTER
====================================

Current Quota Limits:
EOF

openstack quota show -f value -c cores -c instances -c ram -c floatingips -c networks -c ports -c security-groups >> "$OUTPUT_DIR/02_quota_analysis.txt" 2>/dev/null

# ============================================================================
# 3. CURRENT RESOURCE USAGE
# ============================================================================
echo "[3/15] Collecting current resource usage..."

openstack server list -f yaml > "$OUTPUT_DIR/03_current_servers.yaml" 2>/dev/null
openstack server list -f table > "$OUTPUT_DIR/03_current_servers.txt" 2>/dev/null

# Count resources in use
SERVERS_RUNNING=$(openstack server list -f value | wc -l)
FLOATING_IPS_USED=$(openstack floating ip list -f value | wc -l)

cat > "$OUTPUT_DIR/03_usage_summary.txt" << EOF
CURRENT RESOURCE USAGE
======================
Running instances: $SERVERS_RUNNING
Floating IPs allocated: $FLOATING_IPS_USED
EOF

# If servers exist, get detailed info
if [ "$SERVERS_RUNNING" -gt 0 ]; then
    echo "Instances Details:" >> "$OUTPUT_DIR/03_usage_summary.txt"
    openstack server list -f table -c Name -c Status -c Flavor -c Networks >> "$OUTPUT_DIR/03_usage_summary.txt" 2>/dev/null
fi

# ============================================================================
# 4. COMPUTE FLAVORS (VM SIZES)
# ============================================================================
echo "[4/15] Collecting compute flavors..."

openstack flavor list -f yaml > "$OUTPUT_DIR/04_flavors.yaml" 2>/dev/null
openstack flavor list -f table --sort-column VCPUs > "$OUTPUT_DIR/04_flavors.txt" 2>/dev/null

# Get detailed flavor specifications
cat > "$OUTPUT_DIR/04_flavor_details.txt" << 'EOF'
DETAILED FLAVOR SPECIFICATIONS
===============================

For HTCondor cluster design, we need to know exact CPU/RAM/Disk for each flavor.
EOF

openstack flavor list -f value -c ID | while read flavor_id; do
    echo "---" >> "$OUTPUT_DIR/04_flavor_details.txt"
    openstack flavor show "$flavor_id" -f yaml >> "$OUTPUT_DIR/04_flavor_details.txt" 2>/dev/null
done

# Create flavor recommendation matrix
cat > "$OUTPUT_DIR/04_flavor_recommendations.txt" << 'EOF'
FLAVOR RECOMMENDATIONS FOR HTCONDOR ROLES
==========================================

Based on typical HTCondor cluster design:

CENTRAL MANAGER:
  - Light workload (scheduling, matchmaking)
  - Recommended: 2 vCPU, 4-8 GB RAM
  - Suitable flavors from your cloud:
EOF

openstack flavor list -f value | awk '$6 == 2 && $4 >= 4096 {print "    - " $2 " (" $6 " vCPU, " $4 " MB RAM)"}' >> "$OUTPUT_DIR/04_flavor_recommendations.txt" 2>/dev/null

cat >> "$OUTPUT_DIR/04_flavor_recommendations.txt" << 'EOF'

SUBMIT NODE (if separate from central):
  - Medium workload (job submission, file staging)
  - Recommended: 2-4 vCPU, 8-16 GB RAM
  - Suitable flavors:
EOF

openstack flavor list -f value | awk '$6 >= 2 && $6 <= 4 && $4 >= 8192 {print "    - " $2 " (" $6 " vCPU, " $4 " MB RAM)"}' >> "$OUTPUT_DIR/04_flavor_recommendations.txt" 2>/dev/null

cat >> "$OUTPUT_DIR/04_flavor_recommendations.txt" << 'EOF'

EXECUTE NODES (MESA computation):
  - Heavy workload (MESA stellar evolution simulations)
  - Recommended: 4-16 vCPU, 8-32 GB RAM
  - MESA benefits from OpenMP parallelism
  - Suitable flavors:
EOF

openstack flavor list -f value | awk '$6 >= 4 && $4 >= 8192 {print "    - " $2 " (" $6 " vCPU, " $4 " MB RAM) - Can run " int($6/2) " MESA jobs concurrently"}' >> "$OUTPUT_DIR/04_flavor_recommendations.txt" 2>/dev/null

# ============================================================================
# 5. AVAILABLE IMAGES
# ============================================================================
echo "[5/15] Collecting available images..."

openstack image list -f yaml > "$OUTPUT_DIR/05_images.yaml" 2>/dev/null
openstack image list -f table --sort-column Name > "$OUTPUT_DIR/05_images.txt" 2>/dev/null

# Find Ubuntu images specifically
cat > "$OUTPUT_DIR/05_ubuntu_images.txt" << 'EOF'
UBUNTU IMAGES FOR NUDOCKER
===========================

NuDocker requires Ubuntu 20.04 or 22.04 for MESA compatibility.

Available Ubuntu images:
EOF

openstack image list -f value | grep -i ubuntu | awk '{print "  - " $2}' >> "$OUTPUT_DIR/05_ubuntu_images.txt" 2>/dev/null || echo "  No Ubuntu images found" >> "$OUTPUT_DIR/05_ubuntu_images.txt"

cat >> "$OUTPUT_DIR/05_ubuntu_images.txt" << 'EOF'

RECOMMENDATION:
- Use Ubuntu 22.04 LTS for best compatibility
- Will be used as base for Packer custom image build
- Custom image will include: HTCondor, Docker, Singularity, NFS, MESA dependencies
EOF

# ============================================================================
# 6. NETWORK CONFIGURATION
# ============================================================================
echo "[6/15] Collecting network configuration..."

openstack network list -f yaml > "$OUTPUT_DIR/06_networks.yaml" 2>/dev/null
openstack network list -f table > "$OUTPUT_DIR/06_networks.txt" 2>/dev/null

openstack network list --external -f yaml > "$OUTPUT_DIR/06_external_networks.yaml" 2>/dev/null
openstack network list --external -f table > "$OUTPUT_DIR/06_external_networks.txt" 2>/dev/null

openstack subnet list -f yaml > "$OUTPUT_DIR/06_subnets.yaml" 2>/dev/null
openstack subnet list -f table > "$OUTPUT_DIR/06_subnets.txt" 2>/dev/null

openstack router list -f yaml > "$OUTPUT_DIR/06_routers.yaml" 2>/dev/null
openstack router list -f table > "$OUTPUT_DIR/06_routers.txt" 2>/dev/null

# Network analysis
cat > "$OUTPUT_DIR/06_network_analysis.txt" << 'EOF'
NETWORK CONFIGURATION ANALYSIS
===============================

For HTCondor cluster, you need:
1. Internal network - for inter-node communication
2. External network - for floating IP assignment (SSH access)
3. Router - connecting internal to external

Your networks:
EOF

echo "" >> "$OUTPUT_DIR/06_network_analysis.txt"
echo "Internal networks:" >> "$OUTPUT_DIR/06_network_analysis.txt"
openstack network list -f value | grep -v "external\|public" | awk '{print "  - " $2}' >> "$OUTPUT_DIR/06_network_analysis.txt" 2>/dev/null

echo "" >> "$OUTPUT_DIR/06_network_analysis.txt"
echo "External networks (for floating IPs):" >> "$OUTPUT_DIR/06_network_analysis.txt"
openstack network list --external -f value | awk '{print "  - " $2}' >> "$OUTPUT_DIR/06_network_analysis.txt" 2>/dev/null

# ============================================================================
# 7. SECURITY GROUPS
# ============================================================================
echo "[7/15] Collecting security groups..."

openstack security group list -f yaml > "$OUTPUT_DIR/07_security_groups.yaml" 2>/dev/null
openstack security group list -f table > "$OUTPUT_DIR/07_security_groups.txt" 2>/dev/null

# Get rules for each security group
mkdir -p "$OUTPUT_DIR/security_group_rules"
openstack security group list -f value -c ID | while read sg_id; do
    sg_name=$(openstack security group show "$sg_id" -f value -c name 2>/dev/null)
    openstack security group rule list "$sg_id" -f table > "$OUTPUT_DIR/security_group_rules/${sg_name}.txt" 2>/dev/null
done

cat > "$OUTPUT_DIR/07_security_requirements.txt" << 'EOF'
SECURITY GROUP REQUIREMENTS FOR HTCONDOR
=========================================

HTCondor cluster requires these ports open:

CENTRAL MANAGER:
  - TCP 9618 (Collector)
  - TCP 9600-9700 (HTCondor daemons)
  - TCP 22 (SSH)

EXECUTE NODES:
  - TCP 9600-9700 (HTCondor communication)
  - TCP 22 (SSH - for administration)

NFS (if used for shared storage):
  - TCP/UDP 2049 (NFS)
  - TCP/UDP 111 (RPC bind)

INTERNET ACCESS (outbound):
  - Required for package installation during setup
  - Required for Docker image pulls
  - Can be restricted after setup if needed

Current security groups will be analyzed for compatibility.
EOF

# ============================================================================
# 8. SSH KEY PAIRS
# ============================================================================
echo "[8/15] Collecting SSH key pairs..."

openstack keypair list -f yaml > "$OUTPUT_DIR/08_keypairs.yaml" 2>/dev/null
openstack keypair list -f table > "$OUTPUT_DIR/08_keypairs.txt" 2>/dev/null

KEYPAIR_COUNT=$(openstack keypair list -f value | wc -l)

cat > "$OUTPUT_DIR/08_keypair_status.txt" << EOF
SSH KEY PAIR STATUS
===================

Registered key pairs: $KEYPAIR_COUNT

EOF

if [ "$KEYPAIR_COUNT" -gt 0 ]; then
    echo "Available key pairs:" >> "$OUTPUT_DIR/08_keypair_status.txt"
    openstack keypair list -f value -c Name | while read kp; do
        echo "  - $kp" >> "$OUTPUT_DIR/08_keypair_status.txt"
    done
else
    cat >> "$OUTPUT_DIR/08_keypair_status.txt" << 'EOF'
No SSH key pairs registered.

ACTION REQUIRED:
Generate and upload SSH key pair:
  ssh-keygen -t ed25519 -f ~/.ssh/hun-ren-key
  openstack keypair create --public-key ~/.ssh/hun-ren-key.pub hun-ren-key
EOF
fi

# ============================================================================
# 9. FLOATING IPS
# ============================================================================
echo "[9/15] Collecting floating IP information..."

openstack floating ip list -f yaml > "$OUTPUT_DIR/09_floating_ips.yaml" 2>/dev/null
openstack floating ip list -f table > "$OUTPUT_DIR/09_floating_ips.txt" 2>/dev/null

# Get floating IP quota vs usage
FIP_QUOTA=$(openstack quota show -f value -c floatingips)
FIP_USED=$(openstack floating ip list -f value | wc -l)
FIP_AVAILABLE=$((FIP_QUOTA - FIP_USED))

cat > "$OUTPUT_DIR/09_floating_ip_analysis.txt" << EOF
FLOATING IP ANALYSIS
====================

Quota: $FIP_QUOTA
Used: $FIP_USED
Available: $FIP_AVAILABLE

For HTCondor cluster, you typically need:
  - 1 floating IP for Central Manager (SSH access, job submission)
  - Execute nodes can be internal-only (no floating IPs needed)

Minimum required: 1 floating IP
Recommended: 1-2 floating IPs (central manager + optional submit node)
EOF

# ============================================================================
# 10. VOLUMES (BLOCK STORAGE)
# ============================================================================
echo "[10/15] Collecting volume/storage information..."

openstack volume list -f yaml > "$OUTPUT_DIR/10_volumes.yaml" 2>/dev/null
openstack volume list -f table > "$OUTPUT_DIR/10_volumes.txt" 2>/dev/null

# Volume types
openstack volume type list -f yaml > "$OUTPUT_DIR/10_volume_types.yaml" 2>/dev/null
openstack volume type list -f table > "$OUTPUT_DIR/10_volume_types.txt" 2>/dev/null

# Storage quota
VOLUME_QUOTA=$(openstack quota show -f value -c gigabytes)
VOLUMES_QUOTA=$(openstack quota show -f value -c volumes)

cat > "$OUTPUT_DIR/10_storage_analysis.txt" << EOF
STORAGE ANALYSIS FOR MESA SIMULATIONS
======================================

Volume quota: ${VOLUME_QUOTA} GB total, ${VOLUMES_QUOTA} volumes max

MESA STORAGE REQUIREMENTS:
  - MESA source code: ~500 MB per version
  - Compiled MESA: ~2-5 GB per version
  - Results per simulation: 100 MB - 10 GB (depends on resolution, saved profiles)
  - NuDocker containers: ~2-4 GB per image

RECOMMENDED STORAGE DESIGN:
  1. Root disks (ephemeral): 40-80 GB per VM
  2. Shared NFS storage: 100-500 GB (for MESA, results, containers)
     - Can use block storage volume attached to central manager
     - Or use instance storage if available

For Pignatari article reproduction:
  - Parameter grid: ~10-100 models
  - Storage needed: ~100-1000 GB total (depends on saved resolution)
EOF

# ============================================================================
# 11. AVAILABILITY ZONES
# ============================================================================
echo "[11/15] Collecting availability zones..."

openstack availability zone list -f yaml > "$OUTPUT_DIR/11_availability_zones.yaml" 2>/dev/null
openstack availability zone list -f table > "$OUTPUT_DIR/11_availability_zones.txt" 2>/dev/null

cat > "$OUTPUT_DIR/11_az_analysis.txt" << 'EOF'
AVAILABILITY ZONE ANALYSIS
==========================

For HTCondor cluster:
  - All nodes should typically be in same AZ for best network performance
  - Exception: Multi-AZ deployment for high availability (more complex)

RECOMMENDATION: Deploy all cluster nodes in the same availability zone.
EOF

# ============================================================================
# 12. SERVICE CATALOG
# ============================================================================
echo "[12/15] Collecting OpenStack service catalog..."

openstack catalog list -f yaml > "$OUTPUT_DIR/12_services.yaml" 2>/dev/null
openstack catalog list -f table > "$OUTPUT_DIR/12_services.txt" 2>/dev/null

cat > "$OUTPUT_DIR/12_service_analysis.txt" << 'EOF'
OPENSTACK SERVICES ANALYSIS
============================

Required services for HTCondor cluster:
  ✓ Nova (Compute) - for VMs
  ✓ Neutron (Network) - for networking
  ✓ Glance (Image) - for VM images
  ○ Cinder (Volume) - optional, for shared storage
  ○ Swift/Object Store - optional, for result archival

Your available services listed in services.yaml
EOF

# ============================================================================
# 13. LIMITS AND ABSOLUTE USAGE
# ============================================================================
echo "[13/15] Collecting absolute limits..."

openstack limits show --absolute -f yaml > "$OUTPUT_DIR/13_absolute_limits.yaml" 2>/dev/null || echo "Absolute limits not available" > "$OUTPUT_DIR/13_absolute_limits.txt"
openstack limits show --absolute -f table > "$OUTPUT_DIR/13_absolute_limits.txt" 2>/dev/null || true

# ============================================================================
# 14. PRICING (if available)
# ============================================================================
echo "[14/15] Collecting pricing information (if available)..."

cat > "$OUTPUT_DIR/14_pricing_notes.txt" << 'EOF'
PRICING INFORMATION
===================

Contact HUN-REN cloud support for detailed pricing.

Typical OpenStack cloud pricing factors:
  - vCPU hours
  - RAM GB hours
  - Storage GB/month
  - Floating IP allocation
  - Network egress (outbound traffic)

COST ESTIMATION FOR HTCONDOR CLUSTER:
  - Testing (Stages 1-4): ~€7-10 total
  - Small cluster (1 central + 2 execute): ~€50-100/month
  - Medium cluster (1 central + 5 execute): ~€100-300/month
  - Large cluster (1 central + 10 execute): ~€200-500/month

COST OPTIMIZATION:
  - Use preemptible/spot instances if available (50-90% discount)
  - Delete resources when not in use
  - Use instance scheduling (auto-shutdown during nights/weekends)
  - Compress and archive results regularly
EOF

# ============================================================================
# 15. HYPERVISOR STATISTICS
# ============================================================================
echo "[15/15] Collecting hypervisor statistics..."

openstack hypervisor list -f yaml > "$OUTPUT_DIR/15_hypervisors.yaml" 2>/dev/null || echo "Hypervisor info not accessible" > "$OUTPUT_DIR/15_hypervisors.txt"
openstack hypervisor list -f table > "$OUTPUT_DIR/15_hypervisors.txt" 2>/dev/null || true

openstack hypervisor stats show -f yaml > "$OUTPUT_DIR/15_hypervisor_stats.yaml" 2>/dev/null || true
openstack hypervisor stats show -f table > "$OUTPUT_DIR/15_hypervisor_stats.txt" 2>/dev/null || true

# ============================================================================
# GENERATE COMPREHENSIVE SUMMARY
# ============================================================================
echo ""
echo "Generating comprehensive summary..."

cat > "$OUTPUT_DIR/00_SUMMARY_AND_RECOMMENDATIONS.txt" << 'EOF'
================================================================================
HUN-REN CLOUD RESOURCE SUMMARY
HTCONDOR CLUSTER FOR NUDOCKER/MESA SIMULATIONS
================================================================================

Generated: $(date '+%Y-%m-%d %H:%M:%S')

PURPOSE:
--------
Design optimized HTCondor cluster for running NuDocker containerized MESA
simulations to reproduce results from Pignatari et al. nucleosynthesis studies.

CONTENTS OF THIS DIRECTORY:
---------------------------
01_project_info.yaml          - Your HUN-REN project details
02_quota.yaml                 - Resource limits for your project
02_quota_analysis.txt         - Quota breakdown for cluster planning
03_current_servers.yaml       - Currently running VMs
03_usage_summary.txt          - Current resource usage
04_flavors.yaml               - Available VM sizes
04_flavor_details.txt         - Detailed flavor specifications
04_flavor_recommendations.txt - Recommended flavors for each cluster role
05_images.yaml                - Available OS images
05_ubuntu_images.txt          - Ubuntu images for NuDocker
06_networks.yaml              - Network configuration
06_network_analysis.txt       - Network requirements analysis
07_security_groups.yaml       - Current security groups
07_security_requirements.txt  - Required firewall rules for HTCondor
08_keypairs.yaml              - Registered SSH keys
08_keypair_status.txt         - SSH key requirements
09_floating_ips.yaml          - External IP addresses
09_floating_ip_analysis.txt   - Floating IP requirements
10_volumes.yaml               - Block storage volumes
10_storage_analysis.txt       - Storage requirements for MESA
11_availability_zones.yaml    - Compute zones
11_az_analysis.txt            - Availability zone recommendations
12_services.yaml              - Available OpenStack services
12_service_analysis.txt       - Required vs. available services
13_absolute_limits.yaml       - Hard limits
14_pricing_notes.txt          - Cost estimation guidance
15_hypervisors.yaml           - Cloud infrastructure stats

NEXT STEPS:
-----------
1. Review the files in this directory
2. Check quota analysis (02_quota_analysis.txt)
3. Review flavor recommendations (04_flavor_recommendations.txt)
4. Verify network configuration (06_network_analysis.txt)
5. Check storage requirements (10_storage_analysis.txt)

These files will be used to generate:
  - Optimized cluster design
  - Custom terraform.tfvars configurations
  - Resource allocation plan
  - Cost estimates
  - Deployment timeline

================================================================================
TO SHARE THESE RESULTS:
================================================================================

Option 1: Upload entire directory as ZIP
  zip -r cloud_resources.zip $(basename $OUTPUT_DIR)

Option 2: Share specific files
  Most important files:
    - 00_SUMMARY_AND_RECOMMENDATIONS.txt (this file)
    - 02_quota_analysis.txt
    - 04_flavor_recommendations.txt
    - 06_network_analysis.txt
    - 10_storage_analysis.txt

Option 3: Generate single combined file
  cat $(basename $OUTPUT_DIR)/*.txt > combined_report.txt

================================================================================
EOF

# Fill in the actual date in summary
sed -i "s/\$(date '+%Y-%m-%d %H:%M:%S')/$(date '+%Y-%m-%d %H:%M:%S')/" "$OUTPUT_DIR/00_SUMMARY_AND_RECOMMENDATIONS.txt" 2>/dev/null || true

# ============================================================================
# CREATE ARCHIVE
# ============================================================================
echo ""
echo "Creating archive..."

ARCHIVE_NAME="${OUTPUT_DIR}.tar.gz"
tar czf "$ARCHIVE_NAME" "$OUTPUT_DIR"

# ============================================================================
# COMPLETION SUMMARY
# ============================================================================
echo ""
echo "========================================="
echo "Collection Complete!"
echo "========================================="
echo ""
echo "Output directory: $OUTPUT_DIR"
echo "Archive created: $ARCHIVE_NAME"
echo ""
echo "Files collected: $(ls -1 $OUTPUT_DIR | wc -l)"
echo "Archive size: $(du -h $ARCHIVE_NAME | awk '{print $1}')"
echo ""
echo "Next steps:"
echo "  1. Review summary: cat $OUTPUT_DIR/00_SUMMARY_AND_RECOMMENDATIONS.txt"
echo "  2. Share archive: Upload $ARCHIVE_NAME"
echo "  3. Or share directory: Upload entire $OUTPUT_DIR folder"
echo ""
echo "Based on this data, I will create:"
echo "  ✓ Optimized HTCondor cluster design"
echo "  ✓ Custom configuration files"
echo "  ✓ MESA workflow for Pignatari article reproduction"
echo "  ✓ Resource allocation and cost estimates"
echo ""
