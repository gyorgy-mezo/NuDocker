#!/bin/bash
# NuDocker Infrastructure Deployment Script - IMPROVED
# Based on proven patterns from htcondor-slurm-demo
# Deploys HTCondor + SLURM dual-scheduler cluster on HUN-REN Cloud

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ==============================================================================
# Helper Functions
# ==============================================================================

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_command() {
    if ! command -v $1 &> /dev/null; then
        log_error "$1 is not installed. Please install it first."
        exit 1
    fi
}

# ==============================================================================
# Prerequisite Checks
# ==============================================================================

check_prerequisites() {
    log_info "Checking prerequisites..."

    check_command terraform
    check_command packer
    check_command ansible
    check_command ssh
    check_command git

    # Check SSH key
    if [ ! -f ~/.ssh/id_rsa ]; then
        log_warning "SSH key not found at ~/.ssh/id_rsa"
        log_info "Generating SSH key..."
        ssh-keygen -t rsa -b 2048 -f ~/.ssh/id_rsa -N ""
        log_success "SSH key generated"
    fi

    # Check Terraform version
    TERRAFORM_VERSION=$(terraform version -json | grep -o '"terraform_version":"[^"]*' | cut -d'"' -f4)
    log_info "Terraform version: $TERRAFORM_VERSION"

    # Check Packer version
    PACKER_VERSION=$(packer version | head -1 | awk '{print $2}')
    log_info "Packer version: $PACKER_VERSION"

    # Check Ansible version
    ANSIBLE_VERSION=$(ansible --version | head -1 | awk '{print $2}')
    log_info "Ansible version: $ANSIBLE_VERSION"

    log_success "Prerequisites check passed"
}

# ==============================================================================
# Packer Build
# ==============================================================================

build_packer_image() {
    log_info "Building Packer image..."

    cd packer

    # Check if variables file exists
    if [ ! -f variables.pkrvars.hcl ]; then
        log_error "Packer variables file not found: packer/variables.pkrvars.hcl"
        log_info "Please create it from variables.pkrvars.hcl.example"
        exit 1
    fi

    # Initialize Packer
    log_info "Initializing Packer..."
    packer init nudocker-base-improved.pkr.hcl

    # Build image
    log_info "Building image (this takes 30-45 minutes)..."
    packer build -var-file=variables.pkrvars.hcl nudocker-base-improved.pkr.hcl

    if [ $? -eq 0 ]; then
        log_success "Packer image built successfully"
        IMAGE_NAME=$(packer build -var-file=variables.pkrvars.hcl nudocker-base-improved.pkr.hcl 2>&1 | grep "image_name" | tail -1 | awk '{print $NF}')
        log_info "Image name: $IMAGE_NAME"
        echo "$IMAGE_NAME" > ../terraform/image_name.txt
    else
        log_error "Packer build failed"
        exit 1
    fi

    cd ..
}

# ==============================================================================
# Terraform Deployment
# ==============================================================================

deploy_terraform() {
    log_info "Deploying infrastructure with Terraform..."

    cd terraform

    # Check if tfvars exists
    if [ ! -f terraform.tfvars ]; then
        log_error "Terraform variables file not found: terraform/terraform.tfvars"
        log_info "Please create it from terraform.tfvars.example"
        exit 1
    fi

    # Initialize Terraform
    log_info "Initializing Terraform..."
    terraform init

    # Plan
    log_info "Planning infrastructure..."
    terraform plan -out=tfplan

    # Apply
    log_info "Applying infrastructure (this takes 10-15 minutes)..."
    terraform apply tfplan

    if [ $? -eq 0 ]; then
        log_success "Infrastructure deployed successfully"

        # Get outputs
        FLOATING_IP=$(terraform output -raw central_manager_floating_ip)
        log_info "Central Manager IP: $FLOATING_IP"

        # Wait for SSH to become available
        log_info "Waiting for SSH to become available..."
        for i in {1..30}; do
            if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa ubuntu@$FLOATING_IP "echo OK" &>/dev/null; then
                log_success "SSH connection established"
                break
            fi
            echo -n "."
            sleep 10
        done
    else
        log_error "Terraform deployment failed"
        exit 1
    fi

    cd ..
}

# ==============================================================================
# Ansible Configuration
# ==============================================================================

configure_ansible() {
    log_info "Configuring cluster with Ansible..."

    cd ansible

    # Check if inventory was generated by Terraform
    if [ ! -f inventory/hosts-generated.ini ]; then
        log_error "Ansible inventory not found. Did Terraform complete successfully?"
        exit 1
    fi

    # Install Ansible requirements
    if [ -f requirements.yml ]; then
        log_info "Installing Ansible Galaxy requirements..."
        ansible-galaxy install -r requirements.yml
    fi

    # Run playbook
    log_info "Running Ansible playbook (this takes 20-30 minutes)..."
    ansible-playbook -i inventory/hosts-generated.ini site-v2-improved.yml

    if [ $? -eq 0 ]; then
        log_success "Cluster configured successfully"
    else
        log_error "Ansible configuration failed"
        exit 1
    fi

    cd ..
}

# ==============================================================================
# Validation
# ==============================================================================

validate_cluster() {
    log_info "Validating cluster deployment..."

    cd terraform
    FLOATING_IP=$(terraform output -raw central_manager_floating_ip)
    cd ..

    log_info "Testing SSH connection..."
    ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa ubuntu@$FLOATING_IP "echo 'SSH connection OK'"

    log_info "Checking HTCondor pool..."
    ssh -i ~/.ssh/id_rsa ubuntu@$FLOATING_IP "condor_status -total"

    log_info "Checking SLURM cluster..."
    ssh -i ~/.ssh/id_rsa ubuntu@$FLOATING_IP "sinfo"

    log_info "Checking NFS mounts..."
    ssh -i ~/.ssh/id_rsa ubuntu@$FLOATING_IP "df -h | grep storage"

    log_success "Cluster validation complete!"

    # Print access info
    echo ""
    echo "=========================================="
    echo " NuDocker Cluster Deployed Successfully"
    echo "=========================================="
    echo ""
    echo "SSH Access:"
    echo "  ssh -i ~/.ssh/id_rsa ubuntu@$FLOATING_IP"
    echo ""
    echo "HTCondor Pool:"
    echo "  condor_status -total"
    echo "  condor_q"
    echo ""
    echo "SLURM Cluster:"
    echo "  sinfo"
    echo "  squeue"
    echo ""
    echo "Batch Job Scripts:"
    echo "  HTCondor: /storage/htcondor_jobs/"
    echo "  SLURM:    /storage/slurm_jobs/"
    echo ""
    echo "Containers:"
    echo "  Docker:     docker images | grep nudome"
    echo "  Singularity: ls /storage/containers/"
    echo ""
    echo "=========================================="
}

# ==============================================================================
# Main Deployment Function
# ==============================================================================

deploy_all() {
    log_info "Starting complete NuDocker deployment..."

    check_prerequisites
    build_packer_image
    deploy_terraform
    configure_ansible
    validate_cluster

    log_success "Deployment complete!"
}

# ==============================================================================
# Command-Line Interface
# ==============================================================================

show_usage() {
    echo "NuDocker Infrastructure Deployment - IMPROVED"
    echo ""
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  all         - Complete deployment (Packer + Terraform + Ansible + Validation)"
    echo "  packer      - Build Packer image only"
    echo "  terraform   - Deploy infrastructure only"
    echo "  ansible     - Configure cluster only"
    echo "  validate    - Run validation checks only"
    echo "  help        - Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 all              # Complete deployment"
    echo "  $0 packer           # Build image only"
    echo "  $0 terraform        # Deploy infrastructure only"
    echo ""
}

# ==============================================================================
# Main Script
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

case "${1:-all}" in
    all)
        deploy_all
        ;;
    packer)
        check_prerequisites
        build_packer_image
        ;;
    terraform)
        check_prerequisites
        deploy_terraform
        ;;
    ansible)
        check_prerequisites
        configure_ansible
        ;;
    validate)
        validate_cluster
        ;;
    help|--help|-h)
        show_usage
        ;;
    *)
        log_error "Unknown command: $1"
        show_usage
        exit 1
        ;;
esac

log_success "Script completed successfully!"
