# Pignatari Article Reproduction Guide

**Scientific Goal**: Reproduce nucleosynthesis calculations from Pignatari et al. studies using MESA + NuDocker

---

## Scientific Background

### The Pignatari Studies

**Key Publications**:
- Pignatari et al. (2016): "NuGrid Stellar Data Set. I. Stellar Yields from H to Bi for Stars with Metallicities Z = 0.02 and Z = 0.01"
  - ApJS, 225, 24
  - DOI: 10.3847/0067-0049/225/2/24

- Related work: s-process nucleosynthesis in AGB (Asymptotic Giant Branch) stars

**Scientific Topic**:
Heavy element production in stars through the **s-process** (slow neutron capture process)

**Key Questions**:
- How do low and intermediate mass stars (1-8 solar masses) produce elements heavier than iron?
- What are the stellar yields of these elements at different metallicities?
- How do these yields depend on stellar mass and composition?

---

## What MESA Simulations Are Needed

### Stellar Evolution Models

**Type**: Low and intermediate mass stars (1-8 M☉) from main sequence through AGB phase

**Key Phases**:
1. **Main Sequence**: Hydrogen burning core
2. **Red Giant Branch (RGB)**: First dredge-up
3. **Horizontal Branch**: Helium burning
4. **Asymptotic Giant Branch (AGB)**:
   - Thermal pulses (crucial for s-process)
   - Third dredge-up (mixes nucleosynthesis products to surface)

**Duration**:
- Real time: millions to billions of years
- Computation time: hours to days per model (depends on resolution)

### Parameter Grid

For reproduction, you need a grid of models varying:

1. **Initial Mass**: e.g., 1.0, 1.5, 2.0, 2.5, 3.0, 4.0, 5.0, 6.0, 7.0 M☉
   - **Grid size**: ~9-15 mass points

2. **Metallicity (Z)**: e.g., Z = 0.02 (solar), 0.01, 0.001
   - **Grid size**: ~2-4 metallicity points

3. **Total models**: 9 masses × 3 metallicities = **27 models minimum**
   - Full NuGrid set has ~100+ models

4. **Computation per model**:
   - Low mass (1-2 M☉): 4-12 hours (4-8 cores)
   - Intermediate mass (3-5 M☉): 12-48 hours (8-16 cores)
   - High mass (6-8 M☉): 24-72 hours (8-16 cores)

---

## Computational Requirements

### Per-Model Requirements

**MESA Configuration**:
- **CPU**: 4-16 cores (OpenMP parallel)
- **RAM**: 4-16 GB (depends on resolution and network size)
- **Disk**:
  - Source: ~500 MB
  - Compiled: ~2-5 GB
  - Results: 1-20 GB per model (depends on saved profiles/history)
- **Runtime**: 4-72 hours

**Optimal Configuration**:
- 1 model per VM (MESA is OpenMP parallel, not MPI)
- 4-8 cores per model for good efficiency
- Multiple models run concurrently across cluster

### Total Grid Requirements

**Scenario 1: Minimal Grid (27 models)**
- **CPU-hours**: ~1,000-3,000 hours
- **Wall time**:
  - With 3 execute nodes (4 cores each): 10-30 days
  - With 6 execute nodes (4 cores each): 5-15 days
  - With 12 execute nodes (4 cores each): 3-8 days
- **Storage**: ~50-500 GB

**Scenario 2: Full NuGrid Set (~100 models)**
- **CPU-hours**: ~5,000-15,000 hours
- **Wall time**:
  - With 10 execute nodes: 20-60 days
  - With 20 execute nodes: 10-30 days
- **Storage**: ~200-2000 GB

---

## HTCondor Workflow Design

### Job Types

**1. Test Jobs** (validation)
- Short MESA run to end of main sequence
- Purpose: Verify setup works
- Duration: 10-60 minutes
- Resource: 1-2 cores, 2 GB RAM

**2. Production Jobs** (science runs)
- Full evolution to end of AGB
- Duration: 4-72 hours
- Resource: 4-8 cores, 8-16 GB RAM

**3. Post-processing Jobs** (analysis)
- Extract yields, create plots
- Duration: minutes to hours
- Resource: 1-2 cores, 2-4 GB RAM

### HTCondor Submit File Strategy

**Approach 1: Single Submit File with Grid**
```
# Parameter grid via queue statement
executable = run_mesa_model.sh
arguments = $(mass) $(metallicity)
request_cpus = 4
request_memory = 8GB
queue mass,metallicity from parameter_grid.txt
```

**Approach 2: DAG Workflow**
```
# DAGMan for dependencies
JOB test_1M test_run.sub
JOB prod_1M_z002 production_run.sub
JOB postproc_1M analysis.sub

PARENT test_1M CHILD prod_1M_z002
PARENT prod_1M_z002 CHILD postproc_1M
```

**Approach 3: Multiple Submit Files**
- Separate files for different mass ranges
- Allows different resource requests
- Good for heterogeneous cluster

---

## NuDocker Integration

### Why NuDocker?

**Reproducibility**:
- Exact MESA version preserved in container
- Same results years later
- Share exact environment with collaborators

**Portability**:
- Same container runs on laptop, HPC, cloud
- No dependency hell
- Easy distribution

### Container Images Needed

**Base NuDocker Image**:
- Ubuntu 22.04 or 20.04
- MESA r15140 or r22.x.x
- MESA SDK (compilers, libraries)
- NuPPN (optional, for network visualization)

**Custom Image for Pignatari Reproduction**:
- Specific MESA version used in NuGrid set
- Pre-compiled MESA (faster startup)
- MESA inlists for parameter grid
- Analysis scripts

### HTCondor + NuDocker Workflow

**Option 1: Docker Universe**
```
universe = docker
docker_image = nugrid/nudome:20.1
executable = /bin/bash
arguments = -c "cd $MESA_DIR/star/work && ./rn"
```

**Option 2: Singularity (on HPC)**
```
universe = vanilla
executable = run_singularity.sh
arguments = nudome_20.031.sif $(mass) $(metallicity)
```

**Option 3: Pre-installed MESA**
```
universe = vanilla
executable = run_mesa.sh
arguments = $(mass) $(metallicity)
# MESA pre-installed on all execute nodes
```

---

## Data Products

### What Gets Generated

**Per Model**:
1. **History file** (`LOGS/history.data`):
   - Stellar properties vs. time
   - Size: 10-500 MB
   - Contains: L, Teff, log g, central T/ρ, etc.

2. **Profile files** (`LOGS/profileN.data`):
   - Internal structure snapshots
   - Size: 1 MB each, ~100-10,000 profiles per model
   - Contains: T, ρ, composition vs. radius

3. **Abundance evolution**:
   - Isotopic abundances vs. time/model number
   - Key for nucleosynthesis yields

4. **Yield tables**:
   - Final surface abundances
   - Integrated yields
   - Comparison with observations

### Storage Strategy

**During Computation** (on NFS):
- `/storage/mesa/` - MESA source (shared)
- `/storage/runs/mass_X_Z_Y/` - Individual model directories
- Save profiles periodically (not every step - too much data!)

**After Completion**:
- Archive profiles to compressed storage
- Keep history files and yield tables accessible
- Backup to external storage (not on cloud)

**Data Reduction**:
- Full dataset: ~20 GB per model (all profiles)
- Reduced dataset: ~500 MB per model (key profiles + history)
- Yield tables only: ~1 MB per model

---

## Success Criteria

### Technical Success

✅ All models run to completion (end of AGB or carbon ignition)
✅ No numerical failures or crashes
✅ Consistent results across different execute nodes (reproducibility check)
✅ Data files readable and well-formatted
✅ No data corruption or loss

### Scientific Success

✅ Stellar yields match published NuGrid data (within numerical uncertainty)
✅ s-process enhancements (e.g., [Ba/Fe], [Pb/Fe]) consistent with literature
✅ Thermal pulse properties (ΔM, interpulse period) reasonable
✅ Main sequence and RGB evolution matches standard models

### Validation Tests

**Before Full Grid**:
1. Run 1 test model (1.5 M☉, Z=0.02) - compare with NuGrid reference
2. Run 3 models (low/mid/high mass) - verify convergence
3. Check yields against published tables

**During Grid Execution**:
1. Monitor for crashes/failures
2. Check disk space usage
3. Verify reasonable progress (model numbers increasing)

**After Completion**:
1. Compare yields with Pignatari et al. (2016) Table 3
2. Plot HRD (Hertzsprung-Russell Diagram) - should match evolutionary tracks
3. Compare s-process indicators with observations

---

## Timeline Estimation

### Phase 1: Setup (1-2 weeks)
- Build HTCondor cluster infrastructure
- Create custom NuDocker image with MESA
- Test single model end-to-end
- Validate against reference data

### Phase 2: Test Grid (1 week)
- Run 5-10 test models
- Verify reproducibility
- Optimize resource allocation
- Estimate full grid runtime

### Phase 3: Production Grid (2-8 weeks)
- Submit full parameter grid
- Monitor execution
- Handle failures/re-submissions
- Depends on cluster size

### Phase 4: Analysis (1-2 weeks)
- Extract yields from all models
- Create comparison tables
- Generate plots
- Write up results

**Total Timeline**: 2-4 months for full reproduction

---

## Cluster Design Recommendations

### Minimal Cluster (Testing)
- 1 Central Manager (2 vCPU, 4 GB)
- 2 Execute Nodes (4 vCPU, 8 GB each)
- **Capability**: 2 models simultaneously, ~10-20 models/week
- **Use case**: Initial testing, validation

### Small Production Cluster
- 1 Central Manager (2 vCPU, 8 GB)
- 5 Execute Nodes (4-8 vCPU, 8-16 GB each)
- **Capability**: 5-10 models simultaneously, ~50-100 models/month
- **Use case**: Reduced parameter grid (27 models)

### Medium Production Cluster
- 1 Central Manager (4 vCPU, 16 GB)
- 10 Execute Nodes (8 vCPU, 16 GB each)
- **Capability**: 10-20 models simultaneously, ~100-200 models/month
- **Use case**: Full NuGrid reproduction

### Large Production Cluster
- 1 Central Manager (4 vCPU, 16 GB)
- 20+ Execute Nodes (8-16 vCPU, 16-32 GB each)
- **Capability**: 20-40 models simultaneously, ~200-400 models/month
- **Use case**: Multiple parameter grids, systematic studies

---

## Cost Estimation

Based on HUN-REN flavors (m2, r2 series):

### Minimal Cluster (Testing)
- Central: m2.medium (2 vCPU, 4 GB)
- 2× Execute: m2.large (4 vCPU, 8 GB)
- **Total**: 10 vCPU, 20 GB RAM
- **Estimated cost**: €50-100/month
- **Runtime for 27 models**: 4-8 weeks

### Small Production
- Central: r2.medium (2 vCPU, 8 GB)
- 5× Execute: m2.large (4 vCPU, 8 GB)
- **Total**: 22 vCPU, 48 GB RAM
- **Estimated cost**: €100-200/month
- **Runtime for 27 models**: 2-4 weeks
- **Runtime for 100 models**: 6-12 weeks

### Medium Production
- Central: m2.large (4 vCPU, 8 GB)
- 10× Execute: r2.large (4 vCPU, 16 GB)
- **Total**: 44 vCPU, 168 GB RAM
- **Estimated cost**: €200-400/month
- **Runtime for 100 models**: 3-6 weeks

**Cost Optimization**:
- Run cluster only during active computation
- Use spot/preemptible instances if available (50-90% discount)
- Pause cluster on weekends
- Delete results after archival

---

## References

**NuGrid Publications**:
- Pignatari et al. (2016), ApJS, 225, 24 - Main data paper
- Ritter et al. (2018), MNRAS, 480, 538 - NuGrid stellar yields database
- Battino et al. (2016), ApJ, 827, 30 - i-process nucleosynthesis

**MESA Documentation**:
- Paxton et al. (2011, 2013, 2015, 2018, 2019) - MESA instrument papers
- MESA website: http://mesa.sourceforge.net
- MESA forum: https://lists.mesastar.org

**NuGrid Resources**:
- NuGrid collaboration: https://nugrid.github.io
- NuPPN: https://nugrid.github.io/NuPPN
- WENDI (Web Exploration of NuGrid Data Interactive): https://wendi.nugridstars.org

---

## Next Steps

1. **Collect your HUN-REN cloud resources**:
   ```bash
   ./collect_cloud_resources.sh
   ```

2. **Share results** for cluster design

3. **I will create**:
   - Optimized HTCondor cluster design for your quota
   - Custom MESA inlists for parameter grid
   - HTCondor submit files for job distribution
   - Analysis scripts for yield extraction

4. **Deploy and test**:
   - Start with minimal cluster (2 execute nodes)
   - Run 1-3 test models
   - Validate against NuGrid data
   - Scale up to production grid

---

Last updated: 2025-11-19
