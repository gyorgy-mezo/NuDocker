# NuGrid Parameter Study Use Case with NuDocker

**Based on**: NuGrid Stellar Data Set II ([arXiv:1709.08677](https://arxiv.org/abs/1709.08677))
**Authors**: Pignatari et al. (2016)
**Use Case**: Large-scale stellar evolution parameter space exploration

---

## Scientific Motivation

The NuGrid collaboration computed a comprehensive grid of stellar evolution models to understand nucleosynthesis across different stellar masses and metallicities. This type of parameter study is essential for:

- Understanding galactic chemical evolution
- Predicting isotopic abundances in the universe
- Calibrating stellar population synthesis models
- Constraining stellar physics (convection, mass loss, rotation)

---

## Parameter Space Definition

### Original NuGrid Study

**Mass Range**: 12 mass points
- 1, 1.65, 2, 3, 4, 5, 6, 7, 12, 15, 20, 25 M☉ (solar masses)

**Metallicity Range**: 5 metallicity values
- Z = 0.02 (solar metallicity)
- Z = 0.01 (half-solar)
- Z = 0.006 (low metallicity)
- Z = 0.001 (very low metallicity)
- Z = 0.0001 (extremely low metallicity, Population II stars)

**Total Models**: 12 × 5 = **60 stellar evolution models**

**Additional Parameters** (in full study):
- Alpha-enhanced compositions at low metallicities
- Variations in mixing length parameter
- Convective overshooting variations

### Simplified Parameter Study for This Use Case

For demonstration and testing purposes, we'll use a **reduced grid**:

**Masses**: 6 points
- 1, 2, 5, 10, 15, 20 M☉

**Metallicities**: 3 points
- Z = 0.02 (solar)
- Z = 0.01 (half-solar)
- Z = 0.001 (low metallicity)

**Additional Parameter**: Mixing length alpha
- α = 1.8, 2.0, 2.2

**Total Models**: 6 × 3 × 3 = **54 models**

---

## Computational Requirements

### MESA Parallelization Architecture

**Key Finding**: MESA uses **OpenMP** (shared-memory parallelism), **NOT MPI**

**Implications**:
- Each stellar model runs **independently** on a single compute node
- No inter-node communication required
- Perfect for **embarrassingly parallel** workloads
- Ideal for HTCondor and SLURM job arrays

### Resource Requirements Per Model

Based on typical MESA runs:

| Model Type | CPUs | Memory | Wall Time | Disk Space |
|------------|------|--------|-----------|------------|
| 1-2 M☉ | 4-8 | 4-8 GB | 1-6 hours | 500 MB - 2 GB |
| 5-10 M☉ | 8-16 | 8-16 GB | 6-24 hours | 2-5 GB |
| 15-25 M☉ | 16-32 | 16-32 GB | 24-72 hours | 5-10 GB |

**Factors Affecting Runtime**:
- Lower mass stars evolve slower (longer wall time)
- Higher mass stars have more complex physics (more memory)
- Lower metallicity can be faster or slower depending on mass
- Output frequency (saving snapshots affects disk usage)

### Total Resource Estimate (54-model grid)

**Optimistic** (if all run efficiently):
- CPU-hours: ~3,000 - 5,000
- Peak memory: 32 GB per job (for 20 M☉ models)
- Total disk space: ~150-300 GB

**Realistic** (with some failed runs, restarts):
- CPU-hours: ~5,000 - 8,000
- Peak memory: 32 GB per job
- Total disk space: ~200-400 GB

---

## HTCondor Suitability Analysis

### ✅ Excellent Match for HTCondor

#### Why HTCondor is Perfect for This Use Case:

**1. No MPI Required**
- MESA uses OpenMP (shared-memory only)
- Each model is completely independent
- HTCondor excels at independent job scheduling
- **Verdict**: ✅ Perfect fit

**2. Embarrassingly Parallel Workload**
- 54 models can run completely independently
- No communication between jobs
- HTCondor designed for exactly this scenario
- **Verdict**: ✅ Ideal use case

**3. Memory Requirements**
- Range: 4-32 GB per job
- HTCondor can match jobs to appropriate nodes
- Can specify memory requirements per job
- **Verdict**: ✅ Well-suited

**4. Heterogeneous Resource Needs**
- Different models need different resources
- 1 M☉ models: 4 CPUs, 4 GB, 2 hours
- 20 M☉ models: 32 CPUs, 32 GB, 72 hours
- HTCondor's matchmaking handles this naturally
- **Verdict**: ✅ Advantage over uniform job arrays

**5. Long-Running Jobs**
- Some models may run 24-72 hours
- HTCondor handles checkpointing
- Can restart failed jobs
- **Verdict**: ✅ Good support

**6. Docker/Singularity Support**
- HTCondor supports Docker containers
- HTCondor supports Singularity containers
- NuDocker images can run directly
- **Verdict**: ✅ Full compatibility

### ⚠️ Considerations for HTCondor

**1. Disk I/O**
- MESA writes many output files
- HTCondor transfers files back to submit node
- For 300 GB total, this is manageable
- **Solution**: Use shared filesystem (NFS, GPFS) if available

**2. Job Dependencies**
- If later analysis depends on completed models
- HTCondor DAGMan can handle dependencies
- **Solution**: Use DAGMan for workflow management

**3. Checkpointing**
- MESA supports restart from checkpoints
- HTCondor can be configured to use MESA's checkpoints
- **Solution**: Save photos (MESA snapshots) periodically

### HTCondor vs SLURM for This Use Case

| Feature | HTCondor | SLURM | Winner |
|---------|----------|-------|--------|
| Independent jobs | Excellent | Good (arrays) | HTCondor |
| Heterogeneous resources | Excellent | Limited | HTCondor |
| Matchmaking | Intelligent | Static | HTCondor |
| MPI jobs | Limited | Excellent | N/A (not needed) |
| Preemption handling | Excellent | Manual | HTCondor |
| Job priorities | Sophisticated | Good | HTCondor |
| Learning curve | Moderate | Easy | SLURM |
| HPC adoption | Rare | Dominant | SLURM |

**Conclusion**: HTCondor is **excellent** for this use case. The lack of MPI dependency and heterogeneous resource needs actually favor HTCondor over SLURM.

---

## Implementation Strategy

### Option 1: HTCondor Submission (Recommended for heterogeneous resources)

**Advantages**:
- Automatic resource matching
- Better handling of variable runtimes
- Sophisticated priority system
- Can mix with other workloads

### Option 2: SLURM Job Arrays (Recommended for HPC clusters)

**Advantages**:
- Simpler submission
- Better for homogeneous allocations
- Standard on most HPC systems
- Easier debugging

### Option 3: Hybrid Approach

**Strategy**:
- Group models by resource needs (low/medium/high mass)
- Submit 3 job arrays (or HTCondor job clusters)
- Each array has homogeneous resource requirements

---

## Parameter Grid Design

### Grid Specification

```python
# Parameter ranges
masses = [1.0, 2.0, 5.0, 10.0, 15.0, 20.0]  # Solar masses
metallicities = [0.02, 0.01, 0.001]         # Z values
alphas = [1.8, 2.0, 2.2]                     # Mixing length

# Total combinations
n_models = len(masses) * len(metallicities) * len(alphas)
# = 6 × 3 × 3 = 54 models
```

### Resource Classification

**Low-mass models** (1-2 M☉): 18 models
- CPUs: 8
- Memory: 8 GB
- Time: 6 hours
- Group: "low_mass"

**Medium-mass models** (5-10 M☉): 18 models
- CPUs: 16
- Memory: 16 GB
- Time: 24 hours
- Group: "medium_mass"

**High-mass models** (15-20 M☉): 18 models
- CPUs: 32
- Memory: 32 GB
- Time: 72 hours
- Group: "high_mass"

---

## MESA Inlist Parameters

For each model, the following MESA inlist parameters must be set:

### &star_job section
```fortran
initial_mass = 5.0              ! From parameter grid
initial_z = 0.02                ! From parameter grid
```

### &controls section
```fortran
mixing_length_alpha = 2.0       ! From parameter grid

! Evolution controls
max_age = 1d10                  ! 10 Gyr
mesh_delta_coeff = 1.0

! Output controls
history_interval = 1
profile_interval = 50
photo_interval = 100            ! For checkpointing
```

### Model-specific adjustments

**Low-mass stars (1-2 M☉)**:
- Evolve to white dwarf stage
- Longer evolution times
- AGB phase important

**High-mass stars (15-25 M☉)**:
- Evolve to core collapse
- Shorter evolution times
- Complex burning phases

---

## Expected Scientific Outputs

### Per Model

**Primary Output**:
- `history.data` - Evolution track (age, luminosity, Teff, etc.)
- `profiles/` - Stellar structure at various ages
- `photos/` - Restart files (checkpoints)

**File Sizes**:
- history.data: 10-100 MB
- profiles/: 100-500 MB (depending on frequency)
- photos/: 500 MB - 2 GB

### Grid-Level Analysis

Once all 54 models complete:

1. **HR Diagrams**: Plot evolutionary tracks in luminosity-temperature space
2. **Mass-Luminosity Relations**: Compare across metallicities
3. **Lifetime Estimates**: Total main sequence lifetimes vs mass
4. **Nucleosynthesis Yields**: Element production as function of mass/metallicity
5. **Population Synthesis**: Input for galactic chemical evolution models

---

## Implementation Comparison

### For SLURM (HPC Clusters)

**Best approach**: See existing `slurm_scripts/` in repository
- Use `04_large_grid.slurm` with 54-model grid
- Use `generate_parameter_grid.py` to create parameter file
- Pre-compile MESA with `compile_mesa.slurm`

**Pros**:
- Already implemented and tested
- Standard HPC workflow
- Good documentation

**Cons**:
- Fixed resources per job (must use maximum)
- Less efficient for heterogeneous workloads

### For HTCondor

**Best approach**: Create HTCondor submit files (need to implement)
- Use job clustering for similar resource needs
- Leverage matchmaking for optimal placement
- Use DAGMan for dependencies (optional)

**Pros**:
- Better resource efficiency
- Handles heterogeneous jobs naturally
- Sophisticated scheduling

**Cons**:
- Not yet implemented in repository
- Less common in astrophysics HPC
- Requires HTCondor-specific knowledge

---

## Next Steps

### To Prepare This Use Case

1. **Choose target cluster**: HTCondor or SLURM?

2. **For SLURM** (already ready):
   ```bash
   # Use existing scripts
   cd slurm_scripts
   python3 generate_parameter_grid.py > ../parameter_grid_54.txt
   # Edit grid generator for 54-model grid
   sbatch 04_large_grid.slurm
   ```

3. **For HTCondor** (need to implement):
   - Create HTCondor submit files
   - Create parameter management scripts
   - Set up result collection
   - Test on small subset first

4. **Create MESA work directory template**:
   - Set up inlist files with placeholders
   - Create parameter substitution script
   - Test single model first

5. **Validate one model**:
   - Pick one parameter combination
   - Run to completion
   - Verify output quality
   - Estimate actual resource usage

6. **Scale up gradually**:
   - Run 3-model test (low/medium/high mass)
   - Run 9-model test (one metallicity, all masses/alphas)
   - Run full 54-model grid

---

## Risk Mitigation

### Common Issues

**1. Models fail to converge**
- Some parameter combinations may not evolve smoothly
- MESA may require manual intervention
- **Mitigation**: Set up automatic retry with adjusted parameters

**2. Disk space exhaustion**
- 54 models × 5 GB = 270 GB minimum
- **Mitigation**: Use shared filesystem, clean old photos

**3. Memory exceeded**
- High-mass models may need more than allocated
- **Mitigation**: Set conservative memory limits, monitor

**4. Time limits exceeded**
- Some models may run longer than expected
- **Mitigation**: Use checkpointing, generous time limits

---

## Summary

### Is HTCondor Suitable?

**Answer**: ✅ **YES, EXCELLENT FIT**

**Reasons**:
1. ✅ No MPI required (MESA uses OpenMP only)
2. ✅ Embarrassingly parallel workload
3. ✅ Memory requirements well within typical node capacities (4-32 GB)
4. ✅ Heterogeneous resource needs favor HTCondor's matchmaking
5. ✅ Docker/Singularity support available
6. ✅ Long-running jobs supported with checkpointing

### Memory and MPI Dependency Check

| Requirement | MESA Characteristic | HTCondor Support | Status |
|-------------|---------------------|------------------|--------|
| MPI | Not needed (OpenMP only) | Not applicable | ✅ Perfect |
| Memory | 4-32 GB per job | Yes, per-job specification | ✅ Good |
| Shared memory | Required (OpenMP) | Yes, on single node | ✅ Good |
| Disk I/O | Moderate (GB per job) | Yes, with shared FS | ✅ Good |
| Runtime | Variable (1-72 hours) | Yes, with matchmaking | ✅ Excellent |

**Overall Assessment**: This use case is **ideally suited** for HTCondor. The lack of MPI dependency and heterogeneous resource requirements actually make HTCondor **superior** to SLURM for this specific workload.

---

## References

1. Pignatari et al. (2016). "NuGrid Stellar Data Set. II." MNRAS, 480(1), 538-571. [arXiv:1709.08677]
2. Paxton et al. (2011). "Modules for Experiments in Stellar Astrophysics (MESA)." ApJS, 192(1), 3.
3. NuDocker repository: https://github.com/NuGrid/NuDocker
4. MESA documentation: https://docs.mesastar.org

---

**Document Version**: 1.0
**Date**: 2025-11-18
**Status**: Ready for Implementation
