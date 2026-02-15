# Canary Deployment Strategy

Progressive traffic rollout with automated monitoring and rollback for safe production deployments in Kubernetes.

## 📋 Overview

**Canary deployment** is a progressive release strategy that gradually shifts traffic from the stable version to a new version while continuously monitoring metrics. If issues are detected, traffic automatically rolls back to the stable version.

### How It Works

1. Deploy new version to **canary deployment** (0% traffic initially)
2. Run smoke tests on canary
3. Gradually increase traffic: **10% → 25% → 50% → 100%**
4. Monitor error rates and latency at each stage
5. Auto-rollback if metrics exceed thresholds
6. Manual approval gates before each promotion
7. Full promotion: Update stable deployment to new version

### Benefits

✅ **Gradual rollout** - Minimize blast radius of issues
✅ **Automated monitoring** - Metrics-based decision making
✅ **Auto-rollback** - Instant recovery on threshold breach
✅ **Lower risk** - Small percentage of users affected initially
✅ **Real production testing** - Test with real traffic patterns
✅ **Flexible promotion** - Manual or automated gates

### Drawbacks

⚠️ **Complexity** - More moving parts than simple deployments
⚠️ **Monitoring required** - Needs Prometheus or similar
⚠️ **Longer deployment** - Multiple stages take more time
⚠️ **Resource usage** - Two versions running simultaneously
⚠️ **Traffic splitting** - Requires capable ingress controller

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────┐
│              Traefik Ingress Controller                 │
│            (Weighted Traffic Distribution)              │
└──────────────────┬──────────────────────────────────────┘
                   │
                   │ Traffic split based on weights
                   ▼
        ┌──────────┴──────────┐
        │                     │
        │ 90%                 │ 10%
        ▼                     ▼
┌──────────────────┐   ┌──────────────────┐
│ Stable Service   │   │ Canary Service   │
│   (myapp-stable) │   │  (myapp-canary)  │
└────────┬─────────┘   └────────┬─────────┘
         │                      │
         ▼                      ▼
┌──────────────────┐   ┌──────────────────┐
│ Stable Deployment│   │Canary Deployment │
│   Version: v1.0  │   │  Version: v2.0   │
│   Replicas: 3    │   │  Replicas: 1     │
└──────────────────┘   └──────────────────┘
         │                      │
         └──────────┬───────────┘
                    │
         Prometheus monitors both
         (error rates, latency, etc.)
```

### Progressive Rollout Timeline

```
Stage 1:  0% canary │ Deploy, smoke test
Stage 2: 10% canary │ Monitor for 5 minutes → Auto-rollback if errors
Stage 3: 25% canary │ Monitor → Manual approval
Stage 4: 50% canary │ Monitor → Manual approval
Stage 5:100% canary │ Update stable deployment → Reset weights
```

## 📁 Files

```
canary/
├── deployment-stable.yaml        # Stable (production) deployment
├── deployment-canary.yaml        # Canary (new version) deployment
├── service-stable.yaml           # Stable service
├── service-canary.yaml           # Canary service
├── ingress-canary.yaml           # Traefik IngressRoute (weighted)
├── .gitlab-ci.yml                # Automated progressive rollout pipeline
├── scripts/
│   ├── monitor-canary.sh         # Metrics monitoring script
│   └── rollback-canary.sh        # Automated rollback script
└── README.md                     # This file
```

## 🚀 Quick Start

### Prerequisites

- Kubernetes cluster with Traefik or NGINX Ingress
- kubectl configured
- Production namespace: `kubectl create namespace production`
- Prometheus (for metrics-based monitoring)
- GitLab CI/CD (for automated pipeline)

### Step 1: Initial Deployment

Deploy stable version (current production):

```bash
# Create production namespace
kubectl create namespace production

# Deploy stable version
kubectl apply -f deployment-stable.yaml
kubectl apply -f service-stable.yaml

# Deploy canary version (initially same image as stable)
kubectl apply -f deployment-canary.yaml
kubectl apply -f service-canary.yaml

# Deploy ingress with traffic weights (100% stable, 0% canary)
kubectl apply -f ingress-canary.yaml
```

### Step 2: Verify Initial Setup

```bash
# Check deployments
kubectl get deployments -n production -l app=myapp

# Expected output:
# NAME           READY   UP-TO-DATE   AVAILABLE
# myapp-stable   3/3     3            3
# myapp-canary   1/1     1            1

# Check traffic distribution
kubectl get ingressroute myapp-canary -n production \
  -o jsonpath='{range .spec.routes[0].services[*]}{.name}{": "}{.weight}{"%\n"}{end}'

# Expected output:
# myapp-stable: 100%
# myapp-canary: 0%
```

### Step 3: Deploy New Version (Automated Pipeline)

Using GitLab CI/CD:

```bash
# Push code changes
git add .
git commit -m "Deploy version 2.0"
git push origin main

# Pipeline stages execute automatically:
# 1. Build new image
# 2. Deploy to canary (0% traffic)
# 3. Smoke test canary
# 4. Promote to 10% traffic
# 5. Monitor for 5 minutes (auto-rollback if errors)
# 6. Wait for manual approval → Promote to 25%
# 7. Monitor → Manual approval → Promote to 50%
# 8. Monitor → Manual approval → Full promotion (100%)
```

### Step 4: Manual Canary Deployment

Without CI/CD pipeline:

```bash
# Update canary deployment with new image
kubectl set image deployment/myapp-canary \
  myapp=registry.gitlab.homelab.local/myproject/myapp:v2.0 \
  -n production

# Wait for rollout
kubectl rollout status deployment/myapp-canary -n production

# Promote to 10% traffic
kubectl patch ingressroute myapp-canary -n production --type=json -p='[
  {"op":"replace","path":"/spec/routes/0/services/0/weight","value":90},
  {"op":"replace","path":"/spec/routes/0/services/1/weight","value":10}
]'

# Monitor metrics
./scripts/monitor-canary.sh 300 0.01 1000

# If monitoring passes, continue promoting (25%, 50%, 100%)
```

### Step 5: Full Promotion

After successful canary testing:

```bash
# Update stable deployment to canary image
CANARY_IMAGE=$(kubectl get deployment myapp-canary -n production \
  -o jsonpath='{.spec.template.spec.containers[0].image}')

kubectl set image deployment/myapp-stable \
  myapp=${CANARY_IMAGE} \
  -n production

# Wait for stable rollout
kubectl rollout status deployment/myapp-stable -n production

# Reset traffic weights (100% stable, 0% canary)
kubectl patch ingressroute myapp-canary -n production --type=json -p='[
  {"op":"replace","path":"/spec/routes/0/services/0/weight","value":100},
  {"op":"replace","path":"/spec/routes/0/services/1/weight","value":0}
]'
```

## 🎯 Traffic Splitting Strategies

### Traefik IngressRoute (Recommended)

Weighted services in IngressRoute:

```yaml
apiVersion: traefik.containo.us/v1alpha1
kind: IngressRoute
metadata:
  name: myapp-canary
spec:
  routes:
  - match: Host(`myapp.homelab.local`)
    services:
    - name: myapp-stable
      port: 80
      weight: 90    # 90% traffic
    - name: myapp-canary
      port: 80
      weight: 10    # 10% traffic
```

**Update weights:**
```bash
kubectl patch ingressroute myapp-canary -n production --type=json -p='[
  {"op":"replace","path":"/spec/routes/0/services/0/weight","value":75},
  {"op":"replace","path":"/spec/routes/0/services/1/weight","value":25}
]'
```

### NGINX Ingress (Alternative)

NGINX canary annotations:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: myapp-canary
  annotations:
    nginx.ingress.kubernetes.io/canary: "true"
    nginx.ingress.kubernetes.io/canary-weight: "10"  # 10% to canary
spec:
  rules:
  - host: myapp.homelab.local
    http:
      paths:
      - backend:
          service:
            name: myapp-canary
            port:
              number: 80
```

**Update weight:**
```bash
kubectl annotate ingress myapp-canary -n production \
  nginx.ingress.kubernetes.io/canary-weight="25" --overwrite
```

## 📊 Monitoring and Metrics

### Required Metrics

For automated canary analysis:

| Metric | Purpose | Prometheus Query |
|--------|---------|------------------|
| **Error Rate** | 5xx errors percentage | `rate(http_requests_total{version="canary",status=~"5.."}[1m]) / rate(http_requests_total{version="canary"}[1m])` |
| **Latency P95** | 95th percentile response time | `histogram_quantile(0.95, rate(http_request_duration_seconds_bucket{version="canary"}[1m]))` |
| **Request Count** | Traffic volume | `rate(http_requests_total{version="canary"}[1m])` |
| **Pod Health** | Crashed/unhealthy pods | `kube_pod_status_ready{pod=~"myapp-canary.*"}` |

### Monitoring Script

The `monitor-canary.sh` script automatically:

1. Queries Prometheus for metrics
2. Compares against thresholds
3. Exits with error if thresholds breached
4. Triggers automatic rollback in pipeline

**Usage:**
```bash
# Monitor for 5 minutes
# Error threshold: 1% (0.01)
# Latency threshold: 1000ms
./scripts/monitor-canary.sh 300 0.01 1000
```

**Thresholds:**

| Metric | Default | Adjust Based On |
|--------|---------|-----------------|
| Error rate | 1% (0.01) | Application SLO |
| Latency P95 | 1000ms | User experience requirements |
| Duration | 300s (5min) | Traffic volume, confidence level |

### Manual Monitoring

Watch metrics in real-time:

```bash
# Watch pod status
watch kubectl get pods -n production -l app=myapp -L version

# Monitor logs for errors
kubectl logs -n production -l app=myapp,version=canary -f | grep -i error

# Check resource usage
kubectl top pods -n production -l app=myapp,version=canary

# Query Prometheus directly
# Port-forward first:
kubectl port-forward -n monitoring svc/prometheus 9090:9090

# Then query in browser: http://localhost:9090
```

## 🔄 Rollback Procedures

### Automatic Rollback

Pipeline automatically rolls back if:
- Error rate exceeds threshold
- Latency exceeds threshold
- Canary pods crash
- Health checks fail

**How it works:**
```yaml
monitor-canary-10:
  script:
    - ./scripts/monitor-canary.sh 300 0.01 1000
    - if [ $? -ne 0 ]; then
        ./scripts/rollback-canary.sh
        exit 1
      fi
```

### Manual Rollback

Instant rollback at any stage:

```bash
# Using rollback script (recommended)
./scripts/rollback-canary.sh production myapp

# Manual commands
kubectl patch ingressroute myapp-canary -n production --type=json -p='[
  {"op":"replace","path":"/spec/routes/0/services/0/weight","value":100},
  {"op":"replace","path":"/spec/routes/0/services/1/weight","value":0}
]'
```

### Rollback Time

- **Traffic redirect**: < 1 second (change weights)
- **Pod rollback**: 30-60 seconds (update canary to stable image)
- **Total**: Usually < 2 minutes

## ⚙️ Configuration

### Deployment Replicas

**Stable deployment:**
- Replicas: 3 (handle majority of traffic)
- Resources: Standard production limits

**Canary deployment:**
- Replicas: 1 (fewer pods for new version)
- Resources: Same as stable
- Can scale up during high-traffic rollouts

### Traffic Split Progression

**Conservative approach** (safer, slower):
```
0% → 5% → 10% → 25% → 50% → 100%
Monitor 10 minutes at each stage
```

**Aggressive approach** (faster, higher risk):
```
0% → 10% → 50% → 100%
Monitor 5 minutes at each stage
```

**Current pipeline** (balanced):
```
0% → 10% → 25% → 50% → 100%
Monitor 5 minutes, manual approvals
```

### Monitoring Duration

Adjust based on traffic volume:

| Traffic Volume | Recommended Duration |
|----------------|---------------------|
| Low (<10 req/s) | 10-15 minutes |
| Medium (10-100 req/s) | 5-10 minutes |
| High (>100 req/s) | 2-5 minutes |

More traffic = faster statistical significance = shorter monitoring needed.

## 🛡️ Best Practices

### 1. Start Small

Begin with 5-10% traffic:
```bash
# Start conservative
kubectl patch ingressroute myapp-canary -n production --type=json -p='[
  {"op":"replace","path":"/spec/routes/0/services/0/weight","value":95},
  {"op":"replace","path":"/spec/routes/0/services/1/weight","value":5}
]'
```

### 2. Monitor Continuously

Don't skip monitoring stages:
```yaml
# Bad: Promote without monitoring
promote-to-25:
  script:
    - kubectl patch ingressroute ...

# Good: Monitor before next promotion
monitor-canary-10:
  script:
    - ./scripts/monitor-canary.sh 300 0.01 1000
  allow_failure: false  # Block if monitoring fails
```

### 3. Set Realistic Thresholds

Based on current stable metrics:

```bash
# Query current stable error rate
curl -s 'http://prometheus:9090/api/v1/query?query=rate(http_requests_total{version="stable",status=~"5.."}[5m])/rate(http_requests_total{version="stable"}[5m])'

# Set canary threshold slightly higher (e.g., 2x stable)
```

### 4. Use Manual Approval Gates

Require human approval for critical stages:

```yaml
promote-to-50:
  when: manual  # Wait for approval
  environment:
    name: production
```

### 5. Keep Stable Untouched

Don't update stable until canary fully validated:

```yaml
# Bad: Update stable too early
promote-to-25:
  script:
    - kubectl set image deployment/myapp-stable myapp=$NEW_IMAGE

# Good: Update stable only at end
promote-to-100:
  script:
    - kubectl set image deployment/myapp-stable myapp=$NEW_IMAGE
  when: manual
```

### 6. Test at Each Stage

Run smoke tests after each promotion:

```bash
# After promoting to 25%
curl https://myapp.homelab.local/health
./tests/smoke-test.sh
```

### 7. Document Rollback Process

Ensure team knows emergency rollback:

```bash
# One-liner emergency rollback (keep handy)
kubectl patch ingressroute myapp-canary -n production --type=json -p='[{"op":"replace","path":"/spec/routes/0/services/0/weight","value":100},{"op":"replace","path":"/spec/routes/0/services/1/weight","value":0}]'
```

## 🐛 Troubleshooting

### Issue: Canary Receiving No Traffic

**Symptoms:** Canary metrics flat, no requests.

**Diagnosis:**
```bash
# Check ingress weights
kubectl get ingressroute myapp-canary -n production -o yaml | grep -A10 services

# Check canary service endpoints
kubectl get endpoints myapp-canary -n production

# Check canary pods
kubectl get pods -n production -l version=canary
```

**Common Causes:**
- Weight set to 0
- Canary pods not ready
- Service selector mismatch
- Ingress not applied

### Issue: Monitoring Script Fails

**Symptoms:** `monitor-canary.sh` exits with error but metrics look fine.

**Diagnosis:**
```bash
# Test Prometheus connectivity
curl http://prometheus.monitoring.svc.cluster.local:9090/-/healthy

# Run monitoring script with debug
bash -x ./scripts/monitor-canary.sh 60 0.01 1000

# Check if metrics exist
curl 'http://prometheus:9090/api/v1/query?query=http_requests_total{version="canary"}'
```

**Common Causes:**
- Prometheus not reachable
- Metrics not being exported
- Query syntax errors
- Threshold too strict

### Issue: Automatic Rollback Triggered Incorrectly

**Symptoms:** Pipeline rolls back but canary was healthy.

**Diagnosis:**
```bash
# Check monitoring job logs
kubectl logs -n gitlab-runner <monitoring-pod>

# Query actual metrics
curl 'http://prometheus:9090/api/v1/query?query=rate(http_requests_total{version="canary",status=~"5.."}[1m])'
```

**Solutions:**
- Adjust thresholds to realistic values
- Increase monitoring duration
- Fix metric instrumentation

### Issue: Traffic Not Splitting

**Symptoms:** All traffic to stable, none to canary despite weights.

**For Traefik:**
```bash
# Check IngressRoute status
kubectl describe ingressroute myapp-canary -n production

# Check Traefik logs
kubectl logs -n kube-system -l app=traefik -f
```

**For NGINX:**
```bash
# Check canary annotation
kubectl get ingress myapp-canary -n production -o yaml | grep canary

# Check NGINX controller logs
kubectl logs -n ingress-nginx -l app=ingress-nginx -f
```

## 📊 Comparison: Canary vs Blue-Green

| Aspect | Canary | Blue-Green |
|--------|--------|------------|
| **Traffic shift** | Gradual (10%→25%→50%→100%) | Instant (0%→100%) |
| **Risk** | Lower (small % affected) | Higher (all users switch) |
| **Monitoring** | Essential (metrics-based) | Optional (can test offline) |
| **Complexity** | Higher (multiple stages) | Lower (single switch) |
| **Rollback** | Instant (change weights) | Instant (change labels) |
| **Duration** | Longer (hours) | Shorter (minutes) |
| **Use case** | High-risk changes | Low-risk changes, testing |

**When to use Canary:**
- High-traffic production systems
- Risk-sensitive changes
- Want real-world testing with metrics
- Can tolerate longer deployment time

**When to use Blue-Green:**
- Need instant rollback capability
- Want full offline testing
- Simpler setup preferred
- Quick deployments required

See: `../blue-green/README.md` for blue-green strategy.

## 📚 Related Documentation

- **Article 16**: [Deployment Strategies and Automation](../../../docs/articles/Article-16-Deployment-Strategies.md)
- **Blue-Green Deployment**: [../blue-green/README.md](../blue-green/README.md)
- **GitLab CI/CD**: [Phase 4 Documentation](../../../docs/PHASE-4-COMPLETION-SUMMARY.md)
- **Traefik Docs**: https://doc.traefik.io/traefik/routing/services/#weighted-round-robin-service
- **Prometheus Queries**: https://prometheus.io/docs/prometheus/latest/querying/basics/

## 💡 Advanced Patterns

### 1. Automated Canary Analysis

Use Flagger for fully automated canary analysis:

```bash
# Install Flagger
kubectl apply -k github.com/fluxcd/flagger//kustomize/traefik

# Create Canary resource
kubectl apply -f - <<EOF
apiVersion: flagger.app/v1beta1
kind: Canary
metadata:
  name: myapp
  namespace: production
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: myapp
  progressDeadlineSeconds: 300
  service:
    port: 80
  analysis:
    interval: 1m
    threshold: 5
    maxWeight: 50
    stepWeight: 10
    metrics:
    - name: request-success-rate
      thresholdRange:
        min: 99
    - name: request-duration
      thresholdRange:
        max: 500
EOF
```

### 2. Header-Based Routing

Route specific users to canary:

```yaml
# Traefik with header matching
services:
- name: myapp-canary
  weight: 100
  match: Headers(`X-Canary`, `true`)
- name: myapp-stable
  weight: 100
```

### 3. Geo-Based Rollout

Roll out by region:

```yaml
# US traffic first
- name: myapp-canary
  weight: 50
  match: HeadersRegexp(`X-Country`, `US`)
```

## 💡 Next Steps

1. **Implement Flagger** for fully automated canary analysis
2. **Add custom metrics** specific to your application
3. **Set up alerting** for failed canary deployments
4. **Integrate with GitOps** (ArgoCD) in Phase 6
5. **Add A/B testing** capabilities

---

**Status:** Production-ready ✅
**Last Updated:** 2026-02-05
**Part of:** Phase 5 - Advanced CI/CD Patterns
