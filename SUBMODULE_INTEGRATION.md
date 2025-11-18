# Adding htcondor-slurm-demo as a Submodule

This guide explains how to integrate the `htcondor-slurm-demo` repository into NuDocker as a git submodule.

---

## What is a Git Submodule?

A git submodule allows you to keep a git repository as a subdirectory of another git repository. This lets you:
- Keep repositories separate but linked
- Track specific commits of the sub-repository
- Update independently
- Maintain separate git histories

---

## Method 1: Git Submodule (Recommended)

### Step 1: Add the Submodule

```bash
cd /path/to/NuDocker

# Checkout the Claude branch
git checkout claude/claude-md-mi49eroibu15poar-01SZudbvHzHH2ET2UvJiRxg1

# Add as submodule (choose GitHub or GitLab)
# Option A: GitHub
git submodule add https://github.com/gyorgy-mezo/htcondor-slurm-demo.git htcondor-slurm-demo

# Option B: GitLab Wigner
git submodule add https://gitlab.wigner.hu/mezo.gyorgy/htcondor-slurm-demo.git htcondor-slurm-demo
```

### Step 2: Commit the Submodule

```bash
# This creates .gitmodules file and adds the submodule
git add .gitmodules htcondor-slurm-demo
git commit -m "Add htcondor-slurm-demo as submodule"
git push origin claude/claude-md-mi49eroibu15poar-01SZudbvHzHH2ET2UvJiRxg1
```

### Step 3: Working with the Submodule

```bash
# Clone NuDocker with submodules
git clone --recursive https://github.com/gyorgy-mezo/NuDocker.git

# Or if already cloned, initialize submodules
git submodule update --init --recursive

# Update submodule to latest
cd htcondor-slurm-demo
git pull origin main
cd ..
git add htcondor-slurm-demo
git commit -m "Update htcondor-slurm-demo submodule"
```

### Repository Structure After Adding Submodule

```
NuDocker/
├── .gitmodules                    # Submodule configuration
├── bin/
├── build_docker_images/
├── infrastructure/                # HTCondor IaC (just created)
├── htcondor-slurm-demo/          # Submodule (points to your demo repo)
│   └── [contents of your demo repo]
├── LICENSE
└── README.md
```

---

## Method 2: Git Subtree (Alternative)

If you want to merge the repositories instead of linking:

```bash
# Add remote
git remote add demo-repo https://github.com/gyorgy-mezo/htcondor-slurm-demo.git
git fetch demo-repo

# Add as subtree
git subtree add --prefix=htcondor-slurm-demo demo-repo main --squash

# Later, to pull updates
git subtree pull --prefix=htcondor-slurm-demo demo-repo main --squash

# To push changes back
git subtree push --prefix=htcondor-slurm-demo demo-repo main
```

**Advantages of Subtree**:
- Simpler for collaborators (no submodule commands needed)
- Full history merged into parent repo
- Can make changes in parent repo and push back

**Disadvantages**:
- More complex merge history
- Larger repository size

---

## Method 3: Manual Copy (Simplest)

If you just want the files without git linkage:

```bash
# Clone the demo repo temporarily
git clone https://github.com/gyorgy-mezo/htcondor-slurm-demo.git /tmp/demo

# Copy into NuDocker
cp -r /tmp/demo/* htcondor-slurm-demo/
rm -rf htcondor-slurm-demo/.git  # Remove git history

# Add and commit
git add htcondor-slurm-demo/
git commit -m "Add htcondor-slurm-demo files"

# Cleanup
rm -rf /tmp/demo
```

**Disadvantages**:
- No automatic updates
- Loses git history of demo repo
- Manual synchronization required

---

## Recommended Approach

**Use Git Submodule (Method 1)** if:
- ✅ You want to keep repositories separate
- ✅ You need to update the demo repo independently
- ✅ Multiple people work on both repositories
- ✅ You want to track specific versions

**Use Git Subtree (Method 2)** if:
- ✅ You want simpler workflow for collaborators
- ✅ You plan to make changes in the NuDocker context
- ✅ You want unified history

**Use Manual Copy (Method 3)** if:
- ✅ One-time integration
- ✅ Demo repo won't change much
- ✅ Simplest possible setup

---

## Working with Submodules (Detailed)

### For Repository Maintainer (You)

```bash
# Add submodule (first time)
git submodule add <repo-url> htcondor-slurm-demo
git commit -m "Add submodule"
git push

# Update submodule to latest commit
cd htcondor-slurm-demo
git pull origin main
cd ..
git add htcondor-slurm-demo
git commit -m "Update submodule to latest"
git push

# Remove submodule (if needed)
git submodule deinit -f htcondor-slurm-demo
git rm -f htcondor-slurm-demo
rm -rf .git/modules/htcondor-slurm-demo
git commit -m "Remove submodule"
```

### For Collaborators

```bash
# Clone with submodules
git clone --recursive https://github.com/gyorgy-mezo/NuDocker.git

# Or if already cloned without --recursive
git submodule update --init --recursive

# Pull updates including submodule changes
git pull
git submodule update --recursive --remote

# Check submodule status
git submodule status
```

---

## .gitmodules File Example

After adding the submodule, `.gitmodules` will contain:

```ini
[submodule "htcondor-slurm-demo"]
    path = htcondor-slurm-demo
    url = https://github.com/gyorgy-mezo/htcondor-slurm-demo.git
    branch = main
```

---

## Integration with NuDocker Infrastructure

Once the submodule is added, you can reference it in documentation:

### Update Main README.md

```markdown
## Related Repositories

- **htcondor-slurm-demo**: Demonstration examples for HTCondor and SLURM
  - Submodule: `htcondor-slurm-demo/`
  - Repository: https://github.com/gyorgy-mezo/htcondor-slurm-demo
```

### Update infrastructure/README.md

```markdown
## Example Jobs

See the `htcondor-slurm-demo/` directory for:
- HTCondor job examples
- SLURM comparison scripts
- Performance benchmarks
```

---

## Workflow Example

### Developer Workflow

```bash
# Day 1: Add submodule
git submodule add https://github.com/gyorgy-mezo/htcondor-slurm-demo.git htcondor-slurm-demo
git commit -m "Add demo submodule"
git push

# Day 2: Work on demo repo
cd htcondor-slurm-demo
git checkout -b new-feature
# Make changes
git add .
git commit -m "Add new HTCondor example"
git push origin new-feature

# Back to NuDocker
cd ..
# NuDocker still points to old commit

# Day 3: Merge demo feature and update NuDocker
cd htcondor-slurm-demo
git checkout main
git pull
cd ..
git add htcondor-slurm-demo
git commit -m "Update demo to include new feature"
git push
```

---

## Troubleshooting

### Submodule shows modified but no changes

```bash
# Check what changed
cd htcondor-slurm-demo
git status
git diff

# Reset to committed version
git checkout .

# Or update to latest
git pull origin main
```

### Submodule not cloning for collaborators

```bash
# Ensure recursive clone
git clone --recursive <repo-url>

# Or manually initialize
git submodule update --init --recursive
```

### Detached HEAD in submodule

```bash
cd htcondor-slurm-demo
git checkout main
git pull
```

---

## Commands to Run (After You Have Auth Setup)

**On your local machine with git credentials configured:**

```bash
# Navigate to NuDocker
cd ~/NuDocker  # or wherever you have it

# Ensure you're on the Claude branch
git checkout claude/claude-md-mi49eroibu15poar-01SZudbvHzHH2ET2UvJiRxg1
git pull origin claude/claude-md-mi49eroibu15poar-01SZudbvHzHH2ET2UvJiRxg1

# Add the submodule
git submodule add https://github.com/gyorgy-mezo/htcondor-slurm-demo.git htcondor-slurm-demo

# Commit
git add .gitmodules htcondor-slurm-demo
git commit -m "Add htcondor-slurm-demo as submodule

Integrates the HTCondor/SLURM demonstration repository as a git
submodule for easy reference and synchronization.

Submodule URL: https://github.com/gyorgy-mezo/htcondor-slurm-demo.git
Path: htcondor-slurm-demo/"

# Push
git push origin claude/claude-md-mi49eroibu15poar-01SZudbvHzHH2ET2UvJiRxg1
```

Done! The submodule is now integrated.

---

## Next Steps

After adding the submodule, you may want to:

1. **Update Documentation**: Reference the demo in README files
2. **Create Symlinks**: Link demo examples into infrastructure/examples/
3. **Integration Tests**: Add tests that use demo examples
4. **CI/CD**: Setup automated testing with submodule

---

**Recommendation**: Use **Method 1 (Git Submodule)** for clean separation and easy updates.
