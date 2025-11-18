#!/bin/bash
#
# NuDocker Container Starter (Improved Version)
# Create and start a new MESA Docker container
#
# Author: NuGrid Team
# License: BSD 3-Clause

set -o pipefail

# =============================================================================
# CONFIGURATION
# =============================================================================

readonly SCRIPT_NAME="$(basename "$0")"
readonly VERSION="2.0.0"

# Colors for output (disable if not in terminal)
if [[ -t 1 ]]; then
    readonly RED='\033[0;31m'
    readonly GREEN='\033[0;32m'
    readonly YELLOW='\033[1;33m'
    readonly BLUE='\033[0;34m'
    readonly NC='\033[0m' # No Color
else
    readonly RED=''
    readonly GREEN=''
    readonly YELLOW=''
    readonly BLUE=''
    readonly NC=''
fi

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

# Print colored message
log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

# Display usage information
usage() {
    cat << EOF
${BLUE}NuDocker Container Starter v${VERSION}${NC}

${GREEN}USAGE:${NC}
    ${SCRIPT_NAME} [OPTIONS] CONTAINER_NAME IMAGE_NAME MESA_PATH

${GREEN}ARGUMENTS:${NC}
    CONTAINER_NAME    Name for the container (e.g., mesa-r9575)
    IMAGE_NAME        Docker image to use (e.g., nugrid/nudome:16.0)
    MESA_PATH         Full path to MESA source directory on host

${GREEN}OPTIONS:${NC}
    -m PATH           Mount additional directory at /home/user/mnt
    -t THREADS        Set OMP_NUM_THREADS (default: 4)
    -v, --verbose     Enable verbose output
    -h, --help        Show this help message
    --version         Show version information

${GREEN}EXAMPLES:${NC}
    # Basic usage
    ${SCRIPT_NAME} mesa-r9575 nugrid/nudome:16.0 ~/mesa-versions/mesa-r9575

    # With additional mount for runs
    ${SCRIPT_NAME} -m ~/mesa-runs mesa-r9575 nugrid/nudome:16.0 ~/mesa-versions/mesa-r9575

    # Set thread count
    ${SCRIPT_NAME} -t 8 mesa-r9575 nugrid/nudome:16.0 ~/mesa-versions/mesa-r9575

${GREEN}AVAILABLE IMAGES:${NC}
    nugrid/nudome:14.0     - Ubuntu 12.04, MESA SDK 20141212 (deprecated)
    nugrid/nudome:16.0     - Ubuntu 16.04, MESA SDK 20160129
    nugrid/nudome:18.0     - Ubuntu 18.04, MESA SDK 20180822
    nugrid/nudome:20.031   - Ubuntu 20.04, MESA SDK 20.3.1
    nugrid/nudome:20.1     - Ubuntu 20.04, MESA SDK 21.4.1

EOF
}

# Check if Docker is installed and running
check_docker() {
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed"
        log_info "Install Docker from: https://docs.docker.com/get-docker/"
        return 1
    fi

    if ! docker info &> /dev/null; then
        log_error "Docker daemon is not running"
        log_info "Start Docker service or Docker Desktop"
        return 1
    fi

    return 0
}

# Validate that a path exists
validate_path() {
    local path="$1"
    local description="$2"

    if [[ -z "$path" ]]; then
        log_error "${description} is empty"
        return 1
    fi

    # Expand tilde and environment variables
    path=$(eval echo "$path")

    if [[ ! -e "$path" ]]; then
        log_error "${description} does not exist: ${path}"
        return 1
    fi

    if [[ ! -d "$path" ]]; then
        log_error "${description} is not a directory: ${path}"
        return 1
    fi

    if [[ ! -r "$path" ]]; then
        log_error "${description} is not readable: ${path}"
        return 1
    fi

    return 0
}

# Check if container name already exists
check_container_exists() {
    local container_name="$1"

    if docker ps -a --format '{{.Names}}' | grep -q "^${container_name}$"; then
        log_error "Container '${container_name}' already exists"
        log_info "To use existing container, run: nudocker-login.sh ${container_name}"
        log_info "To remove existing container, run: docker rm ${container_name}"
        return 1
    fi

    return 0
}

# Validate container name
validate_container_name() {
    local name="$1"

    if [[ -z "$name" ]]; then
        log_error "Container name is empty"
        return 1
    fi

    # Docker container name must match: [a-zA-Z0-9][a-zA-Z0-9_.-]*
    if [[ ! "$name" =~ ^[a-zA-Z0-9][a-zA-Z0-9_.-]*$ ]]; then
        log_error "Invalid container name: ${name}"
        log_info "Container name must start with alphanumeric and contain only: a-z A-Z 0-9 _ . -"
        return 1
    fi

    return 0
}

# Validate image name format
validate_image_name() {
    local image="$1"

    if [[ -z "$image" ]]; then
        log_error "Image name is empty"
        return 1
    fi

    # Basic validation (can be improved)
    if [[ ! "$image" =~ ^[a-zA-Z0-9/_.-]+:[a-zA-Z0-9._-]+$ ]] && [[ ! "$image" =~ ^[a-zA-Z0-9/_.-]+$ ]]; then
        log_error "Invalid image name format: ${image}"
        log_info "Expected format: repository/name:tag or repository/name"
        return 1
    fi

    return 0
}

# Check if image exists locally or can be pulled
check_image() {
    local image="$1"
    local verbose="$2"

    if docker image inspect "$image" &> /dev/null; then
        [[ "$verbose" == "true" ]] && log_info "Image '${image}' found locally"
        return 0
    fi

    log_warning "Image '${image}' not found locally"
    log_info "Docker will attempt to pull the image (this may take several minutes)"
    return 0
}

# Create and start container
start_container() {
    local container_name="$1"
    local image_name="$2"
    local mesa_path="$3"
    local extra_mount="$4"
    local omp_threads="$5"
    local verbose="$6"

    # Expand paths
    mesa_path=$(eval echo "$mesa_path")
    [[ -n "$extra_mount" ]] && extra_mount=$(eval echo "$extra_mount")

    # Build docker run command
    local docker_args=(
        "run"
        "--hostname" "$container_name"
        "--name" "$container_name"
        "--volume" "${mesa_path}:/home/user/mesa"
    )

    # Add extra mount if specified
    if [[ -n "$extra_mount" ]]; then
        docker_args+=("--volume" "${extra_mount}:/home/user/mnt")
    fi

    # Add environment variable for OMP threads
    if [[ -n "$omp_threads" ]]; then
        docker_args+=("--env" "OMP_NUM_THREADS=${omp_threads}")
    fi

    # Add interactive terminal
    docker_args+=("-it" "$image_name" "/bin/bash")

    # Show command in verbose mode
    if [[ "$verbose" == "true" ]]; then
        log_info "Executing: docker ${docker_args[*]}"
    fi

    # Execute Docker command
    log_info "Starting container '${container_name}'..."
    docker "${docker_args[@]}"
    local exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        log_success "Container exited normally"
        log_info "To re-enter container, run: nudocker-login.sh ${container_name}"
    else
        log_warning "Container exited with code ${exit_code}"
    fi

    return $exit_code
}

# =============================================================================
# MAIN FUNCTION
# =============================================================================

main() {
    local container_name=""
    local image_name=""
    local mesa_path=""
    local extra_mount=""
    local omp_threads=""
    local verbose="false"

    # Parse options
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -m)
                extra_mount="$2"
                shift 2
                ;;
            -t)
                omp_threads="$2"
                shift 2
                ;;
            -v|--verbose)
                verbose="true"
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            --version)
                echo "${SCRIPT_NAME} version ${VERSION}"
                exit 0
                ;;
            -*)
                log_error "Unknown option: $1"
                echo ""
                usage
                exit 1
                ;;
            *)
                # Positional arguments
                if [[ -z "$container_name" ]]; then
                    container_name="$1"
                elif [[ -z "$image_name" ]]; then
                    image_name="$1"
                elif [[ -z "$mesa_path" ]]; then
                    mesa_path="$1"
                else
                    log_error "Too many arguments"
                    echo ""
                    usage
                    exit 1
                fi
                shift
                ;;
        esac
    done

    # Check required arguments
    if [[ -z "$container_name" ]] || [[ -z "$image_name" ]] || [[ -z "$mesa_path" ]]; then
        log_error "Missing required arguments"
        echo ""
        usage
        exit 1
    fi

    # Display banner
    echo -e "${BLUE}╔════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}     NuDocker Container Starter v${VERSION}     ${BLUE}║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════╝${NC}"
    echo ""

    # Run validations
    log_info "Running pre-flight checks..."

    check_docker || exit 1
    validate_container_name "$container_name" || exit 1
    check_container_exists "$container_name" || exit 1
    validate_image_name "$image_name" || exit 1
    validate_path "$mesa_path" "MESA path" || exit 1

    if [[ -n "$extra_mount" ]]; then
        validate_path "$extra_mount" "Extra mount path" || exit 1
        log_info "Extra mount: ${extra_mount} -> /home/user/mnt"
    fi

    if [[ -n "$omp_threads" ]]; then
        if [[ ! "$omp_threads" =~ ^[0-9]+$ ]]; then
            log_error "OMP_NUM_THREADS must be a positive integer"
            exit 1
        fi
        log_info "OpenMP threads: ${omp_threads}"
    fi

    check_image "$image_name" "$verbose"

    log_success "All checks passed"
    echo ""

    # Display configuration
    log_info "Configuration:"
    echo "  Container name: ${container_name}"
    echo "  Image:          ${image_name}"
    echo "  MESA path:      ${mesa_path}"
    [[ -n "$extra_mount" ]] && echo "  Extra mount:    ${extra_mount}"
    [[ -n "$omp_threads" ]] && echo "  OMP threads:    ${omp_threads}"
    echo ""

    # Start container
    start_container "$container_name" "$image_name" "$mesa_path" "$extra_mount" "$omp_threads" "$verbose"
}

# Run main function
main "$@"
