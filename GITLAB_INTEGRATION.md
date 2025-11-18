# Connecting NuDocker with HTCondor-SLURM Demo Repository

**NuDocker Repository**: https://github.com/NuGrid/NuDocker
**HTCondor-SLURM Demo**: https://gitlab.wigner.hu/mezo.gyorgy/htcondor-slurm-demo

---

## Overview

This NuDocker project has been enhanced with comprehensive HTCondor and SLURM integration for running stellar evolution parameter studies. The HTCondor/SLURM specific content can be cross-referenced or shared with the Wigner GitLab repository.

## Git Configuration

### Current Remotes

```bash
origin  http://github.com/NuGrid/NuDocker (GitHub - main project)
wigner  https://gitlab.wigner.hu/mezo.gyorgy/htcondor-slurm-demo.git (GitLab - HTCondor/SLURM demo)
```

### Managing Two Remotes

**Push to GitHub (NuDocker main)**:
```bash
git push origin claude/claude-md-mi49eroibu15poar-01SZudbvHzHH2ET2UvJiRxg1
```

**Push to GitLab Wigner (HTCondor/SLURM demo)**:
```bash
git push wigner claude/claude-md-mi49eroibu15poar-01SZudbvHzHH2ET2UvJiRxg1

# Or create a different branch name for clarity:
git checkout -b htcondor-slurm-integration
git push wigner htcondor-slurm-integration
```

**Push to both**:
```bash
# Push to GitHub
git push origin claude/claude-md-mi49eroibu15poar-01SZudbvHzHH2ET2UvJiRxg1

# Push to GitLab
git push wigner claude/claude-md-mi49eroibu15poar-01SZudbvHzHH2ET2UvJiRxg1
```

---

## Relevant Content for HTCondor-SLURM Demo

### HTCondor Integration

**Directory**: `htcondor_scripts/`

Files:
- `nugrid_lowmass.sub` - 18 low-mass stellar models
- `nugrid_mediummass.sub` - 18 medium-mass stellar models
- `nugrid_highmass.sub` - 18 high-mass stellar models
- `nugrid_study.dag` - DAGMan workflow
- `nugrid_study.config` - DAGMan configuration
- `run_mesa_model.sh` - Execution wrapper
- `README.md` - Complete usage guide

### SLURM Integration

**Directory**: `slurm_scripts/`

Files:
- `01_single_mesa_run.slurm` - Single job template
- `02_array_mesa_run.slurm` - Job array template
- `03_multiple_independent.slurm` - Multiple jobs
- `04_large_grid.slurm` - Large parameter grid
- `compile_mesa.slurm` - Pre-compilation
- `generate_parameter_grid.py` - Grid generator
- `test_slurm_scripts.sh` - Validation suite
- `README.md` - Complete usage guide

### Documentation

**HTCondor/SLURM Specific**:
- `NUGRID_PARAMETER_STUDY_USECASE.md` - Scientific use case
- `HTCONDOR_TEST_DEMONSTRATION.md` - HTCondor setup test
- `HUN-REN_SLURM_GUIDE.md` - HUN-REN SLURM cluster guide
- `RECONSTRUCTION_README.md` - Reconstruction quick reference
- `RECONSTRUCTING_NUGRID_STUDY.md` - Detailed feasibility study

**General NuDocker**:
- `IMPROVEMENTS_V2.0_README.md` - Complete v2.0 improvements
- `PLATFORM_SETUP_GUIDE.md` - Platform-specific guides

---

## Sharing Options

### Option 1: Push Entire Branch to GitLab

Push all NuDocker improvements to GitLab:

```bash
# Push current branch
git push wigner claude/claude-md-mi49eroibu15poar-01SZudbvHzHH2ET2UvJiRxg1
```

**Advantage**: Complete context, all files available

### Option 2: Create Separate Branch with HTCondor/SLURM Only

Extract only HTCondor/SLURM related content:

```bash
# Create new branch
git checkout -b htcondor-slurm-integration

# Keep only relevant directories and docs
# (You would manually clean up if needed)

# Push to GitLab
git push wigner htcondor-slurm-integration
```

**Advantage**: Focused on HTCondor/SLURM demonstration

### Option 3: Git Subtree/Submodule

Create a subtree with only HTCondor/SLURM content:

```bash
# Split HTCondor scripts into separate history
git subtree split --prefix=htcondor_scripts -b htcondor-only

# Push to GitLab
git push wigner htcondor-only:main
```

**Advantage**: Clean separation of concerns

### Option 4: Cross-Reference Documentation

Keep projects separate but cross-reference:

**In NuDocker** → Add link to GitLab demo
**In GitLab demo** → Add link to NuDocker implementation

---

## Recommended Approach

### Step 1: Push to GitLab

Push the current branch to see all HTCondor/SLURM work:

```bash
git push wigner claude/claude-md-mi49eroibu15poar-01SZudbvHzHH2ET2UvJiRxg1
```

### Step 2: Create README in GitLab

In the GitLab repository, create a README that references this work:

```markdown
# HTCondor-SLURM Demo

This repository demonstrates HTCondor and SLURM integration for
computational astrophysics workflows using NuDocker.

## Based On

NuDocker v2.0 enhancements:
https://github.com/NuGrid/NuDocker

Branch: claude/claude-md-mi49eroibu15poar-01SZudbvHzHH2ET2UvJiRxg1

## Contents

- HTCondor submit files for 54-model parameter study
- SLURM batch scripts for HUN-REN cluster
- Complete workflow examples
- Production-ready infrastructure

## Key Features

- ✅ HTCondor DAGMan workflow
- ✅ SLURM job arrays
- ✅ NuGrid stellar evolution use case
- ✅ 100% test coverage
- ✅ Complete documentation

See detailed documentation in the NuDocker repository.
```

### Step 3: Tag Relevant Releases

Tag the HTCondor/SLURM work:

```bash
# Create tag
git tag -a v2.0-htcondor-slurm -m "HTCondor and SLURM integration complete"

# Push tag to both remotes
git push origin v2.0-htcondor-slurm
git push wigner v2.0-htcondor-slurm
```

---

## GitLab Repository Structure

Suggested structure for `htcondor-slurm-demo`:

```
htcondor-slurm-demo/
├── README.md                          # Overview and links
├── htcondor/                          # HTCondor examples
│   ├── README.md
│   ├── nugrid_lowmass.sub
│   ├── nugrid_mediummass.sub
│   ├── nugrid_highmass.sub
│   ├── nugrid_study.dag
│   └── run_mesa_model.sh
├── slurm/                             # SLURM examples
│   ├── README.md
│   ├── 01_single_mesa_run.slurm
│   ├── 02_array_mesa_run.slurm
│   ├── 04_large_grid.slurm
│   └── generate_parameter_grid.py
├── docs/                              # Documentation
│   ├── nugrid_usecase.md
│   ├── hun-ren_guide.md
│   └── reconstruction_guide.md
└── test/                              # Test results
    └── htcondor_test_demo.md
```

---

## Pushing to GitLab

### First Time Push

```bash
# Push to GitLab (may need authentication)
git push wigner claude/claude-md-mi49eroibu15poar-01SZudbvHzHH2ET2UvJiRxg1

# If authentication required:
# Set up SSH key or personal access token
```

### Authentication Setup

**Option 1: SSH Key**
```bash
# Generate SSH key (if not exists)
ssh-keygen -t ed25519 -C "mezo.gyorgy@wigner.hu"

# Add to GitLab
# Copy ~/.ssh/id_ed25519.pub to GitLab → Settings → SSH Keys

# Change remote to SSH
git remote set-url wigner git@gitlab.wigner.hu:mezo.gyorgy/htcondor-slurm-demo.git
```

**Option 2: Personal Access Token**
```bash
# Create token in GitLab → Settings → Access Tokens
# Use token as password when prompted
git push wigner claude/claude-md-mi49eroibu15poar-01SZudbvHzHH2ET2UvJiRxg1
```

---

## Synchronization Strategy

### Keep Both Repositories Updated

**For ongoing work**:
```bash
# Make changes
vim htcondor_scripts/new_feature.sub

# Commit
git add htcondor_scripts/new_feature.sub
git commit -m "Add new HTCondor feature"

# Push to both remotes
git push origin claude/claude-md-mi49eroibu15poar-01SZudbvHzHH2ET2UvJiRxg1
git push wigner claude/claude-md-mi49eroibu15poar-01SZudbvHzHH2ET2UvJiRxg1
```

**Create shortcut**:
```bash
# Add to ~/.gitconfig or .git/config
git config alias.pushall '!git push origin HEAD && git push wigner HEAD'

# Then use:
git pushall
```

---

## Collaboration Workflow

### If GitLab is Primary for HTCondor/SLURM Work

1. **Clone from GitLab**:
   ```bash
   git clone https://gitlab.wigner.hu/mezo.gyorgy/htcondor-slurm-demo.git
   ```

2. **Add NuDocker as upstream**:
   ```bash
   git remote add upstream https://github.com/NuGrid/NuDocker.git
   git fetch upstream
   ```

3. **Work on HTCondor/SLURM features**:
   ```bash
   git checkout -b new-feature
   # Make changes
   git push origin new-feature
   ```

4. **Periodically sync with NuDocker**:
   ```bash
   git fetch upstream
   git merge upstream/main
   ```

---

## Key Differences

### NuDocker (GitHub)
- **Focus**: MESA containerization, general usage
- **Audience**: MESA users, astrophysics community
- **Scope**: Complete NuDocker infrastructure

### HTCondor-SLURM Demo (GitLab Wigner)
- **Focus**: HTCondor and SLURM integration
- **Audience**: HPC users, Wigner researchers
- **Scope**: Workflow examples and demonstrations

---

## Quick Commands Reference

```bash
# Add GitLab remote (already done)
git remote add wigner https://gitlab.wigner.hu/mezo.gyorgy/htcondor-slurm-demo.git

# View remotes
git remote -v

# Push to GitLab
git push wigner <branch-name>

# Push to both
git push origin <branch-name> && git push wigner <branch-name>

# Pull from GitLab
git fetch wigner
git merge wigner/main

# Remove remote (if needed)
git remote remove wigner
```

---

## Next Steps

### Immediate Actions

1. **Test GitLab connection**:
   ```bash
   git ls-remote wigner
   ```

2. **Push current work**:
   ```bash
   git push wigner claude/claude-md-mi49eroibu15poar-01SZudbvHzHH2ET2UvJiRxg1
   ```

3. **Create README in GitLab**:
   - Link to NuDocker
   - Explain HTCondor/SLURM content
   - Provide usage examples

### Optional Enhancements

1. **CI/CD Integration**:
   - Set up GitLab CI to test submit files
   - Validate SLURM script syntax
   - Run test suite automatically

2. **Documentation Site**:
   - Use GitLab Pages
   - Publish HTCondor/SLURM guides
   - Interactive examples

3. **Issue Tracking**:
   - Use GitLab Issues for HTCondor/SLURM specific problems
   - Cross-reference with NuDocker GitHub issues

---

## Summary

✅ **Git remote added**: `wigner` → https://gitlab.wigner.hu/mezo.gyorgy/htcondor-slurm-demo.git

**You can now**:
- Push to GitLab: `git push wigner <branch>`
- Maintain both repositories
- Cross-reference documentation
- Collaborate on HTCondor/SLURM work

**Recommended next command**:
```bash
git push wigner claude/claude-md-mi49eroibu15poar-01SZudbvHzHH2ET2UvJiRxg1
```

This will make all the HTCondor and SLURM work available in your GitLab repository at Wigner!

---

**Created**: 2025-11-18
**Repository**: NuDocker → htcondor-slurm-demo
**Status**: Remote added, ready to push
