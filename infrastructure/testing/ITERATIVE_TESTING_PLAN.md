# NuDocker HUN-REN Cloud Iterative Testing Plan

**Purpose**: Incrementally test infrastructure components on HUN-REN cloud before full deployment
**Approach**: Stage-by-stage validation with clear success criteria
**Timeline**: Each stage 30-60 minutes, total ~6-8 hours testing time
**Date**: 2025-11-19

---

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Testing Stages](#testing-stages)
4. [Stage Execution Guide](#stage-execution-guide)
5. [Success Criteria](#success-criteria)
6. [Troubleshooting](#troubleshooting)
7. [Result Reporting](#result-reporting)

---

## Overview

### Testing Philosophy

**Incremental Validation**: Each stage builds on the previous one. If a stage fails, stop and fix before proceeding.

**Clear Checkpoints**: Each stage has specific success criteria. Document results at each checkpoint.

**Minimal Resources**: Start with smallest viable infrastructure, scale up only after validation.

**Fast Feedback**: Each stage should complete in 30-60 minutes maximum.

### Testing Stages Summary

| Stage | Purpose | Resources | Duration | Risk |
|-------|---------|-----------|----------|------|
| **0** | Prerequisites check | None | 10 min | Low |
| **1** | Basic VM provisioning | 1 VM, 2 vCPU | 15 min | Low |
| **2** | Packer image build | 1 build VM | 45 min | Medium |
| **3** | Single-node HTCondor | 1 VM, 4 vCPU | 30 min | Medium |
| **4** | Multi-node cluster (2 nodes) | 2 VMs, 12 vCPU | 45 min | Medium |
| **5** | SLURM integration | 2 VMs | 30 min | Medium |
| **6** | Full cluster (scaled down) | 3 VMs, 20 vCPU | 60 min | Low |
| **7** | Production deployment | 6 VMs, 48 vCPU | 90 min | Low |

**Total Testing Time**: 5-6 hours (can be done over multiple sessions)

---

## Prerequisites

Before starting any testing stage, ensure you have:

### Required Tools (Local Machine)

- [ ] **Terraform** >= 1.0.0
  ```bash
  terraform version
  ```

- [ ] **Packer** >= 1.8.0
  ```bash
  packer version
  ```

- [ ] **Ansible** >= 2.12
  ```bash
  ansible --version
  ```

- [ ] **OpenStack CLI** (optional but helpful)
  ```bash
  openstack --version
  ```

- [ ] **jq** (JSON processor)
  ```bash
  jq --version
  ```

- [ ] **SSH key** available at `~/.ssh/id_rsa`
  ```bash
  ls -la ~/.ssh/id_rsa*
  ```

### HUN-REN Cloud Access

- [ ] **Cloud credentials** (provided by HUN-REN)
  - Project name
  - Username
  - Password
  - Auth URL
  - Region

- [ ] **Resource quota** verified
  - Minimum for testing: 20 vCPU, 40 GB RAM
  - Full deployment: 72 vCPU, 192 GB RAM

- [ ] **Network access**
  - Floating IP pool available
  - Security group creation allowed
  - Private network creation allowed

### Repository Setup

- [ ] **NuDocker repository** cloned
  ```bash
  git clone https://github.com/gyorgy-mezo/NuDocker.git
  cd NuDocker
  git checkout claude/claude-md-mi49eroibu15poar-01SZudbvHzHH2ET2UvJiRxg1
  ```

- [ ] **Testing directory** exists
  ```bash
  ls infrastructure/testing/
  ```

---

## Testing Stages

### Stage 0: Prerequisites Verification ✓

**Goal**: Verify local tools and HUN-REN cloud access
**Resources**: None (local only)
**Duration**: 10 minutes
**Risk**: Low

**What This Tests**:
- Local tool versions correct
- HUN-REN cloud credentials valid
- API endpoint reachable
- Basic quota available

**Execution**:
```bash
cd infrastructure/testing/stage0
./verify_prerequisites.sh
```

**Success Criteria**:
- ✅ All tools installed with correct versions
- ✅ Can authenticate to HUN-REN cloud
- ✅ Can list available images
- ✅ Can list available flavors
- ✅ Quota shows sufficient resources

**Output**: `results/stage0_results.txt`

**Next Stage**: If all checks pass → Stage 1

---

### Stage 1: Basic VM Provisioning ⚙️

**Goal**: Verify Terraform can create a simple VM on HUN-REN cloud
**Resources**: 1 VM (2 vCPU, 4 GB RAM, 20 GB disk)
**Duration**: 15 minutes
**Risk**: Low

**What This Tests**:
- Terraform provider configuration
- Network creation
- Security group creation
- Floating IP allocation
- SSH key pair creation
- VM instance provisioning
- SSH connectivity

**Infrastructure**:
```
1 VM: test-vm-01
  - 2 vCPU
  - 4 GB RAM
  - Ubuntu 20.04
  - Floating IP
  - SSH access
```

**Execution**:
```bash
cd infrastructure/testing/stage1

# 1. Configure credentials
cp terraform.tfvars.example terraform.tfvars
vim terraform.tfvars  # Fill in HUN-REN credentials

# 2. Initialize Terraform
terraform init

# 3. Plan deployment
terraform plan

# 4. Apply (create VM)
terraform apply

# 5. Test SSH connectivity
./test_connectivity.sh

# 6. Cleanup
terraform destroy
```

**Success Criteria**:
- ✅ Terraform plan completes without errors
- ✅ VM creation succeeds
- ✅ Floating IP assigned
- ✅ SSH connection works
- ✅ Can run basic commands (uptime, df -h)
- ✅ Cleanup (destroy) works

**Output**: `results/stage1_results.txt`

**Troubleshooting**:
- If floating IP fails → Check quota
- If SSH fails → Check security group rules
- If VM creation hangs → Check image availability

**Next Stage**: If all checks pass → Stage 2

---

### Stage 2: Packer Base Image Build 🏗️

**Goal**: Verify Packer can build a custom image with HTCondor + SLURM
**Resources**: 1 build VM (4 vCPU, 8 GB RAM, temporary)
**Duration**: 45 minutes
**Risk**: Medium

**What This Tests**:
- Packer OpenStack plugin
- Image building process
- Software installation (HTCondor, SLURM, Docker, Singularity)
- Image snapshot creation
- Image availability for deployment

**Build Process**:
```
1. Launch temporary Ubuntu 20.04 VM
2. Install packages:
   - HTCondor 23.10
   - SLURM 23.02
   - Docker 24.0
   - Singularity 3.11.4
   - NuDocker dependencies
3. Configure system
4. Create image snapshot
5. Destroy build VM
```

**Execution**:
```bash
cd infrastructure/testing/stage2

# 1. Configure Packer variables
cp packer-test.pkrvars.hcl.example packer-test.pkrvars.hcl
vim packer-test.pkrvars.hcl  # Fill in credentials

# 2. Validate Packer template
packer validate -var-file=packer-test.pkrvars.hcl nudocker-test.pkr.hcl

# 3. Build image (this takes ~30-40 minutes)
packer build -var-file=packer-test.pkrvars.hcl nudocker-test.pkr.hcl

# 4. Verify image exists
./verify_image.sh

# 5. Cleanup old images (optional)
# ./cleanup_images.sh
```

**Success Criteria**:
- ✅ Packer validation passes
- ✅ Build completes without errors
- ✅ Image created and visible in OpenStack
- ✅ Image size reasonable (~2-3 GB)
- ✅ Can launch VM from created image

**Output**:
- `results/stage2_results.txt`
- Image name: `nudocker-test-YYYYMMDD-HHMM`

**Troubleshooting**:
- If build timeout → Increase timeout in template
- If package install fails → Check internet connectivity on build VM
- If image creation fails → Check quota for images

**Next Stage**: If image built successfully → Stage 3

---

### Stage 3: Single-Node HTCondor Test 🔧

**Goal**: Deploy minimal HTCondor pool on single VM from custom image
**Resources**: 1 VM (4 vCPU, 8 GB RAM) using Stage 2 image
**Duration**: 30 minutes
**Risk**: Medium

**What This Tests**:
- Custom image boots correctly
- HTCondor installation works
- HTCondor configuration
- Pool authentication
- Docker Universe support
- Simple job submission and execution

**Infrastructure**:
```
1 VM: htcondor-test
  - Uses custom image from Stage 2
  - Runs: collector, negotiator, schedd, startd (all roles)
  - HTCondor pool password authentication
  - Docker enabled
```

**Execution**:
```bash
cd infrastructure/testing/stage3

# 1. Configure
cp terraform.tfvars.example terraform.tfvars
vim terraform.tfvars  # Set image_name from Stage 2

# 2. Deploy
terraform init
terraform apply

# 3. Run tests
./test_htcondor.sh

# 4. Submit test job
./submit_test_job.sh

# 5. Verify results
./verify_results.sh

# 6. Cleanup
terraform destroy
```

**Test Jobs**:
1. **Echo Test**: Simple echo command
2. **Docker Test**: Run Alpine container
3. **CPU Test**: OpenMP thread test
4. **NuDocker Test**: Run nugrid/nudome:16.0 container

**Success Criteria**:
- ✅ HTCondor services running (condor status active)
- ✅ Pool shows available slots (condor_status)
- ✅ Can submit jobs (condor_submit)
- ✅ Jobs complete successfully
- ✅ Docker Universe works
- ✅ NuDocker container can run

**Output**:
- `results/stage3_results.txt`
- `results/stage3_job_logs/`

**Troubleshooting**:
- If HTCondor not running → Check logs in /var/log/condor/
- If jobs don't run → Check authentication (pool password)
- If Docker fails → Check Docker service status

**Next Stage**: If single-node works → Stage 4

---

### Stage 4: Multi-Node HTCondor Cluster 🖧

**Goal**: Deploy minimal HTCondor cluster (1 central + 1 execute)
**Resources**: 2 VMs (12 vCPU, 24 GB RAM total)
**Duration**: 45 minutes
**Risk**: Medium

**What This Tests**:
- Multi-node deployment
- Ansible playbook execution
- Network communication between nodes
- NFS shared storage
- HTCondor pool with multiple execute nodes
- Job distribution across nodes

**Infrastructure**:
```
Central Manager: 1 VM (4 vCPU, 8 GB RAM)
  - HTCondor: collector, negotiator, schedd
  - NFS server
  - /storage export

Execute Node: 1 VM (8 vCPU, 16 GB RAM)
  - HTCondor: startd
  - NFS client (mount /storage)
  - Docker enabled
```

**Execution**:
```bash
cd infrastructure/testing/stage4

# 1. Configure Terraform
cp terraform.tfvars.example terraform.tfvars
vim terraform.tfvars

# 2. Deploy infrastructure
terraform init
terraform apply

# 3. Get outputs
terraform output > ../results/stage4_terraform_output.txt

# 4. Configure Ansible inventory
./generate_inventory.sh

# 5. Run Ansible playbook
cd ansible
ansible-playbook -i inventory/hosts.ini playbooks/site.yml

# 6. Verify cluster
./verify_cluster.sh

# 7. Run test jobs
./submit_test_jobs.sh

# 8. Cleanup
cd ..
terraform destroy
```

**Test Jobs**:
1. **Multi-job test**: 10 simple jobs
2. **Parallel test**: 4 concurrent CPU-intensive jobs
3. **Docker test**: Multiple container jobs
4. **NFS test**: Jobs read/write to shared storage

**Success Criteria**:
- ✅ Both VMs created and accessible
- ✅ Ansible playbook completes successfully
- ✅ HTCondor pool shows 2 nodes
- ✅ NFS mount works on execute node
- ✅ Jobs distribute across both nodes
- ✅ All test jobs complete successfully
- ✅ Shared storage accessible from jobs

**Output**:
- `results/stage4_results.txt`
- `results/stage4_ansible_log.txt`
- `results/stage4_job_results/`

**Troubleshooting**:
- If NFS mount fails → Check firewall/security groups
- If execute node doesn't register → Check HTCondor pool password
- If jobs only run on one node → Check START/RANK expressions

**Next Stage**: If multi-node HTCondor works → Stage 5

---

### Stage 5: SLURM Integration Test 🔄

**Goal**: Add SLURM to Stage 4 cluster (dual-scheduler)
**Resources**: Same 2 VMs from Stage 4
**Duration**: 30 minutes
**Risk**: Medium

**What This Tests**:
- SLURM controller (slurmctld) installation
- SLURM compute (slurmd) installation
- Munge authentication
- SLURM configuration via Ansible
- Job submission to SLURM
- Singularity container execution
- Dual-scheduler operation (HTCondor + SLURM)

**Infrastructure** (extends Stage 4):
```
Central Manager:
  + SLURM controller (slurmctld)
  + SLURM database (slurmdbd)
  + Munge

Execute Node:
  + SLURM compute (slurmd)
  + Munge
  + Singularity
```

**Execution**:
```bash
cd infrastructure/testing/stage5

# 1. Use Stage 4 infrastructure (don't destroy it)
# OR deploy fresh with SLURM enabled

# 2. Configure Ansible to include SLURM
vim ansible/playbooks/group_vars/all.yml
# Set: enable_slurm: true

# 3. Run SLURM-specific playbook
cd ansible
ansible-playbook -i inventory/hosts.ini playbooks/slurm-setup.yml

# 4. Verify SLURM cluster
./verify_slurm.sh

# 5. Submit SLURM test jobs
./submit_slurm_jobs.sh

# 6. Test dual-scheduler
./test_both_schedulers.sh

# 7. Cleanup
cd ../..
terraform destroy
```

**Test Jobs (SLURM)**:
1. **Simple batch job**: echo test
2. **Singularity job**: Run nudome container
3. **Job array**: 5 array tasks
4. **Parallel job**: OpenMP test

**Test Jobs (Dual-scheduler)**:
1. Submit to HTCondor and SLURM simultaneously
2. Verify both schedulers running independently
3. Check resource allocation doesn't conflict

**Success Criteria**:
- ✅ SLURM controller running (scontrol ping)
- ✅ SLURM shows compute nodes (sinfo)
- ✅ Munge authentication works
- ✅ Can submit SLURM jobs (sbatch)
- ✅ SLURM jobs complete successfully
- ✅ Singularity containers work
- ✅ HTCondor still works (not broken by SLURM)
- ✅ Both schedulers run concurrently

**Output**:
- `results/stage5_results.txt`
- `results/stage5_slurm_jobs/`

**Troubleshooting**:
- If slurmctld won't start → Check slurm.conf syntax
- If compute node doesn't register → Check munge key sync
- If Singularity fails → Check user permissions

**Next Stage**: If SLURM works → Stage 6

---

### Stage 6: Scaled-Down Full Cluster 📊

**Goal**: Deploy minimal version of full infrastructure (3 nodes)
**Resources**: 3 VMs (1 central + 2 execute, 20 vCPU, 40 GB RAM total)
**Duration**: 60 minutes
**Risk**: Low (most components already tested)

**What This Tests**:
- Full deployment pipeline (Packer → Terraform → Ansible)
- All Ansible roles
- NuDocker batch scripts deployment
- Validation scripts
- Health reporting
- Demo job workflows

**Infrastructure**:
```
Central Manager: 1 VM (4 vCPU, 8 GB RAM)
  - HTCondor: collector, negotiator, schedd
  - SLURM: controller
  - NFS server

Execute Nodes: 2 VMs (8 vCPU, 16 GB RAM each)
  - HTCondor: startd
  - SLURM: compute
  - NFS client
  - Docker + Singularity
```

**Execution**:
```bash
cd infrastructure/testing/stage6

# 1. Use existing image from Stage 2
# 2. Deploy with reduced node count

# Configure
cp terraform.tfvars.example terraform.tfvars
vim terraform.tfvars
# Set: execute_node_count = 2

# 3. Full deployment
terraform init
terraform apply

# 4. Run Ansible
cd ../ansible
ansible-playbook -i inventory/generated_hosts.ini playbooks/site.yml

# 5. Run validation
cd ../..
./validate.sh

# 6. Deploy batch examples
# (Already done by Ansible nudocker role)

# 7. Test HTCondor workflow
./test_htcondor_workflow.sh

# 8. Test SLURM workflow
./test_slurm_workflow.sh

# 9. Generate health report
ssh ubuntu@<FLOATING_IP> "cat /storage/cluster_health_report.txt"

# 10. Cleanup
terraform destroy
```

**Test Workflows**:

**HTCondor**:
- Submit nugrid_study.dag (scaled down to 6 models)
- Monitor DAGMan progress
- Verify results collected

**SLURM**:
- Generate parameter grid (12 models)
- Submit job array
- Monitor with squeue
- Verify results

**Success Criteria**:
- ✅ All 3 VMs deploy successfully
- ✅ Ansible playbook completes all roles
- ✅ Validation script passes all checks
- ✅ HTCondor pool shows 16 slots (2×8)
- ✅ SLURM shows 2 compute nodes
- ✅ Batch scripts deployed correctly
- ✅ HTCondor DAG workflow completes
- ✅ SLURM job array completes
- ✅ Health report shows all systems operational

**Output**:
- `results/stage6_results.txt`
- `results/stage6_validation.txt`
- `results/stage6_health_report.txt`
- `results/stage6_htcondor_jobs/`
- `results/stage6_slurm_jobs/`

**Next Stage**: If scaled cluster works → Stage 7 (Production)

---

### Stage 7: Production Deployment 🚀

**Goal**: Deploy full production infrastructure (6 nodes, 48 vCPU)
**Resources**: 1 central (8 vCPU, 16 GB) + 5 execute (40 vCPU, 160 GB total)
**Duration**: 90 minutes
**Risk**: Low (everything already validated)

**What This Tests**:
- Production-scale deployment
- Full resource utilization
- Complete parameter study (54 models)
- Performance at scale
- Long-running jobs
- Monitoring and management

**Infrastructure** (Production):
```
Central Manager: 1 VM (8 vCPU, 16 GB RAM)
Execute Nodes: 5 VMs (8 vCPU, 32 GB RAM each)
Total: 48 vCPU, 176 GB RAM
Storage: 500 GB NFS
```

**Execution**:
```bash
cd infrastructure

# Use main deployment (not testing)
./deploy.sh all

# OR step-by-step:
./deploy.sh packer      # Use existing image from Stage 2
./deploy.sh terraform   # 6 VMs
./deploy.sh ansible     # Full configuration
./deploy.sh verify      # Complete validation
```

**Production Tests**:
1. **Full HTCondor study**: 54 models (all 3 mass groups)
2. **Full SLURM grid**: 150 models (parameter sweep)
3. **Stress test**: Maximum concurrent jobs
4. **Long-running test**: 24+ hour simulation
5. **Fault tolerance**: Kill and restart services
6. **Storage test**: Fill and manage /storage

**Success Criteria**:
- ✅ All 6 VMs operational
- ✅ HTCondor pool: 40 slots available
- ✅ SLURM cluster: 5 compute nodes
- ✅ 500 GB storage mounted
- ✅ All validation tests pass
- ✅ Can run 50+ concurrent jobs
- ✅ Jobs complete successfully
- ✅ Performance meets expectations
- ✅ Monitoring dashboards work
- ✅ Resource utilization optimal

**Output**:
- Complete production environment
- Performance benchmarks
- Documentation of any issues
- Recommendations for optimization

**Outcome**: Production-ready cluster for scientific computing!

---

## Stage Execution Guide

### Before Each Stage

1. **Read stage documentation** completely
2. **Check prerequisites** for that stage
3. **Set up environment variables** (credentials)
4. **Create result tracking document**

### During Each Stage

1. **Follow steps exactly** as written
2. **Document all outputs** (copy/paste to results file)
3. **Capture any errors** immediately
4. **Take screenshots** if helpful
5. **Note timing** for each step

### After Each Stage

1. **Verify all success criteria** met
2. **Save all results** to results/ directory
3. **Cleanup resources** (terraform destroy) unless continuing
4. **Review what worked/didn't work**
5. **Decide**: Continue to next stage OR troubleshoot issues

### Decision Points

After each stage:

```
✅ ALL success criteria met?
   ↓ YES              ↓ NO
Continue to       Stop and
next stage        troubleshoot
```

**Never proceed if stage failed!** Fix issues before continuing.

---

## Success Criteria

### Per-Stage Success Metrics

Each stage has specific criteria listed above. General metrics:

**Stage 0**: ✅ All tools and access verified
**Stage 1**: ✅ Can create and SSH to VM
**Stage 2**: ✅ Custom image built successfully
**Stage 3**: ✅ Single-node HTCondor runs jobs
**Stage 4**: ✅ Multi-node cluster distributes jobs
**Stage 5**: ✅ SLURM works alongside HTCondor
**Stage 6**: ✅ Scaled cluster runs full workflows
**Stage 7**: ✅ Production deployment operational

### Overall Success

**Complete Success**: All stages 0-7 pass all criteria
**Partial Success**: Stages 0-5 pass (minimum viable)
**Failure**: Any stage 0-3 fails (fundamental issues)

---

## Troubleshooting

### Common Issues by Stage

**Stage 1 Issues**:
- **Floating IP fails**: Check quota, try different network
- **SSH timeout**: Check security groups allow port 22
- **Authentication fails**: Verify credentials in tfvars

**Stage 2 Issues**:
- **Build timeout**: Increase timeout, check VM connectivity
- **Package install fails**: Check Ubuntu mirrors, try different image
- **Image creation fails**: Check image quota

**Stage 3 Issues**:
- **HTCondor won't start**: Check logs, verify installation
- **Jobs don't run**: Check pool password, START expression
- **Docker fails**: Verify Docker service, check permissions

**Stage 4 Issues**:
- **NFS mount fails**: Check firewall, verify exports
- **Ansible fails**: Check SSH connectivity, Python version
- **Execute node invisible**: Check pool password sync

**Stage 5 Issues**:
- **SLURM won't start**: Check slurm.conf syntax
- **Munge fails**: Verify key sync, time synchronization
- **Jobs pending**: Check partition configuration

### Getting Help

1. **Check logs** first:
   - HTCondor: `/var/log/condor/`
   - SLURM: `/var/log/slurm/`
   - Ansible: Playbook output

2. **Review documentation**:
   - `infrastructure/DEPLOYMENT_GUIDE.md`
   - Stage-specific README files

3. **Consult stage-specific troubleshooting** sections above

4. **Document issue** completely before asking for help

---

## Result Reporting

### What to Report After Each Stage

Create a file: `results/stageN_results.txt` with:

```
===============================================
Stage N: [STAGE NAME]
Date: YYYY-MM-DD HH:MM
Duration: [X] minutes
Status: [PASS/FAIL/PARTIAL]
===============================================

## Environment
- HUN-REN Project: [project name]
- Image Used: [image name if applicable]
- Resources: [X vCPU, X GB RAM]

## Execution Timeline
[HH:MM] Started stage N
[HH:MM] Step 1 completed: [description]
[HH:MM] Step 2 completed: [description]
...
[HH:MM] Stage N completed

## Success Criteria Results
- [ ] Criterion 1: [PASS/FAIL] - [notes]
- [ ] Criterion 2: [PASS/FAIL] - [notes]
...

## Issues Encountered
[List any problems, even if resolved]

## Performance Notes
[Any observations about speed, resource usage, etc.]

## Outputs
- Terraform state: [location]
- Ansible logs: [location]
- Job results: [location]
- Screenshots: [location]

## Resources Created
- VMs: [list instance IDs]
- Images: [list image IDs]
- Networks: [list network IDs]
- Floating IPs: [list IPs]

## Cleanup Status
- [ ] All resources destroyed
- [ ] Verified nothing left running
- [ ] Costs incurred: [estimate]

## Next Steps
[Continue to Stage N+1 OR troubleshoot specific issue]

## Additional Notes
[Any other observations]
```

### Uploading Results

After completing stages, prepare report:

```bash
# Package all results
cd infrastructure/testing/results
tar czf nudocker-hunren-test-results.tar.gz *.txt *.log

# Include:
# - All stageN_results.txt files
# - Terraform outputs
# - Ansible logs
# - Job outputs (if not too large)
# - Screenshots
```

Share results via:
- GitHub issue
- Email
- Shared drive
- Whatever method works best

---

## Testing Timeline Estimate

**Aggressive (1 day)**:
- Morning: Stages 0-2 (prerequisites, basic VM, Packer)
- Afternoon: Stages 3-4 (single node, multi-node)
- Evening: Stage 5 (SLURM)

**Recommended (2-3 days)**:
- Day 1: Stages 0-3 + troubleshooting
- Day 2: Stages 4-5 + troubleshooting
- Day 3: Stages 6-7 (if all previous passed)

**Conservative (1 week)**:
- Run one stage per day
- Allow time for troubleshooting
- No pressure to rush

---

## Expected Outcomes

### Ideal Scenario
- All stages 0-7 pass
- Total time: 6-8 hours
- Zero major issues
- Production deployment successful

### Realistic Scenario
- Stages 0-5 pass on first try
- Stage 6 requires some adjustments
- Total time: 8-12 hours over 2-3 days
- Minor issues resolved quickly
- Production deployment successful with tweaks

### Challenging Scenario
- Issues in Stage 2 (Packer)
- Network/firewall problems in Stage 4
- Total time: 12-16 hours over 1 week
- Several troubleshooting iterations
- Production deployment delayed but eventually successful

---

## Important Notes

### Cost Management

**Each stage costs money!** Approximate costs:

- Stage 1: < €1 (15 min, 1 VM)
- Stage 2: €2-3 (45 min build)
- Stage 3: €1-2 (30 min, 1 VM)
- Stage 4-5: €3-5 (2 VMs, 1-2 hours)
- Stage 6: €5-8 (3 VMs, few hours)
- Stage 7: €10-20 (6 VMs, several hours)

**Total testing cost: €25-40**

**Always destroy resources after each stage** unless continuing immediately!

### Time Management

Don't rush! Better to:
- Test one stage thoroughly
- Fix any issues
- Document results
- Take a break
- Continue refreshed

### When to Stop

Stop testing if:
- ❌ Stage 0-1 fails completely (fundamental access issues)
- ❌ Stage 2 fails repeatedly (can't build image)
- ❌ Stage 3 fails (core functionality broken)
- ❌ Running out of time/budget
- ❌ Found fundamental HUN-REN incompatibility

Partial success is OK! Even Stage 4 success = viable cluster.

---

## Next Steps After Testing

### If All Stages Pass
1. ✅ Infrastructure validated
2. ✅ Deploy production environment
3. ✅ Start using for MESA simulations
4. ✅ Monitor and optimize

### If Some Stages Pass
1. ✅ Use what works (e.g., HTCondor without SLURM)
2. ⚠️ Document limitations
3. 🔧 Continue troubleshooting failed stages
4. 📝 Update documentation

### If Testing Reveals Issues
1. 📋 Document all issues comprehensively
2. 🔍 Analyze root causes
3. 🛠️ Propose fixes/workarounds
4. 🔄 Re-test after fixes

---

**Ready to begin?** Start with Stage 0!

**Questions?** Review stage-specific documentation in testing/stageN/ directories.

**Need help?** Document the issue thoroughly using the result template above.
