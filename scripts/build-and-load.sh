#!/bin/bash
# Build and load Docker image into local Kubernetes cluster

set -e

# Configuration
IMAGE_NAME="tikky:latest"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Detect cluster type
detect_cluster() {
    local cluster_info=$(kubectl cluster-info 2>/dev/null)
    
    if echo "$cluster_info" | grep -qi "kind"; then
        echo "kind"
    elif echo "$cluster_info" | grep -qi "minikube"; then
        echo "minikube"
    elif echo "$cluster_info" | grep -qi "docker-desktop\|docker-for-desktop"; then
        echo "docker-desktop"
    elif kubectl config current-context 2>/dev/null | grep -qi "docker-desktop\|docker-for-desktop"; then
        echo "docker-desktop"
    else
        # Default to docker-desktop for Docker Desktop users
        local current_context=$(kubectl config current-context 2>/dev/null)
        log_warn "Could not detect cluster type from cluster-info"
        log_warn "Current context: ${current_context}"
        log_warn "Assuming Docker Desktop (no image loading needed)"
        echo "docker-desktop"
    fi
}

# Build Docker image
build_image() {
    log_info "Building Docker image: ${IMAGE_NAME}"
    
    # Build the image
    docker build -t "${IMAGE_NAME}" .
    
    if [ $? -eq 0 ]; then
        log_info "Successfully built ${IMAGE_NAME}"
    else
        log_error "Failed to build Docker image"
        exit 1
    fi
}

# Load image into cluster
load_image() {
    local cluster_type=$1
    
    case $cluster_type in
        "kind")
            log_info "Loading image into kind cluster..."
            kind load docker-image "${IMAGE_NAME}"
            ;;
        "minikube")
            log_info "Loading image into minikube cluster..."
            minikube image load "${IMAGE_NAME}"
            ;;
        "docker-desktop")
            log_info "Image available in Docker Desktop Kubernetes cluster"
            # Docker Desktop uses the same Docker daemon, so no loading needed
            ;;
        *)
            log_error "Unknown cluster type: ${cluster_type}"
            log_error "Supported clusters: kind, minikube, docker-desktop"
            exit 1
            ;;
    esac
}

# Main execution
main() {
    log_info "Starting build and load process..."
    
    # Check if kubectl is available
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed or not in PATH"
        exit 1
    fi
    
    # Check if we can connect to cluster
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Cannot connect to Kubernetes cluster"
        log_error "Please ensure your cluster is running and kubectl is configured"
        exit 1
    fi
    
    # Detect cluster type
    CLUSTER_TYPE=$(detect_cluster)
    log_info "Detected cluster type: ${CLUSTER_TYPE}"
    
    # Build the image
    build_image
    
    # Load image into cluster (if needed)
    load_image "$CLUSTER_TYPE"
    
    log_info "✅ Build and load process completed successfully!"
    log_info "You can now deploy the application with: ./scripts/deploy.sh"
    
    # Show image verification commands
    echo
    log_info "To verify the image is available:"
    case $CLUSTER_TYPE in
        "kind")
            echo "  docker exec -it kind-control-plane crictl images | grep tikky"
            ;;
        "minikube")
            echo "  minikube image ls | grep tikky"
            ;;
        "docker-desktop")
            echo "  docker images | grep tikky"
            ;;
    esac
}

# Handle script arguments
if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    echo "Usage: $0 [--help]"
    echo ""
    echo "This script builds the tikky Docker image and loads it into your local Kubernetes cluster."
    echo ""
    echo "Supported clusters:"
    echo "  - Docker Desktop (macOS/Windows) - uses shared Docker daemon"
    echo "  - kind - loads image into kind cluster"
    echo "  - minikube - loads image into minikube cluster"
    echo ""
    echo "Options:"
    echo "  --help, -h    Show this help message"
    exit 0
fi

# Run main function
main "$@"