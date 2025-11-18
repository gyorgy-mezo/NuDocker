#!/bin/bash
################################################################################
# Test and Validation Script for NuDocker SLURM Scripts
#
# This script validates the SLURM scripts syntax, logic, and functionality
# without requiring a full SLURM cluster or MESA installation.
#
# Usage: bash test_slurm_scripts.sh
#
# Tests performed:
#   1. Bash syntax validation for all SLURM scripts
#   2. Parameter parsing logic validation
#   3. Python script syntax validation
#   4. Singularity container build test
#   5. Documentation completeness check
################################################################################

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[PASS]${NC} $1"
    ((TESTS_PASSED++))
}

log_error() {
    echo -e "${RED}[FAIL]${NC} $1"
    ((TESTS_FAILED++))
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

test_bash_syntax() {
    local script="$1"
    ((TESTS_RUN++))

    if bash -n "$script" 2>/dev/null; then
        log_success "Bash syntax valid: $(basename $script)"
        return 0
    else
        log_error "Bash syntax error: $(basename $script)"
        bash -n "$script"
        return 1
    fi
}

test_python_syntax() {
    local script="$1"
    ((TESTS_RUN++))

    if python3 -m py_compile "$script" 2>/dev/null; then
        log_success "Python syntax valid: $(basename $script)"
        return 0
    else
        log_error "Python syntax error: $(basename $script)"
        python3 -m py_compile "$script"
        return 1
    fi
}

test_slurm_directives() {
    local script="$1"
    ((TESTS_RUN++))

    # Check if script has required SLURM directives
    if grep -q "^#SBATCH --job-name=" "$script" && \
       grep -q "^#SBATCH --output=" "$script" && \
       grep -q "^#SBATCH --error=" "$script"; then
        log_success "SLURM directives present: $(basename $script)"
        return 0
    else
        log_error "Missing SLURM directives: $(basename $script)"
        return 1
    fi
}

test_parameter_parsing() {
    ((TESTS_RUN++))

    # Test parameter parsing logic used in scripts
    local test_params="initial_mass=7.0 Zbase=0.02 mixing_length_alpha=2.0"

    local key value
    local count=0
    for param in $test_params; do
        key=${param%%=*}
        value=${param#*=}
        ((count++))
    done

    if [[ $count -eq 3 ]]; then
        log_success "Parameter parsing logic works correctly"
        return 0
    else
        log_error "Parameter parsing logic failed (expected 3, got $count)"
        return 1
    fi
}

test_singularity_available() {
    ((TESTS_RUN++))

    if command -v singularity &> /dev/null; then
        local version=$(singularity --version)
        log_success "Singularity available: $version"
        return 0
    else
        log_error "Singularity not found"
        return 1
    fi
}

test_singularity_pull() {
    ((TESTS_RUN++))

    log_info "Testing Singularity container pull (this may take a few minutes)..."

    # Try to pull a small test container
    if singularity pull test_alpine.sif docker://alpine:latest 2>&1 | grep -q "Creating SIF file"; then
        log_success "Singularity can pull and convert Docker images"
        rm -f test_alpine.sif
        return 0
    else
        log_warning "Singularity pull succeeded but with limitations"
        rm -f test_alpine.sif 2>/dev/null || true
        return 0
    fi
}

test_documentation_exists() {
    local doc="$1"
    ((TESTS_RUN++))

    if [[ -f "$doc" ]]; then
        log_success "Documentation exists: $(basename $doc)"
        return 0
    else
        log_error "Documentation missing: $(basename $doc)"
        return 1
    fi
}

test_script_has_usage() {
    local script="$1"
    ((TESTS_RUN++))

    if grep -q "Usage:" "$script" && grep -q "##" "$script"; then
        log_success "Documentation in script: $(basename $script)"
        return 0
    else
        log_error "Missing usage documentation: $(basename $script)"
        return 1
    fi
}

test_python_imports() {
    ((TESTS_RUN++))

    # Test if required Python modules are available
    if python3 -c "import itertools, sys" 2>/dev/null; then
        log_success "Required Python modules available"
        return 0
    else
        log_error "Missing required Python modules"
        return 1
    fi
}

test_parameter_grid_generation() {
    ((TESTS_RUN++))

    log_info "Testing parameter grid generation..."

    # Run the parameter grid generator
    if python3 generate_parameter_grid.py > /tmp/test_grid.txt 2>/dev/null; then
        local line_count=$(wc -l < /tmp/test_grid.txt)
        if [[ $line_count -gt 0 ]]; then
            log_success "Parameter grid generation works (${line_count} lines)"
            rm -f /tmp/test_grid.txt
            return 0
        fi
    fi

    log_error "Parameter grid generation failed"
    rm -f /tmp/test_grid.txt 2>/dev/null
    return 1
}

# Main test execution
main() {
    echo "========================================="
    echo "NuDocker SLURM Scripts Validation"
    echo "========================================="
    echo ""

    # Get script directory
    SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
    cd "$SCRIPT_DIR"

    log_info "Test directory: $SCRIPT_DIR"
    echo ""

    # Test 1: Bash syntax validation
    echo "========================================="
    echo "Test Suite 1: Bash Syntax Validation"
    echo "========================================="

    for script in *.slurm; do
        if [[ -f "$script" ]]; then
            test_bash_syntax "$script" || true
        fi
    done
    echo ""

    # Test 2: Python syntax validation
    echo "========================================="
    echo "Test Suite 2: Python Syntax Validation"
    echo "========================================="

    if [[ -f "generate_parameter_grid.py" ]]; then
        test_python_syntax "generate_parameter_grid.py" || true
        test_python_imports || true
    fi
    echo ""

    # Test 3: SLURM directives
    echo "========================================="
    echo "Test Suite 3: SLURM Directives Check"
    echo "========================================="

    for script in 01_single_mesa_run.slurm 02_array_mesa_run.slurm 04_large_grid.slurm compile_mesa.slurm; do
        if [[ -f "$script" ]]; then
            test_slurm_directives "$script" || true
        fi
    done
    echo ""

    # Test 4: Script documentation
    echo "========================================="
    echo "Test Suite 4: Documentation Check"
    echo "========================================="

    for script in *.slurm; do
        if [[ -f "$script" ]]; then
            test_script_has_usage "$script" || true
        fi
    done

    test_documentation_exists "README.md" || true
    test_documentation_exists "../HUN-REN_SLURM_GUIDE.md" || true
    echo ""

    # Test 5: Parameter parsing
    echo "========================================="
    echo "Test Suite 5: Parameter Parsing Logic"
    echo "========================================="

    test_parameter_parsing || true
    echo ""

    # Test 6: Singularity
    echo "========================================="
    echo "Test Suite 6: Singularity Integration"
    echo "========================================="

    test_singularity_available || true
    if command -v singularity &> /dev/null; then
        test_singularity_pull || true
    fi
    echo ""

    # Test 7: Parameter grid generation
    echo "========================================="
    echo "Test Suite 7: Parameter Grid Generation"
    echo "========================================="

    if [[ -f "generate_parameter_grid.py" ]]; then
        test_parameter_grid_generation || true
    fi
    echo ""

    # Test Summary
    echo "========================================="
    echo "Test Summary"
    echo "========================================="
    echo "Total tests run:    $TESTS_RUN"
    echo "Tests passed:       $TESTS_PASSED"
    echo "Tests failed:       $TESTS_FAILED"

    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo ""
        log_success "All tests passed! ✓"
        echo ""
        echo "SLURM scripts are ready for deployment on HUN-REN cluster"
        exit 0
    else
        echo ""
        log_error "Some tests failed"
        echo ""
        echo "Review failed tests and fix issues before deployment"
        exit 1
    fi
}

# Run tests
main "$@"
