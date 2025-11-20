# Using Claude CLI with NuDocker Testing Infrastructure on Mac Air
**Complete guide for running HTCondor cluster testing on HUN-REN Cloud using Claude CLI assistance**
---
## 🎯 Overview
This guide shows you how to use **Claude CLI** to help you run the NuDocker testing infrastructure on your Mac Air. Claude CLI can assist with:
- ✅ Running cloud discovery scripts
- ✅ Analyzing test results
- ✅ Troubleshooting errors
- ✅ Generating configuration files
- ✅ Explaining outputs
- ✅ Providing step-by-step guidance
---
## 📋 Your Setup
You mentioned you have:
- ✅ Mac Air (Apple Silicon or Intel)
- ✅ Python virtualenv: `infraprog`
- ✅ OpenStack CLI installed in virtualenv
- ✅ Application credential for HUN-REN cloud (`app-cred-bridge-openrc.sh`)
- ✅ Packer installed
- ✅ Claude CLI installed
**This is perfect for running the testing infrastructure!**
---
## 🚀 Quick Start with Claude CLI
### Step 1: Set Up Your Environment
```bash
# Navigate to NuDocker repository
cd /path/to/NuDocker/infrastructure/testing
# Activate your virtualenv
source ~/path/to/infraprog/bin/activate
# Authenticate with HUN-REN cloud
source ~/path/to/app-cred-bridge-openrc.sh
# Enter your password when prompted
# Verify OpenStack CLI works
openstack flavor list
```
### Step 2: Start Claude CLI Session
```bash
# Start Claude CLI in the testing directory
claude
# Or start with the testing directory as context
claude --files infrastructure/testing/
```
### Step 3: Ask Claude to Help You
Once in Claude CLI session, you can ask:
```
"I'm ready to start testing. What should I do first?"
"Run the cloud discovery script and help me understand the results"
"I got an error in Stage 1, here's the output: [paste error]"
"Generate a terraform.tfvars file for me with these values: ..."
"Explain what this test is checking"
```
---
## 📝 Stage-by-Stage Guide with Claude CLI
### Stage 0: Prerequisites Verification
**What to do:**
```bash
cd stage0
./verify_prerequisites.sh
```
**Ask Claude:**
```
"I just ran verify_prerequisites.sh. Here's the output: [paste output]
What do the results mean? Are there any issues I need to fix?"
"The script says I'm missing X. How do I install it?"
"All checks passed! What's next?"
```
**Claude can help with:**
- Interpreting test results
- Fixing missing dependencies
- Explaining what each check does
- Confirming you're ready for Stage 1
---
### Stage 1: Basic VM Provisioning
**What to do:**
```bash
cd ../stage1
# Ask Claude to help create terraform.tfvars
# In Claude CLI:
```
**In Claude CLI:**
```
"I need to create terraform.tfvars for Stage 1.
My cloud name is: hun-ren-cloud
My network is: [your network name]
My external network is: [your external network]
My key pair is: [your keypair name]
Can you generate the terraform.tfvars file for me?"
```
**Claude will create the file. Then continue:**
```bash
# Initialize Terraform
terraform init
# Ask Claude to explain the plan
terraform plan
# In Claude CLI:
```
**In Claude CLI:**
```
"Here's my terraform plan output: [paste output]
What resources will be created? Is this correct?"
```
**Then apply:**
```bash
terraform apply
```
**Ask Claude:**
```
"Terraform apply completed. Here's the output: [paste output]
What should I do next?"
"The apply failed with this error: [paste error]
How do I fix it?"
```
**Run tests:**
```bash
./test_connectivity.sh
```
**Ask Claude:**
```
"Here are my Stage 1 test results: [paste results]
Did everything pass? What does each test mean?"
```
**Clean up:**
```bash
terraform destroy -auto-approve
```
---
### Stage 2: Packer Image Build
**What to do:**
```bash
cd ../stage2
# Ask Claude to help with configuration
```
**In Claude CLI:**
```
"I need to configure variables.pkrvars.hcl for Packer.
My cloud details are:
- cloud_name: hun-ren-cloud
- source_image_name: ubuntu-22.04
- flavor: m2.large
- network_id: [your network ID or leave empty]
- external network: public
Can you create variables.pkrvars.hcl for me?"
```
**Initialize and validate:**
```bash
packer init nudocker-test.pkr.hcl
packer validate -var-file=variables.pkrvars.hcl nudocker-test.pkr.hcl
```
**Ask Claude:**
```
"Packer validation output: [paste output]
Is this ready to build?"
```
**Build image (this takes 30-45 minutes):**
```bash
packer build -var-file=variables.pkrvars.hcl nudocker-test.pkr.hcl
```
**While building, ask Claude:**
```
"Packer is building. Can you explain what it's doing?
What components are being installed?"
"Packer failed at step X with error: [paste error]
How do I troubleshoot this?"
```
**After build, verify:**
```bash
./verify_image.sh
```
**Ask Claude:**
```
"Image verification results: [paste results]
All tests passed - what does this mean?"
"Test 3 failed: [paste error]
What's wrong and how do I fix it?"
```
---
### Stage 3: Single-Node HTCondor
**What to do:**
```bash
cd ../stage3
# Ask Claude to create terraform.tfvars
```
**In Claude CLI:**
```
"Create terraform.tfvars for Stage 3.
I need to use the custom image from Stage 2.
My image name is: nudocker-test-stage2-20251119-1430
(Or ask: "How do I find my Stage 2 image name?")
Other values same as Stage 1."
```
**Deploy and test:**
```bash
terraform init
terraform apply
./test_htcondor.sh
```
**Ask Claude:**
```
"HTCondor test results: [paste results]
Did all 12 tests pass?"
"Docker Universe tests failed. Error: [paste error]
How do I debug this?"
"Can you explain what HTCondor Vanilla Universe vs Docker Universe means?"
```
**Clean up:**
```bash
terraform destroy -auto-approve
```
---
### Stage 4: Multi-Node Cluster
**What to do:**
```bash
cd ../stage4
# Ask Claude for configuration
```
**In Claude CLI:**
```
"Create terraform.tfvars for Stage 4 (multi-node cluster).
I want:
- Central manager: m2.medium (2 vCPU, 4GB)
- Execute node: m2.large (4 vCPU, 8GB)
Use the same image and network settings as Stage 3."
```
**Deploy and test:**
```bash
terraform init
terraform apply
./test_cluster.sh
```
**Ask Claude:**
```
"Cluster test results: [paste results]
How many tests passed?"
"NFS mounting failed on execute node. Error: [paste error]
What's the issue?"
"Jobs aren't running on the execute node, only central manager.
Here's condor_status output: [paste output]
What's wrong?"
```
**Clean up:**
```bash
terraform destroy -auto-approve
```
---
## 🔍 Cloud Discovery with Claude CLI
### Comprehensive Resource Collection
**Run the collector:**
```bash
# In terminal (not Claude CLI)
cd /path/to/NuDocker/infrastructure/testing
source ~/path/to/infraprog/bin/activate
source ~/path/to/app-cred-bridge-openrc.sh
./collect_cloud_resources.sh
```
**This creates:**
- `cloud_resources_YYYYMMDD_HHMMSS/` directory
- `cloud_resources_YYYYMMDD_HHMMSS.tar.gz` archive
**Then ask Claude:**
**In Claude CLI:**
```
"I ran collect_cloud_resources.sh. Can you analyze the results?"
# Upload the archive or paste key files
@cloud_resources_20251119_143000.tar.gz
"Based on my cloud resources, what's the optimal HTCondor cluster
configuration for running MESA simulations?"
"How many MESA jobs can I run simultaneously with my quota?"
```
---
## 💡 Common Claude CLI Tasks
### Task 1: Understanding Test Results
**You run:**
```bash
./test_connectivity.sh > results.txt
```
**In Claude CLI:**
```
"Analyze my test results:"
@results.txt
"What does each test check?"
"Are there any failures I should worry about?"
"What should I do next?"
```
### Task 2: Troubleshooting Errors
**When you hit an error:**
**In Claude CLI:**
```
"I got this error during Terraform apply:
[paste error message]
What does it mean and how do I fix it?"
"HTCondor jobs stay in Idle state. Here's condor_q output:
[paste output]
How do I diagnose this?"
```
### Task 3: Configuration File Generation
**In Claude CLI:**
```
"Generate a terraform.tfvars file for Stage 3 with these values:
- cloud_name: hun-ren-cloud
- custom_image_name: nudocker-test-stage2-20251119-1430
- flavor_name: m2.large
- network_name: private
- external_network_name: public
- key_pair_name: my-keypair
- ssh_private_key_path: ~/.ssh/id_rsa"
"Save this to stage3/terraform.tfvars"
```
### Task 4: Explaining Outputs
**In Claude CLI:**
```
"Explain this Terraform output:
[paste terraform output]
What resources were created?"
"What does this HTCondor status mean:
[paste condor_status output]"
"Interpret these MESA inlist parameters:
[paste inlist section]"
```
### Task 5: Planning Next Steps
**In Claude CLI:**
```
"I completed Stage 4 successfully. What should I do next?"
"I want to run a MESA parameter grid with 27 models.
Based on my cloud resources [paste summary],
what cluster configuration do you recommend?"
"How long will it take to run 100 MESA models on a cluster with
10 execute nodes (4 vCPU each)?"
```
---
## 🎯 Using Claude for MESA/Pignatari Workflow
### Step 1: Plan Your Parameter Grid
**In Claude CLI:**
```
"I want to reproduce Pignatari et al. (2016) stellar yields.
My cloud resources: [paste summary from collect_cloud_resources.sh]
Design an optimal parameter grid and cluster configuration for me."
"I have 40 vCPUs available. How should I distribute them across
central manager and execute nodes for MESA simulations?"
```
### Step 2: Generate MESA Inlists
**In Claude CLI:**
```
"Create a MESA inlist for a 1.5 solar mass star with solar metallicity,
evolving from main sequence to the end of AGB phase."
"Modify this inlist to run thermal pulses with these settings:
[describe requirements]"
```
### Step 3: Create HTCondor Submit Files
**In Claude CLI:**
```
"Generate an HTCondor submit file for running a MESA parameter grid:
- Masses: 1.0, 1.5, 2.0, 2.5, 3.0 solar masses
- Metallicities: Z = 0.02, 0.01, 0.001
- Each job needs 4 CPUs and 8 GB RAM
- Use Docker Universe with nugrid/nudome:20.1 image"
```
### Step 4: Analyze Results
**In Claude CLI:**
```
"I have MESA history files from 27 models.
How do I extract the final surface abundances?"
"Compare my yields with Pignatari et al. (2016) Table 3.
Here's my data: [paste or upload]"
```
---
## 🔧 Advanced Claude CLI Usage
### Using File Context
```bash
# Start Claude with specific files as context
claude --files stage1/main.tf,stage1/variables.tf
# Or add files during session
# In Claude CLI:
@stage1/terraform.tfvars
"Review this configuration and suggest improvements"
@results/stage3_results_20251119_143000.txt
"Analyze these test results and identify any issues"
```
### Batch Operations
**In Claude CLI:**
```
"For each testing stage (1-4), list:
1. Required resources
2. Estimated duration
3. Success criteria
4. Common failure modes"
"Create a checklist for deploying a production cluster based on
my testing results"
```
### Code Generation
**In Claude CLI:**
```
"Write a shell script that:
1. Runs stages 1-4 sequentially
2. Captures all test results
3. Generates a summary report
4. Only proceeds to next stage if current passes"
"Create a Python script to parse MESA history files and
extract final abundances for elements Sr, Ba, Pb"
```
---
## 📊 Example Claude CLI Session
Here's a complete example session:
```bash
# Terminal
cd /path/to/NuDocker/infrastructure/testing
source ~/infraprog/bin/activate
source ~/app-cred-bridge-openrc.sh
claude
```
**In Claude CLI:**
```
Me: "I'm starting the NuDocker testing infrastructure.
     I'm in the testing directory with OpenStack CLI configured.
     What should I do first?"
Claude: "Great! Let's start with Stage 0 to verify your prerequisites..."
Me: "cd stage0 && ./verify_prerequisites.sh"
    [paste output]
Claude: "Perfect! All prerequisites are met. Here's what each check verified..."
Me: "I'm ready for Stage 1. My cloud details are:
     - cloud_name: hun-ren-cloud
     - network_name: private
     - external_network_name: public
     - key_pair_name: hun-ren-key
     Generate terraform.tfvars for me."
Claude: "Here's your terraform.tfvars file..."
Me: [copy to stage1/terraform.tfvars]
    "terraform init && terraform apply"
    [paste output]
Claude: "Excellent! Terraform created these resources..."
Me: "./test_connectivity.sh"
    [paste results]
Claude: "All 8 tests passed! This means..."
Me: "Great! Clean up and move to Stage 2?"
Claude: "Yes! Run 'terraform destroy' then we'll configure Packer..."
```
---
## 🎓 Tips for Effective Claude CLI Usage
### 1. Provide Context
```
❌ "It failed"
✅ "Stage 3 terraform apply failed with this error: [full error]
    I'm using m2.large flavor on HUN-REN cloud"
```
### 2. Upload Files
```
❌ "Check my config"
✅ @stage3/terraform.tfvars
    "Is this configuration correct for my setup?"
```
### 3. Ask Specific Questions
```
❌ "Help with HTCondor"
✅ "My HTCondor jobs stay in Idle state.
    condor_status shows 4 slots available.
    Here's condor_q output: [paste]
    What's preventing jobs from running?"
```
### 4. Request Explanations
```
"Explain this output in simple terms"
"What are the implications of this warning?"
"Why is this setting recommended?"
```
### 5. Get Step-by-Step Guidance
```
"Walk me through Stage 4 deployment step by step"
"What's the complete workflow for running a MESA model?"
```
---
## 🚨 Troubleshooting with Claude CLI
### Common Issues and How to Ask Claude
#### Issue: Authentication Fails
```
Me: "openstack token issue fails with:
     [paste error]
     I sourced app-cred-bridge-openrc.sh and entered my password.
     What's wrong?"
```
#### Issue: Terraform Apply Fails
```
Me: "terraform apply fails at resource creation:
     [paste full error]
     Here's my terraform.tfvars:
     @terraform.tfvars
     How do I fix this?"
```
#### Issue: Packer Build Fails
```
Me: "Packer build failed during HTCondor installation:
     [paste relevant log section]
     The build VM can reach the internet.
     What's the issue?"
```
#### Issue: Test Script Fails
```
Me: "test_htcondor.sh reports 3 failed tests:
     [paste results]
     The VM is accessible via SSH.
     How do I debug this?"
```
---
## 📁 Directory Structure for Claude CLI
When working with Claude CLI, keep your working directory organized:
```
~/NuDocker/infrastructure/testing/
├── cloud_resources_*/              # Resource collection outputs
├── results/                        # Test results
├── stage1/
│   ├── terraform.tfvars           # Your custom config
│   └── ...
├── stage2/
│   ├── variables.pkrvars.hcl      # Your custom config
│   └── ...
└── notes/                         # Optional: your notes
    ├── session_2025-11-19.md      # Claude CLI session notes
    └── cluster_design.md          # Your cluster plan
```
---
## 💾 Saving Claude CLI Interactions
You can save useful Claude CLI interactions:
```bash
# In Claude CLI, ask Claude to summarize
"Summarize our session and create a checklist of what we accomplished"
# Copy the output to a file
# Then in terminal:
cat > notes/session_$(date +%Y-%m-%d).md
[paste Claude's summary]
Ctrl+D
```
---
## 🎯 Next Steps
1. **Start with Stage 0**:
   ```bash
   cd stage0
   ./verify_prerequisites.sh
   ```
2. **Ask Claude for help** interpreting results
3. **Proceed through stages** with Claude's guidance
4. **Run cloud resource collection**:
   ```bash
   ./collect_cloud_resources.sh
   ```
5. **Share results with Claude** for optimal cluster design
6. **Use Claude to generate** custom configs for your cluster
7. **Deploy production cluster** with Claude's assistance
---
## 📞 Getting Help
**Within Claude CLI:**
- Just ask! Claude can help with any step
- Provide context (errors, outputs, files)
- Ask for explanations, not just solutions
**Outside Claude CLI:**
- Check stage-specific READMEs
- Review troubleshooting sections
- Examine test result files
**For Claude Code/CLI Issues:**
- Claude CLI documentation
- Claude support
---
## 🎉 Summary
With Claude CLI, you can:
- ✅ Get step-by-step guidance through testing stages
- ✅ Generate configuration files automatically
- ✅ Troubleshoot errors quickly
- ✅ Understand test results and outputs
- ✅ Plan optimal cluster configurations
- ✅ Create MESA workflows and HTCondor jobs
- ✅ Analyze scientific results
**You have everything you need!**
- Mac Air with infraprog virtualenv ✓
- OpenStack CLI and Packer ✓
- HUN-REN cloud access ✓
- Claude CLI for assistance ✓
- Complete testing infrastructure ✓
**Ready to start?**
```bash
cd /path/to/NuDocker/infrastructure/testing
source ~/infraprog/bin/activate
source ~/app-cred-bridge-openrc.sh
claude
# Then ask Claude:
"I'm ready to start testing NuDocker infrastructure on HUN-REN cloud.
 Guide me through Stage 0."
```
---
*Last updated: 2025-11-19*
*For: Mac Air users with Claude CLI*
*Repository: https://github.com/gyorgy-mezo/NuDocker*