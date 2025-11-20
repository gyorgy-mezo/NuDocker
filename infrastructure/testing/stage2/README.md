# Stage 2: Packer Base Image Build Test
**Goal**: Verify Packer can build a custom VM image with HTCondor + SLURM components
**Resources**: 1 build VM (4 vCPU, 8 GB RAM, temporary - auto-deleted after build)
**Duration**: ~30-45 minutes
**Risk**: Low-Medium (longer build time, more components)
---
## Prerequisites
✅ Stage 0 completed (prerequisites verified)
✅ Stage 1 completed (Terraform provisioning works)
✅ Sufficient quota (4 vCPU, 8 GB RAM for build VM)
---
## What Gets Built
This Packer template creates a custom Ubuntu 22.04 image with:
- **HTCondor 23.x** - Distributed computing scheduler
- **Docker** - Container runtime for HTCondor Universe
- **Singularity 3.11.4** - HPC container system for SLURM
- **Munge** - Authentication daemon for SLURM
- **NFS client** - For shared storage mounting
- **Build tools** - gcc, make, git, etc.
- **Directory structure** - /storage, /opt/nudocker
**Image size**: ~3-4 GB
**Build time**: ~30-45 minutes (depends on network speed and VM performance)
---
## Setup
1. **Copy and customize configuration**:
   ```bash
   cd infrastructure/testing/stage2
   cp variables.pkrvars.hcl.example variables.pkrvars.hcl
   vim variables.pkrvars.hcl  # Edit with your values
   ```
2. **Required values in `variables.pkrvars.hcl`**:
   - `cloud_name`: From your `~/.config/openstack/clouds.yaml`
   - `source_image_name`: Base Ubuntu 22.04 image name
   - `flavor`: Build VM size (need ≥4 vCPU, ≥8GB RAM) - typically "m1.medium"
   - `floating_ip_network_name`: External network (usually "public")
   - `network_id`: Optional, leave as `""` to use default
---
## Execution
### Step 1: Initialize Packer
```bash
packer init nudocker-test.pkr.hcl
```
Expected output:
```
Installed plugin github.com/hashicorp/openstack
```
### Step 2: Validate template
```bash
packer validate -var-file=variables.pkrvars.hcl nudocker-test.pkr.hcl
```
Expected output:
```
The configuration is valid.
```
### Step 3: Build image
```bash
packer build -var-file=variables.pkrvars.hcl nudocker-test.pkr.hcl
```
**This will take 30-45 minutes.** You'll see:
1. **VM creation** (~2 min)
   ```
   ==> nudocker-test-stage2.openstack.nudocker_test: Creating server...
   ==> nudocker-test-stage2.openstack.nudocker_test: Waiting for server to become ready...
   ```
2. **Provisioning** (~25-40 min)
   ```
   ==> nudocker-test-stage2.openstack.nudocker_test: Waiting for cloud-init...
   ==> nudocker-test-stage2.openstack.nudocker_test: System Update
   ==> nudocker-test-stage2.openstack.nudocker_test: Installing HTCondor
   ==> nudocker-test-stage2.openstack.nudocker_test: Installing Docker
   ==> nudocker-test-stage2.openstack.nudocker_test: Installing Singularity
   ```
3. **Image creation** (~3 min)
   ```
   ==> nudocker-test-stage2.openstack.nudocker_test: Creating image...
   ==> nudocker-test-stage2.openstack.nudocker_test: Waiting for image to become ready...
   ```
4. **Cleanup** (~1 min)
   ```
   ==> nudocker-test-stage2.openstack.nudocker_test: Deleting build VM...
   Build 'nudocker-test-stage2.openstack.nudocker_test' finished.
   ```
Expected final output:
```
==> Builds finished. The artifacts of successful builds are:
--> nudocker-test-stage2.openstack.nudocker_test: An image was created: nudocker-test-stage2-YYYYMMDD-HHMM
```
### Step 4: Verify image exists
```bash
openstack --os-cloud <your-cloud-name> image list | grep nudocker-test-stage2
```
You should see your newly created image.
### Step 5: Verify image contents
```bash
chmod +x verify_image.sh
./verify_image.sh
```
This script will:
1. Find the most recently built image
2. Launch a test VM from the image
3. Allocate floating IP
4. Connect via SSH
5. Test all installed components:
   - HTCondor version
   - Docker version
   - Singularity version
   - Munge installation
   - NFS client tools
   - Directory structure
   - Build info file
6. Generate result report
7. Clean up test VM
Expected output: All 7 tests should pass ✓
### Step 6: Review results
Check the generated result file:
```bash
cat ../results/stage2_results_*.txt
```
---
## Success Criteria
- ✅ Packer build completes without errors
- ✅ Image created and visible in OpenStack
- ✅ HTCondor installed and functioning
- ✅ Docker installed and functioning
- ✅ Singularity installed and functioning
- ✅ Munge installed (for SLURM)
- ✅ NFS client tools available
- ✅ Directory structure created (/storage, /opt/nudocker)
- ✅ Build info file present
---
## Expected Results
**Result file**: `../results/stage2_results_<timestamp>.txt`
Sample result:
```
STAGE 2: PACKER BASE IMAGE BUILD TEST
======================================
IMAGE DETAILS:
--------------
Image Name: nudocker-test-stage2-20251119-1430
Base Image: Ubuntu 22.04 LTS
VERIFICATION RESULTS:
---------------------
Tests Passed: 7 / 7
✓ HTCondor: $CondorVersion: 23.10.0
✓ Docker: Docker version 24.0.7
✓ Singularity: singularity-ce version 3.11.4
✓ Munge: Installed
✓ NFS client: Installed
✓ Directories: /storage, /opt/nudocker
✓ Build info: /etc/nudocker-image-info.txt
STATUS: ✓ STAGE 2 PASSED
```
---
## Troubleshooting
### Problem: Packer build fails at "Installing HTCondor"
**Error**: `E: Unable to locate package htcondor`
**Solutions**:
```bash
# Test HTCondor repository accessibility from build VM
# The issue might be repository connectivity
# Workaround: Use specific HTCondor version
# Edit nudocker-test.pkr.hcl, change repository URL if needed
```
### Problem: Singularity compilation fails
**Error**: `make: *** [Makefile:...] Error 2`
**Solutions**:
```bash
# Increase build VM resources
# Edit variables.pkrvars.hcl:
flavor = "m1.large"  # 8 vCPU, 16 GB RAM
# Or use pre-compiled Singularity package
# Edit provisioner to use apt package instead of source build
```
### Problem: Build times out
**Error**: `Timeout waiting for SSH`
**Solutions**:
```bash
# Increase SSH timeout in nudocker-test.pkr.hcl
# Add to source block:
ssh_timeout = "15m"
# Check build VM has floating IP
# Check security group allows SSH
```
### Problem: Image verification fails
**Error**: `condor_version: command not found`
**Solutions**:
```bash
# Review Packer build logs
packer build -var-file=variables.pkrvars.hcl nudocker-test.pkr.hcl 2>&1 | tee build.log
# Check if provisioner failed but build continued
grep -i error build.log
grep -i fail build.log
# Rebuild with debug output
PACKER_LOG=1 packer build -var-file=variables.pkrvars.hcl nudocker-test.pkr.hcl
```
### Problem: "No space left on device" during build
**Solution**:
```bash
# Build VM disk is too small
# Edit nudocker-test.pkr.hcl, add to source block:
volume_size = 40  # Increase from default 20 GB
```
---
## Image Reuse
**Important**: Keep this image for subsequent testing stages!
Stages 3-7 will use this image instead of rebuilding each time.
To list your images:
```bash
openstack --os-cloud <cloud-name> image list | grep nudocker
```
To delete the image (only after all testing complete):
```bash
openstack --os-cloud <cloud-name> image delete <image-name>
```
---
## Next Stage
After successful completion:
**→ Proceed to Stage 3: Single-Node HTCondor Test**
```bash
cd ../stage3
cat README.md
```
Stage 3 will deploy a single VM using your custom image and test HTCondor job submission.
---
## Notes
- Packer automatically deletes the build VM after creating the image
- The image is stored in your OpenStack project (check quota for image storage)
- Build is idempotent - you can run it multiple times (new image each time)
- Image name includes timestamp to avoid conflicts
- All provisioners use `DEBIAN_FRONTEND=noninteractive` to avoid interactive prompts
- Singularity is built from source (no official Ubuntu 22.04 package for version 3.11.4)
- HTCondor is installed from official repository (23.x LTS series)
- Docker is installed from official Docker repository (not Ubuntu's outdated version)