#!/bin/bash
# Cleanup/Destroy script for NuDocker HTCondor Infrastructure
# Usage: ./destroy.sh [--keep-images] [--keep-volume]

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Parse arguments
KEEP_IMAGES=false
KEEP_VOLUME=false

for arg in "$@"; do
    case $arg in
        --keep-images)
            KEEP_IMAGES=true
            ;;
        --keep-volume)
            KEEP_VOLUME=true
            ;;
        --help|-h)
            echo "NuDocker HTCondor Infrastructure Cleanup Script"
            echo ""
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  --keep-images    Keep Packer-built images"
            echo "  --keep-volume    Keep data volume (WARNING: detaches but doesn't delete)"
            echo "  --help          Show this help message"
            echo ""
            echo "Default behavior: Destroys all Terraform resources"
            echo ""
            exit 0
            ;;
        *)
            log_error "Unknown argument: $arg"
            exit 1
            ;;
    esac
done

# Warning
log_warn "=== DESTRUCTIVE OPERATION WARNING ==="
log_warn "This script will destroy your HTCondor cluster infrastructure"
log_warn ""

if [ "$KEEP_VOLUME" = false ]; then
    log_error "DATA LOSS WARNING: Shared storage volume will be DELETED"
    log_error "All MESA data, results, and containers will be PERMANENTLY LOST"
fi

log_warn ""
log_warn "Resources to be destroyed:"
log_warn "  - Central Manager VM"
log_warn "  - Execute Node VMs (5)"
log_warn "  - Private network and router"
log_warn "  - Security groups"
log_warn "  - Floating IP"
if [ "$KEEP_VOLUME" = false ]; then
    log_warn "  - Shared storage volume (500 GB) <-- DATA LOSS!"
fi

echo ""
echo -n "Type 'yes' to confirm destruction: "
read -r CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    log_info "Destruction cancelled"
    exit 0
fi

# Backup check
if [ "$KEEP_VOLUME" = false ]; then
    log_warn "Do you have a backup of your data? (y/n)"
    read -r BACKUP_CONFIRM
    if [ "$BACKUP_CONFIRM" != "y" ]; then
        log_error "Please backup your data before destroying the volume"
        log_error "Connect to cluster and run: tar czf backup.tar.gz /storage/"
        exit 1
    fi
fi

# Terraform destroy
log_info "=== Destroying Terraform Infrastructure ==="

cd terraform

if [ ! -f terraform.tfstate ]; then
    log_error "No Terraform state found. Nothing to destroy."
    exit 1
fi

# Optional: keep volume by modifying state temporarily
if [ "$KEEP_VOLUME" = true ]; then
    log_info "Preserving data volume..."
    # Remove volume from Terraform state (it will remain in OpenStack)
    terraform state rm openstack_blockstorage_volume_v3.shared_storage || true
    terraform state rm openstack_compute_volume_attach_v2.shared_storage_attach || true
fi

log_info "Running terraform destroy..."
terraform destroy -auto-approve

log_info "Terraform resources destroyed"

cd ..

# Optionally remove Packer images
if [ "$KEEP_IMAGES" = false ]; then
    log_info "=== Removing Packer Images ==="

    if command -v openstack >/dev/null 2>&1; then
        log_info "Searching for NuDocker images..."

        # List images
        IMAGES=$(openstack image list -f value -c Name | grep nudocker-htcondor-base || true)

        if [ -n "$IMAGES" ]; then
            echo "$IMAGES" | while read -r IMAGE_NAME; do
                log_info "Deleting image: $IMAGE_NAME"
                openstack image delete "$IMAGE_NAME"
            done
            log_info "Images removed"
        else
            log_info "No NuDocker images found"
        fi
    else
        log_warn "OpenStack CLI not available. Skipping image cleanup."
        log_warn "Remove images manually with: openstack image delete <image-name>"
    fi
else
    log_info "Keeping Packer-built images (--keep-images specified)"
fi

# Cleanup local files
log_info "=== Cleaning Up Local Files ==="

rm -f deployment_info.txt
rm -f terraform/tfplan
rm -f terraform/terraform.tfstate.backup
rm -f ansible/inventory/hosts.ini.bak

log_info "Local cleanup completed"

# Summary
log_info "=== Destruction Summary ==="
log_info "✓ Terraform infrastructure destroyed"

if [ "$KEEP_VOLUME" = true ]; then
    log_warn "⚠ Data volume PRESERVED but detached"
    log_warn "  To reattach later, you'll need to manually attach it to a new VM"
    log_warn "  Volume name: nudocker-htcondor-shared-storage"
else
    log_info "✓ Data volume destroyed"
fi

if [ "$KEEP_IMAGES" = true ]; then
    log_info "⚠ Packer images PRESERVED"
    log_info "  To remove later: openstack image delete nudocker-htcondor-base-YYYYMMDD-HHMM"
else
    log_info "✓ Packer images destroyed"
fi

log_info ""
log_info "Destruction completed successfully"

if [ "$KEEP_VOLUME" = true ]; then
    log_warn ""
    log_warn "IMPORTANT: Data volume still exists in your OpenStack project"
    log_warn "It will continue to incur storage costs until deleted"
    log_warn "To delete manually: openstack volume delete nudocker-htcondor-shared-storage"
fi
