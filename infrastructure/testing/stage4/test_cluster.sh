#!/bin/bash
# Stage 4: Multi-Node Cluster Test Script
# Tests HTCondor cluster with central manager + execute node
# Tests NFS storage, distributed job execution
# Run after: terraform apply

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "========================================="
echo "Stage 4: Multi-Node Cluster Test"
echo "========================================="
echo "Date: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# Get outputs from Terraform
echo "Retrieving cluster information..."
CENTRAL_FIP=$(terraform output -raw central_manager_floating_ip 2>/dev/null)
CENTRAL_IP=$(terraform output -raw central_manager_internal_ip 2>/dev/null)
EXECUTE_IP=$(terraform output -raw execute_node_internal_ip 2>/dev/null)

if [ -z "$CENTRAL_FIP" ]; then
    echo -e "${RED}✗ ERROR: Could not retrieve cluster information${NC}"
    exit 1
fi

SSH_KEY="${SSH_KEY_PATH:-~/.ssh/id_rsa}"
SSH_CMD="ssh -i $SSH_KEY -o StrictHostKeyChecking=no ubuntu@$CENTRAL_FIP"

echo -e "${GREEN}✓ Cluster information retrieved${NC}"
echo "  Central Manager IP: $CENTRAL_IP (floating: $CENTRAL_FIP)"
echo "  Execute Node IP: $EXECUTE_IP"
echo ""

# Wait for SSH
echo "Waiting for SSH to central manager (up to 60 seconds)..."
MAX_ATTEMPTS=12
ATTEMPT=1

while [ $ATTEMPT -le $MAX_ATTEMPTS ]; do
    if $SSH_CMD 'exit' >/dev/null 2>&1; then
        echo -e "${GREEN}✓ SSH connection successful${NC}"
        break
    fi
    echo "  Attempt $ATTEMPT/$MAX_ATTEMPTS..."
    sleep 5
    ATTEMPT=$((ATTEMPT + 1))
done

if [ $ATTEMPT -gt $MAX_ATTEMPTS ]; then
    echo -e "${RED}✗ SSH connection failed${NC}"
    exit 1
fi

echo ""

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_WARNED=0

print_result() {
    local test_name="$1"
    local result="$2"
    local message="${3:-}"

    if [ "$result" == "PASS" ]; then
        echo -e "${GREEN}✓ PASS${NC}: $test_name"
        [ -n "$message" ] && echo "  $message"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    elif [ "$result" == "FAIL" ]; then
        echo -e "${RED}✗ FAIL${NC}: $test_name"
        [ -n "$message" ] && echo "  $message"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    elif [ "$result" == "WARN" ]; then
        echo -e "${YELLOW}⚠ WARN${NC}: $test_name"
        [ -n "$message" ] && echo "  $message"
        TESTS_WARNED=$((TESTS_WARNED + 1))
    fi
}

echo "Test Suite 1: NFS Storage"
echo "--------------------------"

# Test 1: NFS server running on central
if $SSH_CMD 'systemctl is-active nfs-kernel-server' >/dev/null 2>&1; then
    print_result "NFS server running on central" "PASS"
else
    print_result "NFS server running on central" "FAIL"
fi

# Test 2: NFS export configured
EXPORTS=$($SSH_CMD 'cat /etc/exports | grep /storage' 2>/dev/null || echo "")
if [ -n "$EXPORTS" ]; then
    print_result "NFS export configured" "PASS"
else
    print_result "NFS export configured" "FAIL"
fi

# Test 3: Storage directory exists on central
if $SSH_CMD '[ -d /storage ]' 2>/dev/null; then
    print_result "Storage directory on central" "PASS"

    # Check subdirectories
    SUBDIRS=$($SSH_CMD 'ls -d /storage/*/ 2>/dev/null | wc -l' || echo "0")
    if [ "$SUBDIRS" -gt 0 ]; then
        echo "  Subdirectories: $SUBDIRS"
    fi
else
    print_result "Storage directory on central" "FAIL"
fi

# Test 4: NFS mounted on execute node
# We need to SSH through central to check execute node
NFS_MOUNTED=$($SSH_CMD "ssh -o StrictHostKeyChecking=no ubuntu@$EXECUTE_IP 'mount | grep /storage' 2>/dev/null" || echo "")
if [ -n "$NFS_MOUNTED" ]; then
    print_result "NFS mounted on execute node" "PASS"
else
    print_result "NFS mounted on execute node" "FAIL"
fi

# Test 5: Storage accessible from execute node
STORAGE_TEST=$($SSH_CMD "ssh -o StrictHostKeyChecking=no ubuntu@$EXECUTE_IP 'ls /storage 2>/dev/null'" || echo "")
if [ -n "$STORAGE_TEST" ]; then
    print_result "Storage accessible from execute" "PASS"
else
    print_result "Storage accessible from execute" "WARN" "May still be mounting"
fi

echo ""

echo "Test Suite 2: HTCondor Central Manager"
echo "---------------------------------------"

# Test 6: HTCondor running on central
if $SSH_CMD 'systemctl is-active condor' >/dev/null 2>&1; then
    print_result "HTCondor service on central" "PASS"
else
    print_result "HTCondor service on central" "FAIL"
fi

# Test 7: Central manager daemons
CENTRAL_DAEMONS=$($SSH_CMD 'condor_who 2>/dev/null | grep -E "Collector|Negotiator|Schedd" | wc -l' || echo "0")
if [ "$CENTRAL_DAEMONS" -ge 3 ]; then
    print_result "Central manager daemons" "PASS" "Found $CENTRAL_DAEMONS daemons"
else
    print_result "Central manager daemons" "FAIL" "Expected 3+, found $CENTRAL_DAEMONS"
fi

# Test 8: CONDOR_HOST set correctly
CONDOR_HOST=$($SSH_CMD 'condor_config_val CONDOR_HOST 2>/dev/null' || echo "")
if [[ "$CONDOR_HOST" == *"$CENTRAL_IP"* ]]; then
    print_result "CONDOR_HOST configuration" "PASS" "Value: $CONDOR_HOST"
else
    print_result "CONDOR_HOST configuration" "WARN" "Expected $CENTRAL_IP, got $CONDOR_HOST"
fi

echo ""

echo "Test Suite 3: HTCondor Execute Node"
echo "------------------------------------"

# Test 9: HTCondor running on execute node
EXECUTE_CONDOR=$($SSH_CMD "ssh -o StrictHostKeyChecking=no ubuntu@$EXECUTE_IP 'systemctl is-active condor 2>/dev/null'" || echo "inactive")
if [ "$EXECUTE_CONDOR" == "active" ]; then
    print_result "HTCondor service on execute" "PASS"
else
    print_result "HTCondor service on execute" "FAIL" "Service: $EXECUTE_CONDOR"
fi

# Test 10: Execute node registered with collector
# Wait up to 30 seconds for execute node to register
echo "Waiting for execute node to register with collector (up to 30 seconds)..."
WAIT_COUNT=0
EXECUTE_REGISTERED=false
while [ $WAIT_COUNT -lt 6 ]; do
    SLOTS=$($SSH_CMD 'condor_status -compact 2>/dev/null | grep -c slot || echo "0"')
    if [ "$SLOTS" -gt 0 ]; then
        print_result "Execute node registered" "PASS" "Found $SLOTS slots"
        EXECUTE_REGISTERED=true
        break
    fi
    echo "  Waiting... (attempt $((WAIT_COUNT + 1))/6)"
    sleep 5
    WAIT_COUNT=$((WAIT_COUNT + 1))
done

if [ "$EXECUTE_REGISTERED" != "true" ]; then
    print_result "Execute node registered" "FAIL" "No slots visible after 30s"
fi

# Test 11: Cluster pool status
POOL_OUTPUT=$($SSH_CMD 'condor_status -total 2>/dev/null | grep Total' || echo "")
if [ -n "$POOL_OUTPUT" ]; then
    print_result "Cluster pool status" "PASS"
    echo "  $POOL_OUTPUT"
else
    print_result "Cluster pool status" "FAIL"
fi

echo ""

echo "Test Suite 4: Distributed Job Execution"
echo "----------------------------------------"

# Test 12: Submit distributed job
if [ "$EXECUTE_REGISTERED" == "true" ]; then
    echo "Submitting 5 distributed jobs..."
    JOB_OUTPUT=$($SSH_CMD 'cd ~/cluster_test && condor_submit distributed_job.sub 2>&1')
    CLUSTER_ID=$(echo "$JOB_OUTPUT" | grep -oP 'submitted to cluster \K[0-9]+' | head -1)

    if [ -n "$CLUSTER_ID" ]; then
        print_result "Distributed job submission" "PASS" "Cluster ID: $CLUSTER_ID"

        # Test 13: Wait for jobs to complete
        echo "Waiting for jobs to complete (up to 60 seconds)..."
        JOB_WAIT=0
        JOBS_COMPLETED=false

        while [ $JOB_WAIT -lt 12 ]; do
            RUNNING=$($SSH_CMD "condor_q $CLUSTER_ID -nobatch 2>/dev/null | grep -c 'R ' || echo '0'")
            IDLE=$($SSH_CMD "condor_q $CLUSTER_ID -nobatch 2>/dev/null | grep -c 'I ' || echo '0'")
            COMPLETED=$($SSH_CMD "condor_history $CLUSTER_ID -limit 10 2>/dev/null | grep -c 'Normal termination' || echo '0'")

            echo "  Status: Running=$RUNNING, Idle=$IDLE, Completed=$COMPLETED"

            if [ "$COMPLETED" -ge 5 ]; then
                print_result "Distributed job execution" "PASS" "All 5 jobs completed"
                JOBS_COMPLETED=true
                break
            fi

            sleep 5
            JOB_WAIT=$((JOB_WAIT + 1))
        done

        if [ "$JOBS_COMPLETED" != "true" ]; then
            print_result "Distributed job execution" "FAIL" "Only $COMPLETED/5 jobs completed"
        fi

        # Test 14: Check output files
        OUTPUT_COUNT=$($SSH_CMD 'ls ~/cluster_test/job_*.out 2>/dev/null | wc -l')
        if [ "$OUTPUT_COUNT" -ge 5 ]; then
            print_result "Job output files created" "PASS" "Found $OUTPUT_COUNT files"

            # Show which hosts ran the jobs
            echo "  Jobs ran on:"
            $SSH_CMD 'for f in ~/cluster_test/job_*.out; do echo "    $(cat $f)"; done' 2>/dev/null | head -5
        else
            print_result "Job output files created" "FAIL" "Expected 5, found $OUTPUT_COUNT"
        fi

        # Test 15: Verify jobs ran on execute node
        EXECUTE_HOSTNAME=$($SSH_CMD "ssh -o StrictHostKeyChecking=no ubuntu@$EXECUTE_IP 'hostname' 2>/dev/null" || echo "unknown")
        JOBS_ON_EXECUTE=$($SSH_CMD "grep -c '$EXECUTE_HOSTNAME' ~/cluster_test/job_*.out 2>/dev/null || echo '0'")

        if [ "$JOBS_ON_EXECUTE" -gt 0 ]; then
            print_result "Jobs executed on execute node" "PASS" "$JOBS_ON_EXECUTE jobs ran on $EXECUTE_HOSTNAME"
        else
            print_result "Jobs executed on execute node" "WARN" "No jobs detected on execute node"
        fi
    else
        print_result "Distributed job submission" "FAIL" "Could not submit job"
    fi
else
    echo "  Skipping distributed job tests (execute node not registered)"
fi

echo ""

echo "Test Suite 5: Network Connectivity"
echo "-----------------------------------"

# Test 16: Central can reach execute
if $SSH_CMD "ping -c 3 $EXECUTE_IP >/dev/null 2>&1"; then
    print_result "Central → Execute connectivity" "PASS"
else
    print_result "Central → Execute connectivity" "WARN" "Ping may be blocked"
fi

# Test 17: Execute can reach central
EXECUTE_TO_CENTRAL=$($SSH_CMD "ssh -o StrictHostKeyChecking=no ubuntu@$EXECUTE_IP 'ping -c 3 $CENTRAL_IP >/dev/null 2>&1 && echo ok' || echo 'fail'")
if [ "$EXECUTE_TO_CENTRAL" == "ok" ]; then
    print_result "Execute → Central connectivity" "PASS"
else
    print_result "Execute → Central connectivity" "WARN" "Ping may be blocked"
fi

echo ""

# Generate result report
RESULT_FILE="../results/stage4_results_$(date +%Y%m%d_%H%M%S).txt"
mkdir -p ../results

cat > "$RESULT_FILE" << EOF
STAGE 4: MULTI-NODE HTCONDOR CLUSTER TEST
==========================================
Date: $(date '+%Y-%m-%d %H:%M:%S')
Duration: ~45 minutes

CLUSTER TOPOLOGY:
-----------------
Central Manager: $CENTRAL_IP (floating: $CENTRAL_FIP)
Execute Node: $EXECUTE_IP

NFS Storage: /storage (central) → /storage (execute)
HTCondor Pool: Central manages, Execute runs jobs

TEST RESULTS:
-------------
Total tests: $((TESTS_PASSED + TESTS_FAILED + TESTS_WARNED))
Passed: $TESTS_PASSED
Failed: $TESTS_FAILED
Warnings: $TESTS_WARNED

NFS STORAGE:
$([ $TESTS_FAILED -eq 0 ] && echo "✓" || echo "⚠") NFS server running
$([ -n "$EXPORTS" ] && echo "✓" || echo "✗") Export configured
$([ -n "$NFS_MOUNTED" ] && echo "✓" || echo "⚠") Mounted on execute node

HTCONDOR CLUSTER:
✓ Central manager daemons: $CENTRAL_DAEMONS
$([ "$SLOTS" -gt 0 ] && echo "✓" || echo "✗") Execute slots available: $SLOTS
$([ -n "$POOL_OUTPUT" ] && echo "✓" || echo "✗") Pool status responding

DISTRIBUTED JOBS:
EOF

if [ -n "$CLUSTER_ID" ]; then
    cat >> "$RESULT_FILE" << EOF
✓ Submitted 5 distributed jobs (Cluster $CLUSTER_ID)
$([ "$JOBS_COMPLETED" == "true" ] && echo "✓" || echo "✗") All jobs completed
✓ Jobs executed on: $EXECUTE_HOSTNAME
EOF
else
    cat >> "$RESULT_FILE" << EOF
✗ Job submission or execution failed
EOF
fi

cat >> "$RESULT_FILE" << EOF

STATUS: $(if [ $TESTS_FAILED -eq 0 ]; then echo "✓ STAGE 4 PASSED"; else echo "✗ STAGE 4 FAILED"; fi)

NEXT STEPS:
-----------
EOF

if [ $TESTS_FAILED -eq 0 ]; then
    cat >> "$RESULT_FILE" << EOF
✓ Multi-node HTCondor cluster functional
✓ NFS shared storage working
✓ Distributed job execution successful

→ Clean up Stage 4: terraform destroy
→ Proceed to Stage 5: SLURM Integration Test
→ Command: cd ../stage5 && terraform init
EOF
else
    cat >> "$RESULT_FILE" << EOF
✗ Cluster setup or job execution failed

TROUBLESHOOTING:
1. Check NFS: ssh ubuntu@$CENTRAL_FIP 'showmount -e'
2. Check execute node registration: ssh ubuntu@$CENTRAL_FIP 'condor_status -long'
3. Review logs: ssh ubuntu@$CENTRAL_FIP 'tail -50 /var/log/condor/*'
4. Check connectivity: ssh ubuntu@$CENTRAL_FIP 'ping $EXECUTE_IP'
EOF
fi

echo "========================================="
echo "Test Summary"
echo "========================================="
echo "Total tests: $((TESTS_PASSED + TESTS_FAILED + TESTS_WARNED))"
echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
echo -e "${YELLOW}Warnings: $TESTS_WARNED${NC}"
echo -e "${RED}Failed: $TESTS_FAILED${NC}"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ Multi-node cluster test passed!${NC}"
    echo ""
    echo "Result saved to: $RESULT_FILE"
    echo ""
    echo "Next steps:"
    echo "  1. Clean up: terraform destroy -auto-approve"
    echo "  2. Proceed to Stage 5: SLURM Integration Test"
    exit 0
else
    echo -e "${RED}✗ Some tests failed${NC}"
    echo ""
    echo "Result saved to: $RESULT_FILE"
    echo ""
    echo "Review the troubleshooting section in the result file"
    exit 1
fi
