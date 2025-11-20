# NuDocker HTCondor Cluster Testing & Deployment System
**Complete infrastructure for deploying optimized HTCondor clusters on HUN-REN Cloud for MESA stellar evolution simulations**
[![License](https://img.shields.io/badge/License-BSD%203--Clause-blue.svg)](../../../LICENSE)
[![Platform](https://img.shields.io/badge/Platform-OpenStack-red.svg)](https://www.openstack.org/)
[![Purpose](https://img.shields.io/badge/Purpose-Reproducible%20Science-green.svg)](https://reproducibility.org/)
---
## 🎯 Purpose
This system enables researchers to:
1. **Test and validate** cloud infrastructure incrementally before production deployment
2. **Deploy optimized HTCondor clusters** on OpenStack clouds (HUN-REN, WIGNER, etc.)
3. **Run NuDocker containerized MESA simulations** for stellar astrophysics research
4. **Reproduce published results** (e.g., Pignatari et al. 2016 nucleosynthesis studies)
**Key Features**:
- ✅ Incremental testing approach (8 stages from prerequisites to production)
- ✅ Cloud resource discovery and optimization
- ✅ Automated testing with pass/fail criteria

- ✅ Scientific workflow integration (MESA/NuGrid)
- ✅ Complete documentation for each step
---
## 📚 Documentation Structure
This directory contains three complementary systems:
### 1. 🧪 Iterative Testing Framework
**Purpose**: Validate infrastructure before production deployment
| Document | Description |
|----------|-------------|
| [README.md](README.md) | This file - overview and quick start |
| [ITERATIVE_TESTING_PLAN.md](ITERATIVE_TESTING_PLAN.md) | Detailed testing methodology |
| [Stage 0-5 READMEs](stage0/README.md) | Step-by-step guides for each stage |
### 2. ☁️ Cloud Resource Discovery
**Purpose**: Understand your cloud environment and capabilities
| Tool | Description |
|------|-------------|
| [CLOUD_SETUP_GUIDE.md](CLOUD_SETUP_GUIDE.md) | Setup guide for app-cred-bridge-openrc.sh users |
| [discover_cloud.sh](discover_cloud.sh) | Quick cloud environment scan (~30 seconds) |
| [check_quota.sh](check_quota.sh) | Fast quota verification for testing stages |
| [collect_cloud_resources.sh](collect_cloud_resources.sh) | Comprehensive resource collection (~60 seconds) |
### 3. 🔬 Scientific Workflow (Pignatari Reproduction)
**Purpose**: Run MESA simulations for nucleosynthesis research
| Document | Description |
|----------|-------------|
| [QUICKSTART_FOR_PIGNATARI.md](QUICKSTART_FOR_PIGNATARI.md) | Quick start guide for scientific users |
| [PIGNATARI_REPRODUCTION_GUIDE.md](PIGNATARI_REPRODUCTION_GUIDE.md) | Complete scientific workflow documentation |
---
## 🚀 Quick Start
### For First-Time Users
**Step 1: Understand Your Goal**
Choose your path:
- **Path A: Just Testing Infrastructure** → Follow testing stages 0-4
- **Path B: Quick MESA Test Run** → Follow QUICKSTART_FOR_PIGNATARI.md
- **Path C: Full Scientific Production** → Complete all documentation
**Step 2: Set Up Your Environment**
```bash
# Clone repository
git clone https://github.com/gyorgy-mezo/NuDocker.git
cd NuDocker/infrastructure/testing
# Activate Python virtualenv (if you have one)
source ~/path/to/your-venv/bin/activate
# Or install OpenStack CLI globally
pip install python-openstackclient
# Authenticate with your cloud
source app-cred-bridge-openrc.sh
# Or: export environment variables from clouds.yaml
```
**Step 3: Discover Your Cloud Resources**
```bash
# Quick scan (30 seconds)
./discover_cloud.sh
# Or comprehensive collection (60 seconds)
./collect_cloud_resources.sh
```
**Step 4: Start Testing**
```bash
# Verify prerequisites
cd stage0
./verify_prerequisites.sh
# If all pass, proceed to Stage 1
cd ../stage1
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
terraform init && terraform apply
./test_connectivity.sh
```
---
## 📊 System Components
### Testing Stages
Incremental validation from simple to complex:
 | Stage | What It Tests | Duration | Resources | 
 | ------- | --------------- | ---------- | ----------- | 
 | **Stage 0** | Prerequisites & cloud access | 10 min | Local only | 
 | **Stage 1** | Basic VM provisioning | 15 min | 1 VM (2 vCPU, 4GB) | 
 | **Stage 2** | Packer image build | 45 min | 1 VM (4 vCPU, 8GB, temp) | 
 | **Stage 3** | Single-node HTCondor | 30 min | 1 VM (4 vCPU, 8GB) | 
 | **Stage 4** | Multi-node cluster + NFS | 45 min | 2 VMs (6 vCPU, 12GB) | 
 | **Stage 5** | SLURM integration | N/A | See Stage 6-7 | 
 | **Stage 6** | Scaled cluster | 60 min | 3 VMs (10 vCPU, 20GB) | 
 | **Stage 7** | Production deployment | 90 min | 6 VMs (20 vCPU, 48GB) | 
### Cloud Discovery Tools
 | Tool | Purpose | Duration | 
 | ------ | --------- | ---------- | 
 | `discover_cloud.sh` | Quick environment scan | 30 sec | 
 | `check_quota.sh` | Quota verification | 5 sec | 
 | `collect_cloud_resources.sh` | Comprehensive inventory | 60 sec | 
### Scientific Workflow Components
For MESA stellar evolution simulations:
- **Parameter Grid Design**: Mass × Metallicity variations
- **HTCondor Job Submission**: Distributed computing workflow
- **NuDocker Integration**: Containerized MESA execution
- **Result Analysis**: Yield extraction and comparison
- **Validation**: Against published NuGrid data
---
## 📁 Directory Structure
```
infrastructure/testing/
│
├── README.md                              # This file - master overview
├── ITERATIVE_TESTING_PLAN.md              # Detailed testing methodology
├── CLOUD_SETUP_GUIDE.md                   # OpenStack setup for OpenRC users
├── QUICKSTART_FOR_PIGNATARI.md            # Quick start for scientists
├── PIGNATARI_REPRODUCTION_GUIDE.md        # Scientific workflow guide
│
├── discover_cloud.sh                      # Quick cloud scan
├── check_quota.sh                         # Quota checker
├── collect_cloud_resources.sh             # Complete resource collector
│
├── stage0/                                # Prerequisites verification
│   ├── README.md
│   └── verify_prerequisites.sh
│
├── stage1/                                # Basic VM provisioning test
│   ├── README.md
│   ├── main.tf
│   ├── variables.tf
│   ├── terraform.tfvars.example
│   └── test_connectivity.sh
│
├── stage2/                                # Packer image build
│   ├── README.md
│   ├── nudocker-test.pkr.hcl
│   ├── variables.pkrvars.hcl.example
│   └── verify_image.sh
│
├── stage3/                                # Single-node HTCondor
│   ├── README.md
│   ├── main.tf
│   ├── variables.tf
│   ├── terraform.tfvars.example
│   └── test_htcondor.sh
│
├── stage4/                                # Multi-node cluster
│   ├── README.md
│   ├── main.tf
│   ├── variables.tf
│   ├── terraform.tfvars.example
│   └── test_cluster.sh
│
├── stage5/                                # SLURM integration guide
│   └── README.md
│
└── results/                               # Test results (auto-generated)
    ├── stage0_results_YYYYMMDD_HHMMSS.txt
    ├── stage1_results_YYYYMMDD_HHMMSS.txt
    └── ...
```
---
## 🎯 Use Cases
## 📈 Timeline Estimates
### Infrastructure Setup
- **Testing (Stages 1-4)**: 1 day
- **Production cluster deployment**: 1-2 weeks (including validation)
- **Total setup time**: 1-3 weeks (depends on experience level)
### Scientific Production (Pignatari Reproduction)
- **Single test model**: 1-2 days
- **Minimal grid (27 models)**: 2-4 weeks with 5-10 execute nodes
- **Full grid (100 models)**: 6-12 weeks with 10-20 execute nodes
- **Analysis and validation**: 1-2 weeks
**Total project timeline**: 2-4 months for complete scientific reproduction
---
## 🎓 Learning Path
### For Cloud/Infrastructure Engineers
1. Read [ITERATIVE_TESTING_PLAN.md](ITERATIVE_TESTING_PLAN.md)
2. Run `discover_cloud.sh` and review results
3. Complete testing stages 0-4 sequentially
4. Study stage-specific READMEs for troubleshooting
5. Deploy production cluster using main infrastructure
### For Scientific Users (Astrophysicists)
1. Read [QUICKSTART_FOR_PIGNATARI.md](QUICKSTART_FOR_PIGNATARI.md)
2. Read [PIGNATARI_REPRODUCTION_GUIDE.md](PIGNATARI_REPRODUCTION_GUIDE.md)
3. Run `collect_cloud_resources.sh`
4. Get optimized cluster design (contact infrastructure team or use discovery reports)
5. Focus on MESA inlists and parameter grids
6. Let infrastructure handle HTCondor/cloud deployment
### For Both
- Start with Stage 0 prerequisites verification
- Don't skip stages (each validates previous work)
- Review test results carefully before proceeding
- Use troubleshooting sections in stage READMEs
---
## 🐛 Troubleshooting
### Common Issues
**Issue: `openstack: command not found`**
```bash
# Solution: Install OpenStack CLI
pip install python-openstackclient
```
**Issue: Authentication fails**
```bash
# Solution: Re-source OpenRC file
source app-cred-bridge-openrc.sh
openstack token issue
```
**Issue: Insufficient quota**
```bash
# Solution 1: Delete unused resources
openstack server list
openstack server delete <vm-name>
# Solution 2: Request quota increase from cloud provider
```
**Issue: Terraform provisioning fails**
```bash
# Solution: Check terraform.tfvars values
# Ensure image_name, network_name, etc. match your cloud
openstack image list
openstack network list
```
**Issue: HTCondor jobs stay idle**
```bash
# Solution: Check execute node registration
ssh ubuntu@<central-manager-ip>
condor_status
condor_q -better-analyze <job-id>
```
### Getting Help
1. **Check stage-specific README troubleshooting sections**
2. **Review test result files** in `results/` directory
3. **Check cloud-init logs**: `sudo tail -100 /var/log/cloud-init-output.log`
4. **HTCondor logs**: `sudo tail -100 /var/log/condor/*`
5. **Open GitHub issue** with error details and test results
---
## 📞 Support and Contact
**For NuDocker project issues**:
- GitHub: https://github.com/NuGrid/NuDocker/issues
**For HUN-REN cloud issues**:
- Contact HUN-REN cloud support
**For MESA questions**:
- MESA forum: https://lists.mesastar.org
- MESA website: http://mesa.sourceforge.net
**For NuGrid scientific questions**:
- NuGrid website: https://nugrid.github.io
- WENDI data browser: https://wendi.nugridstars.org
---
## 🤝 Contributing
Contributions welcome! Areas for improvement:
- Additional testing stages
- Support for other clouds (AWS, Azure, GCP)
- Enhanced monitoring and logging
- Performance optimization scripts
- Additional scientific workflows
- Documentation improvements
**To contribute**:
1. Fork the repository
2. Create feature branch
3. Add tests for new features
4. Submit pull request with clear description
---
## 📄 License
This project is licensed under the BSD 3-Clause License - see the [LICENSE](../../../LICENSE) file for details.
---
## 🙏 Acknowledgments
**NuGrid Collaboration**:
- MESA development team
- NuGrid stellar yields data providers
- Pignatari et al. for published nucleosynthesis data
**Infrastructure**:
- OpenStack community
- HTCondor developers (UW-Madison)
- Terraform and Packer (HashiCorp)
- Ansible community
**Cloud Providers**:
- HUN-REN Science Cloud
- WIGNER Research Centre for Physics
---
## 📊 Project Status
### Completed ✅
- [x] Iterative testing framework (Stages 0-5)
- [x] Cloud discovery and resource collection tools
- [x] Comprehensive documentation for all stages
- [x] HTCondor cluster testing (single and multi-node)
- [x] NFS shared storage testing
- [x] Docker Universe testing
- [x] Scientific workflow documentation (Pignatari)

### In Progress 🚧
- [ ] Stage 6-7 full deployment testing
- [ ] SLURM integration automation
- [ ] Automated result analysis scripts
- [ ] Monitoring dashboard

### Planned 📅
- [ ] Multi-cloud support (AWS, Azure, GCP)
- [ ] GitLab CI/CD integration
- [ ] Automated cluster scaling
- [ ] Performance benchmarking suite
- [ ] Web UI for resource management
---
## 🔗 Related Projects
- **NuDocker**: https://github.com/NuGrid/NuDocker
- **MESA**: http://mesa.sourceforge.net
- **NuGrid**: https://nugrid.github.io
- **HTCondor**: https://htcondor.org
- **OpenStack**: https://www.openstack.org
---
## 📚 References
**Scientific Publications**:
- Pignatari et al. (2016), ApJS, 225, 24 - "NuGrid Stellar Data Set. I."
- Paxton et al. (2011, 2013, 2015, 2018, 2019) - MESA instrument papers
**Technical Documentation**:
- OpenStack Documentation: https://docs.openstack.org
- HTCondor Manual: https://htcondor.readthedocs.io
- Terraform Documentation: https://www.terraform.io/docs
- Ansible Documentation: https://docs.ansible.com
---
## 📝 Version History
- **v1.0** (2025-11-19): Initial release
  - Complete testing framework (Stages 0-5)
  - Cloud discovery tools
  - Pignatari reproduction documentation
  - HTCondor + NFS + Docker testing
  - Comprehensive guides and troubleshooting
---
## ⚡ Quick Reference
```bash
# Prerequisites check
cd stage0 && ./verify_prerequisites.sh
# Cloud discovery
./discover_cloud.sh                  # Quick (30s)
./check_quota.sh                     # Fast quota check (5s)
./collect_cloud_resources.sh         # Comprehensive (60s)
# Testing stages
cd stage1 && terraform apply && ./test_connectivity.sh && terraform destroy
cd stage2 && packer build nudocker-test.pkr.hcl && ./verify_image.sh
cd stage3 && terraform apply && ./test_htcondor.sh && terraform destroy
cd stage4 && terraform apply && ./test_cluster.sh && terraform destroy
# Production deployment (after testing)
cd ../../terraform && terraform apply
cd ../ansible && ansible-playbook playbooks/site.yml
```
---
**Ready to start?** → Begin with [CLOUD_SETUP_GUIDE.md](CLOUD_SETUP_GUIDE.md) or [QUICKSTART_FOR_PIGNATARI.md](QUICKSTART_FOR_PIGNATARI.md)
**Questions?** → Open an issue or check the troubleshooting sections
**Contribute?** → Fork, improve, submit PR
---
*Last updated: 2025-11-19*
*Authors: Claude AI + NuGrid Collaboration*
*Maintained by: NuDocker project contributors*