#!/bin/bash
# HTCondor Scripts Testing and Validation Framework
# Tests submit files, DAG files, and wrapper scripts
# Version: 1.0

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counters
TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_WARNED=0

print_result() {
    local test_name="$1"
    local result="$2"
    local message="${3:-}"

    TESTS_TOTAL=$((TESTS_TOTAL + 1))

    if [ "$result" == "PASS" ]; then
        echo -e "${GREEN}✓ PASS${NC}: $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    elif [ "$result" == "FAIL" ]; then
        echo -e "${RED}✗ FAIL${NC}: $test_name"
        if [ -n "$message" ]; then
            echo -e "  ${RED}└─${NC} $message"
        fi
        TESTS_FAILED=$((TESTS_FAILED + 1))
    elif [ "$result" == "WARN" ]; then
        echo -e "${YELLOW}⚠ WARN${NC}: $test_name"
        if [ -n "$message" ]; then
            echo -e "  ${YELLOW}└─${NC} $message"
        fi
        TESTS_WARNED=$((TESTS_WARNED + 1))
    else
        echo -e "${BLUE}ℹ INFO${NC}: $test_name"
    fi
}

echo "========================================="
echo "HTCondor Scripts Testing Framework"
echo "========================================="
echo "Script Directory: $SCRIPT_DIR"
echo "Date: $(date '+%Y-%m-%d %H:%M:%S')"
echo "========================================="
echo ""

# ==============================================================================
# Test Suite 1: File Existence Check
# ==============================================================================
echo "Test Suite 1: File Existence Check"
echo "-----------------------------------"

REQUIRED_FILES=(
    "run_mesa_model.sh"
    "nugrid_lowmass.sub"
    "nugrid_mediummass.sub"
    "nugrid_highmass.sub"
    "nugrid_study.dag"
    "nugrid_study.config"
    "README.md"
)

for file in "${REQUIRED_FILES[@]}"; do
    if [ -f "$file" ]; then
        print_result "File exists: $file" "PASS"
    else
        print_result "File exists: $file" "FAIL" "Required file not found"
    fi
done
echo ""

# ==============================================================================
# Test Suite 2: Bash Syntax Validation
# ==============================================================================
echo "Test Suite 2: Bash Syntax Validation"
echo "-------------------------------------"

for script in run_mesa_model.sh; do
    if [ -f "$script" ]; then
        if bash -n "$script" 2>/dev/null; then
            print_result "Bash syntax: $script" "PASS"
        else
            ERROR_MSG=$(bash -n "$script" 2>&1 || true)
            print_result "Bash syntax: $script" "FAIL" "$ERROR_MSG"
        fi
    else
        print_result "File exists for test: $script" "FAIL"
    fi
done
echo ""

# ==============================================================================
# Test Suite 3: HTCondor Submit File Syntax
# ==============================================================================
echo "Test Suite 3: HTCondor Submit File Syntax"
echo "------------------------------------------"

if command -v condor_submit >/dev/null 2>&1; then
    for submit in nugrid_*.sub; do
        if [ -f "$submit" ]; then
            ERROR_MSG=$(condor_submit -dry-run "$submit" 2>&1 || true)
            if condor_submit -dry-run "$submit" >/dev/null 2>&1; then
                print_result "Submit syntax: $submit" "PASS"
            else
                print_result "Submit syntax: $submit" "FAIL" "$(echo "$ERROR_MSG" | head -1)"
            fi
        fi
    done
else
    print_result "HTCondor installed (condor_submit)" "WARN" "HTCondor not available, skipping submit validation"
fi
echo ""

# ==============================================================================
# Test Suite 4: DAGMan Syntax Validation
# ==============================================================================
echo "Test Suite 4: DAGMan Syntax Validation"
echo "---------------------------------------"

if command -v condor_submit_dag >/dev/null 2>&1; then
    for dag in *.dag; do
        if [ -f "$dag" ]; then
            # Create temporary directory for dry-run
            TMP_DIR=$(mktemp -d)
            ERROR_MSG=$(condor_submit_dag -no_submit -outfile_dir "$TMP_DIR" "$dag" 2>&1 || true)

            if condor_submit_dag -no_submit -outfile_dir "$TMP_DIR" "$dag" >/dev/null 2>&1; then
                print_result "DAG syntax: $dag" "PASS"
            else
                print_result "DAG syntax: $dag" "FAIL" "$(echo "$ERROR_MSG" | head -1)"
            fi
            rm -rf "$TMP_DIR"
        fi
    done
else
    print_result "DAGMan installed (condor_submit_dag)" "WARN" "HTCondor DAGMan not available, skipping DAG validation"
fi
echo ""

# ==============================================================================
# Test Suite 5: Submit File Required Directives
# ==============================================================================
echo "Test Suite 5: Submit File Required Directives"
echo "----------------------------------------------"

for submit in nugrid_*.sub; do
    if [ ! -f "$submit" ]; then continue; fi

    # Check universe
    if grep -q "^universe" "$submit"; then
        UNIVERSE=$(grep "^universe" "$submit" | awk '{print $3}')
        print_result "$submit: has 'universe' directive ($UNIVERSE)" "PASS"
    else
        print_result "$submit: has 'universe' directive" "FAIL" "Missing universe directive"
    fi

    # Check executable
    if grep -q "^executable" "$submit"; then
        EXECUTABLE=$(grep "^executable" "$submit" | awk '{print $3}')
        print_result "$submit: has 'executable' directive ($EXECUTABLE)" "PASS"
    else
        print_result "$submit: has 'executable' directive" "FAIL" "Missing executable directive"
    fi

    # Check log file
    if grep -q "^log" "$submit"; then
        print_result "$submit: has 'log' directive" "PASS"
    else
        print_result "$submit: has 'log' directive" "WARN" "No log file specified"
    fi

    # Check resource requests
    if grep -q "^request_cpus" "$submit"; then
        CPUS=$(grep "^request_cpus" "$submit" | awk '{print $3}')
        print_result "$submit: requests CPUs ($CPUS)" "PASS"
    else
        print_result "$submit: requests CPUs" "WARN" "No CPU request (will use default)"
    fi

    if grep -q "^request_memory" "$submit"; then
        MEM=$(grep "^request_memory" "$submit" | awk '{print $3}')
        print_result "$submit: requests memory ($MEM)" "PASS"
    else
        print_result "$submit: requests memory" "WARN" "No memory request (will use default)"
    fi
done
echo ""

# ==============================================================================
# Test Suite 6: Docker Integration Check
# ==============================================================================
echo "Test Suite 6: Docker Integration Check"
echo "---------------------------------------"

if command -v docker >/dev/null 2>&1; then
    print_result "Docker installed" "PASS"

    # Check Docker service
    if systemctl is-active --quiet docker 2>/dev/null || pgrep -x dockerd >/dev/null 2>&1; then
        print_result "Docker service running" "PASS"
    else
        print_result "Docker service running" "WARN" "Docker installed but not running"
    fi

    # Check if NuDocker images exist
    for image in nugrid/nudome:16.0 nugrid/nudome:18.0 nugrid/nudome:20.031; do
        if docker image inspect "$image" >/dev/null 2>&1; then
            print_result "Docker image exists: $image" "PASS"
        else
            print_result "Docker image exists: $image" "WARN" "Pull with: docker pull $image"
        fi
    done
else
    print_result "Docker installed" "FAIL" "Docker not found (required for universe=docker)"
fi
echo ""

# ==============================================================================
# Test Suite 7: Parameter Queue Validation
# ==============================================================================
echo "Test Suite 7: Parameter Queue Validation"
echo "-----------------------------------------"

for submit in nugrid_*.sub; do
    if [ ! -f "$submit" ]; then continue; fi

    # Check for queue directive
    if grep -q "^queue" "$submit"; then
        QUEUE_LINE=$(grep "^queue" "$submit" | head -1)
        print_result "$submit: has 'queue' directive" "PASS"

        # Analyze queue type
        if echo "$QUEUE_LINE" | grep -q "from"; then
            # Extract parameter count
            PARAM_START=$(grep -n "queue.*from (" "$submit" | cut -d: -f1 | head -1)
            if [ -n "$PARAM_START" ]; then
                JOB_COUNT=$(tail -n +$((PARAM_START + 1)) "$submit" | sed '/^)/q' | grep -c "^  [0-9]\+\.[0-9]\+," || true)
                if [ "$JOB_COUNT" -gt 0 ]; then
                    print_result "$submit: queues $JOB_COUNT jobs (parameter sweep)" "PASS"
                fi
            fi
        elif echo "$QUEUE_LINE" | grep -qE "queue [0-9]+"; then
            NUM=$(echo "$QUEUE_LINE" | grep -oE "[0-9]+")
            print_result "$submit: queues $NUM jobs (simple queue)" "PASS"
        fi
    else
        print_result "$submit: has 'queue' directive" "FAIL" "Missing queue directive"
    fi

    # Check parameters used in queue
    if grep -q "queue.*mass,metallicity,alpha" "$submit"; then
        print_result "$submit: uses mass, metallicity, alpha parameters" "PASS"
    fi
done
echo ""

# ==============================================================================
# Test Suite 8: DAG File Structure Validation
# ==============================================================================
echo "Test Suite 8: DAG File Structure Validation"
echo "--------------------------------------------"

for dag in *.dag; do
    if [ ! -f "$dag" ]; then continue; fi

    # Check for JOB definitions
    JOB_COUNT=$(grep -c "^JOB" "$dag" || true)
    if [ "$JOB_COUNT" -gt 0 ]; then
        print_result "$dag: defines $JOB_COUNT jobs" "PASS"
    else
        print_result "$dag: defines jobs" "FAIL" "No JOB definitions found"
    fi

    # Check for PARENT/CHILD dependencies
    if grep -q "^PARENT" "$dag"; then
        DEP_COUNT=$(grep -c "^PARENT" "$dag" || true)
        print_result "$dag: has $DEP_COUNT dependency relationships" "PASS"
    else
        print_result "$dag: has dependencies" "WARN" "No PARENT/CHILD relationships"
    fi

    # Check for RETRY directives
    if grep -q "^RETRY" "$dag"; then
        print_result "$dag: configures retries" "PASS"
    else
        print_result "$dag: configures retries" "WARN" "No RETRY directives"
    fi

    # Verify referenced submit files exist
    while IFS= read -r job_line; do
        SUBMIT_FILE=$(echo "$job_line" | awk '{print $3}')
        if [ -f "$SUBMIT_FILE" ]; then
            print_result "$dag: references existing submit file ($SUBMIT_FILE)" "PASS"
        else
            print_result "$dag: references existing submit file ($SUBMIT_FILE)" "FAIL" "File not found"
        fi
    done < <(grep "^JOB" "$dag")
done
echo ""

# ==============================================================================
# Test Suite 9: Executable Script Validation
# ==============================================================================
echo "Test Suite 9: Executable Script Validation"
echo "-------------------------------------------"

EXEC_SCRIPT="run_mesa_model.sh"
if [ -f "$EXEC_SCRIPT" ]; then
    # Check if executable
    if [ -x "$EXEC_SCRIPT" ]; then
        print_result "$EXEC_SCRIPT: is executable" "PASS"
    else
        print_result "$EXEC_SCRIPT: is executable" "WARN" "File exists but not executable (chmod +x needed)"
    fi

    # Check shebang
    if head -1 "$EXEC_SCRIPT" | grep -q "^#!/bin/bash"; then
        print_result "$EXEC_SCRIPT: has correct shebang" "PASS"
    else
        SHEBANG=$(head -1 "$EXEC_SCRIPT")
        print_result "$EXEC_SCRIPT: has correct shebang" "WARN" "Found: $SHEBANG"
    fi

    # Check for required variables
    for var in MESA_DIR OMP_NUM_THREADS; do
        if grep -q "\$${var}" "$EXEC_SCRIPT"; then
            print_result "$EXEC_SCRIPT: uses \$${var}" "PASS"
        else
            print_result "$EXEC_SCRIPT: uses \$${var}" "WARN" "Variable not used"
        fi
    done

    # Check for error handling
    if grep -q "set -e" "$EXEC_SCRIPT"; then
        print_result "$EXEC_SCRIPT: uses 'set -e' (exit on error)" "PASS"
    else
        print_result "$EXEC_SCRIPT: uses 'set -e' (exit on error)" "WARN" "No strict error handling"
    fi
fi
echo ""

# ==============================================================================
# Test Suite 10: Documentation Check
# ==============================================================================
echo "Test Suite 10: Documentation Check"
echo "-----------------------------------"

if [ -f "README.md" ]; then
    print_result "README.md exists" "PASS"

    # Check README size
    README_LINES=$(wc -l < README.md)
    if [ "$README_LINES" -gt 100 ]; then
        print_result "README.md is comprehensive ($README_LINES lines)" "PASS"
    else
        print_result "README.md is comprehensive ($README_LINES lines)" "WARN" "Documentation might be incomplete"
    fi

    # Check for required sections
    for section in "Usage" "Quick Start" "Requirements" "HTCondor"; do
        if grep -qi "$section" README.md; then
            print_result "README.md: has '$section' section" "PASS"
        else
            print_result "README.md: has '$section' section" "WARN" "Section not found"
        fi
    done

    # Check for examples
    if grep -q '```' README.md; then
        print_result "README.md: includes code examples" "PASS"
    else
        print_result "README.md: includes code examples" "WARN" "No code blocks found"
    fi
else
    print_result "README.md exists" "FAIL" "Documentation file missing"
fi
echo ""

# ==============================================================================
# Test Suite 11: Configuration File Validation
# ==============================================================================
echo "Test Suite 11: Configuration File Validation"
echo "---------------------------------------------"

if [ -f "nugrid_study.config" ]; then
    print_result "DAGMan config file exists" "PASS"

    # Check for key DAGMan settings
    for setting in "DAGMAN_MAX_JOBS_SUBMITTED" "DAGMAN_MAX_JOBS_IDLE" "DAGMAN_SUBMIT_DELAY"; do
        if grep -q "^$setting" nugrid_study.config; then
            VALUE=$(grep "^$setting" nugrid_study.config | awk '{print $3}')
            print_result "DAGMan config: sets $setting ($VALUE)" "PASS"
        else
            print_result "DAGMan config: sets $setting" "WARN" "Setting not configured"
        fi
    done
else
    print_result "DAGMan config file exists" "WARN" "nugrid_study.config not found (using defaults)"
fi
echo ""

# ==============================================================================
# Summary
# ==============================================================================
echo "========================================="
echo "Test Summary"
echo "========================================="
echo "Total tests run: $TESTS_TOTAL"
echo -e "${GREEN}Passed:  $TESTS_PASSED${NC}"
echo -e "${YELLOW}Warnings: $TESTS_WARNED${NC}"
echo -e "${RED}Failed:   $TESTS_FAILED${NC}"
echo ""

# Calculate pass rate
if [ $TESTS_TOTAL -gt 0 ]; then
    PASS_RATE=$((TESTS_PASSED * 100 / TESTS_TOTAL))
    echo "Pass rate: $PASS_RATE%"
fi

echo "========================================="

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ All critical tests passed!${NC}"
    if [ $TESTS_WARNED -gt 0 ]; then
        echo -e "${YELLOW}⚠ $TESTS_WARNED warnings - review recommended${NC}"
    fi
    exit 0
else
    echo -e "${RED}✗ $TESTS_FAILED test(s) failed${NC}"
    echo "Please fix the errors above before submitting jobs."
    exit 1
fi
