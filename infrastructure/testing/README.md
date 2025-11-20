# NuDocker Testing Infrastructure

**Incremental testing framework for HTCondor cluster deployment on OpenStack clouds**

[![License](https://img.shields.io/badge/License-BSD%203--Clause-blue.svg)](../../../LICENSE)
[![Platform](https://img.shields.io/badge/Platform-OpenStack-red.svg)](https://www.openstack.org/)
[![HTCondor](https://img.shields.io/badge/HTCondor-23.x-green.svg)](https://htcondor.org/)
[![MESA](https://img.shields.io/badge/MESA-Compatible-orange.svg)](http://mesa.sourceforge.net/)

---

## 🎯 Quick Navigation

**Choose your path:**

| I am... | Start here |
|---------|------------|
| 🔬 **Scientist** wanting to run MESA simulations | [QUICKSTART_FOR_PIGNATARI.md](QUICKSTART_FOR_PIGNATARI.md) |
| 💻 **Mac User** with Claude CLI | [CLAUDE_CLI_GUIDE.md](CLAUDE_CLI_GUIDE.md) ⭐ **NEW** |
| ☁️ **Cloud Admin** setting up infrastructure | [ITERATIVE_TESTING_PLAN.md](ITERATIVE_TESTING_PLAN.md) |
| 🔧 **Using OpenRC file** instead of clouds.yaml | [CLOUD_SETUP_GUIDE.md](CLOUD_SETUP_GUIDE.md) |
| 📚 **Want complete overview** | [README_MASTER.md](README_MASTER.md) |

---

## 📖 What Is This?

This is a **complete testing and deployment system** for running NuDocker containerized MESA stellar evolution simulations on HTCondor clusters in OpenStack clouds.

**What you can do:**
- ✅ Test cloud infrastructure incrementally (8 stages, ~3 hours, ~€8)
- ✅ Deploy optimized HTCondor clusters on HUN-REN, WIGNER, or any OpenStack cloud
- ✅ Run MESA parameter grids for stellar astrophysics research
- ✅ Reproduce published nucleosynthesis results (Pignatari et al. 2016)
- ✅ Use Claude CLI for interactive guidance and troubleshooting

**What's included:**
- 🧪 **Testing Framework**: 8 progressive stages from prerequisites to production
- ☁️ **Cloud Discovery**: Automated resource collection and optimization
- 🔬 **Scientific Workflows**: MESA parameter grids and yield analysis
- 🤖 **AI Integration**: Claude CLI guide for interactive assistance
- 📊 **Cost Tracking**: Estimates and optimization recommendations

---

## 🚀 Quick Start

### For Mac Users with Claude CLI (Recommended)

You have: Mac Air, Python virtualenv, OpenStack CLI, Packer, Claude CLI

```bash
# 1. Navigate to testing directory
cd /path/to/NuDocker/infrastructure/testing

# 2. Activate your virtualenv
source ~/path/to/your-venv/bin/activate

# 3. Authenticate with your cloud
source ~/path/to/app-cred-bridge-openrc.sh

# 4. Start Claude CLI
claude

# 5. Ask Claude:
"I'm ready to start testing NuDocker infrastructure.
Guide me through Stage 0."
```

**Then follow**: [CLAUDE_CLI_GUIDE.md](CLAUDE_CLI_GUIDE.md)

### For Scientists

You want to: Run MESA simulations for nucleosynthesis research

```bash
# 1. Collect your cloud resources
./collect_cloud_resources.sh

# 2. Share results (upload the .tar.gz file)

# 3. Get optimized cluster design

# 4. Deploy and run MESA parameter grid
```

**Then follow**: [QUICKSTART_FOR_PIGNATARI.md](QUICKSTART_FOR_PIGNATARI.md)

### For Infrastructure Engineers

You want to: Validate infrastructure before production deployment

```bash
# 1. Verify prerequisites
cd stage0
./verify_prerequisites.sh

# 2. Test basic provisioning
cd ../stage1
terraform init && terraform apply
./test_connectivity.sh
terraform destroy

# 3. Continue through stages 2-4
```

**Then follow**: [ITERATIVE_TESTING_PLAN.md](ITERATIVE_TESTING_PLAN.md)

---

## 📚 Complete Documentation

### 🎓 Getting Started Guides

| Document | Description | For |
|----------|-------------|-----|
| **[README.md](README.md)** | This file - Navigation hub | Everyone |
| **[CLAUDE_CLI_GUIDE.md](CLAUDE_CLI_GUIDE.md)** ⭐ | Interactive testing with Claude AI | Mac + Claude CLI users |
| **[QUICKSTART_FOR_PIGNATARI.md](QUICKSTART_FOR_PIGNATARI.md)** | Scientific workflow quick start | Scientists/researchers |
| **[CLOUD_SETUP_GUIDE.md](CLOUD_SETUP_GUIDE.md)** | OpenStack setup with OpenRC | OpenRC users |

### 📖 Detailed Documentation

| Document | Description | For |
|----------|-------------|-----|
| **[README_MASTER.md](README_MASTER.md)** | Complete system overview | Comprehensive reference |
| **[ITERATIVE_TESTING_PLAN.md](ITERATIVE_TESTING_PLAN.md)** | Testing methodology | Infrastructure engineers |
| **[PIGNATARI_REPRODUCTION_GUIDE.md](PIGNATARI_REPRODUCTION_GUIDE.md)** | Scientific background & requirements | Scientists |

### 🔧 Tools & Scripts

| Tool | Description | Duration |
|------|-------------|----------|
| **[discover_cloud.sh](discover_cloud.sh)** | Quick cloud environment scan | 30 seconds |
| **[check_quota.sh](check_quota.sh)** | Fast quota verification | 5 seconds |
| **[collect_cloud_resources.sh](collect_cloud_resources.sh)** | Comprehensive resource collection | 60 seconds |

### 📁 Testing Stages

| Stage | Description | Resources | Cost |
|-------|-------------|-----------|------|
| **[Stage 0](stage0/)** | Prerequisites verification | None | €0 |
| **[Stage 1](stage1/)** | Basic VM provisioning | 1 VM (2 vCPU, 4GB) | €0.50 |
| **[Stage 2](stage2/)** | Packer image build | 1 VM (4 vCPU, 8GB) | €2.50 |
| **[Stage 3](stage3/)** | Single-node HTCondor | 1 VM (4 vCPU, 8GB) | €1.50 |
| **[Stage 4](stage4/)** | Multi-node cluster | 2 VMs (6 vCPU, 12GB) | €3.00 |
| **[Stage 5](stage5/)** | SLURM integration | See production | N/A |

Each stage directory contains:
- `README.md` - Detailed guide
- `main.tf` / `.pkr.hcl` - Infrastructure code
- `test_*.sh` - Automated testing script
- `terraform.tfvars.example` - Configuration template

---

## 🎯 Key Features

### 1. Incremental Testing ✅

Start small, build confidence:
- **Stage 0**: Verify tools and access (10 min, €0)
- **Stage 1**: Test basic provisioning (15 min, €0.50)
- **Stage 2**: Build custom image (45 min, €2.50)
- **Stage 3**: Single-node HTCondor (30 min, €1.50)
- **Stage 4**: Multi-node cluster (45 min, €3.00)

**Total**: ~3 hours, ~€8 to fully validate infrastructure

### 2. Cloud Discovery ☁️

Three tools for understanding your cloud:

```bash
# Quick scan (30s)
./discover_cloud.sh

# Quota check (5s)
./check_quota.sh

# Comprehensive collection (60s)
./collect_cloud_resources.sh
```

**Output**: Detailed reports with HTCondor-specific recommendations

### 3. Scientific Workflows 🔬

Run MESA stellar evolution simulations:
- Parameter grid design (mass × metallicity)
- HTCondor job distribution
- NuDocker container integration
- Result analysis and validation
- Comparison with published data (Pignatari et al. 2016)

### 4. Claude CLI Integration 🤖

Interactive AI assistance:
- Step-by-step guidance
- Configuration generation
- Error troubleshooting
- Result interpretation
- Cluster optimization
- Workflow creation

---

## 💰 Cost & Timeline

### Testing Infrastructure

| Phase | Duration | Cost |
|-------|----------|------|
| **Testing** (Stages 1-4) | 3 hours | ~€8 |
| **Production Setup** | 1-2 weeks | ~€50-200 |

### Scientific Production (MESA)

| Grid Size | Models | Duration | Cost |
|-----------|--------|----------|------|
| **Minimal** | 27 | 2-4 weeks | ~€200-400 |
| **Medium** | 50 | 4-6 weeks | ~€400-800 |
| **Full** | 100 | 6-12 weeks | ~€800-1500 |

*With 5-10 execute nodes (4-8 vCPU each)*

---

## 🛠️ Prerequisites

### Required Tools

- **Terraform** ≥ 1.0
- **Packer** (for custom images)
- **Ansible** ≥ 2.9 (for production)
- **OpenStack CLI** (`python-openstackclient`)
- **SSH client**
- **Git**
- **Python 3**

### Optional but Recommended

- **Claude CLI** - For interactive AI assistance
- **Python virtualenv** - For isolated environment

### Cloud Requirements

- **OpenStack cloud account** (HUN-REN, WIGNER, etc.)
- **Application credentials** or clouds.yaml
- **Sufficient quota**:
  - Minimum (testing): 6 vCPUs, 12 GB RAM
  - Recommended (production): 20+ vCPUs, 48+ GB RAM
- **SSH key pair** uploaded to cloud
- **Network access** (internal + external networks)

---

## 📊 Testing Stages Overview

### Stage 0: Prerequisites Verification ✓
**Goal**: Verify all tools and cloud access
**Time**: 10 minutes | **Cost**: €0
**Script**: `./stage0/verify_prerequisites.sh`

### Stage 1: Basic VM Provisioning ✓
**Goal**: Test Terraform can create VMs
**Time**: 15 minutes | **Cost**: €0.50
**Resources**: 1 VM (2 vCPU, 4GB)
**Script**: `./stage1/test_connectivity.sh`

### Stage 2: Packer Image Build ✓
**Goal**: Build custom image with HTCondor, Docker, Singularity
**Time**: 45 minutes | **Cost**: €2.50
**Resources**: 1 build VM (4 vCPU, 8GB, temporary)
**Script**: `./stage2/verify_image.sh`

### Stage 3: Single-Node HTCondor ✓
**Goal**: Test HTCondor in standalone mode
**Time**: 30 minutes | **Cost**: €1.50
**Resources**: 1 VM (4 vCPU, 8GB)
**Tests**: Vanilla Universe (3 jobs) + Docker Universe (2 jobs)
**Script**: `./stage3/test_htcondor.sh`

### Stage 4: Multi-Node Cluster ✓
**Goal**: Test distributed HTCondor + NFS storage
**Time**: 45 minutes | **Cost**: €3.00
**Resources**: 2 VMs (central + execute, 6 vCPU total)
**Tests**: NFS mounting, distributed jobs, network connectivity
**Script**: `./stage4/test_cluster.sh`

### Stage 5: SLURM Integration →
**Goal**: Add SLURM scheduler for dual-scheduler support
**Note**: Requires Ansible (see production deployment)
**Doc**: [stage5/README.md](stage5/README.md)

---

## 🎓 Use Cases

### Use Case 1: "I want to test infrastructure before production"

**Path**: Testing Stages → Production Deployment

```bash
# 1. Run stages 0-4 sequentially
cd stage0 && ./verify_prerequisites.sh
cd stage1 && terraform apply && ./test_connectivity.sh && terraform destroy
cd stage2 && packer build ... && ./verify_image.sh
cd stage3 && terraform apply && ./test_htcondor.sh && terraform destroy
cd stage4 && terraform apply && ./test_cluster.sh && terraform destroy

# 2. Deploy production (if all passed)
cd ../../terraform && terraform apply
cd ../ansible && ansible-playbook playbooks/site.yml
```

**Outcome**: Validated infrastructure, confident deployment

### Use Case 2: "I want to run MESA simulations"

**Path**: Cloud Discovery → Cluster Design → Scientific Production

```bash
# 1. Collect cloud resources
./collect_cloud_resources.sh

# 2. Get cluster design (share results)

# 3. Deploy cluster (with custom configs)

# 4. Run MESA parameter grid
# Submit HTCondor jobs with MESA models
```

**Outcome**: Scientific data (stellar yields, abundances)

### Use Case 3: "I'm new to HTCondor/cloud/MESA"

**Path**: Claude CLI Interactive Learning

```bash
# 1. Start Claude CLI
claude

# 2. Ask for guidance
"I'm new to HTCondor and cloud computing.
Guide me through setting up a cluster for MESA simulations."

# 3. Follow step-by-step
# Claude generates configs, explains concepts, troubleshoots
```

**Outcome**: Learn while building, faster onboarding

### Use Case 4: "I need cost estimates before committing"

**Path**: Discovery → Analysis → Decision

```bash
# 1. Quick quota check
./check_quota.sh

# 2. Detailed resource collection
./collect_cloud_resources.sh

# 3. Review cost estimates in reports

# 4. Decide on cluster size
```

**Outcome**: Informed decision on resource allocation

---

## 🔧 Troubleshooting

### Quick Fixes

**Authentication Issues**:
```bash
source app-cred-bridge-openrc.sh
openstack token issue
```

**Terraform Failures**:
```bash
# Check configuration matches your cloud
openstack image list | grep ubuntu
openstack network list
openstack flavor list
```

**Packer Build Failures**:
```bash
# Increase timeout
ssh_timeout = "15m"  # in .pkr.hcl
```

**HTCondor Job Issues**:
```bash
# On central manager
condor_status  # Check execute nodes registered
condor_q -better-analyze <job-id>  # Diagnose idle jobs
```

### Get Help

1. **Check stage-specific READMEs** for detailed troubleshooting
2. **Use Claude CLI** for interactive troubleshooting
3. **Review test results** in `results/` directory
4. **Check logs**:
   - Cloud-init: `sudo tail -100 /var/log/cloud-init-output.log`
   - HTCondor: `sudo tail -100 /var/log/condor/*`
5. **Open GitHub issue** with error details

---

## 🤝 Contributing

Contributions welcome! Areas:
- Additional testing stages
- Support for other clouds (AWS, Azure, GCP)
- Enhanced monitoring
- Additional scientific workflows
- Documentation improvements

**To contribute**:
1. Fork repository
2. Create feature branch
3. Add tests
4. Submit pull request

---

## 📞 Support

**NuDocker Project**:
- GitHub: https://github.com/NuGrid/NuDocker

**MESA**:
- Forum: https://lists.mesastar.org
- Website: http://mesa.sourceforge.net

**NuGrid**:
- Website: https://nugrid.github.io
- Data: https://wendi.nugridstars.org

**HTCondor**:
- Documentation: https://htcondor.readthedocs.io
- Support: https://htcondor.org/support

---

## 🌟 Highlights

### For Scientists
- ✅ Reproduce Pignatari et al. (2016) stellar yields
- ✅ Run MESA parameter grids efficiently
- ✅ Containerized, reproducible simulations
- ✅ Automated result extraction and analysis

### For Infrastructure Engineers
- ✅ Incremental testing reduces risk
- ✅ Clear success criteria for each stage
- ✅ Cost tracking and optimization
- ✅ Production-ready after testing

### For Mac Users
- ✅ Claude CLI integration for guidance
- ✅ Works with virtualenv setup
- ✅ Interactive troubleshooting
- ✅ Automated configuration generation

### For Cloud Providers
- ✅ OpenStack-agnostic (works on any cloud)
- ✅ Quota-aware cluster design
- ✅ Cost-optimized deployments
- ✅ Comprehensive resource discovery

---

## 📈 Project Status

### ✅ Completed

- [x] Complete testing framework (Stages 0-5)
- [x] Cloud discovery tools (3 scripts)
- [x] Scientific workflow documentation
- [x] HTCondor + Docker + NFS testing
- [x] Claude CLI integration guide
- [x] Cost and timeline estimates
- [x] Comprehensive troubleshooting

### 🚧 In Progress

- [ ] Stage 6-7 full deployment automation
- [ ] Automated result analysis
- [ ] Monitoring dashboard

### 📅 Planned

- [ ] Multi-cloud support (AWS, Azure, GCP)
- [ ] CI/CD integration
- [ ] Performance benchmarking
- [ ] Web UI for management

---

## 📝 Version

**Version**: 1.0
**Date**: 2025-11-19
**Status**: Production Ready

**Changelog**:
- v1.0 (2025-11-19): Initial release
  - Complete testing framework
  - Cloud discovery tools
  - Scientific workflow integration
  - Claude CLI guide
  - Comprehensive documentation

---

## 📄 License

BSD 3-Clause License - See [LICENSE](../../../LICENSE) file

---

## 🙏 Acknowledgments

**Scientific**:
- NuGrid Collaboration
- MESA Development Team
- Pignatari et al. for published data

**Infrastructure**:
- OpenStack Community
- HTCondor Team (UW-Madison)
- HashiCorp (Terraform, Packer)
- Ansible Community

**Cloud Providers**:
- HUN-REN Science Cloud
- WIGNER Research Centre

**AI**:
- Anthropic (Claude CLI)

---

## 🔗 Related Projects

- **NuDocker**: https://github.com/NuGrid/NuDocker
- **MESA**: http://mesa.sourceforge.net
- **NuGrid**: https://nugrid.github.io
- **HTCondor**: https://htcondor.org

---

## ⚡ Quick Commands Reference

```bash
# Prerequisites
cd stage0 && ./verify_prerequisites.sh

# Cloud discovery
./discover_cloud.sh              # Quick (30s)
./check_quota.sh                 # Fast (5s)
./collect_cloud_resources.sh     # Comprehensive (60s)

# Testing stages
cd stage1 && terraform apply && ./test_connectivity.sh && terraform destroy
cd stage2 && packer build nudocker-test.pkr.hcl && ./verify_image.sh
cd stage3 && terraform apply && ./test_htcondor.sh && terraform destroy
cd stage4 && terraform apply && ./test_cluster.sh && terraform destroy

# Production (after testing)
cd ../../terraform && terraform apply
cd ../ansible && ansible-playbook playbooks/site.yml

# With Claude CLI
claude
"Guide me through testing NuDocker infrastructure"
```

---

## 📍 Directory Structure

```
infrastructure/testing/
│
├── README.md                              # This file
├── README_MASTER.md                       # Complete overview
├── CLAUDE_CLI_GUIDE.md                    # Claude CLI integration ⭐
├── QUICKSTART_FOR_PIGNATARI.md            # Scientific quick start
├── CLOUD_SETUP_GUIDE.md                   # OpenStack setup
├── ITERATIVE_TESTING_PLAN.md              # Testing methodology
├── PIGNATARI_REPRODUCTION_GUIDE.md        # Scientific background
│
├── discover_cloud.sh                      # Quick scanner
├── check_quota.sh                         # Quota checker
├── collect_cloud_resources.sh             # Resource collector
│
├── stage0/                                # Prerequisites
├── stage1/                                # Basic VM
├── stage2/                                # Packer image
├── stage3/                                # Single-node HTCondor
├── stage4/                                # Multi-node cluster
├── stage5/                                # SLURM guide
│
└── results/                               # Test results (generated)
```

---

## 🎯 Getting Started Checklist

- [ ] Clone repository
- [ ] Choose your guide (Claude CLI / Quick Start / Full Plan)
- [ ] Install prerequisites (Terraform, Packer, OpenStack CLI)
- [ ] Set up cloud authentication
- [ ] Run Stage 0 verification
- [ ] Collect cloud resources
- [ ] Review recommendations
- [ ] Start testing or deploy production

---

## 💡 Tips

### For Best Results
1. **Don't skip stages** - Each validates previous work
2. **Review test results** - Check `results/` directory after each stage
3. **Use Claude CLI** - Get interactive help when stuck
4. **Start small** - Test with minimal resources first
5. **Read stage READMEs** - Detailed info and troubleshooting

### For Scientists
- Focus on QUICKSTART_FOR_PIGNATARI.md
- Let infrastructure team handle deployment
- Concentrate on MESA inlists and parameter grids

### For Infrastructure
- Complete all testing stages before production
- Document your cloud-specific settings
- Use discovery tools to optimize cluster design

### For Mac + Claude CLI Users
- Follow CLAUDE_CLI_GUIDE.md for best experience
- Ask Claude to generate configs
- Use Claude for real-time troubleshooting

---

**Ready to start?**

→ **Mac + Claude CLI**: [CLAUDE_CLI_GUIDE.md](CLAUDE_CLI_GUIDE.md)
→ **Scientists**: [QUICKSTART_FOR_PIGNATARI.md](QUICKSTART_FOR_PIGNATARI.md)
→ **Infrastructure**: [ITERATIVE_TESTING_PLAN.md](ITERATIVE_TESTING_PLAN.md)
→ **Complete Overview**: [README_MASTER.md](README_MASTER.md)

---

*Last updated: 2025-11-19*
*Maintained by: NuDocker Testing Infrastructure Team*
*Repository: https://github.com/gyorgy-mezo/NuDocker*
