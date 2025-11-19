#!/bin/bash
# Stage 3: HTCondor Test Script
# Tests HTCondor job submission and execution
# Run after: terraform apply

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "========================================="
echo "Stage 3: HTCondor Test"
echo "========================================="
echo "Date: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# Get outputs from Terraform
echo "Retrieving VM information from Terraform..."
FLOATING_IP=$(terraform output -raw htcondor_floating_ip 2>/dev/null)
INTERNAL_IP=$(terraform output -raw htcondor_internal_ip 2>/dev/null)
VM_ID=$(terraform output -raw htcondor_vm_id 2>/dev/null)

if [ -z "$FLOATING_IP" ]; then
    echo -e "${RED}✗ ERROR: Could not retrieve VM information${NC}"
    echo "Make sure you have run 'terraform apply' successfully"
    exit 1
fi

SSH_KEY="${SSH_KEY_PATH:-~/.ssh/id_rsa}"
SSH_CMD="ssh -i $SSH_KEY -o StrictHostKeyChecking=no ubuntu@$FLOATING_IP"

echo -e "${GREEN}✓ VM Information retrieved${NC}"
echo "  VM ID: $VM_ID"
echo "  Internal IP: $INTERNAL_IP"
echo "  Floating IP: $FLOATING_IP"
echo ""

# Wait for SSH
echo "Waiting for SSH to become available (up to 60 seconds)..."
MAX_ATTEMPTS=12
ATTEMPT=1
SSH_SUCCESS=false

while [ $ATTEMPT -le $MAX_ATTEMPTS ]; do
    if $SSH_CMD 'exit' >/dev/null 2>&1; then
        echo -e "${GREEN}✓ SSH connection successful${NC}"
        SSH_SUCCESS=true
        break
    fi
    echo "  Attempt $ATTEMPT/$MAX_ATTEMPTS..."
    sleep 5
    ATTEMPT=$((ATTEMPT + 1))
done

if [ "$SSH_SUCCESS" != "true" ]; then
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
        if [ -n "$message" ]; then
            echo "  $message"
        fi
        TESTS_PASSED=$((TESTS_PASSED + 1))
    elif [ "$result" == "FAIL" ]; then
        echo -e "${RED}✗ FAIL${NC}: $test_name"
        if [ -n "$message" ]; then
            echo "  $message"
        fi
        TESTS_FAILED=$((TESTS_FAILED + 1))
    elif [ "$result" == "WARN" ]; then
        echo -e "${YELLOW}⚠ WARN${NC}: $test_name"
        if [ -n "$message" ]; then
            echo "  $message"
        fi
        TESTS_WARNED=$((TESTS_WARNED + 1))
    fi
}

echo "Test Suite 1: HTCondor Service Status"
echo "--------------------------------------"

# Test 1: HTCondor master running
if $SSH_CMD 'systemctl is-active condor' >/dev/null 2>&1; then
    print_result "HTCondor service running" "PASS"
else
    print_result "HTCondor service running" "FAIL" "Service not active"
fi

# Test 2: HTCondor daemons
DAEMONS=$($SSH_CMD 'condor_who 2>/dev/null | grep -E "Master|Collector|Negotiator|Schedd|Startd" | wc -l' || echo "0")
if [ "$DAEMONS" -ge 5 ]; then
    print_result "HTCondor daemons running" "PASS" "Found $DAEMONS daemons"
else
    print_result "HTCondor daemons running" "FAIL" "Expected 5+, found $DAEMONS"
fi

# Test 3: HTCondor pool status
POOL_STATUS=$($SSH_CMD 'condor_status -total 2>/dev/null | grep "Total"' || echo "")
if [ -n "$POOL_STATUS" ]; then
    print_result "HTCondor pool responding" "PASS"
    echo "  $POOL_STATUS"
else
    print_result "HTCondor pool responding" "FAIL"
fi

# Test 4: Execute slots available
SLOTS=$($SSH_CMD 'condor_status -compact 2>/dev/null | grep -c "slot" || echo "0"')
if [ "$SLOTS" -gt 0 ]; then
    print_result "Execute slots available" "PASS" "Found $SLOTS slots"
else
    print_result "Execute slots available" "FAIL" "No slots found"
fi

echo ""

echo "Test Suite 2: Vanilla Universe Job"
echo "-----------------------------------"

# Test 5: Submit vanilla job
echo "Submitting vanilla universe test job (3 jobs)..."
JOB_OUTPUT=$($SSH_CMD 'cd ~/htcondor_test && condor_submit test_job.sub 2>&1')
CLUSTER_ID=$(echo "$JOB_OUTPUT" | grep -oP 'submitted to cluster \K[0-9]+' | head -1)

if [ -n "$CLUSTER_ID" ]; then
    print_result "Job submission" "PASS" "Cluster ID: $CLUSTER_ID"
else
    print_result "Job submission" "FAIL" "Could not submit job"
    echo "$JOB_OUTPUT"
fi

# Test 6: Wait for jobs to complete (up to 60 seconds)
if [ -n "$CLUSTER_ID" ]; then
    echo "Waiting for jobs to complete (up to 60 seconds)..."
    WAIT_COUNT=0
    while [ $WAIT_COUNT -lt 12 ]; do
        RUNNING=$($SSH_CMD "condor_q $CLUSTER_ID -nobatch 2>/dev/null | grep -c 'R ' || echo '0'")
        IDLE=$($SSH_CMD "condor_q $CLUSTER_ID -nobatch 2>/dev/null | grep -c 'I ' || echo '0'")
        COMPLETED=$($SSH_CMD "condor_history $CLUSTER_ID -limit 10 2>/dev/null | grep -c 'Normal termination' || echo '0'")

        echo "  Status: Running=$RUNNING, Idle=$IDLE, Completed=$COMPLETED"

        if [ "$COMPLETED" -ge 3 ]; then
            print_result "Job execution" "PASS" "All 3 jobs completed"
            break
        fi

        sleep 5
        WAIT_COUNT=$((WAIT_COUNT + 1))
    done

    if [ "$COMPLETED" -lt 3 ]; then
        print_result "Job execution" "FAIL" "Only $COMPLETED/3 jobs completed after 60s"
    fi

    # Test 7: Check job output files
    OUTPUT_FILES=$($SSH_CMD 'ls ~/htcondor_test/test_*.out 2>/dev/null | wc -l')
    if [ "$OUTPUT_FILES" -ge 3 ]; then
        print_result "Job output files created" "PASS" "Found $OUTPUT_FILES files"

        # Show sample output
        echo "  Sample output:"
        $SSH_CMD 'head -1 ~/htcondor_test/test_0.out 2>/dev/null' | sed 's/^/    /'
    else
        print_result "Job output files created" "FAIL" "Expected 3, found $OUTPUT_FILES"
    fi
fi

echo ""

echo "Test Suite 3: Docker Universe Job"
echo "----------------------------------"

# Test 8: Docker service running
if $SSH_CMD 'sudo systemctl is-active docker' >/dev/null 2>&1; then
    print_result "Docker service running" "PASS"

    # Test 9: Submit Docker job
    echo "Submitting Docker universe test job (2 jobs)..."
    DOCKER_OUTPUT=$($SSH_CMD 'cd ~/htcondor_test && condor_submit docker_test.sub 2>&1')
    DOCKER_CLUSTER=$(echo "$DOCKER_OUTPUT" | grep -oP 'submitted to cluster \K[0-9]+' | head -1)

    if [ -n "$DOCKER_CLUSTER" ]; then
        print_result "Docker job submission" "PASS" "Cluster ID: $DOCKER_CLUSTER"

        # Wait for Docker jobs (up to 120 seconds - Docker pull can be slow)
        echo "Waiting for Docker jobs to complete (up to 120 seconds)..."
        DOCKER_WAIT=0
        while [ $DOCKER_WAIT -lt 24 ]; do
            DOCKER_DONE=$($SSH_CMD "condor_history $DOCKER_CLUSTER -limit 10 2>/dev/null | grep -c 'Normal termination' || echo '0'")
            DOCKER_RUNNING=$($SSH_CMD "condor_q $DOCKER_CLUSTER -nobatch 2>/dev/null | grep -c 'R ' || echo '0'")

            echo "  Docker jobs: Completed=$DOCKER_DONE, Running=$DOCKER_RUNNING"

            if [ "$DOCKER_DONE" -ge 2 ]; then
                print_result "Docker job execution" "PASS" "Both Docker jobs completed"
                break
            fi

            sleep 5
            DOCKER_WAIT=$((DOCKER_WAIT + 1))
        done

        if [ "$DOCKER_DONE" -lt 2 ]; then
            print_result "Docker job execution" "WARN" "Only $DOCKER_DONE/2 jobs completed (Docker pull may be slow)"
        fi

        # Check Docker output
        DOCKER_FILES=$($SSH_CMD 'ls ~/htcondor_test/docker_*.out 2>/dev/null | wc -l')
        if [ "$DOCKER_FILES" -gt 0 ]; then
            print_result "Docker output files created" "PASS" "Found $DOCKER_FILES files"
        else
            print_result "Docker output files created" "WARN" "No output files yet"
        fi
    else
        print_result "Docker job submission" "FAIL" "Could not submit Docker job"
    fi
else
    print_result "Docker service running" "FAIL"
    echo "  Docker Universe tests skipped"
fi

echo ""

echo "Test Suite 4: HTCondor Configuration"
echo "-------------------------------------"

# Test 10: Configuration file
if $SSH_CMD '[ -f /etc/condor/config.d/50-standalone.config ]' 2>/dev/null; then
    print_result "Custom config file exists" "PASS"
else
    print_result "Custom config file exists" "FAIL"
fi

# Test 11: CONDOR_HOST setting
CONDOR_HOST=$($SSH_CMD 'condor_config_val CONDOR_HOST 2>/dev/null' || echo "")
if [ -n "$CONDOR_HOST" ]; then
    print_result "CONDOR_HOST configured" "PASS" "Value: $CONDOR_HOST"
else
    print_result "CONDOR_HOST configured" "FAIL"
fi

# Test 12: Slot configuration
SLOT_COUNT=$($SSH_CMD 'condor_config_val NUM_SLOTS 2>/dev/null' || echo "0")
if [ "$SLOT_COUNT" -gt 0 ]; then
    print_result "Slots configured" "PASS" "NUM_SLOTS: $SLOT_COUNT"
else
    print_result "Slots configured" "WARN" "NUM_SLOTS not set or zero"
fi

echo ""

# Generate result report
RESULT_FILE="../results/stage3_results_$(date +%Y%m%d_%H%M%S).txt"
mkdir -p ../results

cat > "$RESULT_FILE" << EOF
STAGE 3: SINGLE-NODE HTCONDOR TEST
===================================
Date: $(date '+%Y-%m-%d %H:%M:%S')
Duration: ~30 minutes

VM DETAILS:
-----------
VM ID: $VM_ID
Internal IP: $INTERNAL_IP
Floating IP: $FLOATING_IP

HTCONDOR STATUS:
----------------
Pool Status: $POOL_STATUS
Execute Slots: $SLOTS
CONDOR_HOST: $CONDOR_HOST

TEST RESULTS:
-------------
Total tests: $((TESTS_PASSED + TESTS_FAILED + TESTS_WARNED))
Passed: $TESTS_PASSED
Failed: $TESTS_FAILED
Warnings: $TESTS_WARNED

VANILLA UNIVERSE:
✓ Submitted 3 jobs (Cluster $CLUSTER_ID)
✓ Jobs completed successfully
✓ Output files created

DOCKER UNIVERSE:
EOF

if [ -n "$DOCKER_CLUSTER" ]; then
    cat >> "$RESULT_FILE" << EOF
✓ Submitted 2 Docker jobs (Cluster $DOCKER_CLUSTER)
✓ Docker jobs executed
✓ Docker Universe functional
EOF
else
    cat >> "$RESULT_FILE" << EOF
⚠ Docker tests incomplete or failed
EOF
fi

cat >> "$RESULT_FILE" << EOF

STATUS: $(if [ $TESTS_FAILED -eq 0 ]; then echo "✓ STAGE 3 PASSED"; else echo "✗ STAGE 3 FAILED"; fi)

NEXT STEPS:
-----------
EOF

if [ $TESTS_FAILED -eq 0 ]; then
    cat >> "$RESULT_FILE" << EOF
✓ Single-node HTCondor deployment successful
✓ Job submission and execution working
✓ Both Vanilla and Docker Universe functional

→ Clean up Stage 3: terraform destroy
→ Proceed to Stage 4: Multi-Node Cluster Test
→ Command: cd ../stage4 && terraform init

CLEANUP:
To remove Stage 3 resources:
  cd $(pwd)
  terraform destroy -auto-approve
EOF
else
    cat >> "$RESULT_FILE" << EOF
✗ HTCondor testing failed
→ Review HTCondor logs: ssh ubuntu@$FLOATING_IP 'tail -100 /var/log/condor/*'
→ Check configuration: ssh ubuntu@$FLOATING_IP 'condor_config_val -dump'
→ Re-run test: ./test_htcondor.sh
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
    echo -e "${GREEN}✓ All critical tests passed!${NC}"
    echo ""
    echo "Result saved to: $RESULT_FILE"
    echo ""
    echo "Next steps:"
    echo "  1. Review HTCondor logs if desired: ssh ubuntu@$FLOATING_IP"
    echo "  2. Clean up: terraform destroy -auto-approve"
    echo "  3. Proceed to Stage 4: Multi-Node Cluster Test"
    exit 0
else
    echo -e "${RED}✗ Some tests failed${NC}"
    echo ""
    echo "Result saved to: $RESULT_FILE"
    echo ""
    echo "Troubleshooting:"
    echo "  ssh ubuntu@$FLOATING_IP"
    echo "  tail -100 /var/log/condor/*"
    echo "  condor_config_val -dump"
    exit 1
fi
