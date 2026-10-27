#!/bin/bash
# Common library functions for Spacelift POC scripts
# Source this file in other scripts: source "$(dirname "$0")/lib/common.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    local title="$1"
    local width=40
    echo -e "\n${BLUE}$(printf '=%.0s' $(seq 1 $width))${NC}"
    echo -e "${BLUE}  $title${NC}"
    echo -e "${BLUE}$(printf '=%.0s' $(seq 1 $width))${NC}\n"
}

# Function to check if a command exists
check_command() {
    if ! command -v "$1" &> /dev/null; then
        print_error "$1 is not installed. Please install $1 and try again."
        case "$1" in
            "docker")
                echo "Installation guides:"
                echo "  - macOS: https://docs.docker.com/desktop/install/mac-install/"
                echo "  - Linux: https://docs.docker.com/engine/install/"
                echo "  - Windows: https://docs.docker.com/desktop/install/windows-install/"
                ;;
            "docker-compose")
                echo "Installation guides:"
                echo "  - Usually included with Docker Desktop"
                echo "  - Linux: https://docs.docker.com/compose/install/"
                ;;
            "kind")
                echo "Installation guides:"
                echo "  - macOS: brew install kind"
                echo "  - Linux: https://kind.sigs.k8s.io/docs/user/quick-start/#installation"
                echo "  - Windows: choco install kind"
                ;;
            "kubectl")
                echo "Installation guides:"
                echo "  - macOS: brew install kubectl"
                echo "  - Linux: https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/"
                echo "  - Windows: choco install kubernetes-cli"
                ;;
            "helm")
                echo "Installation guides:"
                echo "  - macOS: brew install helm"
                echo "  - Linux: https://helm.sh/docs/intro/install/"
                echo "  - Windows: choco install kubernetes-helm"
                ;;
            "terraform")
                echo "Installation guides:"
                echo "  - macOS: brew install terraform"
                echo "  - Linux: https://learn.hashicorp.com/tutorials/terraform/install-cli"
                echo "  - Windows: choco install terraform"
                ;;
            "spacectl")
                echo "Installation guides:"
                echo "  - macOS: brew install spacelift-io/spacelift/spacectl"
                echo "  - Linux: https://github.com/spacelift-io/spacectl#installation"
                echo "  - Windows: https://github.com/spacelift-io/spacectl#installation"
                ;;
            "aws")
                echo "Installation guides:"
                echo "  - macOS: brew install awscli"
                echo "  - Linux: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
                echo "  - Windows: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
                ;;
            "openssl")
                echo "Installation guides:"
                echo "  - macOS: Usually pre-installed, or brew install openssl"
                echo "  - Linux: sudo apt-get install openssl (Ubuntu/Debian) or yum install openssl (RHEL/CentOS)"
                echo "  - Windows: Use WSL or install OpenSSL for Windows"
                ;;
        esac
        exit 1
    fi
}

# Function to check if Docker is running
check_docker_running() {
    if ! docker ps >/dev/null 2>&1; then
        print_error "Docker daemon is not running. Please start Docker and try again."
        exit 1
    fi
    print_success "Docker daemon is running"
}

# Function to check if Kind cluster is accessible
check_kind_cluster() {
    local cluster_name="${1:-spacelift-poc}"
    local context="kind-${cluster_name}"
    
    if ! kubectl cluster-info --context "$context" >/dev/null 2>&1; then
        print_error "Kind cluster '$cluster_name' is not running or accessible"
        print_error "Please run ./setup.sh to start the cluster"
        exit 1
    fi
    print_success "Kind cluster '$cluster_name' is accessible"
}

# Function to wait with timeout and progress indicator
wait_with_timeout() {
    local condition_func="$1"
    local max_attempts="${2:-30}"
    local sleep_interval="${3:-2}"
    local description="${4:-operation}"
    
    local attempt=1
    
    print_status "Waiting for $description..."
    
    while [ $attempt -le $max_attempts ]; do
        if eval "$condition_func"; then
            print_success "$description completed!"
            return 0
        fi
        
        echo -n "."
        sleep "$sleep_interval"
        ((attempt++))
    done
    
    print_error "$description failed after $((max_attempts * sleep_interval)) seconds"
    return 1
}

# Function to run a script and handle errors
run_script() {
    local script_path="$1"
    local description="$2"
    
    print_status "$description"
    
    if [ ! -x "$script_path" ]; then
        print_error "Script not found or not executable: $script_path"
        exit 1
    fi
    
    if "$script_path"; then
        print_success "$description completed successfully"
    else
        print_error "$description failed"
        exit 1
    fi
}

# Function to show progress
show_progress() {
    local step="$1"
    local total="$2"
    local description="$3"
    
    echo -e "\n${BLUE}[Step $step/$total]${NC} $description"
}

# Handle script interruption (should be called in main scripts)
setup_interrupt_handler() {
    local script_name="${1:-Script}"
    trap "print_error '$script_name interrupted by user'; exit 1" INT TERM
}

# Function to validate file exists
require_file() {
    local file_path="$1"
    local error_msg="$2"
    
    if [ ! -f "$file_path" ]; then
        print_error "Required file not found: $file_path"
        if [ -n "$error_msg" ]; then
            echo "$error_msg"
        fi
        exit 1
    fi
}

# Function to validate directory exists
require_directory() {
    local dir_path="$1"
    local error_msg="$2"
    
    if [ ! -d "$dir_path" ]; then
        print_error "Required directory not found: $dir_path"
        if [ -n "$error_msg" ]; then
            echo "$error_msg"
        fi
        exit 1
    fi
}

# Function to check if Spacelift operator is installed
check_spacelift_operator() {
    local context="${1:-kind-spacelift-poc}"
    
    if ! kubectl get namespace spacelift-worker-controller-system --context "$context" >/dev/null 2>&1; then
        print_error "Spacelift operator namespace not found"
        print_error "Please run ./setup.sh to install the Spacelift operator"
        exit 1
    fi
    print_success "Spacelift operator is installed"
}

# Function to confirm user action
confirm_action() {
    local message="${1:-Continue}"
    local default="${2:-N}"
    
    if [ "$default" = "Y" ] || [ "$default" = "y" ]; then
        read -p "$message? (Y/n): " -n 1 -r
        echo
        [[ $REPLY =~ ^[Nn]$ ]] && return 1
    else
        read -p "$message? (y/N): " -n 1 -r
        echo
        [[ $REPLY =~ ^[Yy]$ ]] || return 1
    fi
    
    return 0
}

# Function to create directory with proper permissions
create_secure_directory() {
    local dir_path="$1"
    local permissions="${2:-755}"
    
    if [ ! -d "$dir_path" ]; then
        mkdir -p "$dir_path"
        chmod "$permissions" "$dir_path"
        print_status "Created directory: $dir_path"
    fi
}

# Export functions so they're available when script is sourced
export -f print_status print_success print_warning print_error print_header
export -f check_command check_docker_running check_kind_cluster
export -f wait_with_timeout run_script show_progress setup_interrupt_handler
export -f require_file require_directory check_spacelift_operator
export -f confirm_action create_secure_directory