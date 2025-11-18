# NuDocker HTCondor + SLURM Infrastructure as Code

Complete Infrastructure-as-Code (IaC) solution for deploying NuDocker with dual-scheduler support (HTCondor + SLURM) on HUN-REN Science Cloud.

---

## Quick Start

### Prerequisites

- Terraform >= 1.0
- Packer >= 1.8
- Ansible >= 2.12
- SSH key at `~/.ssh/id_rsa`
- HUN-REN Cloud credentials

### 3-Step Deployment

```bash
# 1. Configure credentials
cd packer
cp variables.pkrvars.hcl.example variables.pkrvars.hcl
vim variables.pkrvars.hcl  # Fill in your HUN-REN credentials

cd ../terraform
cp terraform.tfvars.example terraform.tfvars
vim terraform.tfvars  # Fill in your HUN-REN credentials and image name

# 2. Deploy everything
cd ..
./deploy.sh all

# 3. Access your cluster
# (IP will be shown at end of deployment)
ssh -i ~/.ssh/id_rsa ubuntu@<FLOATING_IP>
```

### Manual Step-by-Step

```bash
# Build base image (30-45 min)
./deploy.sh packer

# Provision infrastructure (10-15 min)
./deploy.sh terraform

# Configure cluster (20-30 min)
./deploy.sh ansible

# Verify
./deploy.sh verify
```

---

## What Gets Deployed

### Infrastructure (Terraform)

- **1 Central Manager**: 8 vCPU, 16 GB RAM (collector + negotiator + schedd + NFS)
- **5 Execute Nodes**: 40 vCPU, 160 GB RAM total (compute workers)
- **Private Network**: 10.0.0.0/24
- **Shared Storage**: 500 GB NFS volume
- **Floating IP**: Public access to central manager

**Total Resources**: 48 vCPU, 176 GB RAM, 500 GB storage
**Efficiency**: 67% of 72 vCPU / 192 GB allocation

### Software Stack (Packer)

- Ubuntu 20.04 LTS
- **HTCondor 23.10** (distributed computing scheduler)
- **SLURM 23.02** (HPC workload manager)
- Docker 24.0 (for HTCondor Docker Universe)
- Singularity/Apptainer 3.11.4 (for SLURM compatibility)
- NFS client/server
- MESA dependencies (compilers, libraries, MPI)
- Python 3 with scientific packages

### Configuration (Ansible)

- **HTCondor pool** with password authentication
- **SLURM cluster** with munge authentication
- NFS shared storage mounted at `/storage`
- Docker and Singularity images pre-loaded
- NuDocker batch scripts deployed (HTCondor and SLURM)
- Environment configured for MESA runs
- Dual-scheduler support: choose HTCondor or SLURM per workload

---

## Directory Structure

```
infrastructure/
├── deploy.sh                # Main deployment script
├── destroy.sh              # Cleanup script
├── DEPLOYMENT_GUIDE.md     # Complete deployment documentation
├── README.md               # This file
│
├── packer/                 # VM image building
│   ├── nudocker-htcondor.pkr.hcl    # Packer template
│   ├── variables.pkrvars.hcl.example # Configuration example
│   ├── scripts/            # Provisioning scripts
│   │   ├── install-docker.sh
│   │   ├── install-singularity.sh
│   │   ├── install-htcondor.sh
│   │   ├── install-slurm.sh
│   │   ├── install-nudocker-deps.sh
│   │   ├── configure-system.sh
│   │   ├── apply-configs.sh
│   │   └── cleanup.sh
│   └── files/              # Configuration files
│       ├── bash_aliases
│       └── htcondor_base.conf
│
├── terraform/              # Infrastructure provisioning
│   ├── main.tf            # Main infrastructure definition
│   ├── variables.tf       # Variable declarations
│   ├── versions.tf        # Provider versions
│   ├── terraform.tfvars.example  # Configuration example
│   └── cloud-init/        # Instance initialization
│       ├── central-manager.yaml
│       └── execute-node.yaml
│
└── ansible/               # Cluster configuration
    ├── ansible.cfg        # Ansible configuration
    ├── requirements.yml   # Galaxy dependencies
    ├── inventory/
    │   └── hosts.ini     # Inventory template
    ├── playbooks/
    │   ├── site.yml      # Main playbook
    │   └── group_vars/
    │       └── all.yml   # Global variables
    └── roles/
        ├── common/           # Common configuration (all nodes)
        ├── htcondor-central/ # HTCondor central manager setup
        ├── htcondor-execute/ # HTCondor execute node setup
        ├── slurm-controller/ # SLURM controller setup
        ├── slurm-compute/    # SLURM compute node setup
        ├── nudocker/         # NuDocker deployment
        └── cluster-verify/   # Health verification
```

---

## Usage Examples

### Submitting HTCondor Jobs

**Single MESA model**:
```bash
ssh ubuntu@<FLOATING_IP>

cd /storage/htcondor_jobs
cat > mesa_test.sub <<EOF
universe = docker
docker_image = nugrid/nudome:16.0
executable = /bin/echo
arguments = "Hello from NuDocker HTCondor"
output = test.out
error = test.err
log = test.log
request_cpus = 1
request_memory = 1GB
queue
EOF

condor_submit mesa_test.sub
condor_q
```

**Parameter study (54 models)**:
```bash
cd /storage/batch_examples/htcondor
condor_submit_dag nugrid_study.dag
watch -n 30 condor_q
```

### Submitting SLURM Jobs

**Single MESA model**:
```bash
ssh ubuntu@<FLOATING_IP>

cd /storage/batch_examples/slurm
sbatch 01_single_mesa_run.slurm
squeue
```

**Job array (parameter sweep)**:
```bash
cd /storage/batch_examples/slurm
python3 generate_parameter_grid.py > /storage/config/parameter_grid.txt
sbatch 02_array_mesa_run.slurm
squeue -u $USER
```

**Large grid (100+ models)**:
```bash
cd /storage/batch_examples/slurm
sbatch 04_large_grid.slurm
watch -n 30 squeue
```

### Monitoring Cluster

**HTCondor**:
```bash
# Pool status
condor_status

# Total resources
condor_status -total

# Job queue
condor_q

# Detailed job info
condor_q -better-analyze <JOB_ID>

# Storage usage
df -h /storage
```

**SLURM**:
```bash
# Cluster status
sinfo

# Node details
sinfo -Nel

# Job queue
squeue

# Your jobs
squeue -u $USER

# Job details
scontrol show job <JOB_ID>

# Partition info
scontrol show partition

# Account usage (if accounting enabled)
sacct -u $USER

# Storage usage
df -h /storage
```

---

## Configuration Files

### Packer Variables (`packer/variables.pkrvars.hcl`)

```hcl
openstack_project_name = "your-project-name"
openstack_username     = "your-username"
openstack_password     = "your-password"
source_image_name      = "Ubuntu-20.04"
```

### Terraform Variables (`terraform/terraform.tfvars`)

```hcl
openstack_project_name = "your-project-name"
openstack_username     = "your-username"
openstack_password     = "your-password"

central_manager_image  = "nudocker-htcondor-base-YYYYMMDD-HHMM"  # From Packer
execute_node_image     = "nudocker-htcondor-base-YYYYMMDD-HHMM"  # Same image

htcondor_pool_password = "STRONG-PASSWORD-32-CHARS-MIN"

execute_node_count     = 5
shared_storage_size    = 500
```

### Ansible Variables (`ansible/playbooks/group_vars/all.yml`)

```yaml
condor_host: "10.0.0.10"
cluster_name: "nudocker-htcondor"
htcondor_pool_password: "{{ lookup('env', 'HTCONDOR_POOL_PASSWORD') }}"
```

**Set before running Ansible**:
```bash
export HTCONDOR_POOL_PASSWORD="your-password-from-terraform-tfvars"
```

---

## Troubleshooting

### Packer Build Fails

**Check**:
- OpenStack credentials correct
- Base image exists: `openstack image list | grep Ubuntu-20.04`
- Network allows outbound traffic
- Flavor `m2.large` available

**Solution**:
```bash
# Verify connectivity
openstack server list

# Check Packer logs
packer build -debug -var-file=variables.pkrvars.hcl nudocker-htcondor.pkr.hcl
```

### Terraform Apply Fails

**Common Issues**:
- Image name mismatch (use exact name from Packer build)
- Quota exceeded
- Network name incorrect

**Solution**:
```bash
# Check quota
openstack quota show

# Verify image exists
openstack image list | grep nudocker

# Check network
openstack network list
```

### Ansible Can't Connect

**Check**:
- Floating IP assigned: `terraform output`
- Security group allows SSH from your IP
- SSH key correct: `ssh -i ~/.ssh/id_rsa ubuntu@<IP>`

**Solution**:
```bash
# Test connectivity
ansible central_manager -m ping

# Verbose mode
ansible-playbook site.yml -vvv
```

### HTCondor Nodes Not Showing

**Check on central manager**:
```bash
ssh ubuntu@<FLOATING_IP>

# Check HTCondor status
sudo systemctl status condor

# Check logs
sudo journalctl -u condor -n 100

# Check network
ping execute-01
```

**Solution**:
```bash
# Restart HTCondor on all nodes
ansible all -a "systemctl restart condor" --become
```

---

## Maintenance

### Updating Software

```bash
# Update all nodes
ansible all -a "apt-get update" --become
ansible all -a "apt-get upgrade -y" --become

# Restart HTCondor
ansible all -a "systemctl restart condor" --become
```

### Scaling Execute Nodes

```bash
# Edit terraform.tfvars
vim terraform/terraform.tfvars
# Change: execute_node_count = 7

cd terraform
terraform plan
terraform apply

# Configure new nodes
cd ../ansible
ansible-playbook playbooks/site.yml --limit execute_nodes
```

### Backup Data

```bash
# On central manager
ssh ubuntu@<FLOATING_IP>

cd /storage
tar czf ~/backup-$(date +%Y%m%d).tar.gz \
  --exclude='containers/*.sif' \
  mesa/ results/ users/

# Copy to local
scp ubuntu@<FLOATING_IP>:~/backup-*.tar.gz ./
```

---

## Cleanup

### Destroy Everything

```bash
./destroy.sh
# Type 'yes' to confirm
```

### Keep Images for Redeployment

```bash
./destroy.sh --keep-images
```

### Preserve Data Volume

```bash
./destroy.sh --keep-volume --keep-images
# Data can be reattached to new deployment later
```

---

## Cost Estimate

| Component | Monthly Cost |
|-----------|--------------|
| Central Manager (8 vCPU, 16 GB) | €60 |
| Execute Nodes (40 vCPU, 160 GB) | €200 |
| Storage (500 GB) | €20 |
| Network/IP | €5 |
| **Total** | **~€285/month** |

**Per-job cost**: ~€2.63 per MESA model (based on 54-model study)

---

## Performance

**Expected Throughput** (5 execute nodes):

- **Low-mass models** (1-2 M☉): 4-6 hours each
- **Medium-mass models** (5-10 M☉): 12-18 hours each
- **High-mass models** (15-20 M☉): 24-48 hours each

**54-model NuGrid study**: 14-21 days total

---

## Documentation

- **DEPLOYMENT_GUIDE.md**: Complete step-by-step deployment
- **README.md**: This quick reference
- **Terraform docs**: `terraform/README.md` (auto-generated)
- **Ansible docs**: `ansible/README.md` (auto-generated)

---

## Support

**NuDocker**:
- GitHub: https://github.com/NuGrid/NuDocker

**HTCondor**:
- Documentation: https://htcondor.readthedocs.io/

**HUN-REN Cloud**:
- Docs: https://docs.slurm.science-cloud.hu/

---

## License

BSD 3-Clause License (same as NuDocker project)

---

**Quick Command Reference**:

```bash
# Deploy
./deploy.sh all                          # Complete deployment
./deploy.sh packer                       # Build images only
./deploy.sh terraform                    # Provision only
./deploy.sh ansible                      # Configure only

# Manage
ansible-playbook ansible/playbooks/site.yml --tags verify   # Health check
terraform output                         # Show cluster info
ssh ubuntu@$(terraform output -raw central_manager_floating_ip)  # Connect

# Cleanup
./destroy.sh                             # Remove everything
./destroy.sh --keep-images               # Keep images
./destroy.sh --keep-volume --keep-images # Keep images and data
```

---

**Ready to deploy?** Run `./deploy.sh all` and follow the prompts!
