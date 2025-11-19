# Stage 1: Basic VM Provisioning Test

**Goal**: Verify that Terraform can provision a simple VM on HUN-REN cloud

**Resources**: 1 VM (2 vCPU, 4 GB RAM, 20 GB disk)

**Duration**: ~15 minutes

**Cost**: ~€0.50-1.00

**Risk**: Low

---

## Prerequisites

✅ Stage 0 completed (prerequisites verified)
✅ `terraform.tfvars` configured with your cloud credentials

---

## Setup

1. **Copy and customize configuration**:
   ```bash
   cd infrastructure/testing/stage1
   cp terraform.tfvars.example terraform.tfvars
   vim terraform.tfvars  # Edit with your values
   ```

2. **Required values in `terraform.tfvars`**:
   - `cloud_name`: From your `~/.config/openstack/clouds.yaml`
   - `network_name`: Get with `openstack network list`
   - `external_network_name`: Get with `openstack network list --external`
   - `key_pair_name`: Upload first with `openstack keypair create`
   - `flavor_name`: Check with `openstack flavor list` (need ≥2 vCPU, ≥4GB RAM)
   - `image_name`: Check with `openstack image list | grep -i ubuntu`

---

## Execution

### Step 1: Initialize Terraform

```bash
terraform init
```

Expected output:
```
Terraform has been successfully initialized!
```

### Step 2: Plan deployment

```bash
terraform plan
```

Review the plan. You should see:
- 1 instance to create
- 1 security group to create
- 2 security group rules to create
- 1 floating IP to create
- 1 floating IP association to create

**Total: 6 resources**

### Step 3: Apply (provision VM)

```bash
terraform apply
```

Type `yes` when prompted.

Wait ~5-10 minutes for provisioning.

Expected output:
```
Apply complete! Resources: 6 added, 0 changed, 0 destroyed.

Outputs:

ssh_command = "ssh -i ~/.ssh/id_rsa ubuntu@<FLOATING_IP>"
test_vm_floating_ip = "<FLOATING_IP>"
test_vm_id = "<VM_ID>"
test_vm_internal_ip = "<INTERNAL_IP>"
```

### Step 4: Test connectivity

```bash
chmod +x test_connectivity.sh
./test_connectivity.sh
```

This script will:
1. Retrieve VM information from Terraform
2. Test network connectivity (ping)
3. Test SSH access (wait up to 60 seconds)
4. Execute basic commands (hostname, uptime, OS version)
5. Check resources (CPU, memory, disk)
6. Test internet connectivity from VM
7. Test package manager (apt)
8. Generate result report

Expected output: All tests should pass ✓

### Step 5: Manual verification (optional)

```bash
# SSH into the VM
ssh -i ~/.ssh/id_rsa ubuntu@$(terraform output -raw test_vm_floating_ip)

# Once inside:
hostname
uname -a
df -h
free -h
nproc
exit
```

### Step 6: Clean up

```bash
terraform destroy -auto-approve
```

Wait ~2-3 minutes for cleanup.

Verify resources removed:
```bash
openstack server list | grep stage1  # Should be empty
```

---

## Success Criteria

- ✅ Terraform successfully provisions VM
- ✅ Floating IP assigned and accessible
- ✅ SSH connection works within 60 seconds
- ✅ VM has expected resources (2+ vCPU, 4+ GB RAM, 20+ GB disk)
- ✅ VM has internet access
- ✅ Package manager works (apt-get update)
- ✅ Terraform destroy removes all resources

---

## Expected Results

**Result file**: `../results/stage1_results_<timestamp>.txt`

Sample result:
```
STAGE 1: BASIC VM PROVISIONING TEST
====================================
VM DETAILS:
-----------
VM ID: 12345678-abcd-...
Internal IP: 10.0.0.5
Floating IP: 192.0.2.100
Hostname: nudocker-test-stage1-test
OS: Ubuntu 22.04.3 LTS
CPU cores: 2
Memory: 3.8Gi
Disk: 20G

TEST RESULTS:
-------------
✓ VM provisioned successfully
✓ Floating IP assigned
✓ SSH connectivity working
✓ Basic commands executing
✓ System information accessible

STATUS: ✓ STAGE 1 PASSED
```

---

## Troubleshooting

### Problem: `terraform init` fails

**Possible causes**:
- OpenStack provider not available
- Internet connectivity issue

**Solutions**:
```bash
# Check Terraform version
terraform version  # Need >= 1.0

# Check internet access
ping -c 3 registry.terraform.io

# Retry with verbose output
TF_LOG=DEBUG terraform init
```

### Problem: `terraform apply` fails with authentication error

**Error**: `Error: Error creating OpenStack compute instance`

**Solutions**:
```bash
# Test OpenStack authentication
openstack --os-cloud <your-cloud-name> token issue

# Verify clouds.yaml
cat ~/.config/openstack/clouds.yaml

# Check cloud_name in terraform.tfvars matches clouds.yaml
```

### Problem: SSH connection times out

**Possible causes**:
- Security group not allowing SSH
- Floating IP not assigned
- VM not fully booted

**Solutions**:
```bash
# Check VM status
openstack server show $(terraform output -raw test_vm_id)

# Check security groups
openstack security group rule list <security-group-id>

# Check from OpenStack console
# Go to dashboard → Instances → Console tab

# Wait longer (VM may be installing updates)
# SSH timeout is 60 seconds, but you can wait more
```

### Problem: VM has no internet access

**This may be expected** depending on HUN-REN network configuration.

**Check**:
```bash
# From VM
ssh ubuntu@<FLOATING_IP>
ping -c 3 8.8.8.8  # Test IP connectivity
ping -c 3 google.com  # Test DNS

# Check routes
ip route

# Check DNS
cat /etc/resolv.conf
```

### Problem: `terraform destroy` fails

**Solutions**:
```bash
# Remove floating IP association first
terraform state rm openstack_compute_floatingip_associate_v2.test_vm_fip_assoc

# Retry destroy
terraform destroy

# Manual cleanup if needed
openstack server delete <VM_NAME>
openstack floating ip delete <FLOATING_IP>
```

---

## Next Stage

After successful completion and cleanup:

**→ Proceed to Stage 2: Packer Base Image Build**

```bash
cd ../stage2
cat README.md
```

Stage 2 will build a custom VM image with HTCondor and SLURM pre-installed.

---

## Notes

- Stage 1 uses minimal resources to minimize cost
- All resources should be deleted after testing to avoid ongoing charges
- The security group allows SSH from anywhere (0.0.0.0/0) - this is acceptable for testing but not recommended for production
- VM uses Ubuntu 22.04 LTS (same as production deployment)
- Floating IP is required for external SSH access
