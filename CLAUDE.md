# CLAUDE.md - AI Assistant Guide for NuDocker

**Last Updated**: 2025-11-18
**Repository**: NuDocker - Virtual Research Environment for Computational Nuclear and Stellar Astrophysics

---

## Table of Contents
- [Project Overview](#project-overview)
- [Repository Structure](#repository-structure)
- [Key Files and Components](#key-files-and-components)
- [Development Workflows](#development-workflows)
- [Scripts and Their Usage](#scripts-and-their-usage)
- [Build System](#build-system)
- [Code Conventions](#code-conventions)
- [Common Tasks](#common-tasks)
- [Important Notes for AI Assistants](#important-notes-for-ai-assistants)

---

## Project Overview

### Purpose
NuDocker provides Docker containerization for MESA (Modules for Experiments in Stellar Astrophysics) to enable **reproducible science** in computational nuclear and stellar astrophysics. It preserves system environments needed to run different MESA versions, going back as far as r4942 (2014).

### Key Concepts
- **MESA**: Large stellar evolution simulation code with many dependencies
- **MESA SDK**: Rich Townsend's SDK that simplifies MESA compilation
- **NuDocker Images (nudome)**: Docker images combining specific Ubuntu + MESA SDK versions
- **Containers**: Running instances where users compile and run MESA
- **Reproducibility**: Preserve exact computational environments for future replication

### Technology Stack
- **Container Runtime**: Docker (primary), Apptainer/Singularity (HPC clusters)
- **Base OS**: Ubuntu 12.04 through 20.04 (varies by image version)
- **Scripting**: Bash shell scripts
- **Build System**: GNU Make with template-based Dockerfiles
- **Version Control**: Git
- **License**: BSD 3-Clause

### Project Scope
- **In Scope**: Running MESA r4942 through latest versions, NuPPN/MPPNP applications
- **Out of Scope**: Pre-r4942 MESA versions, visualization tools (handled on host), pgplot integration
- **Platforms**: Mac OS and Linux hosts (Docker); HPC clusters (Apptainer)

---

## Repository Structure

```
/home/user/NuDocker/
├── bin/                              # User-facing shell scripts (5 files)
│   ├── start_and_login.sh           # Start new container and login
│   ├── login.sh                     # Re-login to existing container
│   ├── apptainer_mesa.sh            # Run on HPC via Apptainer
│   ├── stop_and_rm_all_dockers.sh   # Emergency cleanup (DESTRUCTIVE)
│   └── generate_readme.py           # Generate README with TOC
│
├── build_docker_images/             # Docker build system
│   ├── makefile                     # Build targets for all image versions
│   ├── Dockerfile_template          # Standard image template
│   ├── Dockerfile_template_mppnp    # MPPNP variant with HDF5/OpenMPI/NuSE
│   ├── Dockerfile_template.20       # Ubuntu 20.x specific template
│   ├── Dockerfile.20                # Pre-processed Dockerfile for 20.1
│   ├── apt_packages_nudome.txt      # Ubuntu packages to install
│   ├── dot.bash_aliases             # Bash configuration for containers
│   └── README.md                    # Build system documentation
│
├── LICENSE                          # BSD 3-Clause license
├── README.md                        # Main documentation (auto-generated)
├── README_src.md                    # Source for README generation
└── make_README_readme.md            # Instructions for README generation
```

### Directory Purposes

**`bin/`**: Production scripts for end users and cluster administrators. These are the primary interface to NuDocker functionality.

**`build_docker_images/`**: Complete build system for creating custom Docker images. Contains templates, configuration files, and build automation.

**Root Documentation**: README files provide comprehensive user guide. README.md is auto-generated from README_src.md with table of contents.

---

## Key Files and Components

### User-Facing Scripts (`bin/`)

#### `start_and_login.sh` (Primary Entry Point)
**Purpose**: Initialize and start a new Docker container for MESA development

**Usage**:
```bash
start_and_login.sh [-m /host/dir/to/mnt/for/runs] CONTAINER_NAME IMAGE_NAME MESA_PATH
```

**Arguments**:
- `CONTAINER_NAME`: Unique identifier (recommend: `mesa-rXXXX` matching MESA version)
- `IMAGE_NAME`: Docker image tag (e.g., `nugrid/nudome:16.0`)
- `MESA_PATH`: Absolute path to MESA source directory on host

**Optional**:
- `-m DIR`: Mount additional directory at `/home/user/mnt` for run outputs

**What It Does**:
1. Creates new Docker container with specified name
2. Mounts MESA source to `/home/user/mesa` inside container
3. Optionally mounts run directory to `/home/user/mnt`
4. Sets hostname to container name
5. Provides interactive bash shell

**Example**:
```bash
bin/start_and_login.sh mesa-r9575 nugrid/nudome:16.0 /Volumes/MESA/mesa-r9575
bin/start_and_login.sh -m /scratch/runs mesa-r9575 nugrid/nudome:16.0 /Volumes/MESA/mesa-r9575
```

#### `login.sh` (Re-entry Script)
**Purpose**: Re-login to existing containers (stopped or running)

**Usage**:
```bash
login.sh [--newshell] CONTAINER_NAME
login.sh --help
```

**Modes**:
- **Default**: Starts stopped container and attaches (restarts if exited)
- **`--newshell`**: Opens new bash session in already-running container
- **`--help`**: Display usage information

**Behavior**:
- Shows list of available containers if no name provided
- Handles both stopped and running containers appropriately

**Example**:
```bash
bin/login.sh mesa-r9575                # Restart and attach
bin/login.sh --newshell mesa-r9575     # New shell in running container
```

#### `apptainer_mesa.sh` (HPC Cluster Script)
**Purpose**: Run NuDocker images on HPC clusters via Apptainer/Singularity

**Key Configuration Variables** (edit before use):
```bash
SIF_IMAGE="~/apptainers/nudome_20.031.sif"     # Path to Apptainer image
MESA_SRC="~/mesa/mesa-r12778"                  # MESA source directory
SCRATCH_DIR="~/scratch"                         # Scratch space for runs
OMP_NUM_THREADS=8                               # OpenMP thread count
```

**What It Does**:
1. Mounts MESA source to `/home/user/mesa`
2. Mounts scratch directory at same path in container
3. Sets environment: `MESA_DIR`, `MESASDK_ROOT`, `OMP_NUM_THREADS`
4. Sources MESA SDK initialization
5. Changes to MESA directory and opens shell

**HPC Workflow**:
```bash
# On cluster login node
module load apptainer/1.2.2
apptainer build nudome:14.0.sif docker://nugrid/nudome:14.0

# Edit apptainer_mesa.sh with your paths
vim bin/apptainer_mesa.sh

# Launch container
./bin/apptainer_mesa.sh
```

#### `stop_and_rm_all_dockers.sh` (⚠️ DESTRUCTIVE)
**Purpose**: Emergency cleanup - stops and removes ALL Docker containers

**Command**: `docker stop $(docker ps -aq) && docker rm $(docker ps -aq)`

**WARNING**: This affects ALL containers on your system, not just NuDocker containers. Use with extreme caution.

#### `generate_readme.py`
**Purpose**: Generate README.md with table of contents from README_src.md

**Functionality**:
- Parses `##` headers (H2 level only) from README_src.md
- Generates GitHub-compatible anchor links
- Creates table of contents
- Handles duplicate anchor names with numeric suffixes
- Inserts TOC after main `#` header
- Outputs to README.md

**Usage**:
```bash
python3 bin/generate_readme.py
```

**When to Use**: After editing README_src.md to regenerate README.md

---

### Build System (`build_docker_images/`)

#### `makefile` (Build Orchestration)
**Purpose**: Build different NuDocker image versions with specific Ubuntu/MESA SDK combinations

**Available Targets**:

| Target | Ubuntu | MESA SDK | Image Tag | MESA Versions | Status |
|--------|--------|----------|-----------|---------------|---------|
| `nudome14` | 12.04 | 20141212 | nugrid/nudome:14.0 | r4942-r7624 | Deprecated |
| `nudome16` | 16.04 | 20160129 | nugrid/nudome:16.0 | r8118-r10398 | Active |
| `nudome18` | 18.04 | 20180822 | nugrid/nudome:18.0 | r10000-r12115 | Active |
| `nudome20.031` | 20.04 | 20.3.1 | nugrid/nudome:20.031a | r12778 | Active |
| `nudome20.1` | 20.04 | 21.4.1 | nugrid/nudome:20.1a | r15140, r22.x | Active |
| `numppnp` | 18.04 | 20180822 | nugrid/nudome:mppnp | MPPNP builds | Specialized |
| `nudomexx` | 20.04 | 20.3.1 | nugrid/nudome:20.031 | Template | Template |

**Build Process**:
```bash
cd build_docker_images
make nudome16           # Build specific version
make nudomexx          # Build from template (customize first)
```

**How It Works**:
1. Uses `sed` to substitute placeholders in Dockerfile templates:
   - `mm.nn` → Ubuntu version
   - `yyyymmdd` → MESA SDK version
   - `zzzzzzz` → Zenodo record ID
2. Generates concrete Dockerfile
3. Runs `docker build` with appropriate tag

**Customization**: Edit makefile variables for `nudomexx` target to create new versions

#### Dockerfile Templates

**`Dockerfile_template`** (Standard Images)

**Structure**:
1. `FROM ubuntu:mm.nn` - Base OS
2. Install packages from `apt_packages_nudome.txt`
3. Create user `user` with home `/home/user`
4. Copy `.bash_aliases` (sets up MESA environment)
5. Download MESA SDK from Zenodo
6. Extract to `/home/user/mesasdk`
7. Set user, home, and workdir

**Placeholders**:
- `mm.nn` → Ubuntu version
- `yyyymmdd` → MESA SDK version
- `zzzzzzz` → Zenodo record ID

**`Dockerfile_template_mppnp`** (MPPNP Variant)

**Additional Components**:
- **HDF5 1.8.3**: Compiled from source to `/opt/hdf5-1.8.3`
- **OpenMPI 3.0.0**: Compiled from source to `/opt/openmpi-3.0.0`
- **NuSE (NuGrid Solver Engine)**: Cloned from GitHub, built with HDF5 support

**Use Case**: Multi-zone Post-Processing Nucleosynthesis (MPPNP) calculations

**`Dockerfile_template.20`** (Ubuntu 20.x Specific)

**Differences**:
- Installs packages individually with `-y` flag (avoids geographic prompts)
- Downloads MESA SDK from `astro.wisc.edu` instead of Zenodo
- Uses `wget --user-agent=""` to avoid blocking
- Explicit package list (not file-based)

#### `apt_packages_nudome.txt`
**Purpose**: List of Ubuntu packages to install in containers

**Categories**:
- **Compilers**: gcc, gfortran, g++
- **Build Tools**: binutils, make
- **Version Control**: git, subversion
- **Editors**: emacs, nano, vim
- **Libraries**: libopenblas-dev, libopenmpi-dev, libx11-dev, zlib1g-dev
- **MPI**: openmpi-bin, openmpi-common, openmpi-doc
- **Utilities**: bzip2, less, perl, python3, rsync, ssh, tcsh, unzip, wget
- **Python**: python3, python3-virtualenv

**Modification**: Add packages as needed, one per line

#### `dot.bash_aliases`
**Purpose**: Bash configuration sourced automatically in containers

**Environment Variables**:
```bash
export MESA_DIR=~/mesa                    # Points to mounted MESA source
export MESASDK_ROOT=~/mesasdk             # MESA SDK installation
source $MESASDK_ROOT/bin/mesasdk_init.sh  # Initialize SDK environment
export OMP_NUM_THREADS=4                  # Default OpenMP parallelism
```

**Aliases**:
- `ed='emacs -nw'` - Terminal-mode emacs
- `python='python3'` - Python 3 as default

**Note**: MPPNP support can be enabled by uncommenting OpenMPI PATH export

---

## Development Workflows

### End User Workflow (Using Pre-built Images)

**Objective**: Run MESA simulations in containerized environment

**Steps**:

1. **Install Docker** on host system
   ```bash
   # Test installation
   docker run hello-world
   ```

2. **Download MESA Source**
   ```bash
   wget https://zenodo.org/records/2630796/files/mesa-r9575.zip
   unzip mesa-r9575.zip
   # Creates mesa-r9575/ directory
   ```

3. **Clone NuDocker**
   ```bash
   git clone https://github.com/NuGrid/NuDocker.git
   cd NuDocker
   ```

4. **Start Container**
   ```bash
   ./bin/start_and_login.sh mesa-r9575 nugrid/nudome:16.0 /path/to/mesa-r9575
   # Now inside container
   ```

5. **Build MESA** (inside container)
   ```bash
   cd mesa
   ./install
   # Wait for compilation (~7-30 min depending on hardware)
   ```

6. **Run Test Suite** (inside container)
   ```bash
   cd $MESA_DIR/star/test_suite/7M_prems_to_AGB
   ./mk
   ./rn
   ```

7. **Exit Container**
   ```bash
   exit
   # Container persists in stopped state
   ```

8. **Re-login Later**
   ```bash
   ./bin/login.sh mesa-r9575
   ```

9. **Cleanup When Done**
   ```bash
   docker rm mesa-r9575
   ```

### Developer Workflow (Building Custom Images)

**Objective**: Create custom Docker images with modified configurations

**Steps**:

1. **Navigate to Build Directory**
   ```bash
   cd build_docker_images
   ```

2. **Customize Package List** (optional)
   ```bash
   vim apt_packages_nudome.txt
   # Add required packages, one per line
   ```

3. **Edit Bash Configuration** (optional)
   ```bash
   vim dot.bash_aliases
   # Add custom environment variables or aliases
   ```

4. **Modify Makefile** (for new versions)
   ```bash
   vim makefile
   # Edit nudomexx target variables:
   # - UBUNTU_VERSION
   # - MESASDK_VERSION
   # - ZENODO_RECORD
   # - IMAGE_TAG
   ```

5. **Edit Dockerfile Template** (for major changes)
   ```bash
   vim Dockerfile_template
   # Add custom installation steps
   ```

6. **Build Image**
   ```bash
   make nudome16           # Existing target
   make nudomexx          # Custom target
   ```

7. **Test Image**
   ```bash
   cd ..
   ./bin/start_and_login.sh test-container my-custom-image:tag /path/to/mesa
   # Test MESA compilation and runs
   ```

8. **Tag and Push** (if sharing)
   ```bash
   docker tag my-custom-image:tag nugrid/nudome:custom-tag
   docker push nugrid/nudome:custom-tag
   ```

### HPC Cluster Workflow (Apptainer)

**Objective**: Run NuDocker on clusters without Docker support

**Prerequisites**: Cluster with Apptainer/Singularity installed

**Steps**:

1. **Load Apptainer Module**
   ```bash
   module load apptainer/1.2.2
   # Or singularity, depending on cluster
   ```

2. **Build Apptainer Image from Docker**
   ```bash
   apptainer build nudome_20.031.sif docker://nugrid/nudome:20.031
   # Downloads and converts Docker image
   # Creates .sif file (several GB)
   ```

3. **Download MESA Source** (on cluster)
   ```bash
   wget https://zenodo.org/records/xxxxx/files/mesa-r12778.zip
   unzip mesa-r12778.zip
   ```

4. **Configure Apptainer Script**
   ```bash
   vim bin/apptainer_mesa.sh
   # Edit paths:
   # - SIF_IMAGE="/path/to/nudome_20.031.sif"
   # - MESA_SRC="/path/to/mesa-r12778"
   # - SCRATCH_DIR="/scratch/username"
   # - OMP_NUM_THREADS=8 (or match allocation)
   ```

5. **Launch Container**
   ```bash
   ./bin/apptainer_mesa.sh
   # Inside container now
   ```

6. **Build and Run MESA**
   ```bash
   # Already in $MESA_DIR
   ./install
   cd star/test_suite/7M_prems_to_AGB
   ./mk && ./rn
   ```

7. **Submit Batch Jobs** (cluster-specific)
   ```bash
   # Create SLURM/PBS script that uses apptainer exec
   # Example SLURM:
   #!/bin/bash
   #SBATCH --nodes=1
   #SBATCH --ntasks-per-node=8

   module load apptainer
   apptainer exec -B $MESA_SRC:/home/user/mesa \
     nudome_20.031.sif /home/user/mesa/star/work/rn
   ```

---

## Scripts and Their Usage

### Container Lifecycle Management

**Start New Container**:
```bash
./bin/start_and_login.sh <name> <image> <mesa_path> [-m <run_dir>]
```
- Creates and enters new container
- Mounts MESA source
- Optionally mounts run directory

**Re-login to Existing Container**:
```bash
./bin/login.sh <name>              # Restart if stopped, attach
./bin/login.sh --newshell <name>   # New shell in running container
```

**List Containers**:
```bash
docker ps -a                       # All containers with status
./bin/login.sh                     # Shows available containers
```

**Remove Container**:
```bash
docker rm <name>                   # After exit
docker rm -f <name>                # Force remove running container
```

**Emergency Cleanup** (⚠️ DESTRUCTIVE):
```bash
./bin/stop_and_rm_all_dockers.sh   # Removes ALL Docker containers
```

### Documentation Management

**Regenerate README**:
```bash
cd /home/user/NuDocker
python3 bin/generate_readme.py
# Reads: README_src.md
# Writes: README.md (with TOC)
```

**Editing Process**:
1. Edit `README_src.md` (source file)
2. Run `generate_readme.py`
3. Review `README.md` (auto-generated)
4. Commit both files

### Image Building

**Build Standard Image**:
```bash
cd build_docker_images
make nudome16                      # Ubuntu 16.04, MESA SDK 20160129
make nudome18                      # Ubuntu 18.04, MESA SDK 20180822
make nudome20.1                    # Ubuntu 20.04, MESA SDK 21.4.1
```

**Build MPPNP Image**:
```bash
make numppnp                       # Includes HDF5, OpenMPI, NuSE
```

**Build Custom Image**:
```bash
# 1. Edit makefile nudomexx target
vim makefile
# 2. Build
make nudomexx
```

**Manual Build** (without makefile):
```bash
# Generate Dockerfile
sed -e 's/mm\.nn/20.04/' \
    -e 's/yyyymmdd/21.4.1/' \
    -e 's/zzzzzzz/2630796/' \
    Dockerfile_template > Dockerfile

# Build image
docker build -t custom/nudome:test .
```

---

## Code Conventions

### Shell Script Conventions

**Shebang**: All scripts use `#!/bin/bash`

**Argument Parsing**:
- Use `getopts` for single-letter flags
- Use `if [[ "$1" == "--flag" ]]` for long options
- Provide `--help` option for user-facing scripts

**Error Handling**:
- Check for required arguments
- Provide usage messages on error
- Use descriptive error messages

**Variables**:
- Uppercase for constants/configuration: `MESA_DIR`, `OMP_NUM_THREADS`
- Lowercase for local variables: `container_name`, `image_name`
- Use meaningful names

**Example Pattern** (from `login.sh`):
```bash
#!/bin/bash

# Parse arguments
if [[ "$1" == "--help" ]]; then
    echo "Usage: ..."
    exit 0
fi

newshell=false
if [[ "$1" == "--newshell" ]]; then
    newshell=true
    shift
fi

container_name="$1"

# Validate
if [[ -z "$container_name" ]]; then
    echo "Error: container name required"
    docker ps -a --format "table {{.Names}}\t{{.Status}}"
    exit 1
fi

# Execute based on mode
if $newshell; then
    docker exec -t -i "$container_name" /bin/bash
else
    docker start -i "$container_name"
fi
```

### Dockerfile Conventions

**Structure Order**:
1. `FROM` - Base image
2. Package installation
3. User creation
4. File copies (configuration)
5. Software installation (MESA SDK, etc.)
6. `USER`, `WORKDIR`, `CMD` directives

**User Setup**:
```dockerfile
RUN useradd -ms /bin/bash user
COPY --chown=user:user dot.bash_aliases /home/user/.bash_aliases
USER user
WORKDIR /home/user
```

**Cleanup**:
```dockerfile
RUN wget <url> && \
    tar xf <file> && \
    rm <file>  # Remove archives after extraction
```

**Environment**:
- Set via `.bash_aliases` (sourced at login)
- Not via `ENV` directives (allows user override)

### Makefile Conventions

**Target Naming**: `nudome<version>` (e.g., `nudome16`, `nudome20.1`)

**Variable Naming**: Descriptive, uppercase
- `UBUNTU_VERSION`, `MESASDK_VERSION`, `ZENODO_RECORD`, `IMAGE_TAG`

**Pattern**:
```makefile
nudome16:
    sed -e 's/mm\.nn/16.04/' \
        -e 's/yyyymmdd/20160129/' \
        -e 's/zzzzzzz/2603154/' \
        Dockerfile_template > Dockerfile
    docker build -t nugrid/nudome:16.0 .
```

**Comments**: Explain version numbers and purposes

### Python Conventions

**Shebang**: `#!/usr/bin/env python3`

**Style**: Follow PEP 8 conventions (as seen in `generate_readme.py`)

**Documentation**: Inline comments for complex logic

**Pattern** (anchor generation):
```python
def generate_anchor(title):
    """Convert title to GitHub-compatible anchor"""
    anchor = title.lower()
    anchor = re.sub(r'[^\w\s-]', '', anchor)  # Remove special chars
    anchor = re.sub(r'\s+', '-', anchor)       # Spaces to hyphens
    return anchor
```

---

## Common Tasks

### Task: Run MESA Version X in Container

**Choose Image**:
- r4942-r7624: `nugrid/nudome:14.0` (Ubuntu 12.04, deprecated)
- r8118-r10398: `nugrid/nudome:16.0` (Ubuntu 16.04)
- r10000-r12115: `nugrid/nudome:18.0` (Ubuntu 18.04)
- r12778: `nugrid/nudome:20.031` (Ubuntu 20.04)
- r15140, r22.x: `nugrid/nudome:20.1` (Ubuntu 20.04)

**Steps**:
```bash
# 1. Download MESA
wget https://zenodo.org/records/<record>/files/mesa-r<version>.zip
unzip mesa-r<version>.zip

# 2. Start container
./bin/start_and_login.sh mesa-r<version> nugrid/nudome:<image_version> /path/to/mesa-r<version>

# 3. Build MESA (inside container)
cd mesa
./install

# 4. Run test
cd star/test_suite/7M_prems_to_AGB
./mk && ./rn
```

### Task: Add Custom Ubuntu Package to Image

**Steps**:
```bash
# 1. Edit package list
cd build_docker_images
vim apt_packages_nudome.txt
# Add package name on new line

# 2. Rebuild image
make nudome<version>

# 3. Test
cd ..
./bin/start_and_login.sh test-container nugrid/nudome:<version> /path/to/mesa
# Inside container:
dpkg -l | grep <package_name>  # Verify installation
```

### Task: Set Custom Environment Variables

**Method 1: Modify Image**
```bash
# Edit dot.bash_aliases
cd build_docker_images
vim dot.bash_aliases
# Add: export MY_VAR=value

# Rebuild image
make nudome<version>
```

**Method 2: At Runtime**
```bash
# Inside container
echo 'export MY_VAR=value' >> ~/.bashrc
source ~/.bashrc
```

**Method 3: Docker Run Arguments** (advanced)
```bash
# Modify start_and_login.sh
# Add to docker run command:
-e MY_VAR=value
```

### Task: Change OpenMP Thread Count

**Temporary (Current Session)**:
```bash
# Inside container
export OMP_NUM_THREADS=8
```

**Permanent (Modify Image)**:
```bash
cd build_docker_images
vim dot.bash_aliases
# Change: export OMP_NUM_THREADS=8
make nudome<version>
```

**Per-Run**:
```bash
# Inside container
OMP_NUM_THREADS=16 ./rn
```

### Task: Mount Multiple Host Directories

**Scenario**: MESA source in one location, run directories in another

**Solution**:
```bash
./bin/start_and_login.sh -m /scratch/runs mesa-r9575 nugrid/nudome:16.0 /code/mesa-r9575
# Inside container:
# /home/user/mesa -> /code/mesa-r9575 (host)
# /home/user/mnt  -> /scratch/runs (host)
```

**Create Run Directory**:
```bash
# Inside container
mkdir ~/mnt/my_run
cd ~/mnt/my_run
cp -r $MESA_DIR/star/work/* .
./mk && ./rn
```

### Task: Share Containers Across Users

**Not Recommended**: Docker containers are user-specific

**Alternative**: Share Docker Image
```bash
# User 1: Save image
docker save nugrid/nudome:16.0 | gzip > nudome_16.tar.gz

# User 2: Load image
gunzip -c nudome_16.tar.gz | docker load

# Both users create their own containers
./bin/start_and_login.sh my-mesa-r9575 nugrid/nudome:16.0 /my/path/mesa-r9575
```

### Task: Run MESA on HPC Cluster

**See**: [HPC Cluster Workflow](#hpc-cluster-workflow-apptainer) section above

**Quick Reference**:
```bash
module load apptainer
apptainer build nudome.sif docker://nugrid/nudome:20.031
# Edit bin/apptainer_mesa.sh with paths
./bin/apptainer_mesa.sh
```

### Task: Debug Container Issues

**Check Container Status**:
```bash
docker ps -a                          # List all containers
docker logs <container_name>          # View container logs
docker inspect <container_name>       # Detailed info
```

**Enter Stopped Container** (for inspection):
```bash
docker start <container_name>
docker exec -it <container_name> /bin/bash
```

**Check Mounts**:
```bash
# Inside container
mount | grep /home/user              # Verify mounts
ls -la $MESA_DIR                     # Check MESA source
```

**Permission Issues** (Linux hosts):
```bash
# On host
chmod -R ugo+rwX /path/to/mesa-r<version>
# Then restart container
```

**Reset Container** (if corrupted):
```bash
docker rm <container_name>
./bin/start_and_login.sh <container_name> <image> <mesa_path>
```

### Task: Update README Documentation

**Workflow**:
```bash
# 1. Edit source file
vim README_src.md

# 2. Regenerate README
python3 bin/generate_readme.py

# 3. Review changes
git diff README.md

# 4. Commit both files
git add README_src.md README.md
git commit -m "Update documentation: <description>"
```

**Note**: Never edit `README.md` directly - it's auto-generated

---

## Important Notes for AI Assistants

### Critical Understanding Points

1. **Two-Level System**:
   - **Docker Images**: Templates (blueprints) - built once, reused many times
   - **Containers**: Instances (running environments) - created per MESA version/project
   - Don't confuse images and containers

2. **Volume Mounting Pattern**:
   - MESA source is **mounted**, not copied into containers
   - Changes in container appear on host immediately
   - Changes on host appear in container immediately
   - Container deletion does NOT delete MESA source

3. **Container Persistence**:
   - Exiting container (`exit`) stops it but preserves state
   - Can re-login multiple times with `login.sh`
   - Only `docker rm` permanently deletes container
   - Compiled MESA binaries persist across logins

4. **MESA SDK Environment**:
   - Automatically configured via `.bash_aliases`
   - Sourced on every login
   - Sets `MESA_DIR`, `MESASDK_ROOT`
   - Configures compilers, libraries, paths

5. **Version Compatibility**:
   - Different MESA versions require different MESA SDK versions
   - Different MESA SDK versions require different Ubuntu versions
   - Check compatibility table in README before choosing image

### Code Modification Guidelines

**When Modifying Shell Scripts**:
- Test with `bash -n <script>` before committing (syntax check)
- Preserve existing argument parsing patterns
- Maintain backward compatibility
- Add `--help` support for new user-facing scripts
- Document changes in comments

**When Modifying Dockerfiles**:
- Test build locally before committing
- Keep images minimal (avoid unnecessary packages)
- Clean up artifacts (remove downloaded archives)
- Preserve user creation and permission patterns
- Don't add `ENV` directives - use `.bash_aliases` instead

**When Modifying Makefile**:
- Follow existing target naming conventions
- Test build with `make -n <target>` first (dry run)
- Verify `sed` substitutions produce valid Dockerfile
- Update README with new version information

**When Modifying Configuration Files**:
- `apt_packages_nudome.txt`: One package per line, no comments
- `dot.bash_aliases`: Test in container before committing
- Avoid breaking existing environment assumptions

### Common Pitfalls to Avoid

1. **Don't Edit README.md Directly**
   - Always edit `README_src.md`
   - Run `generate_readme.py` to update `README.md`

2. **Don't Add .gitignore Carelessly**
   - Project currently has no .gitignore
   - Adding one could break existing workflows
   - Consult maintainers first

3. **Don't Use Root User in Containers**
   - All containers use non-root user `user`
   - Essential for permission compatibility with host
   - Never change to `USER root` in Dockerfiles

4. **Don't Break Volume Mount Paths**
   - `/home/user/mesa` is expected by many scripts
   - `/home/user/mnt` is optional but standard
   - Changing these breaks user expectations

5. **Don't Mix Image Versions**
   - Each MESA version has tested/recommended image
   - Using wrong image may cause compilation failures
   - Check compatibility table first

6. **Don't Forget HPC Use Case**
   - Changes must work for both Docker and Apptainer
   - Test Apptainer conversion if modifying Dockerfiles
   - Consider non-Docker users

7. **Don't Assume Docker-Only**
   - Many users on HPC clusters use Apptainer
   - `apptainer_mesa.sh` must remain functional
   - Test both Docker and Apptainer workflows

### Testing Checklist

**Before Committing Script Changes**:
- [ ] Syntax check: `bash -n <script>`
- [ ] Test with valid arguments
- [ ] Test with missing arguments (error handling)
- [ ] Test `--help` flag (if applicable)
- [ ] Test on both macOS and Linux (if possible)

**Before Committing Dockerfile Changes**:
- [ ] Test build: `docker build -t test-image .`
- [ ] Test container creation
- [ ] Test MESA compilation inside container
- [ ] Test volume mounting
- [ ] Verify environment variables set correctly
- [ ] Check image size (avoid bloat)

**Before Committing Documentation**:
- [ ] Edit `README_src.md`, not `README.md`
- [ ] Run `generate_readme.py`
- [ ] Verify TOC generated correctly
- [ ] Check for broken links
- [ ] Verify markdown formatting

### Performance Considerations

**Build Times**:
- Docker image builds: 10-30 minutes (download + package installation)
- MESA compilation: 7-30 minutes (depends on hardware, version)
- Apptainer image conversion: 5-15 minutes (download + convert)

**Disk Space**:
- Docker images: 1-3 GB each
- Apptainer .sif files: 1-3 GB each
- MESA source: 100-500 MB per version
- Compiled MESA: 1-5 GB per version

**Runtime Performance**:
- Docker on Intel/AMD: Native speed or 5-10% faster
- Docker on Apple Silicon: Significantly slower (emulation)
- Apptainer on clusters: Near-native performance

### Architecture Notes

**Apple Silicon (M1/M2) Issues**:
- NuDocker uses `linux/amd64` images
- Runs in emulation on ARM (slow)
- No native ARM images available
- Performance penalty: 3-10x slower
- Recommend Intel/AMD hardware for production use

**Linux Hosts**:
- May require permission adjustments: `chmod -R ugo+rwX mesa-dir`
- User ID mismatches can cause file ownership issues
- Test mounted directory access carefully

**macOS Hosts**:
- Generally works well on Intel Macs
- Slower on Apple Silicon
- Volume mounting permissions usually correct

### Security Considerations

**Non-Root User**:
- Containers run as user `user` (UID typically 1000)
- Improves security
- Prevents accidental host system modification
- Maintains file permission compatibility

**Volume Mounting**:
- Mounted directories accessible to container user
- Changes persist to host
- Be careful with destructive operations
- Consider using `-m` for run directories (isolate output)

**Container Isolation**:
- Containers isolated from each other
- Containers isolated from host (except mounted volumes)
- Network access available (for downloads, etc.)

### Git Workflow Notes

**Current Branch**: `claude/claude-md-mi49eroibu15poar-01SZudbvHzHH2ET2UvJiRxg1`

**Main Branch**: (upstream main branch for PRs)

**Commit Message Style** (infer from history):
- Descriptive, imperative mood
- Examples: "Add numppnp build target", "Fix .bash_aliases file ownership"
- Include context if non-obvious

**Pull Request Process**:
- Develop on Claude branch
- Test thoroughly
- Create PR to main branch when ready
- Include description of changes and rationale

### Documentation Philosophy

**User-Facing Documentation** (README):
- Comprehensive and beginner-friendly
- Assumes minimal Docker knowledge
- Provides examples for all common tasks
- Includes troubleshooting and performance notes

**Developer Documentation** (This File):
- Assumes technical competence
- Focuses on codebase structure and conventions
- Guides AI assistants in making informed modifications
- Includes rationale for design decisions

**Code Comments**:
- Minimal in scripts (prefer self-documenting code)
- Explanatory in Dockerfiles (justify non-obvious steps)
- Helpful in makefile (clarify version numbers)

### Maintenance Guidelines

**When Adding New MESA SDK Version**:
1. Check MESA SDK availability (astro.wisc.edu or Zenodo)
2. Test MESA compilation with target MESA versions
3. Add makefile target following naming convention
4. Update README compatibility table
5. Document any special considerations
6. Tag Docker image appropriately

**When Deprecating Old Versions**:
- Don't remove from repository (reproducibility!)
- Add deprecation notice in README
- Explain why (e.g., "Ubuntu 12.04 LTS expired")
- Suggest migration path to newer version

**When Fixing Bugs**:
- Add test case if possible
- Document the issue in commit message
- Update README if user-visible change
- Consider backward compatibility

### Quick Reference for Common File Locations

```
User scripts:           bin/start_and_login.sh, bin/login.sh
HPC script:             bin/apptainer_mesa.sh
Build system:           build_docker_images/makefile
Dockerfile template:    build_docker_images/Dockerfile_template
Package list:           build_docker_images/apt_packages_nudome.txt
Container config:       build_docker_images/dot.bash_aliases
Documentation source:   README_src.md
Documentation output:   README.md
```

### Resources and References

**MESA**:
- Website: http://mesa.sourceforge.net
- News Archive: http://mesa.sourceforge.net/news.html
- Releases: https://sourceforge.net/projects/mesa/files/releases

**MESA SDK**:
- Website: http://www.astro.wisc.edu/~townsend/static.php?ref=mesasdk

**NuGrid**:
- Project: https://nugrid.github.io
- NuGridPy: https://nugrid.github.io/NuGridPy

**Docker Hub**:
- Images: https://hub.docker.com/repository/docker/nugrid/nudome

**Related Projects**:
- MESA-Docker: https://github.com/evbauer/MESA-Docker
- MESA Marketplace: http://mesastar.org

---

## Changelog

**2025-11-18**: Initial CLAUDE.md creation
- Comprehensive repository analysis
- Documented all scripts, build system, and workflows
- Added conventions, common tasks, and AI assistant guidelines

---

*This file is maintained for AI assistants working with the NuDocker codebase. Keep it updated when significant changes are made to repository structure, conventions, or workflows.*
