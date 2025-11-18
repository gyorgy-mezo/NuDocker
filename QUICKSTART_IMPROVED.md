# NuDocker Improved Scripts - Quick Start Guide

**Get started with the improved NuDocker v2.0.0 in 5 minutes**

---

## What's Different?

The improved scripts offer:
- ✅ Better error messages
- ✅ Input validation
- ✅ Color-coded output
- ✅ Interactive modes
- ✅ Comprehensive help
- ✅ Safety checks

All while maintaining the same basic workflow!

---

## Installation (30 seconds)

```bash
# Clone repository
git clone https://github.com/NuGrid/NuDocker.git
cd NuDocker

# Make scripts executable
chmod +x bin_improved/*.sh

# Optional: Add to PATH
export PATH="$PWD/bin_improved:$PATH"

# Verify installation
./bin_improved/nudocker-start.sh --version
```

---

## First Container (3 minutes)

### Step 1: Download MESA

```bash
# Create directory
mkdir -p ~/mesa-versions
cd ~/mesa-versions

# Download MESA r9575 (example)
wget https://zenodo.org/records/2630796/files/mesa-r9575.zip
unzip mesa-r9575.zip
```

### Step 2: Validate MESA

```bash
# Check if download is valid
~/NuDocker/bin_improved/nudocker-util.sh validate ~/mesa-versions/mesa-r9575

# Should show:
# ✓ Directory exists: star
# ✓ Directory exists: data
# ✓ Install script found
# [SUCCESS] MESA installation appears valid
```

### Step 3: Start Container

```bash
cd ~/NuDocker

# Start container
./bin_improved/nudocker-start.sh \
    mesa-r9575 \
    nugrid/nudome:16.0 \
    ~/mesa-versions/mesa-r9575

# You'll see:
# [INFO] Running pre-flight checks...
# [SUCCESS] All checks passed
# [INFO] Starting container 'mesa-r9575'...
# user@mesa-r9575:~$
```

### Step 4: Compile MESA (inside container)

```bash
cd mesa
./install

# Wait 10-30 minutes for compilation
```

### Step 5: Exit Container

```bash
exit

# Container is saved, MESA is still compiled
```

---

## Daily Usage (1 minute)

### Quick Login

```bash
# Interactive mode - select from list
nudocker-login.sh

# Or specify container name
nudocker-login.sh mesa-r9575
```

### Check Status

```bash
# List all containers
nudocker-util.sh list

# Show container details
nudocker-util.sh info mesa-r9575

# System status
nudocker-util.sh status
```

---

## Common Commands

### Starting Containers

```bash
# Basic
nudocker-start.sh NAME IMAGE PATH

# With extra mount for runs
nudocker-start.sh -m ~/mesa-runs NAME IMAGE PATH

# Set thread count
nudocker-start.sh -t 8 NAME IMAGE PATH

# Verbose mode (debugging)
nudocker-start.sh -v NAME IMAGE PATH

# Get help
nudocker-start.sh --help
```

### Login to Containers

```bash
# Interactive selection
nudocker-login.sh

# Login to specific container
nudocker-login.sh NAME

# Open new shell in running container
nudocker-login.sh --newshell NAME

# List all containers
nudocker-login.sh --list
```

### Utilities

```bash
# List containers
nudocker-util.sh list

# Container details
nudocker-util.sh info NAME

# Validate MESA installation
nudocker-util.sh validate PATH

# Remove stopped containers
nudocker-util.sh clean

# Show Docker status
nudocker-util.sh status

# Pull image
nudocker-util.sh pull nugrid/nudome:20.1
```

---

## Real-World Examples

### Example 1: Quick Test Run

```bash
# Start container
nudocker-start.sh mesa-test nugrid/nudome:16.0 ~/mesa-versions/mesa-r9575

# Inside container
cd $MESA_DIR/star/test_suite/7M_prems_to_AGB
./mk && ./rn

# Exit
exit

# Login again later
nudocker-login.sh mesa-test
```

### Example 2: Production Run

```bash
# Create run directory on host
mkdir -p ~/mesa-runs

# Start with separate mount
nudocker-start.sh -m ~/mesa-runs -t 8 \
    mesa-prod nugrid/nudome:20.1 ~/mesa-versions/mesa-r22.11.1

# Inside container
cd ~/mnt/my_25M_star  # ~/mesa-runs/my_25M_star on host
cp -r $MESA_DIR/star/work/* .
# Edit inlists
./mk && ./rn

# Exit - results in ~/mesa-runs on host
exit
```

### Example 3: Multiple Versions

```bash
# Start container for r9575
nudocker-start.sh mesa-r9575 nugrid/nudome:16.0 ~/mesa-versions/mesa-r9575

# Start container for r10398
nudocker-start.sh mesa-r10398 nugrid/nudome:16.0 ~/mesa-versions/mesa-r10398

# List all
nudocker-util.sh list

# Switch between them
nudocker-login.sh mesa-r9575
# ... do work ...
exit
nudocker-login.sh mesa-r10398
# ... do work ...
exit
```

---

## Troubleshooting

### Problem: "Docker is not running"

```bash
# Start Docker Desktop (Mac)
open /Applications/Docker.app

# Start Docker service (Linux)
sudo systemctl start docker
```

### Problem: "Container already exists"

```bash
# Remove old container
docker rm CONTAINER_NAME

# Or use existing container
nudocker-login.sh CONTAINER_NAME
```

### Problem: "Path does not exist"

```bash
# Check path
ls ~/mesa-versions/mesa-r9575

# Validate MESA installation
nudocker-util.sh validate ~/mesa-versions/mesa-r9575
```

### Problem: Image not found

```bash
# Pull image first
nudocker-util.sh pull nugrid/nudome:16.0

# Or let Docker pull automatically
nudocker-start.sh mesa-r9575 nugrid/nudome:16.0 ~/mesa-versions/mesa-r9575
# (will download on first use)
```

---

## Getting Help

### Built-in Help

```bash
# Detailed help for each command
nudocker-start.sh --help
nudocker-login.sh --help
nudocker-util.sh help
```

### Available Images

```bash
# List local images
nudocker-util.sh images

# Available on Docker Hub:
nugrid/nudome:16.0     # Ubuntu 16.04, MESA SDK 20160129
nugrid/nudome:18.0     # Ubuntu 18.04, MESA SDK 20180822
nugrid/nudome:20.031   # Ubuntu 20.04, MESA SDK 20.3.1
nugrid/nudome:20.1     # Ubuntu 20.04, MESA SDK 21.4.1
```

### Documentation

- **This guide**: Quick start
- **IMPROVEMENTS.md**: Complete documentation
- **PLATFORM_SETUP_GUIDE.md**: Platform-specific setup
- **README.md**: General NuDocker info

---

## Cheat Sheet

```bash
# STARTING CONTAINERS
nudocker-start.sh NAME IMAGE PATH
nudocker-start.sh -m ~/runs NAME IMAGE PATH     # Extra mount
nudocker-start.sh -t 8 NAME IMAGE PATH          # Set threads
nudocker-start.sh --help                        # Help

# LOGGING IN
nudocker-login.sh                               # Interactive
nudocker-login.sh NAME                          # Login
nudocker-login.sh --newshell NAME               # New shell
nudocker-login.sh --list                        # List all

# UTILITIES
nudocker-util.sh list                           # List containers
nudocker-util.sh info NAME                      # Details
nudocker-util.sh validate PATH                  # Check MESA
nudocker-util.sh clean                          # Remove stopped
nudocker-util.sh status                         # System info
nudocker-util.sh pull IMAGE                     # Pull image

# DOCKER COMMANDS (if needed)
docker ps -a                                    # All containers
docker rm NAME                                  # Remove container
docker images                                   # List images
```

---

## Next Steps

1. ✅ Install NuDocker improved scripts
2. ✅ Download MESA version
3. ✅ Start container
4. ✅ Compile MESA
5. ✅ Run test case
6. Read **IMPROVEMENTS.md** for advanced features
7. Run test suite: `./tests/test_nudocker.sh`
8. Explore utility commands
9. Set up multiple MESA versions
10. Customize for your workflow

---

## What You Learned

- ✅ How to start containers with validation
- ✅ How to login interactively
- ✅ How to validate MESA installations
- ✅ How to use utility commands
- ✅ How to manage multiple containers
- ✅ How to get help

---

## Support

**Questions?**
- GitHub Issues: https://github.com/NuGrid/NuDocker/issues
- MESA Forum: http://mesastar.org
- Built-in help: `--help` flag on all commands

**Found a bug?**
- Run tests: `./tests/test_nudocker.sh`
- Report issue with output

**Want to contribute?**
- Read **IMPROVEMENTS.md**
- Submit pull request

---

**Happy Computing with NuDocker v2.0.0!**

*Improved scripts make MESA containerization easier, safer, and more user-friendly.*
