#!/bin/bash
# Stage 0: Prerequisites Verification Script
# Verifies all required tools and HUN-REN cloud access
# Duration: ~10 minutes
# Cost: €0 (local only)

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counters
TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_WARNED=0

print_result() {
    local test_name="$1"
    local result="$2"
    local message="${3:-}"

    TESTS_TOTAL=$((TESTS_TOTAL + 1))

    if [ "$result" == "PASS" ]; then
        echo -e "${GREEN}✓ PASS${NC}: $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    elif [ "$result" == "FAIL" ]; then
        echo -e "${RED}✗ FAIL${NC}: $test_name"
        if [ -n "$message" ]; then
            echo -e "  ${RED}└─${NC} $message"
        fi
        TESTS_FAILED=$((TESTS_FAILED + 1))
    elif [ "$result" == "WARN" ]; then
        echo -e "${YELLOW}⚠ WARN${NC}: $test_name"
        if [ -n "$message" ]; then
            echo -e "  ${YELLOW}└─${NC} $message"
        fi
        TESTS_WARNED=$((TESTS_WARNED + 1))
    else
        echo -e "${BLUE}ℹ INFO${NC}: $test_name - $message"
    fi
}

echo "========================================="
echo "Stage 0: Prerequisites Verification"
echo "========================================="
echo "Date: $(date '+%Y-%m-%d %H:%M:%S')"
echo "========================================="
echo ""

# ==============================================================================
# Test Suite 1: Terraform
# ==============================================================================
echo "Test Suite 1: Terraform"
echo "-----------------------"

if command -v terraform >/dev/null 2>&1; then
    TF_VERSION=$(terraform version -json | grep -o '"terraform_version":"[^"]*"' | cut -d'"' -f4)
    print_result "Terraform installed" "PASS" "Version: $TF_VERSION"

    # Check version >= 1.0
    MAJOR_VERSION=$(echo "$TF_VERSION" | cut -d. -f1)
    if [ "$MAJOR_VERSION" -ge 1 ]; then
        print_result "Terraform version >= 1.0" "PASS"
    else
        print_result "Terraform version >= 1.0" "WARN" "Version $TF_VERSION is old, recommend >= 1.0"
    fi
else
    print_result "Terraform installed" "FAIL" "Install from https://www.terraform.io/downloads"
fi

echo ""

# ==============================================================================
# Test Suite 2: Packer
# ==============================================================================
echo "Test Suite 2: Packer"
echo "--------------------"

if command -v packer >/dev/null 2>&1; then
    PACKER_VERSION=$(packer version | head -1 | awk '{print $2}')
    print_result "Packer installed" "PASS" "Version: $PACKER_VERSION"
else
    print_result "Packer installed" "FAIL" "Install from https://www.packer.io/downloads"
fi

echo ""

# ==============================================================================
# Test Suite 3: Ansible
# ==============================================================================
echo "Test Suite 3: Ansible"
echo "---------------------"

if command -v ansible >/dev/null 2>&1; then
    ANSIBLE_VERSION=$(ansible --version | head -1 | awk '{print $2}' | tr -d '[]')
    print_result "Ansible installed" "PASS" "Version: $ANSIBLE_VERSION"

    # Check ansible-playbook
    if command -v ansible-playbook >/dev/null 2>&1; then
        print_result "ansible-playbook available" "PASS"
    else
        print_result "ansible-playbook available" "FAIL"
    fi
else
    print_result "Ansible installed" "FAIL" "Install: pip3 install ansible"
fi

echo ""

# ==============================================================================
# Test Suite 4: OpenStack CLI
# ==============================================================================
echo "Test Suite 4: OpenStack CLI"
echo "---------------------------"

if command -v openstack >/dev/null 2>&1; then
    print_result "OpenStack CLI installed" "PASS"
else
    print_result "OpenStack CLI installed" "FAIL" "Install: pip3 install python-openstackclient"
fi

echo ""

# ==============================================================================
# Test Suite 5: SSH
# ==============================================================================
echo "Test Suite 5: SSH"
echo "-----------------"

if command -v ssh >/dev/null 2>&1; then
    SSH_VERSION=$(ssh -V 2>&1 | awk '{print $1}')
    print_result "SSH client installed" "PASS" "Version: $SSH_VERSION"
else
    print_result "SSH client installed" "FAIL"
fi

# Check for SSH key
if [ -f ~/.ssh/id_rsa ] || [ -f ~/.ssh/id_ed25519 ]; then
    print_result "SSH key exists" "PASS"
else
    print_result "SSH key exists" "WARN" "Generate with: ssh-keygen -t ed25519"
fi

echo ""

# ==============================================================================
# Test Suite 6: Git
# ==============================================================================
echo "Test Suite 6: Git"
echo "-----------------"

if command -v git >/dev/null 2>&1; then
    GIT_VERSION=$(git --version | awk '{print $3}')
    print_result "Git installed" "PASS" "Version: $GIT_VERSION"
else
    print_result "Git installed" "FAIL"
fi

echo ""

# ==============================================================================
# Test Suite 7: Python
# ==============================================================================
echo "Test Suite 7: Python"
echo "--------------------"

if command -v python3 >/dev/null 2>&1; then
    PYTHON_VERSION=$(python3 --version | awk '{print $2}')
    print_result "Python 3 installed" "PASS" "Version: $PYTHON_VERSION"
else
    print_result "Python 3 installed" "FAIL"
fi

if command -v pip3 >/dev/null 2>&1; then
    print_result "pip3 installed" "PASS"
else
    print_result "pip3 installed" "WARN" "Needed for OpenStack CLI and Ansible"
fi

echo ""

# ==============================================================================
# Test Suite 8: OpenStack Credentials
# ==============================================================================
echo "Test Suite 8: OpenStack Credentials"
echo "------------------------------------"

# Check for clouds.yaml
if [ -f ~/.config/openstack/clouds.yaml ]; then
    print_result "clouds.yaml exists" "PASS" "Location: ~/.config/openstack/clouds.yaml"
else
    print_result "clouds.yaml exists" "WARN" "Create from HUN-REN dashboard"
fi

# Check for terraform.tfvars
TFVARS_PATH="../terraform/terraform.tfvars"
if [ -f "$TFVARS_PATH" ]; then
    print_result "terraform.tfvars exists" "PASS"

    # Check for required variables
    for var in cloud_name external_network_id ssh_public_key_path; do
        if grep -q "^$var" "$TFVARS_PATH"; then
            print_result "terraform.tfvars: $var defined" "PASS"
        else
            print_result "terraform.tfvars: $var defined" "WARN" "Variable not found"
        fi
    done
else
    print_result "terraform.tfvars exists" "WARN" "Copy from terraform.tfvars.example and customize"
fi

echo ""

# ==============================================================================
# Test Suite 9: HUN-REN Cloud Access Test
# ==============================================================================
echo "Test Suite 9: HUN-REN Cloud Access"
echo "-----------------------------------"

if command -v openstack >/dev/null 2>&1 && [ -f ~/.config/openstack/clouds.yaml ]; then
    # Extract cloud name from clouds.yaml
    CLOUD_NAME=$(grep -A 1 "^clouds:" ~/.config/openstack/clouds.yaml | tail -1 | awk '{print $1}' | tr -d ':')

    if [ -n "$CLOUD_NAME" ]; then
        print_result "Cloud name detected" "INFO" "Using: $CLOUD_NAME"

        # Test authentication
        if openstack --os-cloud "$CLOUD_NAME" token issue >/dev/null 2>&1; then
            print_result "HUN-REN cloud authentication" "PASS"

            # Check quota
            QUOTA_OUTPUT=$(openstack --os-cloud "$CLOUD_NAME" quota show 2>&1)
            if [ $? -eq 0 ]; then
                CORES=$(echo "$QUOTA_OUTPUT" | grep "cores" | awk '{print $4}')
                RAM=$(echo "$QUOTA_OUTPUT" | grep "ram" | awk '{print $4}')
                INSTANCES=$(echo "$QUOTA_OUTPUT" | grep "instances" | awk '{print $4}')

                print_result "Quota check" "PASS" "Cores: $CORES, RAM: ${RAM}MB, Instances: $INSTANCES"

                # Verify minimum quota for testing
                if [ "$CORES" -ge 12 ] && [ "$RAM" -ge 24576 ] && [ "$INSTANCES" -ge 6 ]; then
                    print_result "Sufficient quota for full testing" "PASS"
                else
                    print_result "Sufficient quota for full testing" "WARN" "Need ≥12 cores, ≥24GB RAM, ≥6 instances"
                fi
            else
                print_result "Quota check" "WARN" "Could not retrieve quota"
            fi

            # List available images
            IMAGE_COUNT=$(openstack --os-cloud "$CLOUD_NAME" image list -f value 2>/dev/null | wc -l)
            if [ "$IMAGE_COUNT" -gt 0 ]; then
                print_result "Images available" "PASS" "Found $IMAGE_COUNT images"
            else
                print_result "Images available" "WARN" "No images found"
            fi

            # List available networks
            NETWORK_COUNT=$(openstack --os-cloud "$CLOUD_NAME" network list -f value 2>/dev/null | wc -l)
            if [ "$NETWORK_COUNT" -gt 0 ]; then
                print_result "Networks available" "PASS" "Found $NETWORK_COUNT networks"
            else
                print_result "Networks available" "WARN" "No networks found"
            fi

        else
            print_result "HUN-REN cloud authentication" "FAIL" "Check clouds.yaml credentials"
        fi
    else
        print_result "Cloud name detection" "FAIL" "Could not parse clouds.yaml"
    fi
else
    print_result "HUN-REN cloud access test" "WARN" "OpenStack CLI or clouds.yaml not configured"
fi

echo ""

# ==============================================================================
# Test Suite 10: Repository Structure
# ==============================================================================
echo "Test Suite 10: Repository Structure"
echo "------------------------------------"

REQUIRED_DIRS=(
    "../terraform"
    "../packer"
    "../ansible"
    "../ansible/playbooks"
    "../ansible/roles"
)

for dir in "${REQUIRED_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        print_result "Directory exists: $dir" "PASS"
    else
        print_result "Directory exists: $dir" "FAIL" "Required directory missing"
    fi
done

REQUIRED_FILES=(
    "../terraform/main.tf"
    "../terraform/terraform.tfvars.example"
    "../packer/nudocker-htcondor-slurm.pkr.hcl"
    "../ansible/playbooks/site.yml"
)

for file in "${REQUIRED_FILES[@]}"; do
    if [ -f "$file" ]; then
        print_result "File exists: $(basename $file)" "PASS"
    else
        print_result "File exists: $(basename $file)" "FAIL" "Required file missing"
    fi
done

echo ""

# ==============================================================================
# Summary
# ==============================================================================
echo "========================================="
echo "Prerequisites Verification Summary"
echo "========================================="
echo "Total tests: $TESTS_TOTAL"
echo -e "${GREEN}Passed:   $TESTS_PASSED${NC}"
echo -e "${YELLOW}Warnings: $TESTS_WARNED${NC}"
echo -e "${RED}Failed:   $TESTS_FAILED${NC}"
echo ""

# Calculate pass rate
if [ $TESTS_TOTAL -gt 0 ]; then
    PASS_RATE=$((TESTS_PASSED * 100 / TESTS_TOTAL))
    echo "Pass rate: $PASS_RATE%"
fi

echo "========================================="

# Generate result file
RESULT_FILE="../results/stage0_results_$(date +%Y%m%d_%H%M%S).txt"
mkdir -p ../results

cat > "$RESULT_FILE" << EOF
STAGE 0: PREREQUISITES VERIFICATION
====================================
Date: $(date '+%Y-%m-%d %H:%M:%S')
Duration: N/A (manual checks)

SUMMARY:
--------
Total tests: $TESTS_TOTAL
Passed: $TESTS_PASSED
Warnings: $TESTS_WARNED
Failed: $TESTS_FAILED
Pass rate: $PASS_RATE%

STATUS: $(if [ $TESTS_FAILED -eq 0 ]; then echo "✓ READY TO PROCEED"; else echo "✗ ISSUES FOUND"; fi)

NEXT STEPS:
-----------
EOF

if [ $TESTS_FAILED -eq 0 ]; then
    cat >> "$RESULT_FILE" << EOF
✓ All critical prerequisites met
→ Proceed to Stage 1: Basic VM Provisioning
→ Command: cd ../stage1 && terraform init && terraform plan
EOF
    echo -e "${GREEN}✓ All critical prerequisites met!${NC}"
    echo "→ Proceed to Stage 1: Basic VM Provisioning"
    echo "→ Result saved to: $RESULT_FILE"
    exit 0
else
    cat >> "$RESULT_FILE" << EOF
✗ Prerequisites incomplete
→ Install missing tools (see FAIL items above)
→ Configure HUN-REN cloud access (clouds.yaml)
→ Re-run this script: ./verify_prerequisites.sh
EOF
    echo -e "${RED}✗ Prerequisites incomplete${NC}"
    echo "→ Install missing tools and re-run this script"
    echo "→ Result saved to: $RESULT_FILE"
    exit 1
fi
