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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
MINIKUBE_PROFILE="websocket-demo"

log_info "Deploying observability stack (Prometheus + Grafana)..."

# Check if minikube is running
if ! minikube status -p "$MINIKUBE_PROFILE" &> /dev/null; then
    log_error "Minikube is not running. Run: ./scripts/setup-minikube.sh"
    exit 1
fi

# Create monitoring namespace
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

# Deploy Prometheus
log_info "Deploying Prometheus..."
kubectl apply -f "$PROJECT_DIR/observability/prometheus/prometheus.yaml"

# Deploy Grafana
log_info "Deploying Grafana..."
kubectl apply -f "$PROJECT_DIR/observability/grafana/grafana.yaml"

# Wait for deployments
log_info "Waiting for Prometheus to be ready..."
kubectl rollout status deployment/prometheus -n monitoring --timeout=120s

log_info "Waiting for Grafana to be ready..."
kubectl rollout status deployment/grafana -n monitoring --timeout=120s

# Get service info
log_info "Monitoring stack deployed successfully!"
echo ""
log_info "Access the monitoring tools:"
echo ""
echo "  Prometheus:"
echo "    kubectl port-forward -n monitoring svc/prometheus 9090:9090"
echo "    Then access: http://localhost:9090"
echo ""
echo "  Grafana:"
echo "    kubectl port-forward -n monitoring svc/grafana 3000:3000"
echo "    Then access: http://localhost:3000"
echo "    Default credentials: admin / admin"
echo ""

log_success "Observability stack deployed!"
