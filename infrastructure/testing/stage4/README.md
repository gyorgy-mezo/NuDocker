# Stage 4: Multi-Node HTCondor Cluster Test

**Goal**: Deploy and test a 2-node HTCondor cluster with NFS shared storage

**Resources**: 2 VMs (Central: 2 vCPU, 4GB | Execute: 4 vCPU, 8GB)

**Duration**: ~45 minutes

**Cost**: ~€2.50-4.00

**Risk**: Low-Medium

---

## Prerequisites

✅ Stage 0-3 completed successfully
✅ Custom image available from Stage 2
✅ Sufficient quota (6 vCPU, 12 GB RAM total)

---

## What Gets Tested

This stage deploys a distributed HTCondor cluster:

**Central Manager Node**:
- HTCondor Collector, Negotiator, Schedd
- NFS server providing /storage
- Job submission interface

**Execute Node**:
- HTCondor Startd (4 execute slots)
- NFS client mounting /storage
- Runs submitted jobs

**Tests performed**:
1. NFS server/client setup and mounting
2. Central manager daemons functioning
3. Execute node registration with collector
4. Distributed job submission (5 jobs)
5. Job execution across cluster nodes
6. Network connectivity between nodes
7. Shared storage accessibility

---

## Architecture

```
Central Manager (2 vCPU, 4GB)          Execute Node (4 vCPU, 8GB)
┌─────────────────────────────┐        ┌──────────────────────────┐
│ HTCondor Daemons:           │        │ HTCondor Daemons:        │
│  - Collector                │◄───────┤  - Startd (4 slots)      │
│  - Negotiator               │        │                          │
│  - Schedd                   │        │ Executes jobs            │
│                             │        │                          │
│ NFS Server:                 │        │ NFS Client:              │
│  /storage (shared)          │────────┤  /storage (mounted)      │
│   ├── htcondor_jobs         │        │                          │
│   ├── results               │        │                          │
│   └── config                │        │                          │
│                             │        │                          │
│ Floating IP (SSH access)    │        │ Internal IP only         │
└─────────────────────────────┘        └──────────────────────────┘
```

---

## Setup

1. **Copy and customize configuration**:
   ```bash
   cd infrastructure/testing/stage4
   cp terraform.tfvars.example terraform.tfvars
   vim terraform.tfvars
   ```

2. **Required values**:
   - `custom_image_name`: Your Stage 2 image
   - `central_flavor`: Flavor with ≥2 vCPU, ≥4GB RAM (e.g., "m1.small")
   - `execute_flavor`: Flavor with ≥4 vCPU, ≥8GB RAM (e.g., "m1.medium")
   - Other values same as previous stages

---

## Execution

### Step 1: Initialize Terraform

```bash
terraform init
```

### Step 2: Plan deployment

```bash
terraform plan
```

You should see:
- 2 compute instances (central + execute)
- 1 security group
- 7 security group rules (SSH, HTCondor, NFS)
- 1 floating IP + association

**Total: ~13 resources**

### Step 3: Apply (deploy cluster)

```bash
terraform apply
```

Type `yes` when prompted.

Wait ~10-15 minutes for:
- VM provisioning (both nodes)
- user_data scripts execution
- NFS server setup on central
- NFS client mount on execute
- HTCondor configuration
- Services startup
- Execute node registration

### Step 4: Verify cluster status

```bash
# Get central manager IP
CENTRAL_IP=$(terraform output -raw central_manager_floating_ip)

# SSH to central
ssh ubuntu@$CENTRAL_IP

# Check cluster status
condor_status

# Should show:
#  - Central manager node (if configured as execute too)
#  - Execute node with 4 slots
#  - Total slots available

# Check NFS
showmount -e localhost
df -h /storage

# Exit
exit
```

### Step 5: Run automated tests

```bash
chmod +x test_cluster.sh
./test_cluster.sh
```

This comprehensive test suite will:

**Test Suite 1: NFS Storage** (5 tests)
- NFS server running on central
- NFS export configured
- Storage directory exists
- NFS mounted on execute node
- Storage accessible from execute

**Test Suite 2: HTCondor Central Manager** (3 tests)
- Service running
- Daemons active (Collector, Negotiator, Schedd)
- CONDOR_HOST configuration

**Test Suite 3: HTCondor Execute Node** (3 tests)
- Service running on execute
- Node registered with collector
- Pool status responding

**Test Suite 4: Distributed Job Execution** (4 tests)
- Submit 5 distributed jobs
- Jobs complete successfully
- Output files created
- Jobs actually ran on execute node

**Test Suite 5: Network Connectivity** (2 tests)
- Central → Execute connectivity
- Execute → Central connectivity

**Expected**: All critical tests pass (17 tests total)

### Step 6: Manual job submission (optional)

```bash
# Connect to central manager
ssh ubuntu@$(terraform output -raw central_manager_floating_ip)

# Submit distributed job
cd ~/cluster_test
condor_submit distributed_job.sub

# Watch job progress
watch condor_q

# (Wait for jobs to complete, press Ctrl+C to exit watch)

# Check results
cat job_*.out

# Each file will show hostname of node that executed it
# Should see execute node hostname in output files

# Check job history
condor_history -limit 10

# Exit
exit
```

### Step 7: Clean up

```bash
terraform destroy -auto-approve
```

---

## Success Criteria

- ✅ Both VMs deploy successfully
- ✅ NFS server running on central
- ✅ NFS mounted on execute node
- ✅ /storage accessible from both nodes
- ✅ Central manager daemons active
- ✅ Execute node registers with collector
- ✅ Execute slots visible (4 slots)
- ✅ Distributed jobs submit successfully
- ✅ Jobs execute on execute node
- ✅ Job output files created
- ✅ Network connectivity between nodes

---

## Expected Results

**Result file**: `../results/stage4_results_<timestamp>.txt`

Sample result:
```
STAGE 4: MULTI-NODE HTCONDOR CLUSTER TEST
==========================================
CLUSTER TOPOLOGY:
-----------------
Central Manager: 10.0.0.5 (floating: 192.0.2.100)
Execute Node: 10.0.0.6

TEST RESULTS:
-------------
Total tests: 17
Passed: 17
Failed: 0
Warnings: 0

NFS STORAGE:
✓ NFS server running
✓ Export configured
✓ Mounted on execute node

HTCONDOR CLUSTER:
✓ Central manager daemons: 3
✓ Execute slots available: 4
✓ Pool status responding

DISTRIBUTED JOBS:
✓ Submitted 5 distributed jobs (Cluster 1)
✓ All jobs completed
✓ Jobs executed on: nudocker-test-stage4-execute

STATUS: ✓ STAGE 4 PASSED
```

---

## Troubleshooting

### Problem: Execute node not registering

**Symptoms**: `condor_status` shows no execute node slots

**Check**:
```bash
# On central manager
ssh ubuntu@<CENTRAL_IP>

# Get execute node IP
EXECUTE_IP=$(cat /storage/config/central_ip.txt)  # This won't work, get from terraform
EXECUTE_IP="<from terraform output>"

# Check if execute node is reachable
ping -c 3 $EXECUTE_IP

# SSH to execute node and check HTCondor
ssh ubuntu@$EXECUTE_IP
sudo systemctl status condor
condor_config_val CONDOR_HOST
condor_who
exit
```

**Common causes**:
- Execute node HTCondor not started (wait 2-3 minutes)
- CONDOR_HOST pointing to wrong IP
- Network connectivity issues
- Security group blocking HTCondor ports

**Solutions**:
```bash
# On execute node
ssh ubuntu@$EXECUTE_IP

# Verify CONDOR_HOST
condor_config_val CONDOR_HOST
# Should match central manager IP

# Restart HTCondor
sudo systemctl restart condor

# Wait 30 seconds
sleep 30

# Check from central
ssh ubuntu@$CENTRAL_IP 'condor_status'
```

### Problem: NFS mount failed on execute node

**Symptoms**: `/storage` not accessible on execute node

**Check**:
```bash
# On execute node
ssh ubuntu@<EXECUTE_IP>
mount | grep /storage
df -h /storage
ls /storage
```

**Common causes**:
- NFS server not started on central
- Network connectivity issues
- Security group blocking NFS ports (2049, 111)
- Mount attempted before NFS server ready

**Solutions**:
```bash
# On central manager
sudo systemctl status nfs-kernel-server
sudo exportfs -v
showmount -e localhost

# On execute node
sudo umount /storage || true
sudo mount -t nfs $CENTRAL_IP:/storage /storage
df -h /storage
```

### Problem: Jobs not distributing to execute node

**Symptoms**: All jobs run on central manager, none on execute node

**Check**:
```bash
# Check job requirements vs. slot capabilities
condor_q -better-analyze <JOB_ID>

# Check execute node slots
condor_status -long | grep -i slot
```

**Common causes**:
- Execute node slots in wrong state (Drained, Owner)
- Job requirements don't match execute slots
- Negotiator not running
- START expression preventing matches

**Solutions**:
```bash
# Check slot state
condor_status -compact

# If slots are Drained/Owner, investigate why
condor_status -long <SLOT_NAME> | grep -i state

# Force drain release (if needed)
condor_drain -cancel <EXECUTE_NODE>

# Restart negotiation cycle
condor_reschedule
```

### Problem: User data script failures

**Symptoms**: Services not configured correctly

**Check**:
```bash
# On either VM
sudo tail -100 /var/log/cloud-init-output.log
sudo journalctl -u cloud-init -n 100
```

**Solution**:
- Review cloud-init logs for errors
- Manually run configuration steps from user_data
- Rebuild VMs with fixed user_data

---

## Cost Optimization

**Cluster runs for ~45 minutes** for testing

**Estimated cost**: €2.50-4.00

**To reduce costs**:
- Use smaller flavors if they meet minimum requirements
- Run tests quickly and destroy immediately
- Consider using spot/preemptible instances if available

---

## Next Stage

After successful completion and cleanup:

**→ Proceed to Stage 5: SLURM Integration Test**

```bash
cd ../stage5
cat README.md
```

Stage 5 will add SLURM scheduler to the cluster for dual-scheduler testing.

---

## Notes

- Central manager also acts as submit node for jobs
- Execute node has no floating IP (internal network only)
- Security group allows wide access (0.0.0.0/0) - acceptable for testing
- NFS has no_root_squash (simplifies permissions) - not recommended for production
- HTCondor security is permissive (OPTIONAL auth) - testing only
- Jobs use simple `/bin/hostname` executable to show which node executed them
- 30-second sleep in execute node user_data allows central to fully initialize
- Distributed jobs should show execute node hostname in output files
- Total cluster capacity: 4 execute slots (all on execute node in this minimal setup)
