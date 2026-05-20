# WebSocket Real-Time Service - Senior DevOps Challenge

A production-ready WebSocket service deployed on Kubernetes with CI/CD automation and comprehensive observability.

## 🏗️ Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                           Internet                                    │
└───────────────────────────────┬─────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────────┐
│                     NGINX Ingress Controller                         │
│              (WebSocket upgrade, Session Affinity)                   │
└───────────────────────────────┬─────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    Kubernetes Service                                │
│                 (ClusterIP, Session Affinity)                        │
└───────────────────────────────┬─────────────────────────────────────┘
                                │
          ┌─────────────────────┼─────────────────────┐
          │                     │                     │
          ▼                     ▼                     ▼
   ┌─────────────┐       ┌─────────────┐       ┌─────────────┐
   │   Pod 1     │       │   Pod 2     │       │   Pod 3     │
   │  WebSocket  │       │  WebSocket  │       │  WebSocket  │
   │   Server    │       │   Server    │       │   Server    │
   │             │       │             │       │             │
   │ /metrics ───┼───────┼─────────────┼───────┼──────┐      │
   └─────────────┘       └─────────────┘       └──────┼──────┘
                                                      │
                                                      ▼
                              ┌─────────────────────────────────────┐
                              │         Prometheus                  │
                              │    (Metrics Collection)             │
                              └───────────────┬─────────────────────┘
                                              │
                                              ▼
                              ┌─────────────────────────────────────┐
                              │          Grafana                    │
                              │    (Visualization)                  │
                              └─────────────────────────────────────┘
```

## 📋 Challenge Requirements Checklist

### Part 1: Application Layer ✅
- [x] WebSocket server accepting client connections
- [x] Message broadcasting to all connected clients
- [x] Built with Go for high performance and low memory footprint
- [x] Prometheus metrics exposed at `/metrics`
- [x] Health (`/health`) and readiness (`/ready`) endpoints
- [x] Graceful shutdown with connection draining

### Part 2: Kubernetes Deployment ✅
- [x] Proper Deployment definition with 3 replicas
- [x] Resource requests and limits configured
- [x] Rolling update strategy with zero downtime
- [x] Liveness, readiness, and startup probes
- [x] Service with session affinity for WebSocket
- [x] Ingress with WebSocket-specific annotations
- [x] Graceful shutdown (60s termination grace period)
- [x] Pod anti-affinity for high availability
- [x] PodDisruptionBudget for maintenance windows
- [x] HorizontalPodAutoscaler for auto-scaling

### Part 3: CI/CD Pipeline ✅
- [x] GitHub Actions workflow
- [x] Docker image build with multi-arch support
- [x] Clear tagging strategy (SHA, semver, branch)
- [x] Push to GitHub Container Registry (GHCR)
- [x] Kubernetes manifest validation
- [x] Security scanning with Trivy
- [x] Staging and Production deployment jobs
- [x] Automated releases

### Part 4: Observability ✅
- [x] Prometheus for metrics collection
- [x] Grafana for visualization
- [x] Custom metrics:
  - Active connections (`websocket_active_connections`)
  - Total connections (`websocket_connections_total`)
  - Messages received/sent
  - Message latency percentiles
- [x] Pre-configured dashboard
- [x] Kubernetes workload health metrics

## 🚀 Quick Start with Minikube

### Prerequisites

```bash
# Install required tools (macOS)
brew install minikube kubectl docker

# Start Docker Desktop (if not running)
open -a Docker
```

### 1. Setup Minikube Cluster

```bash
# Make scripts executable
chmod +x scripts/*.sh

# Setup minikube with required addons
./scripts/setup-minikube.sh
```

This will:
- Create a minikube cluster with 2 CPUs and 4GB RAM
- Enable ingress, metrics-server, and dashboard addons
- Configure kubectl context

### 2. Build and Deploy Application

```bash
# Build image and deploy to Kubernetes
./scripts/deploy-local.sh
```

### 3. Deploy Observability Stack

```bash
# Deploy Prometheus and Grafana
./scripts/deploy-observability.sh
```

### 4. Add Host Entry

```bash
# Get minikube IP
MINIKUBE_IP=$(minikube ip -p websocket-demo)

# Add to /etc/hosts
sudo sh -c "echo '$MINIKUBE_IP websocket.local' >> /etc/hosts"
```

### 5. Access the Application

```bash
# Option 1: Via Ingress
open http://websocket.local

# Option 2: Via Port Forward
kubectl port-forward -n websocket-app svc/websocket-server 8080:80
open http://localhost:8080
```

### 6. Access Monitoring

```bash
# Prometheus
kubectl port-forward -n monitoring svc/prometheus 9090:9090
open http://localhost:9090

# Grafana (admin/admin)
kubectl port-forward -n monitoring svc/grafana 3000:3000
open http://localhost:3000
```

## 📁 Project Structure

```
.
├── app/                          # Application source code
│   ├── main.go                   # WebSocket server implementation
│   ├── go.mod                    # Go modules
│   ├── Dockerfile                # Multi-stage Docker build
│   └── static/
│       └── index.html            # Web client for testing
│
├── k8s/                          # Kubernetes manifests
│   ├── base/                     # Base manifests (Kustomize)
│   │   ├── namespace.yaml
│   │   ├── deployment.yaml       # Main deployment config
│   │   ├── service.yaml          # ClusterIP service
│   │   ├── ingress.yaml          # NGINX ingress with WS support
│   │   ├── hpa.yaml              # Horizontal Pod Autoscaler
│   │   ├── pdb.yaml              # Pod Disruption Budget
│   │   ├── configmap.yaml
│   │   ├── secret.yaml
│   │   └── kustomization.yaml
│   └── overlays/
│       ├── local/                # Minikube-specific config
│       │   └── kustomization.yaml
│       └── production/           # Production config
│           └── kustomization.yaml
│
├── .github/workflows/
│   └── ci-cd.yaml               # GitHub Actions pipeline
│
├── observability/
│   ├── prometheus/
│   │   └── prometheus.yaml      # Prometheus deployment
│   └── grafana/
│       └── grafana.yaml         # Grafana with dashboards
│
├── scripts/
│   ├── setup-minikube.sh        # Minikube cluster setup
│   ├── deploy-local.sh          # Local deployment script
│   └── deploy-observability.sh  # Monitoring stack deployment
│
└── README.md
```

## 🔧 Kubernetes Configuration Details

### Deployment Strategy

```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxSurge: 1        # Allow 1 extra pod during update
    maxUnavailable: 0  # Never reduce available pods
```

**Why?** WebSocket connections are long-lived. Rolling updates with `maxUnavailable: 0` ensure:
- No existing connections are abruptly terminated
- New pods receive health checks before old pods terminate
- Zero-downtime deployments

### Graceful Shutdown

```yaml
terminationGracePeriodSeconds: 60
lifecycle:
  preStop:
    exec:
      command: ["/bin/sh", "-c", "sleep 15"]
```

**Why?** 
1. `sleep 15` in preStop allows the load balancer to remove the pod from rotation
2. 60s grace period gives time for WebSocket clients to reconnect to other pods
3. The application handles SIGTERM and stops accepting new connections while draining existing ones

### WebSocket Ingress Configuration

```yaml
annotations:
  nginx.ingress.kubernetes.io/proxy-read-timeout: "3600"
  nginx.ingress.kubernetes.io/proxy-send-timeout: "3600"
  nginx.ingress.kubernetes.io/websocket-services: "websocket-server"
  nginx.ingress.kubernetes.io/affinity: "cookie"
```

**Why?**
- Long timeouts (1 hour) prevent premature connection drops
- `websocket-services` annotation ensures proper upgrade handling
- Cookie-based affinity routes reconnecting clients to the same pod when possible

### Horizontal Pod Autoscaler

```yaml
behavior:
  scaleUp:
    stabilizationWindowSeconds: 30
    policies:
      - type: Pods
        value: 2
        periodSeconds: 30
  scaleDown:
    stabilizationWindowSeconds: 300
    policies:
      - type: Pods
        value: 1
        periodSeconds: 60
```

**Why?**
- Fast scale-up (30s) to handle traffic spikes
- Slow scale-down (5min stabilization) to prevent connection disruption

## 📊 Metrics & Observability

### Application Metrics

| Metric | Type | Description |
|--------|------|-------------|
| `websocket_active_connections` | Gauge | Current number of active connections |
| `websocket_connections_total` | Counter | Total connections since startup |
| `websocket_messages_received_total` | Counter | Total messages received |
| `websocket_messages_sent_total` | Counter | Total messages sent |
| `websocket_message_latency_seconds` | Histogram | Message processing latency |

### Golden Signals Mapping

| Signal | Metric |
|--------|--------|
| **Latency** | `websocket_message_latency_seconds` |
| **Traffic** | `rate(websocket_connections_total[5m])` |
| **Errors** | Connection errors (via logs) |
| **Saturation** | CPU/Memory usage, active connections vs capacity |

### Production Monitoring Extensions

In production, I would extend this setup with:

1. **Alerting Rules**:
   ```yaml
   - alert: HighConnectionCount
     expr: websocket_active_connections > 1000
     for: 5m
   - alert: HighLatency
     expr: histogram_quantile(0.95, websocket_message_latency_seconds) > 0.1
     for: 5m
   ```

2. **SLOs**:
   - Connection success rate: 99.9%
   - Message delivery latency p95: < 100ms
   - Availability: 99.95%

3. **Distributed Tracing**: OpenTelemetry integration for request tracing

4. **Log Aggregation**: Loki or ELK stack for centralized logging

## 🔐 Security Considerations

### Implemented
- Non-root container user (UID 1000)
- Read-only root filesystem
- Dropped all capabilities
- No privilege escalation
- Resource limits to prevent DoS
- Security context at pod and container level

### Production Recommendations
- Enable TLS termination at ingress
- Implement rate limiting
- Add authentication for WebSocket connections
- Use NetworkPolicies to restrict pod communication
- Enable PodSecurityPolicy or OPA Gatekeeper
- Secret management with external secrets operator

## 🔄 CI/CD Pipeline

### Workflow Triggers
- **Push to main**: Build, test, scan, validate
- **Push to develop**: Deploy to staging
- **Tags (v*)**: Deploy to production + create release

### Image Tagging Strategy
```
ghcr.io/username/websocket-server:latest      # Latest from main
ghcr.io/username/websocket-server:v1.2.3      # Semantic version
ghcr.io/username/websocket-server:sha-abc1234 # Commit SHA
ghcr.io/username/websocket-server:develop     # Branch name
```

## 🧪 Testing the WebSocket Service

### Using the Web UI
1. Open http://websocket.local in multiple browser tabs
2. Send messages from one tab
3. Observe messages appearing in all tabs

### Using wscat
```bash
# Install wscat
npm install -g wscat

# Connect to WebSocket
wscat -c ws://websocket.local/ws

# Send a message
> Hello, World!
```

### Load Testing with k6
```javascript
import ws from 'k6/ws';

export default function () {
  const url = 'ws://websocket.local/ws';
  const res = ws.connect(url, {}, function (socket) {
    socket.on('open', () => socket.send('Hello'));
    socket.on('message', (data) => console.log(data));
    socket.setTimeout(() => socket.close(), 5000);
  });
}
```

## 🛠️ Troubleshooting

### Common Issues

**Pods not starting:**
```bash
kubectl describe pod -n websocket-app -l app.kubernetes.io/name=websocket-server
kubectl logs -n websocket-app -l app.kubernetes.io/name=websocket-server
```

**Ingress not working:**
```bash
kubectl get ingress -n websocket-app
kubectl describe ingress websocket-server -n websocket-app
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller
```

**WebSocket connection fails:**
- Check ingress annotations for WebSocket support
- Verify the upgrade headers are being passed through
- Check browser console for connection errors

## 📚 Design Decisions

1. **Go for the WebSocket Server**: Chosen for excellent concurrency support, low memory footprint, and fast startup times - ideal for containerized workloads.

2. **Kustomize over Helm**: For this challenge, Kustomize provides sufficient flexibility while keeping manifests readable and auditable. In production, Helm might be preferred for complex applications.

3. **NGINX Ingress**: Most common ingress controller with excellent WebSocket support through annotations. Alternative: Traefik, HAProxy.

4. **GitHub Container Registry**: Zero additional setup when using GitHub Actions. Alternatives: Docker Hub, ECR, ACR.

5. **Prometheus + Grafana**: Industry-standard observability stack with native Kubernetes integration. Alternative: Datadog, New Relic (managed services).

## 📄 License

MIT License - See LICENSE file for details.