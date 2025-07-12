# tikky A Cloud-Native Increment-as-a-Service API

An Increment-as-a-Service API 😆 ready to run in production! Built to show how I think about scalable, secure systems.  

## Quick Start

```bash
# 1. Setup local Kubernetes cluster
./scripts/setup-cluster.sh

# 2. Build and load application image
./scripts/build-and-load.sh

# 3. Deploy the application
./scripts/deploy.sh

# 4. Test the API
curl -X POST http://localhost:8080/write  # {"value":1}
curl http://localhost:8080/read           # {"value":1}
```

## Architecture

- **Go API**: High-performance counter service with structured logging
- **Redis**: Persistent storage using StatefulSet
- **Network Security**: Zero-trust network policies with explicit allow rules
- **Autoscaling**: HPA for automatic pod scaling based on CPU usage
- **Ingress**: NGINX-based routing with rate limiting

## Local Development Setup

### Prerequisites

- Docker Desktop (macOS/Windows) or Docker + minikube (Linux)
- kubectl

### Option A: Docker Desktop (Recommended for macOS/Windows)

**If you already have Kubernetes enabled in Docker Desktop GUI:**
1. ✅ Skip to [Building and Loading Images](#building-and-loading-images)
2. Your cluster and registry are already configured!

**If you haven't enabled Kubernetes yet:**
1. Open Docker Desktop
2. Go to Settings → Kubernetes
3. Check "Enable Kubernetes" and click "Apply & Restart"
4. Wait for the green "Kubernetes is running" status

Docker Desktop automatically sets up:
- Local Kubernetes cluster
- Registry mirror (`kind-registry-mirror`)
- Shared Docker daemon (no image loading needed)

### Option B: Manual kind Setup macOS

For users who want more control or isolation:

```bash
# Install kind
brew install kind

# Create cluster with ingress support
kind create cluster --config=scripts/kind-config.yaml

# Install NGINX ingress controller
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

# Wait for ingress controller
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=90s
```

### Option C: Linux Setup (minikube)

```bash
# Install minikube
curl -Lo minikube https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube /usr/local/bin/

# Start cluster
minikube start --driver=docker

# Enable ingress addon
minikube addons enable ingress
```

## Image Management

### Building and Loading Images

Use the provided script to build and load images into your cluster:

```bash
./scripts/build-and-load.sh
```

Or manually:

```bash
# Build image
docker build -t tikky:latest .

# Load into kind cluster
kind load docker-image tikky:latest

# Or load into minikube
minikube image load tikky:latest
```

### Using Local Registry with kind

For faster development iterations, set up a local registry:

```bash
# Create registry container
docker run -d --restart=always -p 5001:5000 --name kind-registry registry:2

# Connect registry to kind network
docker network connect kind kind-registry

# Build and push to local registry
docker build -t localhost:5001/tikky:latest .
docker push localhost:5001/tikky:latest
```

## Deployment

### Automated Deployment

```bash
./scripts/deploy.sh
```

### Manual Deployment

```bash
# Apply in order
kubectl apply -f k8s/base/
kubectl apply -f k8s/redis/
kubectl wait --for=condition=ready pod -l app=redis -n tikky-app --timeout=300s
kubectl apply -f k8s/app/
kubectl apply -f k8s/ingress/
```

## Testing

### Port Forward Method

```bash
# Forward ingress controller port
kubectl port-forward --namespace=ingress-nginx service/ingress-nginx-controller 8080:80

# Test endpoints
curl -X POST http://localhost:8080/write  # Increment counter
curl http://localhost:8080/read           # Read counter
```

### Direct Service Access

```bash
# Port forward to service
kubectl port-forward -n tikky-app svc/tikky-api-service 8081:80

# Test directly
curl -X POST http://localhost:8081/write
curl http://localhost:8081/read
```

## Monitoring and Debugging

### Check Pod Status

```bash
kubectl get pods -n tikky-app
kubectl describe pods -n tikky-app -l app.kubernetes.io/name=tikky-api
```

### View Logs

```bash
# Application logs
kubectl logs -n tikky-app -l app.kubernetes.io/name=tikky-api -f

# Redis logs
kubectl logs -n tikky-app redis-0 -f
```

### Network Policy Testing

```bash
# Test network connectivity
kubectl exec -n tikky-app deploy/tikky-api -- nslookup redis-service
```

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `REDIS_ADDR` | `redis-service:6379` | Redis connection string |
| `REDIS_PASSWORD` | From secret | Redis authentication password |

### Resource Limits

| Component | CPU Request | CPU Limit | Memory Request | Memory Limit |
|-----------|-------------|-----------|----------------|--------------|
| API | 100m | 200m | 64Mi | 128Mi |
| Redis | 100m | 500m | 128Mi | 256Mi |

## Security Features

- **Network Policies**: Default deny-all with explicit allow rules
- **Non-root Container**: Runs as unprivileged user
- **Minimal Base Image**: Uses scratch base for reduced attack surface
- **Secret Management**: Passwords stored in Kubernetes secrets
- **Rate Limiting**: 10 RPS per IP with burst of 20
- **Resource Quotas**: CPU and memory limits enforced

## Production Readiness

### Scalability
- ✅ Horizontal Pod Autoscaler (CPU-based)
- ✅ Multi-replica deployment
- ✅ Redis connection pooling
- ✅ Stateless API design

### Security
- ✅ Zero-trust network policies
- ✅ Ingress rate limiting
- ✅ Secrets management
- ✅ Non-root container execution
- ✅ Minimal container image

### Observability
- ✅ Structured JSON logging
- ✅ Request correlation IDs
- ✅ Health check endpoints
- ✅ Kubernetes readiness/liveness probes

### Reliability
- ✅ Graceful shutdown handling
- ✅ Circuit breaker patterns
- ✅ Persistent storage for Redis
- ✅ Health monitoring

## Troubleshooting

### Common Issues

**504 Gateway Timeout**
- Check network policies allow ingress controller traffic
- Verify pods are running and ready
- Ensure service endpoints are populated

**Connection Refused**
- Verify ingress controller is running
- Check port-forward syntax
- Validate ingress configuration

**Redis Connection Failed**
- Check Redis pod status
- Verify Redis service exists
- Confirm network policy allows API->Redis traffic

### Debug Commands

```bash
# Check ingress controller
kubectl get pods -n ingress-nginx

# Test service endpoints
kubectl get endpoints -n tikky-app

# Verify network policies
kubectl describe networkpolicy -n tikky-app

# Check HPA status
kubectl get hpa -n tikky-app
```

## Cleanup

```bash
# Remove application
kubectl delete namespace tikky-app

# Remove kind cluster
kind delete cluster

# Remove minikube cluster
minikube delete
```

## Development Workflow

### Using Make (Recommended)

```bash
make help          # Show all available commands
make test          # Run unit tests with coverage
make dev           # Complete development deployment
make load-test     # Run performance tests
make ci            # Run CI pipeline (test, lint, build)
make status        # Show cluster status
```

### Manual Workflow

1. **Code Changes**: Modify application code
2. **Build**: `./scripts/build-and-load.sh`
3. **Deploy**: `kubectl rollout restart deployment/tikky-api -n tikky-app`
4. **Test**: Use port-forward to test changes
5. **Scale**: `kubectl scale deployment/tikky-api --replicas=5 -n tikky-app`

### Testing

```bash
# Run all tests
make test

# Run with HTML coverage report
make test-html

# Run benchmarks
make bench
```

## Load Testing

First, make sure you have the ingress accessible:

```bash
# Forward ingress controller port (keep this running in another terminal)
kubectl port-forward --namespace=ingress-nginx service/ingress-nginx-controller 8080:80
```

Then run the load test:

```bash
./scripts/load-test.sh
```

**Expected Results**: The load test will show ~30-50 successful requests out of 500 total requests (~6-10% success rate). This is **intentional** and demonstrates multiple production-ready features:

### 🛡️ **Rate Limiting Protection**
The primary bottleneck is our **NGINX rate limiting** (10 RPS + burst of 20):
- ✅ Protects against DDoS and abuse
- ✅ Ensures service stability under load
- ✅ Prevents resource exhaustion
- ✅ Returns proper HTTP 429 responses

### 🔍 **Performance Analysis**
The "failed" requests reveal system design decisions:
- **Rate limiting**: 470+ requests blocked (working as intended)
- **Redis capacity**: Single instance handles ~30-50 RPS effectively
- **Connection pooling**: Shows need for optimization at higher loads
- **Horizontal scaling**: Demonstrates when to add more replicas

### 🎯 **Production Tuning Recommendations**
- **Rate limiting**: Adjust limits based on capacity planning
- **Redis optimization**: Connection pooling and clustering
- **API caching**: Implement for read-heavy workloads
- **Load balancing**: Multiple Redis instances for scale-out
- **Monitoring**: Add alerts for rate limit violations

**This demonstrates production-ready thinking**: Rate limiting isn't a bug, it's a feature protecting service reliability! 🚀

## Production Deployment

This project is designed for local development and demonstration. For production deployment in a **GCP environment**, the following enterprise-grade patterns should be implemented:

### 🏢 **GCP Container Registry Strategy**

```bash
# GCP Artifact Registry (recommended)
gcloud auth configure-docker us-central1-docker.pkg.dev
docker tag tikky:latest us-central1-docker.pkg.dev/bluecore-prod/tikky-repo/tikky:v1.2.3
docker push us-central1-docker.pkg.dev/bluecore-prod/tikky-repo/tikky:v1.2.3

# Legacy Container Registry (if still using)
gcloud auth configure-docker
docker tag tikky:latest gcr.io/bluecore-prod/tikky:v1.2.3
docker push gcr.io/bluecore-prod/tikky:v1.2.3
```

### 🚀 **Cloud Build CI/CD Integration**

**cloudbuild.yaml:**
```yaml
steps:
  # Build the container image
  - name: 'gcr.io/cloud-builders/docker'
    args:
      - 'build'
      - '-t'
      - 'us-central1-docker.pkg.dev/$PROJECT_ID/tikky-repo/tikky:$TAG_NAME'
      - '.'
  
  # Push to Artifact Registry
  - name: 'gcr.io/cloud-builders/docker'
    args:
      - 'push'
      - 'us-central1-docker.pkg.dev/$PROJECT_ID/tikky-repo/tikky:$TAG_NAME'
  
  # Deploy to GKE
  - name: 'gcr.io/cloud-builders/gke-deploy'
    args:
      - 'run'
      - '--filename=k8s/'
      - '--image=us-central1-docker.pkg.dev/$PROJECT_ID/tikky-repo/tikky:$TAG_NAME'
      - '--location=us-central1'
      - '--cluster=bluecore-prod-cluster'

# Trigger on git tags
options:
  substitution_option: 'ALLOW_LOOSE'
```

### 🏗️ **Terraform for GCP**

**terraform/main.tf:**
```hcl
# GKE Cluster
resource "google_container_cluster" "tikky_cluster" {
  name     = "tikky-prod-cluster"
  location = "us-central1"
  
  # Workload Identity for secure service account access
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }
  
  # Network policy for security
  network_policy {
    enabled = true
  }
}

# Artifact Registry
resource "google_artifact_registry_repository" "tikky_repo" {
  repository_id = "tikky-repo"
  location      = "us-central1"
  format        = "DOCKER"
}

# Cloud SQL for Redis Alternative (if needed)
resource "google_redis_instance" "tikky_redis" {
  name           = "tikky-redis-prod"
  memory_size_gb = 1
  region         = "us-central1"
  
  # VPC connectivity
  authorized_network = google_compute_network.tikky_vpc.id
}
```

### ⚡ **GitOps with Config Sync (GCP's GitOps)**

**config-sync.yaml:**
```yaml
apiVersion: configmanagement.gke.io/v1
kind: ConfigManagement
metadata:
  name: config-management
spec:
  git:
    syncRepo: https://github.com/bluecore/tikky-manifests
    syncBranch: main
    secretType: none
    policyDir: "manifests/production"
  sourceFormat: unstructured
```

### 🎯 **GCP Production Deployment Checklist**

**GCP Prerequisites:**
- [ ] **GKE Cluster** provisioned with Workload Identity
- [ ] **Artifact Registry** repository created
- [ ] **Cloud Build** triggers configured
- [ ] **Secret Manager** for sensitive configuration
- [ ] **Cloud Operations** (Stackdriver) for monitoring
- [ ] **Cloud Load Balancing** for ingress
- [ ] **Cloud Armor** for DDoS protection

**Environment-Specific Changes:**
- [ ] Update image references to `us-central1-docker.pkg.dev/PROJECT_ID/tikky-repo/tikky:TAG`
- [ ] Configure **Google Cloud Load Balancer** instead of nginx ingress
- [ ] Set up **Cloud SQL** or **Memorystore Redis** for production data
- [ ] Configure **Cloud KMS** for encryption at rest
- [ ] Set up **VPC-native networking** for security
- [ ] Implement **Binary Authorization** for container security

**GCP Enterprise Integration:**
- [ ] **CI/CD**: Cloud Build with GitHub/GitLab integration
- [ ] **GitOps**: Config Sync or ArgoCD on GKE
- [ ] **IaC**: Terraform with Cloud Build for automated deployments
- [ ] **Security**: Container Analysis API + Binary Authorization
- [ ] **Observability**: Cloud Operations Suite (Stackdriver)
- [ ] **Compliance**: Policy Controller (OPA Gatekeeper) on GKE

### 🔧 **Next Steps for GCP Production**

1. **Registry Setup**: Configure Cloud Build to push to Artifact Registry
2. **GKE Migration**: Deploy to GKE with Workload Identity
3. **Secret Management**: Replace hardcoded secrets with Secret Manager
4. **Resource Sizing**: Right-size based on GCP monitoring data
5. **Monitoring**: Integrate with Cloud Operations Suite
6. **Security**: Enable Binary Authorization and Pod Security Standards
7. **Networking**: Configure VPC-native networking and private clusters

**For Bluecore's GCP Environment**, this would typically integrate with:
- **Container Registry**: Artifact Registry with vulnerability scanning
- **Orchestration**: GKE with Autopilot for simplified operations
- **Infrastructure**: Terraform with Cloud Build for GitOps
- **CI/CD**: Cloud Build with GitHub integration
- **Monitoring**: Cloud Operations Suite with custom dashboards
- **Security**: Cloud Security Command Center integration

## Contributing

1. Follow Go best practices and security guidelines
2. Update documentation for configuration changes
3. Test all network policy modifications
4. Ensure resource limits are appropriate
5. Validate security configurations before committing