#!/bin/bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Configuration
MINIKUBE_PROFILE="websocket-demo"
MINIKUBE_CPUS="2"
MINIKUBE_MEMORY="4096"
MINIKUBE_DRIVER="docker"  # Can also use: hyperkit, virtualbox

log_info "Setting up Minikube for WebSocket Demo..."

# Check if minikube is installed
if ! command -v minikube &> /dev/null; then
    log_error "minikube is not installed. Please install it first:"
    echo "  brew install minikube"
    exit 1
fi

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    log_error "kubectl is not installed. Please install it first:"
    echo "  brew install kubectl"
    exit 1
fi

# Check if Docker is running (for docker driver)
if [ "$MINIKUBE_DRIVER" == "docker" ]; then
    if ! docker info &> /dev/null; then
        log_error "Docker is not running. Please start Docker Desktop."
        exit 1
    fi
fi

# Start or create minikube cluster
log_info "Starting Minikube cluster (profile: $MINIKUBE_PROFILE)..."
if minikube status -p "$MINIKUBE_PROFILE" &> /dev/null; then
    log_info "Minikube cluster already running"
else
    minikube start \
        -p "$MINIKUBE_PROFILE" \
        --cpus="$MINIKUBE_CPUS" \
        --memory="$MINIKUBE_MEMORY" \
        --driver="$MINIKUBE_DRIVER" \
        --addons=ingress \
        --addons=metrics-server \
        --addons=dashboard
fi

# Wait for cluster to be ready
log_info "Waiting for cluster to be ready..."
kubectl wait --for=condition=Ready nodes --all --timeout=120s

# Enable required addons
log_info "Enabling required addons..."
minikube addons enable ingress -p "$MINIKUBE_PROFILE"
minikube addons enable metrics-server -p "$MINIKUBE_PROFILE"
minikube addons enable dashboard -p "$MINIKUBE_PROFILE"

# Wait for ingress controller to be ready
log_info "Waiting for ingress controller..."
kubectl wait --namespace ingress-nginx \
    --for=condition=ready pod \
    --selector=app.kubernetes.io/component=controller \
    --timeout=120s || true

# Get minikube IP
MINIKUBE_IP=$(minikube ip -p "$MINIKUBE_PROFILE")
log_success "Minikube is running at: $MINIKUBE_IP"

# Add hosts entry reminder
log_warn "Add this to your /etc/hosts file:"
echo "  $MINIKUBE_IP websocket.local"
echo ""
echo "  sudo sh -c 'echo \"$MINIKUBE_IP websocket.local\" >> /etc/hosts'"

# Print useful commands
echo ""
log_info "Useful commands:"
echo "  minikube dashboard -p $MINIKUBE_PROFILE   # Open Kubernetes dashboard"
echo "  minikube tunnel -p $MINIKUBE_PROFILE      # Enable LoadBalancer access"
echo "  minikube stop -p $MINIKUBE_PROFILE        # Stop cluster"
echo "  minikube delete -p $MINIKUBE_PROFILE      # Delete cluster"

log_success "Minikube setup complete!"
