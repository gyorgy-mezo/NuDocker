# Reconstructing the NuGrid Stellar Data Set II
**Can we reproduce the NuGrid paper ([Pignatari et al. 2016](https://arxiv.org/abs/1709.08677)) from scratch using NuDocker?**
**Short Answer**: ✅ **Yes! Feasible in 2-4 months with moderate effort.**
---
## Quick Summary
| Aspect | Status | Details |
|--------|--------|---------|
| **Feasibility** | ✅ Yes | 4/5 stars - highly reproducible |
| **Timeline** | 2-4 months | Depends on scope (see below) |
 | 70k-110k CPU-hours | ~$4-5k if using cloud | 
 | Moderate | Medium learning curve | 
 | ✅ Yes | NuDocker + HTCondor complete | 
 | ⚠️ No | Expect 1-5% differences (acceptable) | 
---
## Three Reconstruction Levels
### 🥉 Level 1: Minimal (Proof of Concept)
**Goal**: Validate the approach
**Scope**:
- 10-20 selected stellar models
- MESA evolution only (no nucleosynthesis)
- Basic analysis and HR diagrams
**Resources**:
- **Timeline**: 2-3 weeks
- **CPU-hours**: ~5,000

**What You Get**:
- Working pipeline validated
- Subset of models compared with original
- Confidence to proceed
**Recommended for**:
- Learning MESA/NuDocker
- Testing infrastructure
- Quick validation
---
### 🥈 Level 2: Intermediate (Scientific Dataset)
**Goal**: Reproduce main results
**Scope**:
- Full 60-model stellar evolution grid
- MESA evolution complete
- Partial nucleosynthesis (simplified network)
- Main paper figures
**Resources**:
- **Timeline**: 8-10 weeks
- **CPU-hours**: ~50,000

**What You Get**:
- Complete stellar evolution tracks
- Basic element yields
- Most figures from paper
- Publication-quality comparison
**Recommended for**:
- Creating usable scientific dataset
- Most scientific applications
- Reasonable resource investment
---
### 🥇 Level 3: Full (Complete Reproduction)
**Goal**: Maximum reproducibility
**Scope**:
- Full 60-model grid
- Complete MESA evolution
- Complete MPPNP nucleosynthesis (full network)
- All paper figures
- Comprehensive validation
**Resources**:
- **Timeline**: 12-16 weeks
- **CPU-hours**: ~100,000

**What You Get**:
- Complete independent dataset
- Full yield tables (all isotopes)
- Every figure reproduced
- Publishable reproducibility study
**Recommended for**:
- Full reproducibility verification
- Publication of new dataset
- Comprehensive validation study
---
## What You Have (Ready Now)
✅ **NuDocker Container System**
- Ubuntu environment with MESA SDK
- Multiple MESA versions available
- Reproducible computational environment
✅ **HTCondor Submission Infrastructure**
- Submit files for 54 models (easy to expand to 60+)
- DAGMan workflow management
- Automated job execution and result collection
- Production-ready scripts
✅ **Parameter Grid**
- 54 models defined (6 masses × 3 metallicities × 3 mixing lengths)
- Easy to expand to 60+ models matching original study
- Automated parameter substitution
✅ **Documentation**
- Complete usage guides
- HTCondor vs SLURM comparison
- Step-by-step instructions
---
## What You Need to Add
### Easy to Add (Days)
✅ **Expand Parameter Grid**
- Add missing mass points: 1.65, 3, 4, 6, 7, 12, 25 M☉
- Add missing metallicities: Z=0.0001, Z=0.006
- **Time**: 1 day
- **Difficulty**: ⭐☆☆☆☆
✅ **Download Original Data for Comparison**
```bash
# Available from Canadian Astronomical Data Center
wget http://www.cadc-ccda.hia-iha.nrc-cnrc.gc.ca/nugrid/...
```
- **Time**: 1 day
- **Difficulty**: ⭐☆☆☆☆
### Medium Difficulty (Weeks)
⚠️ **Configure MESA to Match Original Study**
- Identify exact MESA version (r7624-r10398 era)
- Set inlist parameters
- Match physics modules
- **Time**: 1-2 weeks
- **Difficulty**: ⭐⭐⭐☆☆
⚠️ **Create Analysis Scripts**
- Read MESA outputs
- Generate plots
- Calculate derived quantities
- **Time**: 2-3 weeks
- **Difficulty**: ⭐⭐⭐☆☆
### Hard (Months)
❌ **Set Up MPPNP Nucleosynthesis**
- Use `nugrid/nudome:mppnp` Docker image
- Configure nuclear reaction network
- Set up MPI environment
- Run post-processing
- **Time**: 4-8 weeks
- **Difficulty**: ⭐⭐⭐⭐⭐
**MPPNP Details**:
```bash
# Use MPPNP-enabled container
docker pull nugrid/nudome:mppnp
# Includes:
# - HDF5 1.8.3
# - OpenMPI 3.0.0
# - NuSE (NuGrid Solver Engine)
# - MPPNP code
```
---
## Quick Start Guide
### Option A: Minimal Reconstruction (Recommended First Step)
**Week 1**:
```bash
# 1. Set up MESA
cd NuDocker/htcondor_scripts
# 2. Configure 10 test models
vim nugrid_lowmass.sub
# Edit to only run 10 models
# 3. Submit to HTCondor
condor_submit nugrid_lowmass.sub
```
**Week 2**:
```bash
# 4. Monitor jobs
condor_q
condor_watch_q
# 5. Collect results
tar xzf results_*.tar.gz
# 6. Compare with original NuGrid data
python compare_with_nugrid.py
```
**Week 3**:
```bash
# 7. Create validation plots
python plot_hr_diagrams.py
python plot_lifetimes.py
# 8. Write validation report
# Document what matches, what differs, why
```
### Option B: Full MESA Grid (Intermediate)
**Follow HTCondor scripts README**:
```bash
cd NuDocker/htcondor_scripts
cat README.md
# Submit all mass groups
condor_submit nugrid_lowmass.sub      # 18 models
condor_submit nugrid_mediummass.sub   # 18 models
condor_submit nugrid_highmass.sub     # 18 models
# Or use DAG workflow
condor_submit_dag nugrid_study.dag
```
**Expected Runtime**: 48-72 hours (with parallel execution)
### Option C: Add MPPNP (Full Reconstruction)
**Requires MPPNP expertise** - see detailed guide in `RECONSTRUCTING_NUGRID_STUDY.md`
---
## Expected Differences from Original
### ✅ What Will Match Well (< 1% difference)
- Overall evolution tracks
- Main sequence lifetimes
- Final masses
- General nucleosynthesis patterns
### ⚠️ What May Differ (1-5%)
- Exact numerical values
- Some abundance ratios
- Detailed nucleosynthesis yields
- Minor evolutionary features
### ❌ Why Perfect Match Is Impossible
1. **Compiler Differences**
   - GCC versions may differ
   - Optimization flags
   - Numerical libraries
2. **Undocumented Choices**
   - Some parameters not in paper
   - Initial conditions
   - Convergence criteria
3. **Code Evolution**
   - MESA updates over time
   - Reaction rate updates
   - Physics module improvements
**But**: 1-5% differences are scientifically acceptable and validate reproducibility!
---
## Resource Requirements
### Per-Model Estimates
 | CPUs | Memory | Time | Disk | 
 | ------ | -------- | ------ | ------ | 
 | 8 | 8 GB | 2-6 hr | 750 MB | 
 | 16 | 16 GB | 6-24 hr | 2 GB | 
 | 32 | 32 GB | 24-72 hr | 5 GB | 
### Total Study (60+ models)
**MESA Evolution**:
- CPU-hours: ~40,000-50,000
- Peak memory: 32 GB
- Disk: 100-300 GB
- Wallclock: 3-7 days (parallel)
**MPPNP Post-Processing** (if added):
- CPU-hours: ~30,000-60,000
- Peak memory: 64 GB
- Disk: 300-1,000 GB
- Wallclock: 2-5 days (parallel)
**Total Combined**:
- CPU-hours: 70,000-110,000
- Peak memory: 64 GB
- Disk: 400-1,300 GB
- Wallclock: 2-4 months (including setup)
## Why HTCondor is Perfect for This
### ✅ MESA Uses OpenMP, NOT MPI
**This is crucial**:
- Each stellar model = independent job on single node
- No inter-process communication
- Perfect for HTCondor's scheduling
### ✅ Heterogeneous Resource Needs
Different models need different resources:
- 1 M☉: 8 CPUs, 6 hours
- 20 M☉: 32 CPUs, 72 hours
HTCondor's **matchmaking** handles this optimally!
### ✅ Long Runtimes Supported
- Jobs up to 72 hours
- Checkpointing via MESA photos
- Automatic retry on failure
### ⚠️ MPPNP Does Use MPI
If doing full nucleosynthesis:
- MPPNP needs MPI (unlike MESA)
- HTCondor can still run MPI jobs
- Or use SLURM for MPPNP phase
---
## Timeline Breakdown
### Minimal Reconstruction (2-3 weeks)
 | Tasks | Deliverables | 
 | ------- | -------------- | 
 | Setup, configure 10 models | Test jobs running | 
 | Run models, collect results | 10 completed models | 
 | Compare, analyze, validate | Validation report | 
### Intermediate Reconstruction (8-10 weeks)
 | Phase | Deliverables | 
 | ------- | -------------- | 
 | MESA setup, test runs | Validated configuration | 
 | Run full 60-model grid | All MESA models complete | 
 | Basic nucleosynthesis | Simplified yields | 
 | Analysis and figures | Main results reproduced | 
 | Validation and documentation | Complete report | 
### Full Reconstruction (12-16 weeks)
 | Phase | Deliverables | 
 | ------- | -------------- | 
 | MESA evolution | 60 models validated | 
 | MPPNP setup and execution | Full nucleosynthesis | 
 | Analysis and validation | All figures, full dataset | 
 | Documentation and publication | Reproducibility paper | 
---
## Success Criteria
### Minimal Success ✅
- [ ] 10+ models run successfully
- [ ] Results within 5% of original
- [ ] HR diagrams match
- [ ] Pipeline validated
### Intermediate Success ✅
- [ ] 60 models completed
- [ ] Lifetimes within 2% of original
- [ ] Evolution tracks match
- [ ] Main figures reproduced
### Full Success ✅
- [ ] Complete nucleosynthesis
- [ ] Yield tables within 5%
- [ ] All figures reproduced
- [ ] Publishable comparison
---
## Common Questions
### Q: Do I need to contact the NuGrid team?
**A**: Not required, but **highly recommended**!
- They can provide exact inlists
- Clarify undocumented choices
- Share validation data
- Offer MPPNP expertise
### Q: Can I use SLURM instead of HTCondor?
**A**: ✅ **Yes!** We have SLURM scripts too.
- See `slurm_scripts/` directory
- Already production-tested
- Simpler for HPC clusters
- Both work equally well
### Q: What if I don't have 100,000 CPU-hours?
**A**: Do minimal or intermediate reconstruction
- 10 models: ~1,000 CPU-hours
- 20 models: ~5,000 CPU-hours
- Still scientifically valuable!
### Q: How close will my results be?
**A**: Typically 1-5% differences
- Good enough for validation
- Scientifically acceptable
- Demonstrates reproducibility
### Q: Can I skip MPPNP?
**A**: ✅ **Yes!** Still very valuable.
- MESA evolution alone is useful
- Many scientific applications
- Can add MPPNP later if needed
### Q: What programming skills do I need?
**A**:
- **Minimal**: Basic command line, can follow instructions
- **Intermediate**: Bash scripting, basic Python
- **Full**: Python, some Fortran understanding, MPI knowledge
---
## Helpful Resources
### Documentation in This Repository
- **RECONSTRUCTING_NUGRID_STUDY.md**: Full detailed feasibility study
- **NUGRID_PARAMETER_STUDY_USECASE.md**: Complete use case description
- **htcondor_scripts/README.md**: HTCondor usage guide
- **slurm_scripts/README.md**: SLURM usage guide
### External Resources
**NuGrid**:
- Website: https://nugrid.github.io
- NuGridPy: https://nugrid.github.io/NuGridPy
- Data: http://www.cadc-ccda.hia-iha.nrc-cnrc.gc.ca/
**MESA**:
- Documentation: https://docs.mesastar.org
- Forums: http://mesastar.org
- Tutorials: https://docs.mesastar.org/en/latest/tutorial.html
**Original Paper**:
- arXiv: https://arxiv.org/abs/1709.08677
- Journal: MNRAS, 480(1), 538-571 (2016)
---
## Getting Started
### Step 1: Choose Your Scope
Pick one of the three levels based on:
- Available time (2-16 weeks)
- Computational resources (5k-100k CPU-hours)
- Scientific goals
- Learning objectives
### Step 2: Set Up Infrastructure
```bash
# Clone NuDocker
git clone https://github.com/NuGrid/NuDocker.git
cd NuDocker
# Choose your scheduler
cd htcondor_scripts  # For HTCondor
# or
cd slurm_scripts     # For SLURM
```
### Step 3: Run Test Case
```bash
# Start with 1 model
# Follow quick start guide above
# Validate before scaling up
```
### Step 4: Scale Up
```bash
# Once test works:
# - Expand to 10 models (minimal)
# - Then 60 models (intermediate)
# - Add MPPNP if needed (full)
```
### Step 5: Validate and Document
```bash
# Compare with original data
# Create plots
# Write validation report
# Share results!
```
---
## Recommendation
### 🎯 Recommended Path for Most Users
**Start**: Minimal reconstruction (2-3 weeks)

- Validates infrastructure
- Learn MESA/NuDocker
**Then**: Intermediate reconstruction (8-10 weeks)
- Scientifically useful dataset
- Publishable comparison
- Moderate resource investment
**Finally**: Full reconstruction (only if needed)
- For publication
- Complete reproducibility study
- Requires significant resources
---
## Support
### Need Help?
**NuDocker Issues**:
- GitHub: https://github.com/NuGrid/NuDocker/issues
**MESA Questions**:
- Forums: http://mesastar.org
**NuGrid/MPPNP**:
- Contact NuGrid team
- Check documentation: https://nugrid.github.io
**HTCondor**:
- Manual: https://htcondor.readthedocs.io
- Email: htcondor-users@cs.wisc.edu
---
## Citation
If you use this reconstruction in your research:
```bibtex
@article{Pignatari2016,
  title={NuGrid Stellar Data Set. II. Stellar yields from H to Bi for stellar models with M$_{ZAMS}$ = 1–25 M$_{\odot}$ and Z = 0.0001–0.02},
  author={Pignatari, M. and others},
  journal={Monthly Notices of the Royal Astronomical Society},
  volume={480},
  number={1},
  pages={538--571},
  year={2016},
  doi={10.1093/mnras/stx2713}
}
```
And cite NuDocker:
```
NuDocker: Docker Containerization for MESA
NuGrid Team (2025)
https://github.com/NuGrid/NuDocker
```
---
## Final Thoughts
### Is It Worth It?
**Yes, if you want to**:
- ✅ Validate computational reproducibility
- ✅ Learn MESA and stellar evolution
- ✅ Create independent dataset for comparison
- ✅ Demonstrate open science practices
- ✅ Contribute to reproducible research
**Maybe not, if**:
- ❌ Just need the original data (use published dataset)
- ❌ Very limited resources
- ❌ Need exact numerical match (impossible)
### The Value
**Scientific**:
- Independent verification of published results
- Demonstrates reproducibility
- Creates comparable dataset
**Educational**:
- Learn MESA stellar evolution
- Practice HPC workflow management
- Understand nucleosynthesis calculations
**Community**:
- Contribute to open science
- Validate reproducibility practices
- Share infrastructure with others
---
**Version**: 1.0
**Date**: 2025-11-18
**Status**: Ready to Use
**License**: BSD 3-Clause
---
## Quick Reference Card
```
┌─────────────────────────────────────────────────────────┐
│              RECONSTRUCTION QUICK REFERENCE              │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  Feasibility:        ✅ Yes (4/5 stars)                 │
│  Timeline:           2-4 months                          │
│  CPU-hours:          70k-110k                            │
│  Infrastructure:     ✅ Ready (NuDocker + HTCondor)     │
│                                                          │
│  LEVELS:                                                 │
│  ├─ Minimal:         2-3 weeks, 5k CPU-hrs              │
│  ├─ Intermediate:    8-10 weeks, 50k CPU-hrs            │
│  └─ Full:            12-16 weeks, 100k CPU-hrs           │
│                                                          │
│  MESA:               ✅ Fully achievable                │
│  MPPNP:              ⚠️ Complex but doable              │
│  Perfect match:      ❌ No (1-5% diff expected)         │
│                                                          │
│  RECOMMENDED START:  Minimal → Intermediate → Full      │
│                                                          │
└─────────────────────────────────────────────────────────┘
```
**Ready to start? See: Quick Start Guide above ⬆️**