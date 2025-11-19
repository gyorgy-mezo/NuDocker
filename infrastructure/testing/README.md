# NuDocker Infrastructure Testing Guide

**Iterative Testing Plan for HUN-REN Cloud Deployment**

This directory contains incremental testing infrastructure to validate the NuDocker HTCondor + SLURM cluster deployment on HUN-REN Science Cloud.

---

## 📋 Overview

The testing approach is **iterative and incremental**:
- Each stage builds on the previous
- Clear success criteria for each stage
- Minimal resources to reduce costs
- Fast feedback (30-60 minute stages)
- Easy troubleshooting with detailed test scripts

**Total testing time**: 6-8 hours over 1-3 days
**Estimated cost**: €25-40 for complete testing

---

## 🎯 Testing Philosophy

1. **Start Small**: Begin with simple infrastructure (1 VM) and gradually add complexity
2. **Validate Early**: Test each component before proceeding to next stage
3. **Clear Checkpoints**: Each stage has explicit pass/fail criteria
4. **Document Results**: All stages generate timestamped result files
5. **Iterative Approach**: Build confidence stage-by-stage

---

## 📊 Testing Stages

| Stage | Description | Resources | Duration | Cost | Status |
|-------|-------------|-----------|----------|------|--------|
| **0** | Prerequisites Verification | 0 VMs (local only) | 10 min | €0 | ✅ Ready |
| **1** | Basic VM Provisioning | 1 VM (2 vCPU, 4GB) | 15 min | €0.50 | ✅ Ready |
| **2** | Packer Image Build | 1 VM (4 vCPU, 8GB, temp) | 45 min | €2.50 | ✅ Ready |
| **3** | Single-Node HTCondor | 1 VM (4 vCPU, 8GB) | 30 min | €1.50 | ✅ Ready |
| **4** | Multi-Node Cluster | 2 VMs (6 vCPU, 12GB total) | 45 min | €3.00 | ✅ Ready |
| **5** | SLURM Integration | (See Stage 6) | N/A | N/A | ⏭️ Optional |
| **6** | Scaled Cluster | 3 VMs (10 vCPU, 20GB total) | 60 min | €4.00 | 🚧 Use full infra |
| **7** | Production Deploy | 6 VMs (20 vCPU, 48GB total) | 90 min | €6.00 | 🚧 Use full infra |

---

## 🚀 Quick Start

### Prerequisites

Ensure you have:
- [ ] OpenStack CLI installed
- [ ] Terraform ≥ 1.0
- [ ] Packer installed
- [ ] Ansible ≥ 2.9
- [ ] SSH key pair
- [ ] HUN-REN cloud access configured (`~/.config/openstack/clouds.yaml`)

**Verify prerequisites**:
```bash
cd stage0
./verify_prerequisites.sh
```

### Stage-by-Stage Execution

#### Stage 0: Prerequisites ✓
```bash
cd stage0
./verify_prerequisites.sh
# Expected: All critical tests pass
```

#### Stage 1: Basic VM ✓
```bash
cd stage1
cp terraform.tfvars.example terraform.tfvars
vim terraform.tfvars  # Edit with your values

terraform init
terraform plan
terraform apply

./test_connectivity.sh
# Expected: VM accessible via SSH

terraform destroy -auto-approve
```

#### Stage 2: Packer Image ✓
```bash
cd stage2
cp variables.pkrvars.hcl.example variables.pkrvars.hcl
vim variables.pkrvars.hcl  # Edit with your values

packer init nudocker-test.pkr.hcl
packer validate -var-file=variables.pkrvars.hcl nudocker-test.pkr.hcl
packer build -var-file=variables.pkrvars.hcl nudocker-test.pkr.hcl

./verify_image.sh
# Expected: All 7 component tests pass

# Keep the image for Stages 3-7
```

#### Stage 3: Single-Node HTCondor ✓
```bash
cd stage3
cp terraform.tfvars.example terraform.tfvars
vim terraform.tfvars  # Update custom_image_name from Stage 2

terraform init
terraform apply

./test_htcondor.sh
# Expected: 12/12 tests pass (Vanilla + Docker Universe)

terraform destroy -auto-approve
```

#### Stage 4: Multi-Node Cluster ✓
```bash
cd stage4
cp terraform.tfvars.example terraform.tfvars
vim terraform.tfvars  # Update custom_image_name

terraform init
terraform apply

./test_cluster.sh
# Expected: 17/17 tests pass (NFS + distributed jobs)

terraform destroy -auto-approve
```

#### Stage 5: SLURM Integration ⏭️
**Optional - Recommended to skip to Stage 6/7**

See `stage5/README.md` for manual SLURM setup instructions.

#### Stage 6-7: Full Deployment 🚧
Use the main infrastructure deployment with Ansible:
```bash
cd ../../  # Back to infrastructure/
# Follow main README for full deployment
```

---

## 📁 Directory Structure

```
infrastructure/testing/
├── README.md                          # This file
├── ITERATIVE_TESTING_PLAN.md          # Detailed testing methodology
│
├── stage0/                            # Prerequisites verification
│   ├── README.md
│   └── verify_prerequisites.sh
│
├── stage1/                            # Basic VM provisioning
│   ├── README.md
│   ├── main.tf
│   ├── variables.tf
│   ├── terraform.tfvars.example
│   └── test_connectivity.sh
│
├── stage2/                            # Packer image build
│   ├── README.md
│   ├── nudocker-test.pkr.hcl
│   ├── variables.pkrvars.hcl.example
│   └── verify_image.sh
│
├── stage3/                            # Single-node HTCondor
│   ├── README.md
│   ├── main.tf
│   ├── variables.tf
│   ├── terraform.tfvars.example
│   └── test_htcondor.sh
│
├── stage4/                            # Multi-node cluster
│   ├── README.md
│   ├── main.tf
│   ├── variables.tf
│   ├── terraform.tfvars.example
│   └── test_cluster.sh
│
├── stage5/                            # SLURM integration
│   └── README.md                      # (Manual setup guide)
│
└── results/                           # Test results (auto-generated)
    ├── stage0_results_YYYYMMDD_HHMMSS.txt
    ├── stage1_results_YYYYMMDD_HHMMSS.txt
    ├── stage2_results_YYYYMMDD_HHMMSS.txt
    ├── stage3_results_YYYYMMDD_HHMMSS.txt
    └── stage4_results_YYYYMMDD_HHMMSS.txt
```

---

## ✅ Success Criteria by Stage

### Stage 0: Prerequisites
- ✓ All required tools installed
- ✓ OpenStack CLI configured
- ✓ HUN-REN cloud accessible
- ✓ Sufficient quota available

### Stage 1: Basic VM
- ✓ Terraform can provision VM
- ✓ Floating IP assigned
- ✓ SSH access working
- ✓ VM has expected resources

### Stage 2: Packer Image
- ✓ Packer builds custom image (30-45 min)
- ✓ HTCondor 23.x installed
- ✓ Docker installed
- ✓ Singularity installed
- ✓ Munge installed
- ✓ Directory structure created

### Stage 3: Single-Node HTCondor
- ✓ HTCondor standalone mode works
- ✓ All daemons running
- ✓ Vanilla Universe jobs execute
- ✓ Docker Universe jobs execute
- ✓ Job output files created

### Stage 4: Multi-Node Cluster
- ✓ NFS server/client working
- ✓ Central manager functional
- ✓ Execute node registers
- ✓ Distributed jobs execute
- ✓ Jobs run on execute node
- ✓ Network connectivity verified

---

## 🐛 Troubleshooting

### Common Issues

**Problem**: `clouds.yaml` not found
**Solution**:
```bash
mkdir -p ~/.config/openstack
# Download from HUN-REN dashboard
# Or create manually with credentials
```

**Problem**: Terraform auth fails
**Solution**:
```bash
# Test OpenStack auth
openstack --os-cloud <cloud-name> token issue

# Verify cloud name matches clouds.yaml
grep "^clouds:" ~/.config/openstack/clouds.yaml -A 1
```

**Problem**: Packer build times out
**Solution**:
```bash
# Increase timeout in nudocker-test.pkr.hcl
# Add to source block:
ssh_timeout = "15m"
```

**Problem**: HTCondor jobs stay idle
**Solution**:
```bash
# Check slot availability
condor_status

# Analyze job requirements
condor_q -better-analyze <JOB_ID>

# Check logs
sudo tail -50 /var/log/condor/*
```

**Problem**: NFS mount fails
**Solution**:
```bash
# On central (server)
sudo systemctl status nfs-kernel-server
sudo showmount -e

# On execute (client)
sudo mount -t nfs <CENTRAL_IP>:/storage /storage
```

### Getting Help

1. **Check stage-specific README**: Each `stageN/README.md` has detailed troubleshooting
2. **Review result files**: `results/stageN_results_*.txt` contain detailed test output
3. **Check logs**:
   - Cloud-init: `sudo tail -100 /var/log/cloud-init-output.log`
   - HTCondor: `sudo tail -100 /var/log/condor/*`
   - System: `sudo journalctl -xe`

---

## 💰 Cost Management

### Cost Breakdown

| Stage | Duration | Resources | Est. Cost |
|-------|----------|-----------|-----------|
| 0 | 10 min | None | €0 |
| 1 | 15 min | 1× 2vCPU 4GB | €0.50 |
| 2 | 45 min | 1× 4vCPU 8GB | €2.50 |
| 3 | 30 min | 1× 4vCPU 8GB | €1.50 |
| 4 | 45 min | 2× VMs | €3.00 |
| **Total** | **~3 hours** | | **~€7.50** |

**Note**: Costs are estimates. Actual costs depend on HUN-REN pricing.

### Cost Optimization Tips

1. **Run tests sequentially**: Don't leave VMs running between stages
2. **Destroy immediately**: Always run `terraform destroy` after testing
3. **Reuse images**: Keep Stage 2 image for all subsequent stages
4. **Use smaller flavors**: If minimum requirements met, use cheaper options
5. **Schedule wisely**: Run during off-peak if pricing varies

---

## 📝 Result Reporting

### Result Files

Each stage generates a timestamped result file in `results/`:

```
STAGE N: <STAGE_NAME>
======================
Date: YYYY-MM-DD HH:MM:SS
Duration: ~XX minutes

<STAGE-SPECIFIC DETAILS>

TEST RESULTS:
-------------
Total tests: XX
Passed: XX
Failed: XX
Warnings: XX

STATUS: ✓ STAGE N PASSED / ✗ STAGE N FAILED

NEXT STEPS:
-----------
<What to do next>
```

### Sharing Results

To share test results with the team:

```bash
# Collect all results
tar czf nudocker_test_results_$(date +%Y%m%d).tar.gz results/

# Upload to shared location
# Or attach to issue/PR
```

---

## 🔄 Continuous Testing

### Regression Testing

After infrastructure changes, re-run stages to verify nothing broke:

```bash
# Quick regression test (Stages 1, 3, 4)
cd stage1 && terraform apply && ./test_connectivity.sh && terraform destroy
cd stage3 && terraform apply && ./test_htcondor.sh && terraform destroy
cd stage4 && terraform apply && ./test_cluster.sh && terraform destroy
```

### Automated Testing

Consider setting up automated testing:
- GitLab CI/CD pipeline
- GitHub Actions workflow
- Jenkins job
- Scheduled cron job

---

## 📚 Additional Documentation

- **Detailed Testing Plan**: See `ITERATIVE_TESTING_PLAN.md`
- **Main Infrastructure**: See `../README.md`
- **Ansible Playbooks**: See `../ansible/README.md`
- **Terraform Modules**: See `../terraform/README.md`
- **Packer Templates**: See `../packer/README.md`

---

## 🤝 Contributing

When modifying testing infrastructure:

1. **Test your changes**: Run affected stages locally
2. **Update documentation**: Keep READMEs current
3. **Add result samples**: Include example outputs
4. **Document new tests**: Explain what's being tested
5. **Update costs**: Adjust cost estimates if resource requirements change

---

## ⚠️ Important Notes

- **Testing is destructive**: VMs are created and destroyed
- **Costs accumulate**: Don't leave resources running
- **Security is permissive**: Testing configs are NOT production-ready
- **Cleanup is manual**: Always run `terraform destroy`
- **Images persist**: Stage 2 image remains until manually deleted
- **Results accumulate**: Clean up old result files periodically

---

## 🎓 Learning Path

**New to infrastructure testing?** Follow this order:

1. Read `ITERATIVE_TESTING_PLAN.md` for context
2. Run Stage 0 to verify your setup
3. Proceed through stages sequentially
4. Don't skip stages (each builds on previous)
5. Review result files after each stage
6. Troubleshoot before proceeding to next stage

**Experienced users?**

- Jump to specific stages for targeted testing
- Modify configs for your specific needs
- Use stages as templates for custom tests

---

## 📞 Support

For issues specific to:
- **HUN-REN Cloud**: Contact HUN-REN support
- **NuDocker Project**: Open issue on GitHub
- **Testing Infrastructure**: Check stage-specific README troubleshooting sections

---

**Happy Testing! 🚀**

Last updated: 2025-11-19
