# NuDocker Platform Setup Guide
**Complete step-by-step instructions for running NuDocker on different platforms**
Last Updated: 2025-11-18
---
## Table of Contents
- [Linux Desktop Setup](#linux-desktop-setup)
  - [Prerequisites](#linux-prerequisites)
  - [Docker Installation](#linux-docker-installation)
  - [Post-Installation Setup](#linux-post-installation-setup)
  - [Running NuDocker](#linux-running-nudocker)
  - [Complete Example](#linux-complete-example)
  - [Troubleshooting](#linux-troubleshooting)
- [MacBook Setup](#macbook-setup)
  - [Prerequisites](#mac-prerequisites)
  - [Docker Installation](#mac-docker-installation)
  - [Running NuDocker](#mac-running-nudocker)
  - [Complete Example](#mac-complete-example)
  - [Apple Silicon Considerations](#apple-silicon-considerations)
  - [Troubleshooting](#mac-troubleshooting)
- [OpenStack Cloud Setup](#openstack-cloud-setup)
  - [Prerequisites](#openstack-prerequisites)
  - [Instance Creation](#openstack-instance-creation)
  - [Docker Installation](#openstack-docker-installation)
  - [Volume Management](#openstack-volume-management)
  - [Running NuDocker](#openstack-running-nudocker)
  - [Complete Example](#openstack-complete-example)
  - [Troubleshooting](#openstack-troubleshooting)
- [Platform Comparison](#platform-comparison)
- [Performance Tips](#performance-tips)
---
# Linux Desktop Setup
## Linux Prerequisites
### Hardware Requirements
- **Minimum**: 4 CPU cores, 8 GB RAM, 50 GB disk space
- **Recommended**: 8 CPU cores, 16 GB RAM, 100 GB disk space
- **Storage Note**: Each MESA version requires ~5-10 GB when compiled
### Software Requirements
- Linux distribution: Ubuntu 18.04+, Debian 10+, Fedora 30+, or equivalent
- Kernel version: 3.10 or higher
- Terminal access with sudo privileges
- Internet connection for downloading packages and images
### Supported Distributions
This guide covers:
- **Ubuntu/Debian-based**: Ubuntu 20.04 LTS, Ubuntu 22.04 LTS, Debian 11/12
- **RHEL/Fedora-based**: Fedora 36+, CentOS 8+, Rocky Linux 8+
- **Arch-based**: Arch Linux, Manjaro
---
## Linux Docker Installation
### Method 1: Ubuntu/Debian Installation
#### Step 1: Update System
```bash
sudo apt update
sudo apt upgrade -y
```
#### Step 2: Install Prerequisites
```bash
sudo apt install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    software-properties-common
```
#### Step 3: Add Docker Repository
```bash
# Add Docker's official GPG key
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
# Set up the repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
```
**For Debian**, replace the repository URL:
```bash
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
```
#### Step 4: Install Docker Engine
```bash
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```
#### Step 5: Verify Installation
```bash
sudo docker --version
# Expected output: Docker version 24.0.x, build xxxxxxx
sudo docker run hello-world
# Should download and run a test container
```
### Method 2: Fedora/RHEL/CentOS Installation
#### Step 1: Update System
```bash
sudo dnf update -y
```
#### Step 2: Add Docker Repository
```bash
sudo dnf -y install dnf-plugins-core
sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
```
**For CentOS/RHEL**, use:
```bash
sudo dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
```
#### Step 3: Install Docker
```bash
sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```
#### Step 4: Start Docker Service
```bash
sudo systemctl start docker
sudo systemctl enable docker
```
#### Step 5: Verify Installation
```bash
sudo docker --version
sudo docker run hello-world
```
### Method 3: Arch Linux Installation
#### Step 1: Update System
```bash
sudo pacman -Syu
```
#### Step 2: Install Docker
```bash
sudo pacman -S docker
```
#### Step 3: Start Docker Service
```bash
sudo systemctl start docker.service
sudo systemctl enable docker.service
```
#### Step 4: Verify Installation
```bash
sudo docker --version
sudo docker run hello-world
```
---
## Linux Post-Installation Setup
### Allow Non-Root Docker Access (Recommended)
By default, Docker requires root privileges. To run Docker as a regular user:
#### Step 1: Create Docker Group (if not exists)
```bash
sudo groupadd docker
```
#### Step 2: Add Your User to Docker Group
```bash
sudo usermod -aG docker $USER
```
#### Step 3: Apply Group Membership
**Option A**: Log out and log back in
**Option B**: Run this command (temporary for current shell)
```bash
newgrp docker
```
#### Step 4: Verify Non-Root Access
```bash
docker run hello-world
# Should work WITHOUT sudo
```
#### Step 5: Configure Docker to Start on Boot
```bash
sudo systemctl enable docker.service
sudo systemctl enable containerd.service
```
### Configure Docker Storage (Optional but Recommended)
Check current Docker storage location:
```bash
docker info | grep "Docker Root Dir"
```
If you have a separate disk/partition for data, configure Docker to use it:
#### Step 1: Stop Docker
```bash
sudo systemctl stop docker
```
#### Step 2: Edit Daemon Configuration
```bash
sudo mkdir -p /etc/docker
sudo nano /etc/docker/daemon.json
```
Add (replace `/mnt/docker-data` with your desired path):
```json
{
  "data-root": "/mnt/docker-data"
}
```
#### Step 3: Copy Existing Data (if any)
```bash
sudo rsync -aP /var/lib/docker/ /mnt/docker-data/
```
#### Step 4: Restart Docker
```bash
sudo systemctl start docker
docker info | grep "Docker Root Dir"
# Should show new location
```
---
## Linux Running NuDocker
### Step 1: Create Working Directory Structure
```bash
# Create directory for MESA versions
mkdir -p ~/mesa-versions
cd ~/mesa-versions
# Create directory for NuDocker
cd ~
git clone https://github.com/NuGrid/NuDocker.git
cd NuDocker
```
### Step 2: Download MESA Source Code
Choose a MESA version and corresponding Docker image:
| MESA Version | Docker Image | Download URL |
|--------------|--------------|--------------|
| r9575 | nugrid/nudome:16.0 | https://zenodo.org/records/2630796/files/mesa-r9575.zip |
| r10398 | nugrid/nudome:16.0 | https://zenodo.org/records/2603170/files/mesa-r10398.zip |
| r12778 | nugrid/nudome:20.031 | https://zenodo.org/records/3706650/files/mesa-r12778.zip |
| r22.11.1 | nugrid/nudome:20.1 | https://zenodo.org/records/7472129/files/mesa-r22.11.1.zip |
**Example: Download MESA r9575**
```bash
cd ~/mesa-versions
wget https://zenodo.org/records/2630796/files/mesa-r9575.zip
unzip mesa-r9575.zip
# Creates mesa-r9575/ directory
ls mesa-r9575/
# Should show: data/ kap/ star/ README_mesa_r9575.rst ...
```
### Step 3: Start NuDocker Container
```bash
cd ~/NuDocker
./bin/start_and_login.sh mesa-r9575 nugrid/nudome:16.0 ~/mesa-versions/mesa-r9575
```
**What happens**:
1. Docker pulls the `nugrid/nudome:16.0` image (first time only, ~1-2 GB download)
2. Creates a container named `mesa-r9575`
3. Mounts `~/mesa-versions/mesa-r9575` to `/home/user/mesa` inside container
4. Logs you into the container
**Expected output**:
```
Unable to find image 'nugrid/nudome:16.0' locally
16.0: Pulling from nugrid/nudome
...
Status: Downloaded newer image for nugrid/nudome:16.0
user@mesa-r9575:~$
```
### Step 4: Compile MESA (Inside Container)
```bash
# You are now inside the container
cd mesa
./install
# This will take 10-30 minutes depending on your CPU
# You'll see compilation progress
```
**Expected output**:
```
./install
Configuring MESA SDK...
Building MESA modules...
...
********************************************************
MESA installation was successful.
********************************************************
```
### Step 5: Run Test Suite (Inside Container)
```bash
cd $MESA_DIR/star/test_suite/7M_prems_to_AGB
./mk    # Compile test case (~2-5 minutes)
./rn    # Run simulation (~5-15 minutes)
```
**Expected output**:
```
./mk
...
test compiled successfully
./rn
...
termination code: max_age
```
### Step 6: Exit Container
```bash
exit
# You're back on your host system
```
**Important**: The container still exists in a stopped state!
### Step 7: Re-Login to Container (Later)
```bash
cd ~/NuDocker
./bin/login.sh mesa-r9575
# Back inside container, MESA still compiled
```
### Step 8: View Results (On Host System)
```bash
cd ~/mesa-versions/mesa-r9575/star/test_suite/7M_prems_to_AGB
ls LOGS/
# View output files: history.data, profiles, etc.
```
---
## Linux Complete Example
### Full Workflow: MESA r9575 on Ubuntu 22.04
```bash
# ============================================
# PART 1: SYSTEM SETUP (One-time)
# ============================================
# Update system
sudo apt update && sudo apt upgrade -y
# Install Docker
sudo apt install -y apt-transport-https ca-certificates curl gnupg lsb-release
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io
# Allow non-root Docker
sudo groupadd docker
sudo usermod -aG docker $USER
newgrp docker
# Verify Docker
docker run hello-world
# ============================================
# PART 2: SETUP NUDOCKER (One-time)
# ============================================
# Create directories
mkdir -p ~/mesa-versions
cd ~
git clone https://github.com/NuGrid/NuDocker.git
# Download MESA
cd ~/mesa-versions
wget https://zenodo.org/records/2630796/files/mesa-r9575.zip
unzip mesa-r9575.zip
# Verify download
ls mesa-r9575/
# Should show MESA source tree
# ============================================
# PART 3: RUN NUDOCKER (Every session)
# ============================================
# Start container (first time - downloads image)
cd ~/NuDocker
./bin/start_and_login.sh mesa-r9575 nugrid/nudome:16.0 ~/mesa-versions/mesa-r9575
# === NOW INSIDE CONTAINER ===
# Compile MESA (first time only, ~15 minutes)
cd mesa
./install
# Run test case
cd $MESA_DIR/star/test_suite/7M_prems_to_AGB
./mk
./rn
# Check results
ls LOGS/
cat LOGS/history.data | head -20
# Exit container
exit
# === BACK ON HOST ===
# View results on host system
cd ~/mesa-versions/mesa-r9575/star/test_suite/7M_prems_to_AGB/LOGS
ls
# Files are accessible on host!
# ============================================
# PART 4: RE-USE CONTAINER (Later sessions)
# ============================================
# Re-login to existing container
cd ~/NuDocker
./bin/login.sh mesa-r9575
# === INSIDE CONTAINER ===
# MESA already compiled, ready to use
cd $MESA_DIR/star/work
# ... do your work ...
exit
# ============================================
# PART 5: CLEANUP (When completely done)
# ============================================
# List containers
docker ps -a
# Remove specific container
docker rm mesa-r9575
# Remove Docker image (to free space)
docker rmi nugrid/nudome:16.0
# Complete cleanup (remove all containers)
docker container prune
docker image prune -a
```
### Creating a Custom MESA Run
```bash
# Start container
cd ~/NuDocker
./bin/login.sh mesa-r9575
# === INSIDE CONTAINER ===
# Create run directory
cd ~/mesa
mkdir my_5M_star
cd my_5M_star
# Copy template
cp -r $MESA_DIR/star/work/* .
# Edit parameters
nano inlist_project
# Modify initial_mass = 5.0
# Modify max_age = 1.0e10
# Compile
./mk
# Run
./rn
# Monitor progress
tail -f LOGS/out.txt
# Exit when done
exit
# === BACK ON HOST ===
# Results available on host
cd ~/mesa-versions/mesa-r9575/my_5M_star/LOGS
ls
# Analyze with your preferred tools (Python, etc.)
```
---
## Linux Troubleshooting
### Issue: Permission Denied Errors
**Symptom**:
```bash
docker: permission denied while trying to connect to the Docker daemon socket
```
**Solution**:
```bash
# Add user to docker group
sudo usermod -aG docker $USER
# Log out and back in, or:
newgrp docker
# Verify
docker run hello-world
```
### Issue: Files in Container Have Wrong Permissions
**Symptom**: Files created in container are owned by root on host, or vice versa
**Solution**:
```bash
# On host, make MESA directory world-accessible
chmod -R ugo+rwX ~/mesa-versions/mesa-r9575
# If files are owned by wrong user:
sudo chown -R $USER:$USER ~/mesa-versions/mesa-r9575
```
**Prevention**: This is a known issue on Linux. The container runs as user `user` (UID 1000), which may not match your host UID.
**Workaround**: Keep MESA source read-only in container, use `-m` option for output:
```bash
# Create output directory
mkdir -p ~/mesa-runs
# Mount it separately
cd ~/NuDocker
./bin/start_and_login.sh -m ~/mesa-runs mesa-r9575 nugrid/nudome:16.0 ~/mesa-versions/mesa-r9575
# Inside container, create runs in ~/mnt
cd ~/mnt
mkdir my_run
cp -r $MESA_DIR/star/work/* my_run/
cd my_run
./mk && ./rn
```
### Issue: Docker Daemon Not Running
**Symptom**:
```bash
Cannot connect to the Docker daemon. Is the docker daemon running?
```
**Solution**:
```bash
# Start Docker service
sudo systemctl start docker
# Check status
sudo systemctl status docker
# Enable auto-start
sudo systemctl enable docker
```
### Issue: Out of Disk Space
**Symptom**:
```bash
no space left on device
```
**Solution**:
```bash
# Check Docker disk usage
docker system df
# Remove unused containers
docker container prune
# Remove unused images
docker image prune -a
# Remove all unused data (careful!)
docker system prune -a --volumes
```
### Issue: Download Speed Very Slow
**Symptom**: Docker image or MESA download takes hours
**Solution**:
```bash
# Use a mirror or VPN if in restricted location
# For China, consider using a Docker mirror
# Configure Docker to use mirror
sudo nano /etc/docker/daemon.json
```
Add:
```json
{
  "registry-mirrors": ["https://mirror.example.com"]
}
```
```bash
sudo systemctl restart docker
```
### Issue: Container Won't Start
**Symptom**:
```bash
Error response from daemon: Conflict. The container name "/mesa-r9575" is already in use
```
**Solution**:
```bash
# List all containers
docker ps -a
# Remove conflicting container
docker rm mesa-r9575
# Or force remove
docker rm -f mesa-r9575
# Start fresh
./bin/start_and_login.sh mesa-r9575 nugrid/nudome:16.0 ~/mesa-versions/mesa-r9575
```
### Issue: MESA Compilation Fails
**Symptom**: Errors during `./install`
**Common Causes**:
1. **Wrong Docker image for MESA version**
   - Check compatibility table
   - Use correct image version
2. **Corrupted download**
   ```bash
   # Re-download MESA
   cd ~/mesa-versions
   rm -rf mesa-r9575*
   wget https://zenodo.org/records/2630796/files/mesa-r9575.zip
   unzip mesa-r9575.zip
   ```
3. **Insufficient resources**
   ```bash
   # Check available RAM
   free -h
   # Need at least 4 GB free
   # Reduce parallelism inside container
   export OMP_NUM_THREADS=2
   cd $MESA_DIR
   ./install
   ```
---
# MacBook Setup
## Mac Prerequisites
### Hardware Requirements
- **Minimum**: 4 CPU cores, 8 GB RAM, 50 GB disk space
- **Recommended**: 8 CPU cores, 16 GB RAM, 100 GB SSD
- **Note**: Apple Silicon (M1/M2/M3) will run slower due to emulation
### Software Requirements
- macOS 10.15 (Catalina) or later
- macOS 11+ recommended for Docker Desktop
- Admin privileges for installation
- Internet connection
### Check Your Mac Type
```bash
# Determine if Intel or Apple Silicon
uname -m
# x86_64 = Intel
# arm64 = Apple Silicon (M1/M2/M3)
```
---
## Mac Docker Installation
### Step 1: Download Docker Desktop
**Visit**: https://www.docker.com/products/docker-desktop/
**Choose version**:
- **Intel Mac**: Docker Desktop for Mac (Intel chip)
- **Apple Silicon**: Docker Desktop for Mac (Apple chip)
**Alternative - Direct Download**:
```bash
# Intel Mac
curl -o Docker.dmg "https://desktop.docker.com/mac/main/amd64/Docker.dmg"
# Apple Silicon Mac
curl -o Docker.dmg "https://desktop.docker.com/mac/main/arm64/Docker.dmg"
```
### Step 2: Install Docker Desktop
1. **Open the DMG file**
   ```bash
   open Docker.dmg
   ```
2. **Drag Docker to Applications**
   - Drag the Docker icon to the Applications folder
3. **Launch Docker**
   ```bash
   open /Applications/Docker.app
   ```
4. **Grant Permissions**
   - Docker will request privileged access
   - Enter your password
   - Grant permissions in System Preferences if prompted
5. **Wait for Docker to Start**
   - Docker icon appears in menu bar
   - Wait until icon is steady (not animating)
### Step 3: Verify Installation
Open Terminal (Applications → Utilities → Terminal):
```bash
# Check Docker version
docker --version
# Expected: Docker version 24.0.x, build xxxxxxx
# Test Docker
docker run hello-world
# Should download and run test container
```
### Step 4: Configure Docker Desktop (Recommended)
1. **Click Docker icon in menu bar → Settings**
2. **Resources → Advanced**:
   - **CPUs**: Allocate 4-8 cores (leave some for macOS)
   - **Memory**: Allocate 8-16 GB (leave at least 4 GB for macOS)
   - **Disk**: 100+ GB recommended
   - **Swap**: 2 GB
3. **Resources → File Sharing**:
   - Ensure your home directory is shared
   - Add additional directories if MESA will be elsewhere
4. **Click "Apply & Restart"**
---
## Mac Running NuDocker
### Step 1: Setup Directory Structure
```bash
# Open Terminal
# Create MESA directory
mkdir -p ~/mesa-versions
cd ~/mesa-versions
# Clone NuDocker
cd ~
git clone https://github.com/NuGrid/NuDocker.git
cd NuDocker
```
### Step 2: Download MESA Source
**Example: MESA r9575**
```bash
cd ~/mesa-versions
# Download using curl (macOS default)
curl -L -o mesa-r9575.zip "https://zenodo.org/records/2630796/files/mesa-r9575.zip"
# Or install and use wget
brew install wget
wget https://zenodo.org/records/2630796/files/mesa-r9575.zip
# Unzip
unzip mesa-r9575.zip
# Verify
ls mesa-r9575/
```
### Step 3: Start NuDocker Container
```bash
cd ~/NuDocker
./bin/start_and_login.sh mesa-r9575 nugrid/nudome:16.0 ~/mesa-versions/mesa-r9575
```
**First run**: Docker will download the image (~1-2 GB, 5-15 minutes)
**Subsequent runs**: Container starts immediately
**Expected prompt**:
```
user@mesa-r9575:~$
```
### Step 4: Compile MESA (Inside Container)
```bash
# Inside container
cd mesa
./install
# Compilation time:
# Intel Mac: 10-20 minutes
# Apple Silicon: 20-40 minutes (emulation)
```
### Step 5: Run Test (Inside Container)
```bash
cd $MESA_DIR/star/test_suite/7M_prems_to_AGB
./mk
./rn
```
### Step 6: Exit and Re-login
```bash
# Exit container
exit
# Re-login later
cd ~/NuDocker
./bin/login.sh mesa-r9575
```
---
## Mac Complete Example
### Full Workflow: MESA r10398 on macOS
```bash
# ============================================
# PART 1: INSTALL DOCKER (One-time)
# ============================================
# Download Docker Desktop from docker.com
# Install by dragging to Applications
# Launch Docker.app and wait for startup
# Verify in Terminal
docker --version
docker run hello-world
# ============================================
# PART 2: SETUP NUDOCKER (One-time)
# ============================================
# Create directories
mkdir -p ~/mesa-versions
cd ~
git clone https://github.com/NuGrid/NuDocker.git
# Download MESA r10398
cd ~/mesa-versions
curl -L -o mesa-r10398.zip "https://zenodo.org/records/2603170/files/mesa-r10398.zip"
unzip mesa-r10398.zip
ls mesa-r10398/  # Verify
# ============================================
# PART 3: FIRST RUN (Downloads image)
# ============================================
cd ~/NuDocker
./bin/start_and_login.sh mesa-r10398 nugrid/nudome:16.0 ~/mesa-versions/mesa-r10398
# Wait for image download (first time only)
# ~1-2 GB download
# === NOW INSIDE CONTAINER ===
# Compile MESA (first time, ~15-25 min)
cd mesa
./install
# Test compilation
cd $MESA_DIR/star/test_suite/7M_prems_to_AGB
./mk
./rn
# Exit when done
exit
# ============================================
# PART 4: DAILY USAGE
# ============================================
# Re-login to container
cd ~/NuDocker
./bin/login.sh mesa-r10398
# === INSIDE CONTAINER ===
# MESA already compiled
# Create your run directory
cd ~/mesa
mkdir my_stellar_model
cd my_stellar_model
cp -r $MESA_DIR/star/work/* .
# Edit inlists
# (use nano, vim, or edit on host with your favorite editor)
nano inlist_project
# Run
./mk
./rn
exit
# === ON HOST ===
# Access results with your Mac tools
cd ~/mesa-versions/mesa-r10398/my_stellar_model/LOGS
open .  # Opens in Finder
# Or analyze with Python, Jupyter, etc.
```
---
## Apple Silicon Considerations
### Performance Warning
**Apple Silicon Macs (M1/M2/M3) run NuDocker in emulation mode**, which is significantly slower:
- **Docker Image**: Built for `linux/amd64` (Intel architecture)
- **Your Mac**: Runs `arm64` (Apple Silicon)
- **Result**: Emulation via Rosetta 2
- **Performance**: 3-10x slower than Intel Macs
### Performance Comparison
| Task | Intel Mac | Apple Silicon | Slowdown |
|------|-----------|---------------|----------|
| MESA compile | 15 min | 30-40 min | 2-3x |
| MESA run (7M_prems_to_AGB) | 10 min | 60-120 min | 6-12x |
### Recommendations for Apple Silicon Users
**Option 1: Accept Slower Performance**
- Works correctly, just slower
- Good for learning, small test runs
- Not ideal for production research
**Option 2: Use Cloud Resources**
- Run on OpenStack (see below)
- Use HPC clusters with Apptainer
- Much faster for large runs
**Option 3: Wait for ARM Images**
- Native ARM images not yet available
- May be developed in future
- Check NuDocker repository for updates
### Checking Architecture
Inside container:
```bash
uname -m
# On Intel Mac: x86_64
# On Apple Silicon: x86_64 (emulated!)
# Check if running under emulation
sysctl sysctl.proc_translated 2>/dev/null
# 1 = running under Rosetta (emulation)
# 0 = native
```
---
## Mac Troubleshooting
### Issue: Docker Desktop Won't Start
**Symptom**: Docker icon shows error, won't start
**Solution 1: Reset Docker**
```bash
# Quit Docker completely
# Menu bar → Docker icon → Quit Docker Desktop
# Remove Docker data (will delete all containers/images!)
rm -rf ~/Library/Containers/com.docker.docker
rm -rf ~/Library/Application\ Support/Docker\ Desktop
# Restart Docker
open /Applications/Docker.app
```
**Solution 2: Check macOS Version**
- Docker Desktop requires macOS 10.15+
- Update macOS if needed
**Solution 3: Check Disk Space**
```bash
df -h
# Need at least 10 GB free
```
### Issue: "Permission Denied" in Container
**Symptom**: Cannot write files in mounted directories
**Solution**: On Mac, permissions usually work correctly. If issues occur:
```bash
# On Mac host
chmod -R 755 ~/mesa-versions/mesa-r9575
# Grant Docker full disk access (macOS Monterey+)
# System Preferences → Security & Privacy → Privacy
# → Full Disk Access → Enable Docker
```
### Issue: Very Slow Performance on Apple Silicon
**This is expected** - see [Apple Silicon Considerations](#apple-silicon-considerations)
**Mitigations**:
```bash
# Inside container, reduce parallelism
export OMP_NUM_THREADS=2
# Allocate more resources to Docker
# Docker Desktop → Settings → Resources
# Increase CPUs to 6-8
# Increase Memory to 12-16 GB
```
### Issue: Cannot Access MESA Files in Finder
**Symptom**: MESA directory empty in Finder, but works in Terminal
**Solution**: This is a macOS permission issue
```bash
# Grant Terminal full disk access
# System Preferences → Security & Privacy → Privacy
# → Full Disk Access → Add Terminal
# Or access via Terminal
cd ~/mesa-versions/mesa-r9575
open .  # Opens in Finder
```
### Issue: Docker Image Download Fails
**Symptom**: Network error during image pull
**Solution**:
```bash
# Check Docker is running
docker info
# Test network
ping docker.com
# If behind corporate firewall, configure proxy
# Docker Desktop → Settings → Resources → Proxies
# Retry pull manually
docker pull nugrid/nudome:16.0
```
### Issue: "Error response from daemon: Mounts denied"
**Symptom**: Container won't start due to mount error
**Solution**:
```bash
# Check File Sharing settings
# Docker Desktop → Settings → Resources → File Sharing
# Ensure /Users is listed
# Add your directory if needed
# Click + button → Select ~/mesa-versions
# Apply & Restart
```
### Issue: Container Exists But Can't Login
**Symptom**: `./bin/login.sh mesa-r9575` fails
**Solution**:
```bash
# Check container status
docker ps -a | grep mesa-r9575
# If exited with error, check logs
docker logs mesa-r9575
# Remove and recreate
docker rm mesa-r9575
cd ~/NuDocker
./bin/start_and_login.sh mesa-r9575 nugrid/nudome:16.0 ~/mesa-versions/mesa-r9575
```
---
# OpenStack Cloud Setup
## OpenStack Prerequisites
### What is OpenStack?
OpenStack is a cloud computing platform that provides virtual machines (instances) on-demand. Common deployments:
- **Arbutus**: Digital Research Alliance of Canada (formerly Compute Canada)
- **Jetstream2**: US academic cloud (XSEDE)
- **Private institutional clouds**: Many universities run OpenStack
### Requirements
- **OpenStack Account**: Access to an OpenStack cloud
- **Project with Resources**: Allocated VCPUs, RAM, storage, floating IPs
- **SSH Key Pair**: For secure access
- **Basic Linux Knowledge**: You'll be managing a remote Linux server
### Resource Allocation Needed
For MESA work:
- **Minimum**: 4 VCPUs, 8 GB RAM, 50 GB storage
- **Recommended**: 8 VCPUs, 16 GB RAM, 100 GB storage
- **Large runs**: 16+ VCPUs, 32+ GB RAM, 500+ GB storage
---
## OpenStack Instance Creation
### Step 1: Access OpenStack Dashboard
**Log in** to your OpenStack Horizon dashboard:
- **Arbutus**: https://arbutus.cloud.computecanada.ca
- **Jetstream2**: https://js2.jetstream-cloud.org
- **Your institution**: Ask your cloud administrator
### Step 2: Create SSH Key Pair
#### Option A: Use Existing Key
If you have an SSH key (`~/.ssh/id_rsa.pub`):
```bash
# On your local machine
cat ~/.ssh/id_rsa.pub
# Copy the output
```
In OpenStack dashboard:
1. Navigate to **Compute → Key Pairs**
2. Click **Import Public Key**
3. Name: `my-laptop-key`
4. Paste your public key
5. Click **Import Key Pair**
#### Option B: Create New Key
In OpenStack dashboard:
1. Navigate to **Compute → Key Pairs**
2. Click **Create Key Pair**
3. Name: `mesa-key`
4. Key Type: SSH Key
5. Click **Create Key Pair**
6. **Download the private key** (`mesa-key.pem`)
**Save the private key securely**:
```bash
# On your local machine
mv ~/Downloads/mesa-key.pem ~/.ssh/
chmod 600 ~/.ssh/mesa-key.pem
```
### Step 3: Create Security Group
1. Navigate to **Network → Security Groups**
2. Click **Create Security Group**
   - Name: `mesa-access`
   - Description: `SSH access for MESA work`
3. Click **Create Security Group**
4. Click **Manage Rules** on the new group
5. Click **Add Rule**:
   - Rule: SSH
   - Remote: CIDR
   - CIDR: `0.0.0.0/0` (allow from anywhere) or your IP
6. Click **Add**
**Recommended**: Add your specific IP for better security:
```bash
# Find your IP
curl ifconfig.me
# Use this IP/32 instead of 0.0.0.0/0
```
### Step 4: Launch Instance
1. Navigate to **Compute → Instances**
2. Click **Launch Instance**
**Details Tab**:
- Instance Name: `mesa-server-01`
- Description: `MESA NuDocker server`
- Count: 1
**Source Tab**:
- Select Boot Source: Image
- Create New Volume: No (for testing) or Yes (for production)
- **Choose Image**: Ubuntu 22.04 or Ubuntu 20.04
- Click ↑ arrow to select
**Flavor Tab** (choose based on needs):
- **Small**: c4-7.5gb-36 (4 VCPUs, 7.5 GB RAM)
- **Medium**: c8-15gb-75 (8 VCPUs, 15 GB RAM)
- **Large**: c16-30gb-150 (16 VCPUs, 30 GB RAM)
- Click ↑ arrow to select
**Networks Tab**:
- Select your default network (usually auto-allocated)
**Security Groups Tab**:
- Select: `mesa-access` (and `default` if needed)
**Key Pair Tab**:
- Select your key pair: `mesa-key` or `my-laptop-key`
3. Click **Launch Instance**
4. **Wait** for instance to reach **Active** status (~2-5 minutes)
### Step 5: Assign Floating IP
Your instance needs a public IP to access from internet.
1. In **Instances** list, click ▼ dropdown for your instance
2. Click **Associate Floating IP**
3. **If no IP available**:
   - Click **+** to allocate new IP
   - Pool: (select available pool)
   - Click **Allocate IP**
4. Select the floating IP
5. Click **Associate**
**Note the IP address** - you'll use this to connect (e.g., `206.167.181.123`)
### Step 6: Connect to Instance
```bash
# On your local machine
# If you created key in OpenStack:
ssh -i ~/.ssh/mesa-key.pem ubuntu@206.167.181.123
# If using existing key:
ssh ubuntu@206.167.181.123
# Replace 206.167.181.123 with your floating IP
# Username varies by image: ubuntu, debian, centos, rocky, etc.
```
**First connection**:
```
The authenticity of host '206.167.181.123' can't be established.
ECDSA key fingerprint is SHA256:...
Are you sure you want to continue connecting (yes/no/[fingerprint])? yes
```
**Expected prompt**:
```
ubuntu@mesa-server-01:~$
```
**You are now on your cloud instance!**
---
## OpenStack Docker Installation
### Step 1: Update System
```bash
# On cloud instance
sudo apt update
sudo apt upgrade -y
# Install basic tools
sudo apt install -y wget curl git unzip
```
### Step 2: Install Docker
```bash
# Add Docker repository
sudo apt install -y apt-transport-https ca-certificates curl gnupg lsb-release
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
# Install Docker
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
# Allow non-root Docker
sudo usermod -aG docker ubuntu
newgrp docker
# Verify
docker run hello-world
```
### Step 3: Setup NuDocker
```bash
# Create directories
mkdir -p ~/mesa-versions
cd ~
git clone https://github.com/NuGrid/NuDocker.git
```
---
## OpenStack Volume Management
For larger MESA installations and runs, use persistent volumes.
### Create and Attach Volume
#### In OpenStack Dashboard:
1. **Volumes → Volumes → Create Volume**:
   - Name: `mesa-data`
   - Size: 100 GB (or more)
   - Click **Create Volume**
2. **Wait** for volume status: **Available**
3. **Attach to Instance**:
   - Click ▼ dropdown on volume
   - **Manage Attachments**
   - Select instance: `mesa-server-01`
   - Click **Attach Volume**
#### On Cloud Instance:
```bash
# Check for new disk
lsblk
# Look for unformatted disk (e.g., vdb, sdb)
# Example output:
# NAME   MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
# vda    252:0    0   20G  0 disk
# └─vda1 252:1    0   20G  0 part /
# vdb    252:16   0  100G  0 disk   <-- This is your volume
# Format volume (FIRST TIME ONLY - DESTROYS DATA!)
sudo mkfs.ext4 /dev/vdb
# Create mount point
sudo mkdir -p /mnt/mesa-data
# Mount volume
sudo mount /dev/vdb /mnt/mesa-data
# Set ownership
sudo chown -R ubuntu:ubuntu /mnt/mesa-data
# Verify
df -h /mnt/mesa-data
# Make mount permanent (survives reboot)
echo '/dev/vdb /mnt/mesa-data ext4 defaults 0 2' | sudo tee -a /etc/fstab
# Test fstab
sudo mount -a
```
### Use Volume for MESA
```bash
# Move mesa-versions to volume
mv ~/mesa-versions /mnt/mesa-data/
ln -s /mnt/mesa-data/mesa-versions ~/mesa-versions
# Verify
ls ~/mesa-versions  # Should work via symlink
```
---
## OpenStack Running NuDocker
### Standard Workflow
```bash
# SSH into instance
ssh ubuntu@206.167.181.123
# Download MESA
cd ~/mesa-versions
wget https://zenodo.org/records/2630796/files/mesa-r9575.zip
unzip mesa-r9575.zip
# Start NuDocker
cd ~/NuDocker
./bin/start_and_login.sh mesa-r9575 nugrid/nudome:16.0 ~/mesa-versions/mesa-r9575
# Compile MESA
cd mesa
./install
# Run test
cd $MESA_DIR/star/test_suite/7M_prems_to_AGB
./mk
./rn
exit
```
### Long-Running Jobs
For jobs that take hours/days, use `screen` or `tmux`:
#### Using Screen
```bash
# SSH into instance
ssh ubuntu@206.167.181.123
# Start screen session
screen -S mesa-run
# Inside screen, start container
cd ~/NuDocker
./bin/login.sh mesa-r9575
# Inside container, start long run
cd $MESA_DIR/star/work
./rn
# Detach from screen: Ctrl+A, then D
# (Run continues in background)
# Close SSH connection
exit
# ===== LATER (hours/days later) =====
# SSH back in
ssh ubuntu@206.167.181.123
# Reattach to screen
screen -r mesa-run
# Check progress
# Inside container, tail output:
tail -f LOGS/out.txt
# Exit when done
exit  # from container
exit  # from screen (Ctrl+D)
```
#### Using Tmux
```bash
# Install tmux
sudo apt install -y tmux
# Start tmux session
tmux new -s mesa
# Start your work
cd ~/NuDocker
./bin/login.sh mesa-r9575
# ... do work ...
# Detach: Ctrl+B, then D
# Reattach later
tmux attach -t mesa
```
### Transferring Results to Local Machine
#### Method 1: SCP (Small Files)
```bash
# On your local machine
scp -i ~/.ssh/mesa-key.pem -r ubuntu@206.167.181.123:~/mesa-versions/mesa-r9575/star/work/LOGS ./
# Downloads LOGS directory to current location
```
#### Method 2: Rsync (Large Files, Resume Capability)
```bash
# On your local machine
# Install rsync if needed (usually pre-installed)
rsync -avz -e "ssh -i ~/.ssh/mesa-key.pem" ubuntu@206.167.181.123:~/mesa-versions/mesa-r9575/star/work/LOGS ./
# -a: archive mode (preserves permissions, timestamps)
# -v: verbose
# -z: compress during transfer
```
#### Method 3: Tar and Transfer
```bash
# On cloud instance, compress first
cd ~/mesa-versions/mesa-r9575/star/work
tar czf results.tar.gz LOGS/
# On local machine, download
scp -i ~/.ssh/mesa-key.pem ubuntu@206.167.181.123:~/mesa-versions/mesa-r9575/star/work/results.tar.gz ./
# Extract locally
tar xzf results.tar.gz
```
---
## OpenStack Complete Example
### Full Production Workflow on Arbutus Cloud
```bash
# ============================================
# PART 1: LOCAL MACHINE - SETUP ACCESS
# ============================================
# Generate SSH key if needed
ssh-keygen -t rsa -b 4096 -f ~/.ssh/arbutus-key
# Press Enter for no passphrase (or set one for security)
# Note your public key
cat ~/.ssh/arbutus-key.pub
# Copy this for OpenStack dashboard
# ============================================
# PART 2: OPENSTACK DASHBOARD - CREATE INSTANCE
# ============================================
# 1. Log into https://arbutus.cloud.computecanada.ca
# 2. Import public key (Compute → Key Pairs → Import)
# 3. Create security group (Network → Security Groups → mesa-access)
#    - Add SSH rule
# 4. Launch instance (Compute → Instances → Launch):
#    - Name: mesa-production
#    - Image: Ubuntu 22.04
#    - Flavor: c8-15gb-75 (8 cores, 15 GB RAM)
#    - Security Groups: mesa-access, default
#    - Key Pair: arbutus-key
# 5. Create volume (Volumes → Volumes → Create):
#    - Name: mesa-storage
#    - Size: 200 GB
# 6. Attach volume to instance
# 7. Associate floating IP: 206.167.181.50 (example)
# ============================================
# PART 3: INSTANCE SETUP (First Time)
# ============================================
# SSH into instance
ssh -i ~/.ssh/arbutus-key ubuntu@206.167.181.50
# Update system
sudo apt update && sudo apt upgrade -y
sudo apt install -y wget curl git unzip screen htop
# Install Docker
sudo apt install -y apt-transport-https ca-certificates curl gnupg lsb-release
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io
sudo usermod -aG docker ubuntu
newgrp docker
# Setup volume
sudo mkfs.ext4 /dev/vdb  # ONLY FIRST TIME!
sudo mkdir -p /mnt/mesa-storage
sudo mount /dev/vdb /mnt/mesa-storage
sudo chown ubuntu:ubuntu /mnt/mesa-storage
echo '/dev/vdb /mnt/mesa-storage ext4 defaults 0 2' | sudo tee -a /etc/fstab
# Setup directories
mkdir -p /mnt/mesa-storage/mesa-versions
mkdir -p /mnt/mesa-storage/mesa-runs
ln -s /mnt/mesa-storage/mesa-versions ~/mesa-versions
ln -s /mnt/mesa-storage/mesa-runs ~/mesa-runs
# Clone NuDocker
cd ~
git clone https://github.com/NuGrid/NuDocker.git
# ============================================
# PART 4: DOWNLOAD AND SETUP MESA
# ============================================
# Download MESA r12778
cd ~/mesa-versions
wget https://zenodo.org/records/3706650/files/mesa-r12778.zip
unzip mesa-r12778.zip
ls mesa-r12778/  # Verify
# Start NuDocker container
cd ~/NuDocker
./bin/start_and_login.sh -m ~/mesa-runs mesa-r12778 nugrid/nudome:20.031 ~/mesa-versions/mesa-r12778
# === INSIDE CONTAINER ===
# Set threads for 8-core instance
export OMP_NUM_THREADS=8
# Compile MESA (~8 minutes on 8-core)
cd mesa
time ./install
# Test
cd $MESA_DIR/star/test_suite/7M_prems_to_AGB
./mk
time ./rn
exit
# ============================================
# PART 5: PRODUCTION RUN
# ============================================
# Start screen session (for persistent work)
screen -S production
# Enter container
cd ~/NuDocker
./bin/login.sh mesa-r12778
# === INSIDE CONTAINER ===
# Create run directory on mounted volume
cd ~/mnt
mkdir 25M_solar_metallicity
cd 25M_solar_metallicity
# Copy work template
cp -r $MESA_DIR/star/work/* .
# Edit parameters
nano inlist_project
# Set: initial_mass = 25.0
# Set: max_age = 5e9
# Adjust: mesh_delta_coeff, time_delta_coeff, etc.
# Compile
./mk
# Start run
./rn > run.log 2>&1
# Detach from screen: Ctrl+A, then D
# ============================================
# PART 6: MONITORING (From Local Machine)
# ============================================
# SSH and check progress
ssh -i ~/.ssh/arbutus-key ubuntu@206.167.181.50
# Reattach to screen
screen -r production
# Inside screen/container, monitor:
tail -f LOGS/out.txt
# Check resource usage (open new SSH session)
ssh -i ~/.ssh/arbutus-key ubuntu@206.167.181.50
htop
docker stats
# ============================================
# PART 7: RETRIEVE RESULTS
# ============================================
# When run completes, exit container and screen
exit  # from container
exit  # from screen (Ctrl+D)
# Compress results
cd ~/mesa-runs/25M_solar_metallicity
tar czf results_25M.tar.gz LOGS/
# On local machine, download
scp -i ~/.ssh/arbutus-key ubuntu@206.167.181.50:~/mesa-runs/25M_solar_metallicity/results_25M.tar.gz ./
# Or use rsync for large files
rsync -avz --progress -e "ssh -i ~/.ssh/arbutus-key" ubuntu@206.167.181.50:~/mesa-runs/25M_solar_metallicity/LOGS/ ./25M_results/
# ============================================
# PART 8: CLEANUP (When completely done)
# ============================================
# On instance, remove containers
docker container prune -f
docker image prune -a -f
# In OpenStack dashboard:
# - Snapshot instance (for future use)
# - Detach volume (to preserve data)
# - Keep volume with all MESA data
```
---
## OpenStack Troubleshooting
### Issue: Cannot SSH into Instance
**Symptom**: Connection refused or timeout
**Check 1: Security Group**
```bash
# In OpenStack dashboard
# Network → Security Groups → mesa-access → Manage Rules
# Ensure SSH rule exists with your IP or 0.0.0.0/0
```
**Check 2: Floating IP**
```bash
# Verify floating IP is associated
# Compute → Instances → check IP column
```
**Check 3: SSH Key**
```bash
# On local machine
chmod 600 ~/.ssh/mesa-key.pem
ssh -v -i ~/.ssh/mesa-key.pem ubuntu@206.167.181.123
# -v shows verbose debug info
```
**Check 4: Username**
```bash
# Try different usernames based on image
ssh ubuntu@...    # Ubuntu images
ssh debian@...    # Debian images
ssh centos@...    # CentOS images
ssh rocky@...     # Rocky Linux images
```
### Issue: Volume Not Showing Up
**Symptom**: `lsblk` doesn't show new disk
**Solution**:
```bash
# On instance
# Rescan SCSI bus
echo "- - -" | sudo tee /sys/class/scsi_host/host*/scan
# Check again
lsblk
# Check dmesg for errors
dmesg | grep sd
```
### Issue: Out of Disk Space on Root Volume
**Symptom**: `No space left on device` on small root disk
**Solution**:
```bash
# Check usage
df -h
# Clean Docker
docker system prune -a --volumes -f
# If still full, need to attach larger volume
# Or recreate instance with larger root disk
```
### Issue: Performance Slower Than Expected
**Check 1: Verify Flavor**
```bash
# On instance
nproc  # Should match vCPU count
free -h  # Should match RAM allocation
```
**Check 2: Monitor Resources**
```bash
# Install monitoring
sudo apt install -y htop
# Run htop
htop
# Check if CPU/RAM maxed out
# Check Docker stats
docker stats
```
**Check 3: Disk I/O**
```bash
# Install iotop
sudo apt install -y iotop
# Monitor disk I/O
sudo iotop
```
### Issue: Lost Connection During Long Run
**Symptom**: SSH disconnected, unsure if job still running
**Prevention**: Always use `screen` or `tmux`!
**Recovery**:
```bash
# SSH back in
ssh ubuntu@206.167.181.123
# Check if Docker container running
docker ps
# If mesa-r12778 is listed, it's still running
# Login to container
cd ~/NuDocker
./bin/login.sh --newshell mesa-r12778
# Check process
ps aux | grep rn
# Or check output
tail -f ~/mesa/star/work/LOGS/out.txt
```
### Issue: Instance Becomes Unresponsive
**Symptom**: Cannot SSH, console access needed
**Solution**:
```bash
# In OpenStack dashboard
# Compute → Instances → mesa-production
# Click instance name → Console tab
# Click "Click here to show only console"
# Login with credentials
# Check system load
uptime
top
# If needed, reboot
sudo reboot
```
### Issue: Need to Save State Before Instance Deletion
**Create Snapshot**:
```bash
# In OpenStack dashboard
# Compute → Instances → ▼ dropdown → Create Snapshot
# Name: mesa-production-2025-11-18
# Click Create Snapshot
# Later, launch new instance from snapshot
# Compute → Images → mesa-production-2025-11-18 → Launch
```
**Detach Volume (Preserves Data)**:
```bash
# In OpenStack dashboard
# Volumes → Volumes → mesa-storage → ▼ dropdown
# Manage Attachments → Detach Volume
# Volume preserved even if instance deleted
# Attach to new instance later
```
---
# Platform Comparison
## Quick Reference Table
| Feature | Linux Desktop | MacBook (Intel) | MacBook (Apple Silicon) | OpenStack Cloud |
|---------|---------------|-----------------|------------------------|-----------------|
| **Setup Difficulty** | Easy | Very Easy | Very Easy | Moderate |
| **Performance** | Excellent | Excellent | Poor (emulated) | Excellent |
 | Free (own hardware) | Free (own hardware) | Free (own hardware) | Pay-per-use | 
 | Limited by hardware | Limited by hardware | Limited by hardware | Scale up/down | 
 | Local only | Local only | Local only | Anywhere | 
 | Permanent | Permanent | Permanent | Need volumes | 
 | Personal workstation | Mac users (Intel) | Learning only | Large runs, collaboration | 
 | 10-15 min | 10-15 min | 30-40 min | 8-12 min (8 cores) | 
 | 5-10 min | 5-10 min | 60-120 min | 3-5 min (8 cores) | 
## Recommendation by Use Case
### Learning MESA
- **Best**: Linux Desktop or MacBook (Intel)
- **Why**: Free, fast feedback, easy iteration
- **Avoid**: Apple Silicon (too slow), OpenStack (overkill)
### Production Research (Small Scale)
- **Best**: Linux Desktop
- **Why**: Fast, free, full control
- **Alternative**: MacBook Intel (if that's what you have)
### Production Research (Large Scale)
- **Best**: OpenStack Cloud
- **Why**: Scalable resources, persistent, accessible anywhere

### Collaboration & Sharing
- **Best**: OpenStack Cloud
- **Why**: Team members can access same instance, shared volumes
- **Alternative**: Linux server in your lab
### Quick Tests & Debugging
- **Best**: Whatever you have locally
- **Why**: Fast iteration, no setup overhead
### Parameter Studies (Many Runs)
- **Best**: OpenStack or HPC Cluster
- **Why**: Can launch multiple instances in parallel
- **Alternative**: Linux desktop with good specs
---
# Performance Tips
## General Optimization
### 1. Set Appropriate Thread Count
```bash
# Inside container
# Set to number of physical cores (not hyperthreads)
export OMP_NUM_THREADS=8
# Check current setting
echo $OMP_NUM_THREADS
# Find optimal number
# Linux desktop/cloud
nproc  # Total cores
# Use nproc or nproc-1
```
### 2. Docker Resource Allocation
**Mac Docker Desktop**:
- Settings → Resources → Advanced
- CPUs: Leave 2 for macOS, allocate rest
- Memory: Leave 4 GB for macOS, allocate rest
**Linux**: Docker uses all resources by default (good!)
### 3. Disk Performance
**Linux/Mac**:
- Use SSD for MESA source and runs
- Avoid networked drives (NFS, SMB) for compilation
**OpenStack**:
- Use volumes, not ephemeral storage
- Choose volume-backed instances for production
### 4. Compilation Optimization
```bash
# Inside container, before ./install
# Use all cores for compilation
export USE_PARALLEL_MAKE=1
# Number of parallel make jobs (use core count)
export MESA_MAKE_THREADS=8
./install
```
## Platform-Specific Tips
### Linux Desktop
**Optimize Docker Storage Driver**:
```bash
# Check current driver
docker info
# For SSD, overlay2 is best (usually default)
# If not overlay2, configure it
sudo nano /etc/docker/daemon.json
```
Add:
```json
{
  "storage-driver": "overlay2"
}
```
```bash
sudo systemctl restart docker
```
**Disable Swap** (if you have enough RAM):
```bash
sudo swapoff -a
# Improves performance, prevents slowdowns
```
### MacBook
**Intel Macs**:
- Allocate maximum safe resources to Docker
- Close unnecessary applications
- Use terminal, not remote tools
**Apple Silicon**:
- Accept slower performance, or use cloud
- Reduce `OMP_NUM_THREADS` to 2-4 (emulation overhead)
- Consider Docker alternatives (not currently available for MESA)
### OpenStack Cloud
**Choose Right Flavor**:
- Compute-optimized (c-series): Best for MESA
- Memory-optimized (m-series): For large memory needs
- Avoid general-purpose if c-series available
**Use Local Storage for Temp Files**:
```bash
# Inside container
export MESA_TMPDIR=/tmp
# Uses instance local disk for temporary files
```
**Multiple Instances for Parameter Studies**:
```bash
# Launch multiple instances
# Run different MESA configurations on each
# Much faster than serial runs
```
**Persistent Sessions**:
```bash
# Always use screen or tmux
# Prevents lost work on disconnection
screen -S mesa
# Do work
# Ctrl+A, D to detach
# Logout, close laptop, etc.
# Login later
ssh ubuntu@instance
screen -r mesa  # Resume exactly where you left off
```
## Monitoring Performance
### Inside Container
```bash
# Check CPU usage
top
# Press '1' to see individual cores
# Press 'q' to quit
# Check memory
free -h
# Monitor I/O
iostat -x 1
# Install if needed: apt install sysstat
```
### On Host (Linux/OpenStack)
```bash
# Install monitoring tools
sudo apt install -y htop iotop nethogs
# Interactive CPU/RAM monitor
htop
# Disk I/O monitor
sudo iotop
# Network monitor
sudo nethogs
# Docker resource usage
docker stats
```
### On Mac
```bash
# Activity Monitor (GUI)
# Applications → Utilities → Activity Monitor
# Terminal monitoring
top -o cpu
# Or install htop via Homebrew
brew install htop
htop
```
---
## Conclusion
You now have comprehensive guides for running NuDocker on:
1. **Linux Desktop**: Fast, free, full control
2. **MacBook**: Easy setup, Intel performs well
3. **OpenStack Cloud**: Scalable, accessible, production-ready
Choose the platform that best fits your needs, resources, and use case. For learning and small runs, use your local machine. For production research and large parameter studies, consider OpenStack or HPC clusters.
**Next Steps**:
1. Choose your platform
2. Follow the detailed setup guide
3. Run the complete example
4. Start your MESA research!
**Need Help?**
- NuDocker Issues: https://github.com/NuGrid/NuDocker/issues
- MESA Support: http://mesa.sourceforge.net
- OpenStack Documentation: Your cloud provider's docs
**Happy Computing!**