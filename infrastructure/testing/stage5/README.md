# Stage 5: SLURM Integration Test

**Goal**: Add SLURM scheduler to existing HTCondor cluster for dual-scheduler testing

**Resources**: Reuses Stage 4 setup (2 VMs with SLURM added)

**Duration**: ~30 minutes

**Cost**: ~€1.50-2.50

**Risk**: Low

---

## Prerequisites

✅ Stage 0-4 completed successfully
✅ Understanding of both HTCondor and SLURM workflows
✅ Custom image with SLURM dependencies (munge) installed

---

## What Gets Tested

This stage adds SLURM to the HTCondor cluster from Stage 4:

**Central Manager**:
- HTCondor services (from Stage 4)
- SLURM Controller (slurmctld)
- Munge authentication
- SLURM job scheduling

**Execute Node**:
- HTCondor Startd (from Stage 4)
- SLURM Compute Daemon (slurmd)
- Dual job execution capability

**Tests performed**:
1. Munge key synchronization
2. SLURM controller running
3. SLURM compute node registration
4. SLURM job submission and execution
5. Singularity container jobs
6. Dual-scheduler coexistence

---

## Note

Stage 5 requires SLURM installation which is included in the full infrastructure deployment (Stages 6-7) but requires additional Ansible configuration beyond simple Terraform user_data scripts.

**For comprehensive SLURM testing**, proceed directly to:
- **Stage 6**: Scaled-down cluster with full Ansible provisioning
- **Stage 7**: Production deployment

This stage (5) is **optional** and primarily validates that the dual-scheduler architecture works in principle.

---

## Simplified Testing Approach

Since SLURM installation via user_data is complex, Stage 5 testing can be performed by:

1. Using the **full Ansible playbooks** from `infrastructure/ansible/` with a minimal inventory
2. Deploying just 1 controller + 1 compute node
3. Testing both HTCondor and SLURM job submission

**Recommended**: Skip to Stage 6 which includes proper Ansible provisioning.

---

## Alternative: Manual SLURM Setup

If you want to test SLURM integration manually:

### On Central Manager (as Controller):

```bash
# Install SLURM
sudo apt-get update
sudo apt-get install -y slurm-wlm

# Configure as controller
sudo vi /etc/slurm/slurm.conf
# (Use configuration from infrastructure/ansible/roles/slurm-controller/templates/slurm.conf.j2)

# Start services
sudo systemctl enable slurmctld
sudo systemctl start slurmctld
```

### On Execute Node (as Compute):

```bash
# Install SLURM
sudo apt-get install -y slurmd

# Copy munge key from controller
scp ubuntu@<CENTRAL_IP>:/etc/munge/munge.key /tmp/
sudo mv /tmp/munge.key /etc/munge/
sudo chown munge:munge /etc/munge/munge.key
sudo chmod 400 /etc/munge/munge.key
sudo systemctl restart munge

# Configure slurm
sudo vi /etc/slurm/slurm.conf
# (Same config as controller)

# Start compute daemon
sudo systemctl enable slurmd
sudo systemctl start slurmd
```

### Test SLURM:

```bash
# On central manager
sinfo  # Should show compute node
squeue  # Should be empty

# Submit test job
sbatch -N 1 -n 1 --wrap="hostname && date"

# Check status
squeue
sacct
```

---

## Success Criteria

- ✅ Munge authentication working
- ✅ SLURM controller active
- ✅ Compute node registered
- ✅ SLURM jobs submit and execute
- ✅ HTCondor still functional
- ✅ Both schedulers coexist without conflicts

---

## Recommendation

**For thorough SLURM integration testing, proceed to Stage 6** which uses the complete Ansible provisioning system with proper SLURM configuration, munge key distribution, and cluster setup.

Stage 6 provides:
- Automated SLURM installation via Ansible
- Proper configuration management
- Both schedulers fully configured
- Complete testing infrastructure

---

## Next Stage

**→ Proceed to Stage 6: Scaled-Down Cluster Test**

```bash
cd ../stage6
cat README.md
```

Stage 6 deploys a 3-node cluster (1 central + 2 execute) with both HTCondor and SLURM fully configured via Ansible.
