# Reconstructing the NuGrid Stellar Data Set II from Scratch

**Question**: Can we reconstruct the NuGrid Stellar Data Set II paper (Pignatari et al. 2016) from scratch using NuDocker?

**Short Answer**: ✅ **Yes, mostly - but it requires significant additional work beyond the HTCondor setup.**

---

## Table of Contents

- [Overview](#overview)
- [What We Have](#what-we-have)
- [What's Missing](#whats-missing)
- [Step-by-Step Reconstruction Plan](#step-by-step-reconstruction-plan)
- [Computational Requirements](#computational-requirements)
- [Time Estimates](#time-estimates)
- [Practical Limitations](#practical-limitations)
- [Realistic Reconstruction Scope](#realistic-reconstruction-scope)
- [Implementation Roadmap](#implementation-roadmap)

---

## Overview

The **NuGrid Stellar Data Set II** paper ([Pignatari et al. 2016](https://arxiv.org/abs/1709.08677)) presents:

1. **Stellar Evolution Models**: Computed with MESA
2. **Nucleosynthesis Calculations**: Post-processing with MPPNP (Multi-zone Post-Processing Network)
3. **Yield Tables**: Element production for each mass/metallicity
4. **Analysis**: HR diagrams, lifetimes, abundances, isotopic ratios
5. **Data Products**: Complete datasets available via CADC (Canadian Astronomical Data Center)

### Can We Reproduce It?

| Component | Reproducible? | Difficulty | Notes |
|-----------|---------------|------------|-------|
| MESA models | ✅ Yes | Medium | Have tools, need time |
| MPPNP post-processing | ⚠️ Partial | Hard | Need MPPNP setup |
| Yield calculations | ⚠️ Partial | Hard | Requires MPPNP |
| Basic analysis | ✅ Yes | Easy | Python/matplotlib |
| Full paper figures | ⚠️ Partial | Medium | Some figures complex |
| Complete dataset | ⚠️ Partial | Hard | Many models |

**Overall**: ✅ **Yes, with significant effort - feasible in weeks to months**

---

## What We Have

### 1. ✅ NuDocker Container System

**Status**: Fully ready

**What it provides**:
- Ubuntu environment with MESA SDK
- All compilers and libraries
- Consistent computational environment
- Multiple MESA versions supported

**What we can do**:
- Run MESA stellar evolution models
- Reproduce computational environment from 2016
- Ensure reproducibility

### 2. ✅ HTCondor Submission Infrastructure

**Status**: Production-ready

**What it provides**:
- Submit files for 54 models
- DAGMan workflow management
- Automated job execution
- Result collection

**What we can do**:
- Run parameter grid automatically
- Manage heterogeneous resources
- Handle job failures and retries

### 3. ✅ Parameter Grid Definition

**Status**: Defined (simplified version)

**Our grid**:
- Masses: 1, 2, 5, 10, 15, 20 M☉ (6 points)
- Metallicities: 0.02, 0.01, 0.001 (3 points)
- Mixing length: 1.8, 2.0, 2.2 (3 points)
- **Total**: 54 models

**Original NuGrid grid**:
- Masses: 1, 1.65, 2, 3, 4, 5, 6, 7, 12, 15, 20, 25 M☉ (12 points)
- Metallicities: 0.02, 0.01, 0.006, 0.001, 0.0001 (5 points)
- Plus alpha-enhanced compositions
- **Total**: 60+ models

**Gap**: Need to expand grid to match original

### 4. ✅ MESA Installation

**Status**: Can be set up

**What we have**:
- Access to MESA versions used in original study
- Installation instructions
- Pre-compilation workflow

**What we need**:
- Identify exact MESA version used (likely r7624-r10000 era)
- Configure MESA parameters to match paper
- Set up proper inlists

---

## What's Missing

### 1. ❌ MPPNP (Nucleosynthesis Post-Processing)

**Status**: Not yet set up

**What it is**:
- Multi-zone Post-Processing Network code
- Takes MESA stellar structure profiles
- Computes detailed nucleosynthesis
- Tracks 5,000+ isotopes through nuclear reactions

**What it's needed for**:
- Element yield calculations
- Isotopic abundance ratios
- Nuclear reaction network solutions
- Main scientific results of the paper

**Availability**:
- Available from NuGrid (open source)
- NuDocker has `nudome:mppnp` image variant
- Requires HDF5, OpenMPI setup
- More complex than MESA

**Setup difficulty**: **High** (weeks of work)

**How to add**:
```bash
# Use MPPNP-enabled NuDocker image
docker pull nugrid/nudome:mppnp

# Contains:
# - HDF5 1.8.3
# - OpenMPI 3.0.0
# - NuSE (NuGrid Solver Engine)
# - MPPNP code
```

### 2. ❌ Specific MESA Configuration

**Status**: Need to determine

**Missing details**:
- Exact MESA version used
- Specific inlist parameters
- Physics modules enabled/disabled
- Output cadence and profiles
- Boundary conditions
- Numerical tolerances

**How to find**:
- Read paper methods section carefully
- Check NuGrid data repository for inlists
- Contact NuGrid team
- Examine existing NuGrid models

**Setup difficulty**: **Medium** (days to weeks)

### 3. ❌ Analysis Scripts

**Status**: Not implemented

**What's needed**:
- Read MESA history files
- Read MPPNP output
- Calculate yields
- Generate HR diagrams
- Compute lifetimes
- Create abundance plots
- Statistical analysis

**Tools available**:
- NuGridPy (Python package for NuGrid data)
- MESA SDK tools
- Standard scientific Python stack

**Setup difficulty**: **Medium** (weeks)

**Example**:
```python
# Using NuGridPy
import nugridpy as mp

# Load MESA stellar evolution
s = mp.se(mass=5, Z=0.02)

# Plot HR diagram
s.kippenhahn_plot()

# Get yields
yields = s.get_yields()
```

### 4. ❌ Complete Parameter Space

**Status**: Partial

**Our grid**: 54 models
**Original grid**: 60+ models

**Missing**:
- Additional mass points (1.65, 3, 4, 6, 7, 12, 25 M☉)
- Additional metallicity (Z=0.0001, Z=0.006)
- Alpha-enhanced compositions
- Possibly rotation variants

**Setup difficulty**: **Easy** (just extend grid definition)

### 5. ❌ Validation Data

**Status**: Available but not processed

**What's needed**:
- Original NuGrid dataset (available from CADC)
- Comparison scripts
- Statistical validation
- Difference analysis

**How to get**:
```bash
# Download from Canadian Astronomical Data Center
# http://www.cadc-ccda.hia-iha.nrc-cnrc.gc.ca/en/
# Search for "NuGrid"
```

**Setup difficulty**: **Easy** (download and compare)

---

## Step-by-Step Reconstruction Plan

### Phase 1: MESA Stellar Evolution (Weeks 1-4)

#### Week 1: Setup and Configuration

**Tasks**:
1. Identify exact MESA version used in original paper
   - Read paper methods section
   - Check NuGrid documentation
   - Test different versions if needed

2. Set up reference MESA configuration
   - Download inlists from NuGrid if available
   - Configure physics modules
   - Set output parameters

3. Run single test model
   - Pick representative model (e.g., 5 M☉, Z=0.02)
   - Compare with original NuGrid data
   - Verify physics settings

4. Validate test model
   - Check evolution track
   - Compare timescales
   - Verify final state

**Deliverables**:
- Working MESA configuration
- Validated test model
- Documentation of settings

#### Week 2-3: Full Grid Execution

**Tasks**:
1. Expand parameter grid to match original
   - Add missing mass points
   - Add missing metallicities
   - Configure alpha-enhanced models

2. Create MESA work templates
   - Parameterized inlists
   - Automated configuration
   - Quality checks

3. Submit jobs to HTCondor (or SLURM)
   - Use existing submission infrastructure
   - Monitor progress
   - Handle failures

4. Collect MESA outputs
   - History files
   - Profile files
   - Photos (checkpoints)

**Deliverables**:
- 60+ completed MESA models
- Organized output directories
- Quality control report

#### Week 4: MESA Validation

**Tasks**:
1. Compare with original NuGrid dataset
   - HR diagram positions
   - Main sequence lifetimes
   - Final masses
   - Key evolutionary phases

2. Statistical validation
   - Model-to-model differences
   - Identify outliers
   - Document discrepancies

3. Rerun failed/problematic models
   - Adjust parameters if needed
   - Verify convergence
   - Document issues

**Deliverables**:
- Validation report
- Comparison plots
- Corrected models

### Phase 2: Nucleosynthesis Post-Processing (Weeks 5-8)

#### Week 5: MPPNP Setup

**Tasks**:
1. Set up MPPNP environment
   - Use `nugrid/nudome:mppnp` Docker image
   - Install dependencies (HDF5, OpenMPI)
   - Clone MPPNP code

2. Configure MPPNP
   - Nuclear reaction network
   - Reaction rates
   - Initial abundances
   - Solver parameters

3. Run test case
   - Post-process one MESA model
   - Verify output format
   - Check isotope tracking

**Deliverables**:
- Working MPPNP installation
- Test run outputs
- Configuration documentation

#### Week 6-7: Full Post-Processing

**Tasks**:
1. Extract MESA profiles
   - Select profiles for post-processing
   - Convert to MPPNP input format
   - Organize directory structure

2. Run MPPNP on all models
   - Submit MPPNP jobs
   - Monitor nucleosynthesis calculations
   - Collect outputs

3. Calculate yields
   - Integrate nucleosynthesis over stellar lifetime
   - Account for mass loss
   - Compute element yields

**Deliverables**:
- MPPNP outputs for all models
- Yield tables
- Nucleosynthesis profiles

#### Week 8: Nucleosynthesis Validation

**Tasks**:
1. Compare yields with original NuGrid
   - Element-by-element comparison
   - Isotopic ratios
   - Abundance patterns

2. Identify discrepancies
   - Check reaction rates
   - Verify initial compositions
   - Document differences

**Deliverables**:
- Yield comparison report
- Validated nucleosynthesis results

### Phase 3: Analysis and Visualization (Weeks 9-12)

#### Week 9: Basic Analysis

**Tasks**:
1. Set up NuGridPy
   ```python
   pip install nugridpy
   ```

2. Load all models
   ```python
   import nugridpy as mp
   models = [mp.se(mass=m, Z=z) for m, z in parameter_grid]
   ```

3. Extract key properties
   - Lifetimes
   - Final masses
   - HR diagram tracks
   - Nucleosynthesis yields

**Deliverables**:
- Data extraction scripts
- Summary tables
- Basic plots

#### Week 10-11: Figure Reproduction

**Tasks**:
1. Reproduce main paper figures
   - HR diagrams (evolutionary tracks)
   - Mass-lifetime relationships
   - Yield tables
   - Abundance patterns
   - Isotopic ratios

2. Create analysis plots
   - Metallicity dependencies
   - Mass dependencies
   - Comparative plots

3. Statistical analysis
   - Trends
   - Correlations
   - Uncertainties

**Deliverables**:
- Reproduction of all paper figures
- Analysis plots
- Statistical summaries

#### Week 12: Final Validation

**Tasks**:
1. Comprehensive comparison
   - Our results vs. original NuGrid
   - Quantify differences
   - Identify causes of discrepancies

2. Documentation
   - Methods documentation
   - Parameter choices
   - Known limitations
   - Recommendations for users

3. Data products
   - Formatted yield tables
   - Model data files
   - Analysis scripts
   - Documentation

**Deliverables**:
- Complete validation report
- Reconstructed dataset
- User documentation
- Publication-ready figures

---

## Computational Requirements

### MESA Evolution Phase

**Per Model**:
- CPUs: 8-32
- Memory: 8-32 GB
- Time: 2-72 hours
- Disk: 1-5 GB

**Total (60 models)**:
- CPU-hours: ~40,000-50,000
- Peak memory: 32 GB per job
- Total disk: 100-300 GB
- Wallclock: 3-7 days (with parallel execution)

### MPPNP Post-Processing Phase

**Per Model**:
- CPUs: 16-32 (MPI parallel)
- Memory: 16-64 GB
- Time: 4-48 hours (depends on network size)
- Disk: 5-20 GB

**Total (60 models)**:
- CPU-hours: ~30,000-60,000
- Peak memory: 64 GB per job
- Total disk: 300-1000 GB
- Wallclock: 2-5 days (with parallel execution)

### Total Computational Cost

**Combined**:
- CPU-hours: ~70,000-110,000
- Peak memory: 64 GB
- Total disk: 400-1300 GB
- Wallclock: 1-3 months (including setup, debugging, validation)

**Cost estimate** (if rented on cloud):
- AWS c5.9xlarge (36 vCPU): ~$1.50/hour
- 100,000 CPU-hours ÷ 36 = 2,778 hours
- Cost: ~$4,000-$5,000 (compute only)

---

## Time Estimates

### Optimistic Timeline: 8 weeks

**Assumptions**:
- Experienced MESA user
- No major issues
- Sufficient compute resources
- Original inlists available

### Realistic Timeline: 12 weeks

**Assumptions**:
- Some learning curve
- Normal debugging
- Resource constraints
- Need to figure out some settings

### Conservative Timeline: 16-24 weeks

**Assumptions**:
- Learning MESA and MPPNP from scratch
- Resource limitations
- Significant debugging
- Need validation iterations

---

## Practical Limitations

### 1. Exact Reproducibility Challenges

**Issue**: Cannot perfectly reproduce original paper

**Reasons**:
- Exact MESA version may differ
- Compiler versions may differ
- Numerical precision differences
- Undocumented parameter choices
- Reaction rate updates

**Impact**: Results will be very similar but not identical

**Mitigation**:
- Use version control
- Document all choices
- Compare with original data
- Quantify differences

### 2. MPPNP Complexity

**Issue**: MPPNP is more complex than MESA

**Challenges**:
- Nuclear reaction network setup
- MPI configuration
- Memory requirements
- Long computation times
- Complex input/output

**Impact**: Significant learning curve

**Mitigation**:
- Use NuGrid examples
- Contact NuGrid team
- Start with simple test cases
- Use `nugrid/nudome:mppnp` image

### 3. Data Volume

**Issue**: Large amounts of data

**Challenges**:
- 400-1300 GB total storage
- File management
- Transfer times
- Backup requirements

**Impact**: Infrastructure requirements

**Mitigation**:
- Use shared filesystem
- Compress old data
- Selective output saving
- Cloud storage (if budget allows)

### 4. Validation Complexity

**Issue**: Difficult to validate all aspects

**Challenges**:
- Many models to compare
- Complex nucleosynthesis results
- Statistical variations
- Undocumented choices in original

**Impact**: Uncertainty in validation

**Mitigation**:
- Focus on key results
- Statistical comparison
- Document discrepancies
- Contact original authors

---

## Realistic Reconstruction Scope

### Fully Achievable ✅

**1. MESA Stellar Evolution Models**
- Run 60+ models matching original grid
- Get evolution tracks, lifetimes, final states
- Reproduce basic stellar evolution results
- **Timeline**: 4-6 weeks
- **Difficulty**: Medium

**2. Basic Analysis**
- HR diagrams
- Mass-lifetime relationships
- Final mass functions
- **Timeline**: 1-2 weeks
- **Difficulty**: Easy

**3. Partial Nucleosynthesis**
- Run MPPNP on subset of models
- Calculate yields for some elements
- Get basic abundance patterns
- **Timeline**: 4-6 weeks
- **Difficulty**: Hard

### Partially Achievable ⚠️

**1. Complete Nucleosynthesis**
- Full MPPNP calculation for all models
- All isotopes tracked
- Complete yield tables
- **Timeline**: 8-12 weeks
- **Difficulty**: Very Hard
- **Limitation**: May not match exactly due to network/rate updates

**2. All Paper Figures**
- Can reproduce most figures
- Some complex plots may require iteration
- **Timeline**: 2-4 weeks
- **Difficulty**: Medium
- **Limitation**: Figure aesthetics may differ

### Difficult to Achieve ❌

**1. Exact Numerical Match**
- Exact reproduction of all numbers
- **Limitation**: Numerical differences unavoidable
- **Best case**: Agreement within 1-5%

**2. Undocumented Details**
- All parameter choices
- All numerical settings
- All post-processing steps
- **Limitation**: Some information not in paper

---

## Implementation Roadmap

### Minimal Viable Reconstruction

**Goal**: Demonstrate reproducibility of key results

**Scope**:
- 10-20 selected models
- MESA evolution only (no MPPNP)
- Basic analysis (HR diagrams, lifetimes)

**Timeline**: 2-3 weeks

**Deliverables**:
- Working NuDocker+HTCondor pipeline
- Subset of models
- Comparison with original data
- Validation report

**Resource**: ~5,000 CPU-hours

### Intermediate Reconstruction

**Goal**: Reproduce main MESA results

**Scope**:
- Full 60-model grid
- MESA evolution
- Basic nucleosynthesis (limited network)
- Main paper figures

**Timeline**: 8-10 weeks

**Deliverables**:
- Complete MESA dataset
- Partial yield tables
- Main figures reproduced
- Comprehensive validation

**Resource**: ~50,000 CPU-hours

### Full Reconstruction

**Goal**: Complete reproduction

**Scope**:
- Full 60-model grid
- MESA evolution
- Complete MPPNP nucleosynthesis
- All paper figures
- Full validation

**Timeline**: 12-16 weeks

**Deliverables**:
- Complete dataset
- Full yield tables
- All figures reproduced
- Publication-quality validation
- Public data release

**Resource**: ~100,000 CPU-hours

---

## Recommendation

### For Learning/Validation: Minimal Reconstruction ✅

**Best choice if**:
- Want to learn MESA/NuDocker
- Test HTCondor infrastructure
- Validate approach
- Limited resources

**Effort**: 2-3 weeks, ~5,000 CPU-hours

### For Scientific Use: Intermediate Reconstruction ✅

**Best choice if**:
- Need stellar evolution models
- Want comparable dataset
- Have moderate resources
- Acceptable timeframe

**Effort**: 8-10 weeks, ~50,000 CPU-hours

### For Full Reproducibility: Full Reconstruction ⚠️

**Best choice if**:
- Need complete nucleosynthesis
- Want exact comparison
- Have significant resources
- Long-term project

**Effort**: 12-16 weeks, ~100,000 CPU-hours

---

## Conclusion

### Can We Reconstruct the Paper?

✅ **Yes, with realistic expectations:**

**What we CAN do**:
1. ✅ Reproduce MESA stellar evolution models
2. ✅ Match evolutionary tracks, lifetimes, final states
3. ✅ Create most figures from the paper
4. ⚠️ Calculate nucleosynthesis yields (with effort)
5. ✅ Validate computational reproducibility

**What will be DIFFERENT**:
1. Minor numerical differences (1-5%)
2. Some undocumented parameters estimated
3. Possible reaction rate updates
4. Computational environment differences

**What we CANNOT do**:
1. ❌ Exactly reproduce every number
2. ❌ Reverse-engineer all undocumented choices
3. ❌ Replicate human judgment in analysis

### Final Assessment

**Reproducibility Score**: ⭐⭐⭐⭐☆ (4/5)

**Feasibility**: ✅ **Feasible with moderate effort**

**Recommended Approach**:
1. Start with minimal reconstruction (2-3 weeks)
2. Validate approach with subset
3. Expand to intermediate reconstruction if successful
4. Consider full reconstruction only if needed for publication

**Key Success Factors**:
- Access to sufficient compute resources
- HTCondor or SLURM cluster
- 2-4 months timeline
- Willingness to contact NuGrid team for help

**Value**:
- Demonstrates reproducibility of computational astrophysics
- Validates NuDocker infrastructure
- Creates independent dataset for comparison
- Educational value in understanding stellar evolution

---

## Next Steps

### Immediate (Week 1)

1. Download original NuGrid dataset for comparison
2. Identify exact MESA version used
3. Set up single test model
4. Validate test model against original

### Short Term (Weeks 2-4)

1. Implement minimal reconstruction
2. Run 10 models
3. Compare with original
4. Document approach

### Medium Term (Weeks 5-12)

1. Expand to full MESA grid
2. Set up MPPNP
3. Run nucleosynthesis calculations
4. Reproduce main figures

### Long Term (Weeks 13+)

1. Complete validation
2. Public data release
3. Write reproducibility report
4. Contribute back to NuGrid

---

## References

1. Pignatari et al. (2016). "NuGrid Stellar Data Set. II." MNRAS, 480(1), 538-571. [arXiv:1709.08677]
2. NuGrid website: https://nugrid.github.io
3. NuGridPy: https://nugrid.github.io/NuGridPy
4. Canadian Astronomical Data Center: http://www.cadc-ccda.hia-iha.nrc-cnrc.gc.ca/
5. MESA documentation: https://docs.mesastar.org

---

**Document Version**: 1.0
**Date**: 2025-11-18
**Author**: NuDocker Enhancement Project
**Status**: Feasibility Assessment
