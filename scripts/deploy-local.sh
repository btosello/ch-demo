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
IMAGE_NAME="websocket-server"
IMAGE_TAG="${1:-local}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

log_info "Building and deploying WebSocket server to Minikube..."

# Check if minikube is running
if ! minikube status -p "$MINIKUBE_PROFILE" &> /dev/null; then
    log_error "Minikube is not running. Run: ./scripts/setup-minikube.sh"
    exit 1
fi

# Configure Docker to use Minikube's Docker daemon
log_info "Configuring Docker to use Minikube's Docker daemon..."
eval $(minikube docker-env -p "$MINIKUBE_PROFILE")

# Build the Docker image inside Minikube's Docker
log_info "Building Docker image: $IMAGE_NAME:$IMAGE_TAG"
cd "$PROJECT_DIR/app"
docker build -t "$IMAGE_NAME:$IMAGE_TAG" .

# Verify the image exists
if docker images --format '{{.Repository}}:{{.Tag}}' | grep -q "^${IMAGE_NAME}:${IMAGE_TAG}$"; then
    log_success "Image built successfully: $IMAGE_NAME:$IMAGE_TAG"
else
    log_error "Failed to build image"
    exit 1
fi

# Deploy to Kubernetes using Kustomize
log_info "Deploying to Kubernetes..."
cd "$PROJECT_DIR"

# Create namespace if it doesn't exist
kubectl create namespace websocket-app --dry-run=client -o yaml | kubectl apply -f -

# Apply the kustomize overlay for local environment
kubectl apply -k k8s/overlays/local

# Wait for deployment to be ready
log_info "Waiting for deployment to be ready..."
kubectl rollout status deployment/websocket-server -n websocket-app --timeout=120s

# Get pod status
log_info "Pod status:"
kubectl get pods -n websocket-app -l app.kubernetes.io/name=websocket-server

# Get service info
log_info "Service info:"
kubectl get svc -n websocket-app

# Get ingress info
log_info "Ingress info:"
kubectl get ingress -n websocket-app

# Get Minikube IP
MINIKUBE_IP=$(minikube ip -p "$MINIKUBE_PROFILE")

echo ""
log_success "Deployment complete!"
echo ""
log_info "Access the application:"
echo "  - Web UI:    http://websocket.local (add to /etc/hosts: $MINIKUBE_IP websocket.local)"
echo "  - WebSocket: ws://websocket.local/ws"
echo "  - Health:    http://websocket.local/health"
echo "  - Metrics:   http://websocket.local/metrics"
echo ""
log_info "Or use port-forward:"
echo "  kubectl port-forward -n websocket-app svc/websocket-server 8080:80"
echo "  Then access: http://localhost:8080"
