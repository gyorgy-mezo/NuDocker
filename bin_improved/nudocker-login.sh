#!/bin/bash
#
# NuDocker Container Login (Improved Version)
# Login to existing MESA Docker container
#
# Author: NuGrid Team
# License: BSD 3-Clause

set -o pipefail

# =============================================================================
# CONFIGURATION
# =============================================================================

readonly SCRIPT_NAME="$(basename "$0")"
readonly VERSION="2.0.0"

# Colors for output
if [[ -t 1 ]]; then
    readonly RED='\033[0;31m'
    readonly GREEN='\033[0;32m'
    readonly YELLOW='\033[1;33m'
    readonly BLUE='\033[0;34m'
    readonly NC='\033[0m'
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

usage() {
    cat << EOF
${BLUE}NuDocker Container Login v${VERSION}${NC}

${GREEN}USAGE:${NC}
    ${SCRIPT_NAME} [OPTIONS] [CONTAINER_NAME]

${GREEN}ARGUMENTS:${NC}
    CONTAINER_NAME    Name of container to login to (optional)

${GREEN}OPTIONS:${NC}
    -n, --newshell    Open new shell in running container
    -l, --list        List all containers and exit
    -v, --verbose     Enable verbose output
    -h, --help        Show this help message
    --version         Show version information

${GREEN}BEHAVIOR:${NC}
    Without --newshell:  Starts stopped container and attaches
    With --newshell:     Opens new bash shell in running container

${GREEN}EXAMPLES:${NC}
    # Login to container (starts if stopped)
    ${SCRIPT_NAME} mesa-r9575

    # Open new shell in running container
    ${SCRIPT_NAME} --newshell mesa-r9575

    # List all containers
    ${SCRIPT_NAME} --list

    # Interactive mode (no container name)
    ${SCRIPT_NAME}

EOF
}

# Check if Docker is running
check_docker() {
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed"
        return 1
    fi

    if ! docker info &> /dev/null; then
        log_error "Docker daemon is not running"
        return 1
    fi

    return 0
}

# List all containers
list_containers() {
    log_info "Available containers:"
    echo ""

    if ! docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Image}}" | grep -v "^NAMES"; then
        echo "  No containers found"
        return 1
    fi

    return 0
}

# Get container status
get_container_status() {
    local container_name="$1"

    docker inspect --format='{{.State.Status}}' "$container_name" 2>/dev/null
}

# Check if container exists
container_exists() {
    local container_name="$1"

    docker ps -a --format '{{.Names}}' | grep -q "^${container_name}$"
}

# Check if container is running
container_running() {
    local container_name="$1"

    [[ "$(get_container_status "$container_name")" == "running" ]]
}

# Login to container (start if needed)
login_container() {
    local container_name="$1"
    local newshell="$2"
    local verbose="$3"

    if ! container_exists "$container_name"; then
        log_error "Container '${container_name}' does not exist"
        log_info "Available containers:"
        docker ps -a --format "  - {{.Names}} ({{.Status}})"
        log_info ""
        log_info "To create new container, run: nudocker-start.sh"
        return 1
    fi

    local status
    status=$(get_container_status "$container_name")
    [[ "$verbose" == "true" ]] && log_info "Container status: ${status}"

    if [[ "$newshell" == "true" ]]; then
        # Open new shell in running container
        if ! container_running "$container_name"; then
            log_error "Container '${container_name}' is not running (status: ${status})"
            log_info "Start container first: ${SCRIPT_NAME} ${container_name}"
            return 1
        fi

        log_info "Opening new shell in container '${container_name}'..."
        docker exec -it "$container_name" /bin/bash
    else
        # Start and attach to container
        if container_running "$container_name"; then
            log_info "Attaching to running container '${container_name}'..."
            docker attach "$container_name"
        else
            log_info "Starting container '${container_name}'..."
            docker start -i "$container_name"
        fi
    fi

    local exit_code=$?
    if [[ $exit_code -eq 0 ]]; then
        log_success "Session ended normally"
    else
        log_warning "Session ended with code ${exit_code}"
    fi

    return $exit_code
}

# Interactive container selection
select_container_interactive() {
    log_info "Available containers:"
    echo ""

    # Get list of containers
    local containers
    mapfile -t containers < <(docker ps -a --format '{{.Names}}')

    if [[ ${#containers[@]} -eq 0 ]]; then
        log_error "No containers found"
        log_info "Create a new container with: nudocker-start.sh"
        return 1
    fi

    # Display containers with numbers
    local i=1
    for container in "${containers[@]}"; do
        local status
        status=$(get_container_status "$container")
        local image
        image=$(docker inspect --format='{{.Config.Image}}' "$container")

        printf "%2d) %-20s [%-10s] %s\n" "$i" "$container" "$status" "$image"
        ((i++))
    done

    echo ""
    read -r -p "Select container number (or 'q' to quit): " selection

    if [[ "$selection" == "q" ]] || [[ "$selection" == "Q" ]]; then
        log_info "Cancelled"
        return 1
    fi

    if [[ ! "$selection" =~ ^[0-9]+$ ]] || [[ "$selection" -lt 1 ]] || [[ "$selection" -gt ${#containers[@]} ]]; then
        log_error "Invalid selection"
        return 1
    fi

    # Return selected container name
    echo "${containers[$((selection-1))]}"
    return 0
}

# =============================================================================
# MAIN FUNCTION
# =============================================================================

main() {
    local container_name=""
    local newshell="false"
    local list_only="false"
    local verbose="false"

    # Parse options
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -n|--newshell)
                newshell="true"
                shift
                ;;
            -l|--list)
                list_only="true"
                shift
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
                if [[ -z "$container_name" ]]; then
                    container_name="$1"
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

    # Check Docker
    check_docker || exit 1

    # Handle list-only mode
    if [[ "$list_only" == "true" ]]; then
        list_containers
        exit $?
    fi

    # Interactive mode if no container specified
    if [[ -z "$container_name" ]]; then
        container_name=$(select_container_interactive)
        if [[ $? -ne 0 ]] || [[ -z "$container_name" ]]; then
            exit 1
        fi
    fi

    # Display banner
    echo -e "${BLUE}╔════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}      NuDocker Container Login v${VERSION}      ${BLUE}║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════╝${NC}"
    echo ""

    # Login to container
    login_container "$container_name" "$newshell" "$verbose"
}

# Run main function
main "$@"
