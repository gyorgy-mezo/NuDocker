#!/bin/bash
# Script to add htcondor-slurm-demo as a git submodule
# Run this on your local machine where you have git credentials configured

set -e

echo "================================================"
echo "Adding htcondor-slurm-demo as Git Submodule"
echo "================================================"
echo ""

# Check we're in NuDocker repo
if [ ! -d ".git" ]; then
    echo "ERROR: Must be run from NuDocker repository root"
    exit 1
fi

# Check current branch
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
echo "Current branch: $CURRENT_BRANCH"

# Recommend Claude branch
CLAUDE_BRANCH="claude/claude-md-mi49eroibu15poar-01SZudbvHzHH2ET2UvJiRxg1"
if [ "$CURRENT_BRANCH" != "$CLAUDE_BRANCH" ]; then
    echo ""
    echo "WARNING: You are not on the Claude branch"
    echo "Recommended branch: $CLAUDE_BRANCH"
    echo ""
    echo -n "Do you want to switch to Claude branch? (y/n): "
    read -r SWITCH
    if [ "$SWITCH" = "y" ]; then
        git checkout "$CLAUDE_BRANCH"
        git pull origin "$CLAUDE_BRANCH"
    fi
fi

# Choose repository source
echo ""
echo "Choose repository source:"
echo "  1) GitHub (https://github.com/gyorgy-mezo/htcondor-slurm-demo.git)"
echo "  2) GitLab Wigner (https://gitlab.wigner.hu/mezo.gyorgy/htcondor-slurm-demo.git)"
echo ""
echo -n "Enter choice (1 or 2): "
read -r CHOICE

if [ "$CHOICE" = "1" ]; then
    REPO_URL="https://github.com/gyorgy-mezo/htcondor-slurm-demo.git"
    REPO_NAME="GitHub"
elif [ "$CHOICE" = "2" ]; then
    REPO_URL="https://gitlab.wigner.hu/mezo.gyorgy/htcondor-slurm-demo.git"
    REPO_NAME="GitLab Wigner"
else
    echo "Invalid choice"
    exit 1
fi

echo ""
echo "Using: $REPO_NAME"
echo "URL: $REPO_URL"
echo ""

# Check if submodule already exists
if [ -d "htcondor-slurm-demo" ]; then
    echo "ERROR: htcondor-slurm-demo directory already exists"
    echo "Remove it first: rm -rf htcondor-slurm-demo"
    exit 1
fi

if grep -q "htcondor-slurm-demo" .gitmodules 2>/dev/null; then
    echo "ERROR: Submodule already configured in .gitmodules"
    exit 1
fi

# Add submodule
echo "Adding submodule..."
git submodule add "$REPO_URL" htcondor-slurm-demo

# Commit
echo ""
echo "Committing submodule..."
git add .gitmodules htcondor-slurm-demo

git commit -m "Add htcondor-slurm-demo as submodule

Integrates the HTCondor/SLURM demonstration repository as a git
submodule for easy reference and synchronization.

Source: $REPO_NAME
Submodule URL: $REPO_URL
Path: htcondor-slurm-demo/"

echo ""
echo "================================================"
echo "Submodule added successfully!"
echo "================================================"
echo ""
echo "Next steps:"
echo "  1. Review: git log -1"
echo "  2. Push: git push origin $CURRENT_BRANCH"
echo "  3. Explore: cd htcondor-slurm-demo && ls -la"
echo ""
echo "To update submodule later:"
echo "  cd htcondor-slurm-demo"
echo "  git pull origin main"
echo "  cd .."
echo "  git add htcondor-slurm-demo"
echo "  git commit -m 'Update submodule'"
echo ""
