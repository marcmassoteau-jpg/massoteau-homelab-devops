# Blue-Green Deployment Strategy

Complete implementation of the blue-green deployment pattern for zero-downtime deployments in Kubernetes.

## 📋 Overview

**Blue-green deployment** is a release management strategy that reduces downtime and risk by running two identical production environments: **blue** and **green**. Only one environment serves production traffic at any time.

### How It Works

1. **Blue** environment is currently active (serving production traffic)
2. Deploy new version to **green** environment (inactive)
3. Test green environment thoroughly
4. Switch production traffic from blue to green
5. Blue environment remains running for quick rollback if needed

### Benefits

✅ **Zero downtime** - Instant traffic switch
✅ **Easy rollback** - Simply switch traffic back
✅ **Full testing** - Test new version in production-like environment
✅ **Reduced risk** - Keep old version running for safety
✅ **Simple concept** - Easy to understand and implement

### Drawbacks

⚠️ **Resource usage** - Requires 2x resources (two full environments)
⚠️ **Database migrations** - Complex with backward-incompatible changes
⚠️ **Stateful apps** - Challenging for applications with shared state
⚠️ **Cost** - Higher infrastructure cost than rolling updates

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Load Balancer                        │
│                  (Production Service)                   │
│          Selector: app=myapp, role=active               │
└──────────────────────┬──────────────────────────────────┘
                       │
                       │ Traffic routes to pods
                       │ with role=active label
                       ▼
        ┌──────────────┴──────────────┐
        │                             │
        ▼                             ▼
┌───────────────────┐         ┌───────────────────┐
│  Blue Environment │         │ Green Environment │
│   (role=active)   │         │  (role=inactive)  │
├───────────────────┤         ├───────────────────┤
│  Version: v1.0    │         │  Version: v2.0    │
│  Replicas: 3      │         │  Replicas: 3      │
│  Status: ACTIVE   │         │  Status: TESTING  │
└───────────────────┘         └───────────────────┘
        │                             │
        └─────────────┬───────────────┘
                      │
        Both environments always running
```

**Traffic Switch:**
```
Before: Production Service → Blue (v1.0)
After:  Production Service → Green (v2.0)
```

The switch happens by changing pod labels from `role=inactive` to `role=active`.

## 📁 Files

```
blue-green/
├── deployment-blue.yaml        # Blue environment deployment
├── deployment-green.yaml       # Green environment deployment
├── service-production.yaml     # Production service (routes to active)
├── service-blue.yaml           # Direct blue access (testing)
├── service-green.yaml          # Direct green access (testing)
├── ingress.yaml                # Ingress for external access
├── .gitlab-ci.yml              # Automated deployment pipeline
├── rollback-blue-green.sh      # Manual rollback script
└── README.md                   # This file
```

## 🚀 Quick Start

### Prerequisites

- Kubernetes cluster operational
- kubectl configured
- Production namespace created: `kubectl create namespace production`
- GitLab CI/CD (for automated pipeline)

### Step 1: Initial Deployment

Deploy both environments for the first time:

```bash
# Create production namespace
kubectl create namespace production

# Deploy blue environment (initially active)
kubectl apply -f deployment-blue.yaml
kubectl apply -f service-blue.yaml

# Deploy green environment (initially inactive)
kubectl apply -f deployment-green.yaml
kubectl apply -f service-green.yaml

# Deploy production service
kubectl apply -f service-production.yaml

# Deploy ingress
kubectl apply -f ingress.yaml

# Set blue as active environment
kubectl label pods -l app=myapp,version=blue role=active --overwrite -n production
kubectl label pods -l app=myapp,version=green role=inactive --overwrite -n production
```

### Step 2: Verify Initial Setup

```bash
# Check all pods are running
kubectl get pods -n production -l app=myapp -L role,version

# Expected output:
# NAME                          READY   STATUS    ROLE      VERSION
# myapp-blue-xxxx-yyyy          1/1     Running   active    blue
# myapp-blue-xxxx-zzzz          1/1     Running   active    blue
# myapp-blue-xxxx-aaaa          1/1     Running   active    blue
# myapp-green-xxxx-bbbb         1/1     Running   inactive  green
# myapp-green-xxxx-cccc         1/1     Running   inactive  green
# myapp-green-xxxx-dddd         1/1     Running   inactive  green

# Test production service (should route to blue)
kubectl run test-pod --rm -it --image=curlimages/curl:latest -- \
  curl http://myapp-production.production.svc.cluster.local/
```

### Step 3: Deploy New Version

Using GitLab CI/CD (recommended):

```bash
# Push code changes to main branch
git add .
git commit -m "Deploy version 2.0"
git push origin main

# Pipeline will:
# 1. Build new Docker image
# 2. Detect blue is active
# 3. Deploy to green (inactive)
# 4. Run smoke tests on green
# 5. Wait for manual approval
# 6. Switch traffic to green
```

Manual deployment:

```bash
# Update green environment image
kubectl set image deployment/myapp-green \
  myapp=registry.gitlab.homelab.local/myproject/myapp:v2.0 \
  -n production

# Wait for rollout
kubectl rollout status deployment/myapp-green -n production

# Ensure green is labeled inactive
kubectl label pods -l app=myapp,version=green role=inactive --overwrite -n production
```

### Step 4: Test Inactive Environment

Test the green environment before switching traffic:

```bash
# Test via green-specific service
kubectl port-forward svc/myapp-green 8080:80 -n production

# In another terminal
curl http://localhost:8080/health
curl http://localhost:8080/

# Or use the direct URL
curl http://myapp-green.homelab.local/
```

### Step 5: Switch Traffic

```bash
# Make green active, blue inactive
kubectl label pods -l app=myapp,version=green role=active --overwrite -n production
kubectl label pods -l app=myapp,version=blue role=inactive --overwrite -n production

# Verify the switch
kubectl get pods -n production -l app=myapp -L role,version

# Test production endpoint (should now serve green)
curl http://myapp.homelab.local/
```

### Step 6: Rollback (if needed)

If issues detected, instant rollback:

```bash
# Run rollback script
./rollback-blue-green.sh production myapp

# Or manually
kubectl label pods -l app=myapp,version=blue role=active --overwrite -n production
kubectl label pods -l app=myapp,version=green role=inactive --overwrite -n production
```

## 🔄 Deployment Workflow

### Automated Pipeline Flow

The GitLab CI/CD pipeline (`.gitlab-ci.yml`) automates the entire process:

**Stage 1: Build**
- Build Docker image with new code
- Tag with commit SHA

**Stage 2: Deploy to Inactive**
- Detect which environment is currently active
- Deploy new image to inactive environment
- Wait for rollout completion

**Stage 3: Test Inactive**
- Run smoke tests against inactive environment
- Health checks
- Readiness checks
- Optional load tests

**Stage 4: Switch** (Manual Approval Required)
- Switch labels: inactive → active, active → inactive
- Production traffic instantly routes to new version
- Old version remains running

**Stage 5: Cleanup** (Optional)
- Scale down old environment to save resources
- Or keep running for easy rollback

### Manual Workflow

For manual deployments without CI/CD:

```bash
# 1. Determine active environment
ACTIVE=$(kubectl get pods -n production -l app=myapp,role=active -o jsonpath='{.items[0].metadata.labels.version}')
INACTIVE=$([ "$ACTIVE" = "blue" ] && echo "green" || echo "blue")

# 2. Deploy to inactive
kubectl set image deployment/myapp-${INACTIVE} myapp=<new-image> -n production
kubectl rollout status deployment/myapp-${INACTIVE} -n production

# 3. Test inactive
curl http://myapp-${INACTIVE}.homelab.local/health

# 4. Switch traffic
kubectl label pods -l app=myapp,version=${INACTIVE} role=active --overwrite -n production
kubectl label pods -l app=myapp,version=${ACTIVE} role=inactive --overwrite -n production
```

## 🧪 Testing Strategy

### Pre-Switch Testing

Before switching traffic, test the inactive environment:

**1. Health Checks**
```bash
curl http://myapp-green.homelab.local/health
```

**2. Functional Tests**
```bash
# Test critical user flows
curl -X POST http://myapp-green.homelab.local/api/auth/login -d '{"user":"test","pass":"test"}'
curl http://myapp-green.homelab.local/api/products
```

**3. Load Testing**
```bash
# Using k6 (included in pipeline)
k6 run loadtest.js --env URL=http://myapp-green.homelab.local
```

**4. Integration Tests**
```bash
# Test database connectivity
curl http://myapp-green.homelab.local/api/db/health

# Test external APIs
curl http://myapp-green.homelab.local/api/external/test
```

### Post-Switch Monitoring

After switching, monitor for issues:

```bash
# Watch logs
kubectl logs -n production -l app=myapp,role=active -f

# Check pod status
kubectl get pods -n production -l app=myapp,role=active

# Monitor metrics
kubectl top pods -n production -l app=myapp,role=active
```

## 🔧 Configuration

### Environment Variables

Set in deployment YAMLs:

| Variable | Description | Example |
|----------|-------------|---------|
| `VERSION` | Environment identifier | `blue` or `green` |
| `ENVIRONMENT` | Deployment environment | `production` |

### Labels

Critical labels for routing:

| Label | Values | Purpose |
|-------|--------|---------|
| `app` | `myapp` | Application identifier |
| `version` | `blue`/`green` | Environment identifier |
| `role` | `active`/`inactive` | Traffic routing |

### Resource Limits

Per-pod resources (adjust based on application needs):

```yaml
resources:
  requests:
    cpu: 100m      # Guaranteed CPU
    memory: 128Mi  # Guaranteed memory
  limits:
    cpu: 500m      # Max CPU
    memory: 512Mi  # Max memory (OOM if exceeded)
```

### Health Checks

Configure appropriate probes:

**Liveness Probe** (restart unhealthy pods):
```yaml
livenessProbe:
  httpGet:
    path: /health
    port: 8080
  initialDelaySeconds: 30
  periodSeconds: 10
  failureThreshold: 3
```

**Readiness Probe** (remove from service if not ready):
```yaml
readinessProbe:
  httpGet:
    path: /ready
    port: 8080
  initialDelaySeconds: 10
  periodSeconds: 5
  failureThreshold: 3
```

## 🛠️ Rollback Procedure

### Using Rollback Script

```bash
# Interactive rollback with confirmation
./rollback-blue-green.sh production myapp

# Script will:
# 1. Detect current active environment
# 2. Ask for confirmation
# 3. Switch labels back
# 4. Verify the rollback
# 5. Display current state
```

### Manual Rollback

```bash
# Instant rollback by switching labels
kubectl label pods -l app=myapp,version=blue role=active --overwrite -n production
kubectl label pods -l app=myapp,version=green role=inactive --overwrite -n production

# If previous environment was scaled down, scale back up
kubectl scale deployment myapp-blue --replicas=3 -n production
kubectl rollout status deployment/myapp-blue -n production
```

### Rollback Time

- **Label switch**: Instant (< 1 second)
- **If environment scaled down**: 30-60 seconds (pod startup time)
- **Total**: Usually < 2 minutes

## 📊 Monitoring

### Key Metrics to Watch

**During Deployment:**
- Pod readiness status
- Health check success rate
- Response times (inactive environment)
- Error rates (inactive environment)

**After Traffic Switch:**
- Error rate spike (should be minimal)
- Latency changes
- 5xx errors
- Active connections
- Resource usage

### Health Check Endpoints

Required endpoints in your application:

| Endpoint | Purpose | Success Criteria |
|----------|---------|------------------|
| `/health` | Liveness check | Returns 200 OK |
| `/ready` | Readiness check | Returns 200 when ready to serve traffic |
| `/version` | Version info | Returns current version |

### Logging

Monitor logs during switch:

```bash
# Tail logs from active environment
kubectl logs -n production -l app=myapp,role=active -f --tail=100

# Check for errors after switch
kubectl logs -n production -l app=myapp,role=active --since=5m | grep -i error
```

## 🔐 Best Practices

### 1. Always Test Thoroughly

- Run comprehensive smoke tests on inactive environment
- Load test before switching production traffic
- Validate database connections
- Test all critical user flows

### 2. Keep Old Environment Running

- Don't immediately scale down old environment
- Keep for at least 1-2 hours after switch
- Allows instant rollback if issues arise

### 3. Database Migration Strategy

For backward-incompatible DB changes:

**Bad approach:**
```
1. Deploy new code with new schema
2. Switch traffic
3. Rollback fails (old code incompatible with new schema)
```

**Good approach:**
```
1. Deploy DB schema changes (backward-compatible)
2. Deploy new code to inactive environment
3. Test thoroughly
4. Switch traffic
5. Remove old code compatibility layer (next release)
```

### 4. Gradual Traffic Migration (Advanced)

Consider canary deployment if you need gradual traffic shift:

```yaml
# 10% traffic to green, 90% to blue
# Requires weighted services or service mesh
```

See: `../canary/` for canary deployment pattern.

### 5. Monitoring and Alerting

Set up alerts for:
- Pod crash loops
- High error rates
- Slow response times
- Failed health checks
- Resource exhaustion

### 6. Document Rollback Procedure

Ensure team knows how to rollback quickly:
```bash
# Emergency rollback (paste in terminal)
kubectl label pods -l app=myapp,version=blue role=active --overwrite -n production && \
kubectl label pods -l app=myapp,version=green role=inactive --overwrite -n production
```

### 7. Automate Everything

Use GitLab CI/CD pipeline for:
- Consistent deployments
- Automated testing
- Manual approval gates
- Audit trail

## 🐛 Troubleshooting

### Issue: Traffic Not Switching

**Symptoms:** Production still serving old version after label change.

**Diagnosis:**
```bash
# Check production service selector
kubectl get svc myapp-production -n production -o yaml | grep -A5 selector

# Check pod labels
kubectl get pods -n production -l app=myapp -L role,version

# Check which pods are receiving traffic
kubectl get endpoints myapp-production -n production
```

**Solution:**
- Ensure pods have correct `role=active` label
- Verify service selector matches pod labels
- Check for network policies blocking traffic

### Issue: Inactive Environment Failing Health Checks

**Symptoms:** Smoke tests fail on inactive environment.

**Diagnosis:**
```bash
# Check pod status
kubectl get pods -n production -l app=myapp,version=green

# Check logs
kubectl logs -n production -l app=myapp,version=green --tail=100

# Describe pod
kubectl describe pod <pod-name> -n production
```

**Common Causes:**
- Database connection issues
- Missing environment variables
- ConfigMap/Secret not updated
- Image pull errors
- Resource limits too low

### Issue: Rollback Not Working

**Symptoms:** Old environment unavailable for rollback.

**Diagnosis:**
```bash
# Check if old deployment scaled down
kubectl get deployment myapp-blue -n production

# Check pod count
kubectl get pods -n production -l app=myapp,version=blue
```

**Solution:**
```bash
# Scale back up if needed
kubectl scale deployment myapp-blue --replicas=3 -n production
kubectl rollout status deployment/myapp-blue -n production

# Then perform rollback
./rollback-blue-green.sh production myapp
```

### Issue: Both Environments Receiving Traffic

**Symptoms:** Production serving mix of old and new versions.

**Diagnosis:**
```bash
# Check labels on all pods
kubectl get pods -n production -l app=myapp -L role,version

# Check service endpoints
kubectl describe svc myapp-production -n production
```

**Solution:**
```bash
# Ensure only one environment is active
kubectl label pods -l app=myapp,version=green role=active --overwrite -n production
kubectl label pods -l app=myapp,version=blue role=inactive --overwrite -n production
```

## 📚 Related Documentation

- **Article 16**: [Deployment Strategies and Automation](../../../docs/articles/Article-16-Deployment-Strategies.md)
- **Canary Deployment**: [../canary/README.md](../canary/README.md)
- **GitLab CI/CD**: [Phase 4 Documentation](../../../docs/PHASE-4-COMPLETION-SUMMARY.md)
- **Kubernetes Deployments**: https://kubernetes.io/docs/concepts/workloads/controllers/deployment/

## 💡 Next Steps

1. **Implement canary deployment** for gradual traffic shifting
2. **Add monitoring stack** (Prometheus + Grafana) in Phase 7
3. **Implement GitOps** (ArgoCD) for declarative deployments in Phase 6
4. **Add automated testing** to pipeline
5. **Set up alerting** for deployment issues

---

**Status:** Production-ready ✅
**Last Updated:** 2026-02-05
**Part of:** Phase 5 - Advanced CI/CD Patterns
