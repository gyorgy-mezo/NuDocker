#!/bin/bash
# NuDocker environment profile
# Automatically sourced for all users

# Shared storage
export NUDOCKER_STORAGE=/storage
export NUDOCKER_MESA=$NUDOCKER_STORAGE/mesa
export NUDOCKER_CONTAINERS=$NUDOCKER_STORAGE/containers
export NUDOCKER_RESULTS=$NUDOCKER_STORAGE/results

# Singularity configuration
export SINGULARITY_CACHEDIR=$NUDOCKER_CONTAINERS/singularity_cache
export APPTAINER_CACHEDIR=$NUDOCKER_CONTAINERS/singularity_cache

# HTCondor job directory
export CONDOR_JOBS=$NUDOCKER_STORAGE/htcondor_jobs

# Add NuDocker scripts to PATH
if [ -d "$NUDOCKER_STORAGE/nudocker/bin" ]; then
    export PATH=$NUDOCKER_STORAGE/nudocker/bin:$PATH
fi

# Helpful aliases
alias goto-storage='cd $NUDOCKER_STORAGE'
alias goto-jobs='cd $CONDOR_JOBS'
alias goto-results='cd $NUDOCKER_RESULTS'
alias condor-status='condor_status'
alias condor-q='condor_q'
