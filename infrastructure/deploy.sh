#!/bin/bash
# Complete deployment automation script for NuDocker HTCondor Infrastructure
# Usage: ./deploy.sh [phase]
# Phases: packer, terraform, ansible, all

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Prerequisites check
check_prerequisites() {
    log_info "Checking prerequisites..."

    local missing=0

    if ! command_exists terraform; then
        log_error "Terraform not found. Install from https://www.terraform.io/downloads"
        missing=1
    fi

    if ! command_exists packer; then
        log_error "Packer not found. Install from https://www.packer.io/downloads"
        missing=1
    fi

    if ! command_exists ansible; then
        log_error "Ansible not found. Install with: pip install ansible"
        missing=1
    fi

    if ! command_exists ssh; then
        log_error "SSH client not found"
        missing=1
    fi

    if [ ! -f ~/.ssh/id_rsa.pub ]; then
        log_warn "SSH key not found at ~/.ssh/id_rsa.pub"
        log_warn "Generate with: ssh-keygen -t rsa -b 4096"
    fi

    if [ $missing -eq 1 ]; then
        log_error "Missing required tools. Please install them first."
        exit 1
    fi

    log_info "All prerequisites satisfied"
}

# Phase 1: Build Packer images
phase_packer() {
    log_info "=== Phase 1: Building Packer Images ==="

    cd packer

    if [ ! -f variables.pkrvars.hcl ]; then
        log_error "Packer variables file not found: packer/variables.pkrvars.hcl"
        log_error "Copy from variables.pkrvars.hcl.example and fill in your values"
        exit 1
    fi

    log_info "Validating Packer template..."
    packer validate -var-file=variables.pkrvars.hcl nudocker-htcondor.pkr.hcl

    log_info "Building base image... (this will take 30-45 minutes)"
    packer build -var-file=variables.pkrvars.hcl nudocker-htcondor.pkr.hcl

    log_info "Packer build completed successfully"
    log_warn "IMPORTANT: Note the image name and update terraform.tfvars"

    cd ..
}

# Phase 2: Provision with Terraform
phase_terraform() {
    log_info "=== Phase 2: Provisioning Infrastructure with Terraform ==="

    cd terraform

    if [ ! -f terraform.tfvars ]; then
        log_error "Terraform variables file not found: terraform/terraform.tfvars"
        log_error "Copy from terraform.tfvars.example and fill in your values"
        exit 1
    fi

    log_info "Initializing Terraform..."
    terraform init

    log_info "Planning infrastructure..."
    terraform plan -out=tfplan

    log_warn "Review the plan above. Press Enter to continue or Ctrl+C to abort"
    read -r

    log_info "Applying Terraform configuration... (this will take 10-15 minutes)"
    terraform apply tfplan

    log_info "Saving outputs..."
    terraform output > ../deployment_info.txt

    log_info "Terraform deployment completed successfully"

    # Get floating IP
    CENTRAL_IP=$(terraform output -raw central_manager_floating_ip)
    log_info "Central Manager IP: $CENTRAL_IP"
    log_info "SSH command: ssh -i ~/.ssh/id_rsa ubuntu@$CENTRAL_IP"

    # Wait for SSH to be available
    log_info "Waiting for SSH to be available..."
    for i in {1..30}; do
        if ssh -i ~/.ssh/id_rsa -o ConnectTimeout=5 -o StrictHostKeyChecking=no ubuntu@$CENTRAL_IP "exit" 2>/dev/null; then
            log_info "SSH is available"
            break
        fi
        echo -n "."
        sleep 10
    done
    echo ""

    cd ..
}

# Phase 3: Configure with Ansible
phase_ansible() {
    log_info "=== Phase 3: Configuring Cluster with Ansible ==="

    cd ansible

    # Get floating IP from Terraform
    if [ -f ../terraform/terraform.tfstate ]; then
        CENTRAL_IP=$(cd ../terraform && terraform output -raw central_manager_floating_ip 2>/dev/null || echo "")
    else
        log_error "Terraform state not found. Run terraform phase first."
        exit 1
    fi

    if [ -z "$CENTRAL_IP" ]; then
        log_error "Could not get central manager IP from Terraform"
        exit 1
    fi

    log_info "Central Manager IP: $CENTRAL_IP"

    # Update inventory
    log_info "Updating Ansible inventory..."
    sed -i.bak "s/FLOATING_IP_HERE/$CENTRAL_IP/" inventory/hosts.ini

    # Check HTCondor pool password
    if [ -z "$HTCONDOR_POOL_PASSWORD" ]; then
        log_warn "HTCONDOR_POOL_PASSWORD not set"
        echo -n "Enter HTCondor pool password (or press Enter to read from terraform.tfvars): "
        read -r HTCONDOR_POOL_PASSWORD

        if [ -z "$HTCONDOR_POOL_PASSWORD" ]; then
            # Try to extract from terraform.tfvars
            HTCONDOR_POOL_PASSWORD=$(grep htcondor_pool_password ../terraform/terraform.tfvars | cut -d'"' -f2 || echo "")
        fi

        if [ -z "$HTCONDOR_POOL_PASSWORD" ]; then
            log_error "HTCondor pool password is required"
            exit 1
        fi

        export HTCONDOR_POOL_PASSWORD
    fi

    log_info "Installing Ansible requirements..."
    ansible-galaxy collection install -r requirements.yml

    log_info "Testing Ansible connectivity..."
    if ! ansible central_manager -m ping; then
        log_error "Cannot connect to central manager"
        exit 1
    fi

    log_info "Running Ansible playbook... (this will take 20-30 minutes)"

    cd playbooks
    ansible-playbook site.yml

    log_info "Ansible configuration completed successfully"

    cd ../..
}

# Verification phase
phase_verify() {
    log_info "=== Phase 4: Verification ==="

    if [ -f terraform/terraform.tfstate ]; then
        CENTRAL_IP=$(cd terraform && terraform output -raw central_manager_floating_ip 2>/dev/null || echo "")
    else
        log_error "Terraform state not found"
        exit 1
    fi

    log_info "Connecting to central manager to verify cluster..."

    ssh -i ~/.ssh/id_rsa -o StrictHostKeyChecking=no ubuntu@$CENTRAL_IP << 'ENDSSH'
echo "=== HTCondor Status ==="
condor_status -total

echo ""
echo "=== Job Queue ==="
condor_q

echo ""
echo "=== Shared Storage ==="
df -h /storage

echo ""
echo "=== Docker Images ==="
docker images | grep nugrid

echo ""
echo "=== Singularity Images ==="
ls -lh /storage/containers/*.sif 2>/dev/null || echo "No Singularity images yet"

echo ""
echo "=== Cluster Health Report ==="
cat /storage/cluster_health_report.txt 2>/dev/null || echo "Not generated yet"
ENDSSH

    log_info "Verification completed"
}

# Main deployment function
deploy_all() {
    log_info "=== Complete NuDocker HTCondor Infrastructure Deployment ==="
    log_info "This will deploy the entire infrastructure"
    log_warn "Estimated time: 60-90 minutes"
    log_warn "Press Enter to continue or Ctrl+C to abort"
    read -r

    check_prerequisites
    phase_packer
    phase_terraform
    phase_ansible
    phase_verify

    log_info "=== Deployment Completed Successfully ==="
    log_info "Access your cluster with:"
    if [ -f terraform/terraform.tfstate ]; then
        CENTRAL_IP=$(cd terraform && terraform output -raw central_manager_floating_ip 2>/dev/null || echo "")
        log_info "  ssh -i ~/.ssh/id_rsa ubuntu@$CENTRAL_IP"
    fi
}

# Parse command line arguments
PHASE=${1:-help}

case $PHASE in
    packer)
        check_prerequisites
        phase_packer
        ;;
    terraform)
        check_prerequisites
        phase_terraform
        ;;
    ansible)
        check_prerequisites
        phase_ansible
        ;;
    verify)
        phase_verify
        ;;
    all)
        deploy_all
        ;;
    help|--help|-h)
        echo "NuDocker HTCondor Infrastructure Deployment Script"
        echo ""
        echo "Usage: $0 [phase]"
        echo ""
        echo "Phases:"
        echo "  packer      Build base VM images with Packer"
        echo "  terraform   Provision infrastructure with Terraform"
        echo "  ansible     Configure cluster with Ansible"
        echo "  verify      Verify cluster health"
        echo "  all         Run all phases (complete deployment)"
        echo "  help        Show this help message"
        echo ""
        echo "Examples:"
        echo "  $0 all              # Complete deployment"
        echo "  $0 packer           # Build images only"
        echo "  $0 terraform        # Provision infrastructure only"
        echo ""
        echo "Prerequisites:"
        echo "  - Terraform >= 1.0"
        echo "  - Packer >= 1.8"
        echo "  - Ansible >= 2.12"
        echo "  - SSH key at ~/.ssh/id_rsa"
        echo "  - HUN-REN Cloud credentials"
        echo ""
        ;;
    *)
        log_error "Unknown phase: $PHASE"
        echo "Run '$0 help' for usage information"
        exit 1
        ;;
esac
