# Quick Start: Pignatari Article Reproduction on HUN-REN Cloud

**Goal**: Set up HTCondor cluster on HUN-REN cloud optimized for running NuDocker/MESA simulations

---

## 🎯 Your Goal

Run MESA stellar evolution models to reproduce nucleosynthesis calculations from **Pignatari et al. (2016)** paper on s-process element production in AGB stars.

**What you'll build**:
- HTCondor distributed computing cluster
- Custom VM image with MESA + dependencies
- Parameter grid workflow (varying stellar mass and metallicity)
- Data analysis pipeline

---

## 📋 Prerequisites Checklist

Before starting, ensure you have:

- [ ] Mac Air with Python virtual environment (`infraprog`)
- [ ] `python-openstackclient` installed in virtualenv
- [ ] `app-cred-bridge-openrc.sh` from HUN-REN dashboard
- [ ] OpenStack CLI working (`openstack flavor list` succeeds)
- [ ] SSH key pair generated
- [ ] NuDocker repository cloned

---

## 🚀 Step-by-Step Process

### Step 1: Collect Your Cloud Resources (15 minutes)

This discovers what resources you have available and what you can build.

```bash
# On your Mac Air
cd /path/to/NuDocker/infrastructure/testing

# Activate Python environment
source ~/path/to/infraprog/bin/activate

# Authenticate with HUN-REN cloud
source app-cred-bridge-openrc.sh
# Enter your password/secret when prompted

# Run comprehensive resource collection
chmod +x collect_cloud_resources.sh
./collect_cloud_resources.sh
```

**What this does**:
- Scans all your HUN-REN cloud project resources
- Collects quotas, flavors, images, networks
- Analyzes what cluster configurations are possible
- Estimates costs and timelines
- Creates directory: `cloud_resources_YYYYMMDD_HHMMSS/`
- Creates archive: `cloud_resources_YYYYMMDD_HHMMSS.tar.gz`

**Output**: ~15-20 files with complete resource inventory

### Step 2: Share Your Cloud Resources with Me

Choose one method:

**Method A: Upload Archive (Recommended)**
```bash
# Upload this file in your next message:
ls -lh cloud_resources_*.tar.gz
```

**Method B: Share Key Files**
```bash
# Share these specific files:
cd cloud_resources_*/
cat 00_SUMMARY_AND_RECOMMENDATIONS.txt
cat 02_quota_analysis.txt
cat 04_flavor_recommendations.txt
cat 10_storage_analysis.txt
```

**Method C: Just Tell Me**
Tell me:
- How many vCPUs you have available
- How much RAM quota you have
- Which flavors you want to use (from `openstack flavor list`)
- Your goal: minimal testing or full production grid

### Step 3: I Will Design Your Cluster

Based on your resources, I'll create:

**✅ Optimized Cluster Design**
- Number of nodes (central manager + execute nodes)
- Flavor selection for each node
- Storage configuration
- Network setup
- Cost estimates

**✅ Custom Configuration Files**
- `terraform.tfvars` for each testing stage
- MESA inlist templates for parameter grid
- HTCondor submit files for job distribution
- Ansible inventory (for production deployment)

**✅ Scientific Workflow**
- Parameter grid definition (mass × metallicity)
- Job submission strategy
- Resource allocation per job
- Timeline estimates

**✅ Analysis Pipeline**
- Scripts to extract yields from MESA output
- Comparison with Pignatari et al. (2016) data
- Plotting and visualization

### Step 4: Deploy Infrastructure (1-2 weeks)

We'll proceed through testing stages:

**Stage 0: Prerequisites** (10 min)
```bash
cd stage0
./verify_prerequisites.sh
```

**Stage 1: Basic VM** (15 min)
- Test Terraform provisioning
- Verify networking
- **Cost**: ~€0.50

**Stage 2: Custom Image** (45 min)
- Build Packer image with HTCondor + MESA dependencies
- **Cost**: ~€2.50
- **Result**: Reusable VM image (~4 GB)

**Stage 3: Single-Node HTCondor** (30 min)
- Test HTCondor standalone
- Run test MESA model
- **Cost**: ~€1.50

**Stage 4: Multi-Node Cluster** (45 min)
- Deploy 2-node cluster (central + 1 execute)
- Test distributed job submission
- **Cost**: ~€3.00

**Total Testing Cost**: ~€7.50

### Step 5: Run Test MESA Model (1-2 days)

Before running full grid, validate with single model:

**Test Model**: 1.5 M☉, Z=0.02 (solar metallicity)
- **Why**: Well-studied, matches NuGrid reference
- **Duration**: 6-12 hours
- **Resource**: 4 cores, 8 GB RAM
- **Output**: ~2 GB

**Validation**:
- Compare with NuGrid MESA output
- Check stellar properties (luminosity, Teff)
- Verify thermal pulses occur
- Check s-process enhancements

### Step 6: Scale to Production Cluster (1 week)

Deploy full cluster based on your quota:

**Example**: If you have 50 vCPUs available:
- 1 Central Manager: m2.large (4 vCPU, 8 GB)
- 10 Execute Nodes: m2.large (4 vCPU, 8 GB each)
- **Total**: 44 vCPU, 88 GB RAM
- **Capability**: Run 10 MESA models simultaneously

**Deploy with Ansible**:
```bash
cd /path/to/NuDocker/infrastructure
# Use full Ansible deployment (not testing stages)
terraform apply
ansible-playbook ansible/playbooks/site.yml
```

### Step 7: Run Parameter Grid (2-8 weeks)

Submit jobs for full parameter grid:

**Minimal Grid**: 27 models
- 9 masses × 3 metallicities
- **Duration**: 2-4 weeks (with 10 execute nodes)
- **Storage**: ~50-500 GB
- **Cost**: ~€200-400 total

**Full NuGrid Grid**: ~100 models
- **Duration**: 6-12 weeks
- **Storage**: ~200-2000 GB
- **Cost**: ~€500-1500 total

**HTCondor Submission**:
```bash
# On central manager
cd /storage/mesa_grid
condor_submit pignatari_grid.sub
condor_q  # Monitor jobs
condor_watch_q  # Watch in real-time
```

### Step 8: Analyze Results (1-2 weeks)

Extract yields and compare with Pignatari et al.:

```bash
# Extract final abundances
python extract_yields.py results/

# Compare with published data
python compare_with_pignatari.py yields.dat

# Generate plots
python plot_yields.py --mass-range 1-8 --elements sr,ba,pb
```

**Expected Outputs**:
- Yield tables (CSV/FITS format)
- HRD (Hertzsprung-Russell Diagram)
- s-process abundance patterns
- Comparison plots with observations

---

## 📊 Resource Requirements Summary

### For Testing (Stages 1-4)
- **vCPUs**: 6 (peak)
- **RAM**: 12 GB (peak)
- **Storage**: ~50 GB
- **Floating IPs**: 1
- **Duration**: 1 day
- **Cost**: ~€7.50

### For Minimal Science Run (27 models)
- **vCPUs**: 20-40
- **RAM**: 40-80 GB
- **Storage**: 100-500 GB
- **Floating IPs**: 1-2
- **Duration**: 2-4 weeks
- **Cost**: ~€200-400

### For Full Production (100 models)
- **vCPUs**: 40-80
- **RAM**: 80-160 GB
- **Storage**: 500-2000 GB
- **Floating IPs**: 1-2
- **Duration**: 6-12 weeks
- **Cost**: ~€500-1500

---

## 💡 What I Need From You

To create your optimized cluster design, please run:

```bash
./collect_cloud_resources.sh
```

And share the generated archive or tell me:

1. **Your quota limits**:
   - How many vCPUs total?
   - How much RAM total?
   - How many instances allowed?

2. **Your available flavors** (you already showed these!):
   ```
   m2.tiny     (1 vCPU,  1GB)
   m2.small    (1 vCPU,  2GB)
   m2.medium   (2 vCPU,  4GB)  ← Good for central manager
   m2.large    (4 vCPU,  8GB)  ← Good for execute nodes
   m2.xlarge   (8 vCPU, 16GB)  ← Good for heavy MESA jobs
   m2.2xlarge  (16 vCPU, 32GB)
   m2.4xlarge  (32 vCPU, 65GB)
   r2.medium   (2 vCPU,  8GB)  ← Alternative for central
   r2.large    (4 vCPU, 16GB)  ← Alternative for execute
   r2.xlarge   (8 vCPU, 32GB)
   r2.2xlarge  (16 vCPU, 65GB)
   ```

3. **Your preference**:
   - Start with minimal testing? (recommended)
   - Or go straight to production cluster?

4. **Your timeline**:
   - Quick test (1-2 weeks)?
   - Full reproduction (2-3 months)?

5. **Your budget** (optional):
   - Any cost constraints?
   - Prefer minimal resources or faster completion?

---

## 🎓 Expected Scientific Outcome

After completing this project, you will have:

✅ **Reproduced NuGrid stellar yields**
- Validated against Pignatari et al. (2016)
- Stellar yields from H to Bi
- s-process abundance patterns

✅ **Working HTCondor cluster**
- Reusable infrastructure
- Can run future MESA grids
- Documented and reproducible

✅ **Scientific data products**
- Yield tables
- Abundance evolution tracks
- Comparison with observations
- Publication-ready plots

✅ **Computational expertise**
- HTCondor workflow management
- MESA stellar evolution modeling
- Nucleosynthesis post-processing
- Cloud infrastructure deployment

---

## 📚 Key Documents to Review

1. **PIGNATARI_REPRODUCTION_GUIDE.md** - Scientific background and requirements
2. **CLOUD_SETUP_GUIDE.md** - How to authenticate and use OpenStack CLI
3. **README.md** - Testing stages overview
4. **ITERATIVE_TESTING_PLAN.md** - Detailed testing methodology

---

## ❓ FAQ

**Q: Do I need to learn MESA first?**
A: Not necessarily! I'll provide configured MESA inlists. But understanding basics helps for troubleshooting. See: http://mesa.sourceforge.net

**Q: How long does one MESA model take?**
A: 4-72 hours depending on mass, resolution, and CPU cores. Typical: 12 hours on 4 cores.

**Q: Can I run this on my laptop?**
A: Testing yes, production grid no. MESA runs fine locally but full grid needs cluster resources.

**Q: What if my quota is too small?**
A: We can:
- Start with reduced parameter grid (fewer mass/metallicity points)
- Use smaller execute nodes (m2.medium instead of m2.large)
- Run sequentially instead of parallel (slower but works)
- Request quota increase from HUN-REN

**Q: What's the minimum cluster I can build?**
A: 1 central manager (m2.medium) + 1 execute node (m2.large) = 6 vCPUs total. Can run 1 model at a time.

**Q: How is this different from running MESA normally?**
A: HTCondor + NuDocker provides:
- Parallel execution (run many models simultaneously)
- Reproducibility (exact environment in container)
- Scalability (add more nodes as needed)
- Portability (same setup on any cloud/HPC)

---

## 🚦 Current Status: Awaiting Your Cloud Resources

**Next action**: Run `./collect_cloud_resources.sh` and share results

Once I have your cloud resource data, I will provide:
1. ✅ Optimized cluster design
2. ✅ Custom configuration files
3. ✅ Deployment instructions
4. ✅ MESA parameter grid definition
5. ✅ Analysis scripts

Then you'll be ready to deploy and run your Pignatari reproduction!

---

**Questions? Ready to proceed? Share your cloud resources and let's build your cluster!**

Last updated: 2025-11-19
