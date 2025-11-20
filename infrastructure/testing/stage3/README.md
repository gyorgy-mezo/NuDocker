# Stage 3: Single-Node HTCondor Test
**Goal**: Deploy and test HTCondor in standalone mode on a single VM
**Resources**: 1 VM (4 vCPU, 8 GB RAM, 40 GB disk)
**Duration**: ~30 minutes
**Risk**: Low
---
## Prerequisites
✅ Stage 0 completed (prerequisites verified)
✅ Stage 1 completed (Terraform works)
✅ Stage 2 completed (custom image built and verified)
✅ Custom image available in OpenStack
---
## What Gets Tested
This stage deploys a single VM that acts as both:
- **HTCondor Central Manager** (collector, negotiator, schedd)
- **HTCondor Execute Node** (startd with 4 slots)
**Tests performed**:
1. HTCondor service status and daemons
2. Vanilla Universe job submission (3 jobs)
3. Docker Universe job submission (2 jobs)
4. Job execution and completion
5. Output file creation
6. Configuration validation
---
## Setup
1. **Copy and customize configuration**:
   ```bash
   cd infrastructure/testing/stage3
   cp terraform.tfvars.example terraform.tfvars
   vim terraform.tfvars
   ```
2. **Required values**:
   - `custom_image_name`: Your Stage 2 image name (find with `openstack image list`)
   - `cloud_name`, `network_name`, `external_network_name`, `key_pair_name` (same as previous stages)
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
- 1 compute instance
- 1 security group
- 4 security group rules (SSH + HTCondor ports)
- 1 floating IP
- 1 floating IP association
**Total: 8 resources**
### Step 3: Apply (deploy VM)
```bash
terraform apply
```
Type `yes` when prompted.
Wait ~5-10 minutes for:
- VM provisioning
- user_data script execution (HTCondor configuration)
- Services to start
### Step 4: Verify SSH access
```bash
ssh -i ~/.ssh/id_rsa ubuntu@$(terraform output -raw htcondor_floating_ip)
```
Inside the VM, check HTCondor:
```bash
# Check service
sudo systemctl status condor
# Check pool status
condor_status
# Check job queue
condor_q
# Exit
exit
```
### Step 5: Run automated tests
```bash
chmod +x test_htcondor.sh
./test_htcondor.sh
```
This script will:
1. **Test HTCondor Service** (4 tests)
   - Service running
   - Daemons active (Master, Collector, Negotiator, Schedd, Startd)
   - Pool responding
   - Execute slots available
2. **Test Vanilla Universe** (3 tests)
   - Submit 3 test jobs
   - Wait for completion (up to 60s)
   - Verify output files
3. **Test Docker Universe** (3 tests)
   - Check Docker service
   - Submit 2 Docker jobs
   - Wait for completion (up to 120s - includes Docker pull)
   - Verify Docker output
4. **Test Configuration** (3 tests)
   - Custom config file exists
   - CONDOR_HOST configured
   - Slots configured
**Expected**: All tests pass (12/12)
### Step 6: Manual verification (optional)
```bash
# Connect to VM
ssh ubuntu@$(terraform output -raw htcondor_floating_ip)
# View vanilla job outputs
cat ~/htcondor_test/test_*.out
# Expected: "Hello from HTCondor job 0", "...job 1", "...job 2"
# View Docker job outputs
cat ~/htcondor_test/docker_*.out
# Expected: Linux kernel info and "Docker job successful"
# Check HTCondor logs
sudo tail -50 /var/log/condor/MasterLog
sudo tail -50 /var/log/condor/StartdLog
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
- ✅ VM deploys successfully from custom image
- ✅ HTCondor service running
- ✅ All 5 HTCondor daemons active
- ✅ Execute slots available (4 slots)
- ✅ Vanilla Universe jobs submit and complete
- ✅ Docker Universe jobs submit and complete
- ✅ Job output files created correctly
- ✅ Configuration applied correctly
---
## Expected Results
**Result file**: `../results/stage3_results_<timestamp>.txt`
Sample result:
```
STAGE 3: SINGLE-NODE HTCONDOR TEST
===================================
HTCONDOR STATUS:
----------------
Pool Status: Total Owner Claimed Unclaimed Matched Preempting Backfill  Drain
              X86_64/LINUX     4     0       0         4       0          0        0      0
Execute Slots: 4
CONDOR_HOST: ip-10-0-0-5.ec2.internal
TEST RESULTS:
-------------
Total tests: 12
Passed: 12
Failed: 0
Warnings: 0
VANILLA UNIVERSE:
✓ Submitted 3 jobs (Cluster 1)
✓ Jobs completed successfully
✓ Output files created
DOCKER UNIVERSE:
✓ Submitted 2 Docker jobs (Cluster 2)
✓ Docker jobs executed
✓ Docker Universe functional
STATUS: ✓ STAGE 3 PASSED
```
---
## Troubleshooting
### Problem: HTCondor service not running
**Check**:
```bash
ssh ubuntu@<FLOATING_IP>
sudo systemctl status condor
sudo journalctl -u condor -n 50
```
**Common causes**:
- user_data script still running (wait 2-3 minutes)
- Configuration syntax error
- Port conflicts
**Solution**:
```bash
# Check user_data execution
sudo tail -100 /var/log/cloud-init-output.log
# Restart service
sudo systemctl restart condor
# Check configuration
condor_config_val -dump | grep ERROR
```
### Problem: No execute slots available
**Check**:
```bash
ssh ubuntu@<FLOATING_IP>
condor_status
condor_config_val NUM_SLOTS
condor_config_val DAEMON_LIST
```
**Solution**:
```bash
# Verify STARTD in daemon list
sudo grep DAEMON_LIST /etc/condor/config.d/50-standalone.config
# Restart to apply config
sudo systemctl restart condor
# Wait 10 seconds
sleep 10
condor_status
```
### Problem: Jobs stay idle
**Symptoms**: Jobs submitted but don't run
**Check**:
```bash
ssh ubuntu@<FLOATING_IP>
condor_q -better-analyze <CLUSTER_ID>
```
**Common causes**:
- No available slots (check `condor_status`)
- Resource requirements too high
- Negotiator not running
**Solution**:
```bash
# Check all daemons running
condor_who
# Check negotiator
sudo systemctl status condor
ps aux | grep condor_negotiator
# Check match making
condor_q -better-analyze
```
### Problem: Docker jobs fail
**Error**: Docker Universe jobs stay idle or go to hold state
**Check**:
```bash
ssh ubuntu@<FLOATING_IP>
sudo systemctl status docker
sudo docker ps
condor_q -hold
```
**Solutions**:
```bash
# Verify Docker enabled in HTCondor
condor_config_val DOCKER
# Check Docker permissions
sudo usermod -aG docker condor
sudo systemctl restart condor
# Test Docker manually
sudo docker run ubuntu:22.04 echo "test"
# Pull image manually (if slow network)
sudo docker pull ubuntu:22.04
```
### Problem: Jobs complete but no output files
**Check**:
```bash
ssh ubuntu@<FLOATING_IP>
ls -la ~/htcondor_test/
condor_history <CLUSTER_ID> -limit 5 -af ExitCode HoldReason
```
**Common causes**:
- Jobs failed (non-zero exit code)
- Permission issues
- Wrong working directory
**Solution**:
```bash
# Check job exit codes
condor_history -limit 10 -af ClusterId ExitCode
# Check job stderr
cat ~/htcondor_test/test_*.err
# Re-submit with explicit paths
# Edit submit file to use absolute paths
```
---
## Next Stage
After successful completion and cleanup:
**→ Proceed to Stage 4: Multi-Node Cluster Test**
```bash
cd ../stage4
cat README.md
```
Stage 4 will deploy a 2-node cluster (1 central manager + 1 execute node) to test distributed job execution.
---
## Notes
- This is a standalone HTCondor setup (not production-ready)
- Security is permissive (ALLOW_WRITE = *, etc.) - acceptable for testing
- 4 execute slots configured (1 per vCPU)
- Docker Universe requires Docker service running (verified in tests)
- Vanilla Universe uses standard `/bin/echo` for testing
- user_data script configures everything automatically
- HTCondor logs available in /var/log/condor/
- Test jobs are simple and fast (complete in seconds)