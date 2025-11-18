#!/bin/bash
#
# NuDocker Utilities
# Common operations for managing NuDocker containers
#
# Author: NuGrid Team
# License: BSD 3-Clause

set -o pipefail

# =============================================================================
# CONFIGURATION
# =============================================================================

readonly SCRIPT_NAME="$(basename "$0")"
readonly VERSION="2.0.0"

# Colors
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
${BLUE}NuDocker Utilities v${VERSION}${NC}

${GREEN}USAGE:${NC}
    ${SCRIPT_NAME} COMMAND [OPTIONS]

${GREEN}COMMANDS:${NC}
    list              List all containers
    info CONTAINER    Show detailed container information
    clean             Remove stopped containers
    cleanup           Remove all containers and images (DESTRUCTIVE!)
    images            List NuDocker images
    pull IMAGE        Pull NuDocker image from Docker Hub
    validate PATH     Validate MESA installation in directory
    status            Show Docker system status
    help              Show this help message

${GREEN}EXAMPLES:${NC}
    # List all containers
    ${SCRIPT_NAME} list

    # Show container details
    ${SCRIPT_NAME} info mesa-r9575

    # Remove stopped containers
    ${SCRIPT_NAME} clean

    # Pull latest image
    ${SCRIPT_NAME} pull nugrid/nudome:20.1

    # Validate MESA installation
    ${SCRIPT_NAME} validate ~/mesa-versions/mesa-r9575

    # Show system status
    ${SCRIPT_NAME} status

EOF
}

# Check Docker
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

# List containers
cmd_list() {
    log_info "NuDocker containers:"
    echo ""
    docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Image}}\t{{.CreatedAt}}" | head -20
}

# Show container info
cmd_info() {
    local container_name="$1"

    if [[ -z "$container_name" ]]; then
        log_error "Container name required"
        return 1
    fi

    if ! docker ps -a --format '{{.Names}}' | grep -q "^${container_name}$"; then
        log_error "Container '${container_name}' not found"
        return 1
    fi

    log_info "Container information: ${container_name}"
    echo ""

    # Get info
    local status image created mounts
    status=$(docker inspect --format='{{.State.Status}}' "$container_name")
    image=$(docker inspect --format='{{.Config.Image}}' "$container_name")
    created=$(docker inspect --format='{{.Created}}' "$container_name")
    mounts=$(docker inspect --format='{{range .Mounts}}{{.Source}} -> {{.Destination}}{{"\n"}}{{end}}' "$container_name")

    echo -e "${BLUE}Name:${NC}      ${container_name}"
    echo -e "${BLUE}Status:${NC}    ${status}"
    echo -e "${BLUE}Image:${NC}     ${image}"
    echo -e "${BLUE}Created:${NC}   ${created}"
    echo -e "${BLUE}Mounts:${NC}"
    echo "$mounts" | sed 's/^/  /'
}

# Clean stopped containers
cmd_clean() {
    log_info "Removing stopped containers..."

    local stopped_containers
    stopped_containers=$(docker ps -a --filter "status=exited" --format '{{.Names}}' | wc -l)

    if [[ "$stopped_containers" -eq 0 ]]; then
        log_info "No stopped containers to remove"
        return 0
    fi

    log_warning "This will remove ${stopped_containers} stopped container(s)"
    read -r -p "Continue? [y/N] " response

    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        log_info "Cancelled"
        return 0
    fi

    docker container prune -f
    log_success "Cleaned up stopped containers"
}

# Cleanup everything (destructive)
cmd_cleanup() {
    log_warning "This will remove ALL NuDocker containers and images!"
    log_warning "This operation cannot be undone!"
    echo ""
    read -r -p "Type 'DELETE' to confirm: " response

    if [[ "$response" != "DELETE" ]]; then
        log_info "Cancelled"
        return 0
    fi

    log_info "Removing all containers..."
    docker ps -a -q | xargs -r docker rm -f

    log_info "Removing NuDocker images..."
    docker images 'nugrid/nudome' --format '{{.ID}}' | xargs -r docker rmi -f

    log_success "Cleanup complete"
}

# List images
cmd_images() {
    log_info "NuDocker images:"
    echo ""
    docker images 'nugrid/nudome' --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}"

    echo ""
    log_info "Available images on Docker Hub:"
    echo "  - nugrid/nudome:16.0     (Ubuntu 16.04, MESA SDK 20160129)"
    echo "  - nugrid/nudome:18.0     (Ubuntu 18.04, MESA SDK 20180822)"
    echo "  - nugrid/nudome:20.031   (Ubuntu 20.04, MESA SDK 20.3.1)"
    echo "  - nugrid/nudome:20.1     (Ubuntu 20.04, MESA SDK 21.4.1)"
}

# Pull image
cmd_pull() {
    local image="$1"

    if [[ -z "$image" ]]; then
        log_error "Image name required"
        return 1
    fi

    log_info "Pulling image: ${image}"
    docker pull "$image"
}

# Validate MESA installation
cmd_validate() {
    local mesa_path="$1"

    if [[ -z "$mesa_path" ]]; then
        log_error "MESA path required"
        return 1
    fi

    mesa_path=$(eval echo "$mesa_path")

    if [[ ! -d "$mesa_path" ]]; then
        log_error "Path does not exist: ${mesa_path}"
        return 1
    fi

    log_info "Validating MESA installation: ${mesa_path}"
    echo ""

    local errors=0

    # Check essential directories
    local dirs=("star" "data" "utils")
    for dir in "${dirs[@]}"; do
        if [[ -d "${mesa_path}/${dir}" ]]; then
            echo -e "${GREEN}✓${NC} Directory exists: ${dir}"
        else
            echo -e "${RED}✗${NC} Missing directory: ${dir}"
            ((errors++))
        fi
    done

    # Check install script
    if [[ -f "${mesa_path}/install" ]]; then
        echo -e "${GREEN}✓${NC} Install script found"
    else
        echo -e "${RED}✗${NC} Install script not found"
        ((errors++))
    fi

    # Check if compiled
    if [[ -d "${mesa_path}/star/work" ]]; then
        if [[ -f "${mesa_path}/star/work/mk" ]]; then
            echo -e "${GREEN}✓${NC} Work directory configured"
        else
            echo -e "${YELLOW}!${NC} Work directory exists but not configured"
        fi
    fi

    echo ""
    if [[ $errors -eq 0 ]]; then
        log_success "MESA installation appears valid"
        return 0
    else
        log_error "MESA installation has ${errors} issue(s)"
        return 1
    fi
}

# Show system status
cmd_status() {
    log_info "Docker system status:"
    echo ""

    # Docker version
    docker version --format 'Client: {{.Client.Version}}, Server: {{.Server.Version}}'

    # Container count
    local running stopped
    running=$(docker ps -q | wc -l)
    stopped=$(docker ps -a -q | wc -l)
    stopped=$((stopped - running))

    echo "Containers: ${running} running, ${stopped} stopped"

    # Image count
    local images
    images=$(docker images -q | wc -l)
    echo "Images: ${images} total"

    # Disk usage
    echo ""
    docker system df

    echo ""
    log_info "NuDocker containers:"
    docker ps -a --format "  - {{.Names}} [{{.Status}}]" | head -10
}

# =============================================================================
# MAIN FUNCTION
# =============================================================================

main() {
    local command="$1"
    shift

    if [[ -z "$command" ]]; then
        usage
        exit 1
    fi

    check_docker || exit 1

    case "$command" in
        list)
            cmd_list
            ;;
        info)
            cmd_info "$@"
            ;;
        clean)
            cmd_clean
            ;;
        cleanup)
            cmd_cleanup
            ;;
        images)
            cmd_images
            ;;
        pull)
            cmd_pull "$@"
            ;;
        validate)
            cmd_validate "$@"
            ;;
        status)
            cmd_status
            ;;
        help|--help|-h)
            usage
            exit 0
            ;;
        *)
            log_error "Unknown command: ${command}"
            echo ""
            usage
            exit 1
            ;;
    esac
}

main "$@"
