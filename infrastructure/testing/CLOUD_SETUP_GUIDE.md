# HUN-REN Cloud Setup Guide for NuDocker Testing

**For users with `app-cred-bridge-openrc.sh` instead of `clouds.yaml`**

---

## Overview

This guide helps you:
1. Configure your environment for OpenStack CLI
2. Discover your HUN-REN cloud capabilities
3. Verify you have sufficient quota for testing
4. Prepare configuration files for testing stages

---

## Prerequisites

You need:
- ✅ Python virtual environment with `python-openstackclient` installed
- ✅ `app-cred-bridge-openrc.sh` file from HUN-REN dashboard
- ✅ SSH key pair (for VM access)

---

## Step 1: Activate Your Python Environment

```bash
# Navigate to your project directory
cd /path/to/your/project

# Activate your Python virtual environment
source infraprog/bin/activate  # Or whatever your venv is named

# Verify OpenStack CLI is available
openstack --version
```

Expected output:
```
openstack 6.x.x
```

---

## Step 2: Authenticate with HUN-REN Cloud

```bash
# Source your OpenRC file (this sets environment variables)
source app-cred-bridge-openrc.sh

# It may prompt for password - enter your application credential secret

# Verify authentication works
openstack token issue
```

If successful, you'll see a token with your project information.

---

## Step 3: Discover Your Cloud Environment

We've created scripts to automatically map your cloud capabilities.

### Option A: Full Discovery Report (Recommended)

```bash
# Navigate to testing directory
cd infrastructure/testing

# Make script executable
chmod +x discover_cloud.sh

# Run the discovery script
./discover_cloud.sh
```

**What this does**:
- Scans all available resources in your HUN-REN cloud project
- Generates comprehensive report (~1000 lines)
- Saves to: `hun-ren-cloud-report_YYYYMMDD_HHMMSS.txt`
- Takes ~30 seconds to run

**Report includes**:
1. Project information and quotas
2. Available VM flavors (sizes)
3. Available images (Ubuntu, etc.)
4. Network configuration
5. Current resource usage
6. Specific recommendations for NuDocker testing

### Option B: Quick Quota Check

```bash
# Make script executable
chmod +x check_quota.sh

# Run quota check
./check_quota.sh
```

**What this does**:
- Quick check (5 seconds)
- Shows current quota vs. usage
- Verifies you can run each testing stage
- Provides recommendations if quota is insufficient

---

## Step 4: Review Your Results

### View the Discovery Report

```bash
# List generated reports
ls -lt hun-ren-cloud-report_*.txt | head -1

# View the most recent report
cat hun-ren-cloud-report_*.txt
```

**Key sections to review**:

1. **Section 2: Quota** - Your limits
   - Look for: `cores`, `instances`, `ram`, `floatingips`
   - Ensure you have: ≥6 cores, ≥2 instances, ≥1 floating IP available

2. **Section 3: Flavors** - VM sizes
   - You need flavors with:
     - 2 vCPU, 4GB RAM (for Stage 1, central manager)
     - 4 vCPU, 8GB RAM (for Stages 2-4, execute nodes)
   - Based on your `openstack flavor list`, good options:
     - `m2.medium` - 2 vCPU, 4GB RAM
     - `m2.large` - 4 vCPU, 8GB RAM
     - `r2.medium` - 2 vCPU, 8GB RAM
     - `r2.large` - 4 vCPU, 16GB RAM

3. **Section 4: Images** - Operating systems
   - Look for Ubuntu 22.04 or 20.04
   - Note the exact image name (you'll need this)

4. **Section 5: Networks** - Connectivity
   - Note your internal network name
   - Note your external network name (for floating IPs)

5. **Section 13: Recommendations** - NuDocker-specific
   - This section provides ready-to-use configuration values

---

## Step 5: Share Results with Claude (Optional)

If you need help interpreting your cloud environment:

### Method 1: Copy/Paste (Quick)

```bash
# Display the report
cat hun-ren-cloud-report_*.txt

# Copy the output and paste in your message to Claude
```

### Method 2: Upload File (Better)

Simply upload the generated `hun-ren-cloud-report_YYYYMMDD_HHMMSS.txt` file.

### Method 3: Share Specific Sections

If the full report is too long, share just the relevant parts:

```bash
# Show just quota and recommendations
cat hun-ren-cloud-report_*.txt | grep -A 50 "QUOTA LIMITS"
cat hun-ren-cloud-report_*.txt | grep -A 100 "RECOMMENDATIONS"
```

---

## Step 6: Configure Testing Files

Based on your discovery report, you'll need to create configuration files for each testing stage.

### Create clouds.yaml (Alternative to sourcing OpenRC each time)

```bash
# Create OpenStack config directory
mkdir -p ~/.config/openstack

# Create clouds.yaml from your OpenRC environment
cat > ~/.config/openstack/clouds.yaml << EOF
clouds:
  hun-ren-cloud:
    auth:
      auth_url: $OS_AUTH_URL
      application_credential_id: $OS_APPLICATION_CREDENTIAL_ID
      application_credential_secret: $OS_APPLICATION_CREDENTIAL_SECRET
    region_name: $OS_REGION_NAME
    interface: public
    identity_api_version: 3
    auth_type: "v3applicationcredential"
EOF
```

**Benefit**: You won't need to `source app-cred-bridge-openrc.sh` every time.

**Test it**:
```bash
openstack --os-cloud hun-ren-cloud server list
```

### Update Stage 0 Configuration

Stage 0 (prerequisites verification) will now use this configuration automatically.

---

## Step 7: Prepare for Testing Stages

### Create SSH Key Pair (if you don't have one)

```bash
# Generate SSH key pair
ssh-keygen -t ed25519 -f ~/.ssh/hun-ren-key -C "hun-ren-cloud"

# Upload public key to OpenStack
openstack keypair create --public-key ~/.ssh/hun-ren-key.pub hun-ren-key

# Verify
openstack keypair list
```

### Note Your Configuration Values

From your discovery report, collect these values:

```bash
# Example values (replace with yours from discovery report)
CLOUD_NAME="hun-ren-cloud"                    # From clouds.yaml or OpenRC
IMAGE_NAME="ubuntu-22.04"                     # From Section 4.1
NETWORK_NAME="private"                        # From Section 5.1
EXTERNAL_NETWORK="public"                     # From Section 5.2
KEY_PAIR_NAME="hun-ren-key"                   # From Section 7
SMALL_FLAVOR="m2.medium"                      # 2 vCPU, 4GB
MEDIUM_FLAVOR="m2.large"                      # 4 vCPU, 8GB
```

**Save these values** - you'll need them for `terraform.tfvars` files in each stage.

---

## Common Issues and Solutions

### Issue: `openstack: command not found`

**Solution**:
```bash
# Make sure virtual environment is activated
source infraprog/bin/activate

# Install OpenStack client
pip install python-openstackclient
```

### Issue: Authentication fails

**Solution**:
```bash
# Re-source the OpenRC file
source app-cred-bridge-openrc.sh

# Enter your application credential secret when prompted

# Verify
openstack token issue
```

### Issue: Discovery script fails

**Solution**:
```bash
# Run with verbose output to see what's failing
bash -x ./discover_cloud.sh

# Common fix: ensure you're authenticated first
source app-cred-bridge-openrc.sh
./discover_cloud.sh
```

### Issue: Insufficient quota

**Solutions**:
1. **Delete unused resources**:
   ```bash
   # List current VMs
   openstack server list

   # Delete old VMs
   openstack server delete <vm-name>

   # Release floating IPs
   openstack floating ip list
   openstack floating ip delete <ip-address>
   ```

2. **Request quota increase**:
   - Contact HUN-REN cloud support
   - Request: 20 vCPUs, 48 GB RAM, 10 instances, 5 floating IPs
   - Mention: "For NuDocker HTCondor cluster testing"

---

## What You'll Have After This Setup

✅ OpenStack CLI configured and working
✅ Comprehensive cloud discovery report
✅ Quota verification complete
✅ `clouds.yaml` created (optional but recommended)
✅ SSH key pair registered
✅ Configuration values ready for testing stages

---

## Next Steps

Once setup is complete:

1. **Start with Stage 0**:
   ```bash
   cd stage0
   ./verify_prerequisites.sh
   ```

2. **Proceed to Stage 1**:
   ```bash
   cd ../stage1
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your values from discovery report
   ```

3. **Follow the testing stages** in order (0 → 1 → 2 → 3 → 4)

---

## Quick Reference Commands

```bash
# Authenticate
source app-cred-bridge-openrc.sh

# List flavors
openstack flavor list

# List images
openstack image list | grep -i ubuntu

# List networks
openstack network list
openstack network list --external

# Check quota
openstack quota show

# List current VMs
openstack server list

# Test authentication
openstack token issue

# Run discovery
./discover_cloud.sh

# Quick quota check
./check_quota.sh
```

---

## Getting Help

**For cloud access issues**: Contact HUN-REN cloud support

**For discovery script issues**: Share the generated report or error output

**For testing stages**: See stage-specific README files (stage1/README.md, etc.)

---

Last updated: 2025-11-19
