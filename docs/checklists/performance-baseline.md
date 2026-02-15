# Performance Baseline Checklist

A structured checklist for establishing and verifying performance baselines across all critical Kubernetes cluster components. Use this to detect degradation, validate upgrades, and plan capacity.

**Automated capture:** Run `scripts/assessment/performance-baseline.sh --save baseline.json` to capture a baseline.

---

## 1. API Server Latency

### 1.1 Health Endpoint Response Times

- [ ] `/healthz` responds under 100ms
- [ ] `/livez` responds under 100ms
- [ ] `/readyz` responds under 200ms

**How to measure:**
```bash
# Time each health endpoint
for endpoint in healthz livez readyz; do
  time kubectl get --raw "/$endpoint" > /dev/null
done
```

**Acceptable thresholds:**

| Endpoint | Healthy | Warning | Critical |
|----------|---------|---------|----------|
| /healthz | < 100ms | 100-500ms | > 500ms |
| /livez | < 100ms | 100-500ms | > 500ms |
| /readyz | < 200ms | 200-1000ms | > 1000ms |

### 1.2 API Request Latency

- [ ] List all pods completes under 500ms
- [ ] Get single resource completes under 100ms
- [ ] API error rate below 1%
- [ ] No 5xx errors from API server in last hour

**How to measure:**
```bash
# Time common operations
time kubectl get pods -A > /dev/null
time kubectl get nodes > /dev/null
time kubectl get deployments -A > /dev/null

# Check API server error rate (requires Prometheus)
# PromQL: rate(apiserver_request_total{code=~"5.."}[5m]) / rate(apiserver_request_total[5m])
```

### 1.3 API Server Resource Usage

- [ ] API server CPU usage below 50% of allocated
- [ ] API server memory usage below 70% of allocated
- [ ] API server request queue depth is 0 under normal load

**How to measure:**
```bash
kubectl top pods -n kube-system -l component=kube-apiserver
```

---

## 2. etcd Performance

### 2.1 Database Health

- [ ] etcd database size below 500MB
- [ ] etcd member count matches expected (1 for single control plane, 3 for HA)
- [ ] All etcd members are healthy
- [ ] Leader is stable (no recent leader elections)

**How to measure:**
```bash
# Check etcd status (run on control plane node)
sudo ETCDCTL_API=3 etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  endpoint status --write-out=table

# Check member health
sudo ETCDCTL_API=3 etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  endpoint health --write-out=table
```

### 2.2 Disk Performance

- [ ] WAL fsync duration p99 below 10ms
- [ ] Backend commit duration p99 below 25ms
- [ ] No disk I/O warnings in etcd logs

**How to measure:**
```bash
# Check etcd logs for slow disk warnings
sudo journalctl -u etcd --since "1 hour ago" | grep -i "slow\|took too long"

# Via Prometheus (if available)
# PromQL: histogram_quantile(0.99, rate(etcd_disk_wal_fsync_duration_seconds_bucket[5m]))
# PromQL: histogram_quantile(0.99, rate(etcd_disk_backend_commit_duration_seconds_bucket[5m]))
```

**Acceptable thresholds:**

| Metric | Healthy | Warning | Critical |
|--------|---------|---------|----------|
| DB size | < 500MB | 500MB-1GB | > 1GB |
| WAL fsync p99 | < 10ms | 10-50ms | > 50ms |
| Backend commit p99 | < 25ms | 25-100ms | > 100ms |
| Leader changes (24h) | 0 | 1-2 | > 2 |

### 2.3 etcd Object Counts

- [ ] Total Kubernetes object count is within expected range
- [ ] No single namespace has excessive object count

**How to measure:**
```bash
# Count objects by resource type
for resource in pods deployments services configmaps secrets; do
  count=$(kubectl get $resource -A --no-headers 2>/dev/null | wc -l)
  echo "$resource: $count"
done
```

---

## 3. Node Resource Utilization

### 3.1 CPU Utilization

- [ ] No node exceeds 70% sustained CPU usage
- [ ] Control plane node CPU below 50%
- [ ] CPU allocation ratio (requests/allocatable) below 80%

**How to measure:**
```bash
# Current usage
kubectl top nodes

# Allocation vs capacity
kubectl describe nodes | grep -A 5 "Allocated resources"
```

**Acceptable thresholds per node:**

| Node Role | Healthy | Warning | Critical |
|-----------|---------|---------|----------|
| Control Plane | < 50% | 50-70% | > 70% |
| Worker | < 70% | 70-85% | > 85% |

### 3.2 Memory Utilization

- [ ] No node exceeds 80% sustained memory usage
- [ ] Control plane node memory below 60%
- [ ] Memory allocation ratio (requests/allocatable) below 85%

**How to measure:**
```bash
# Current memory usage
kubectl top nodes

# Detailed per-node memory
kubectl get nodes -o custom-columns=\
NAME:.metadata.name,\
CAPACITY:.status.capacity.memory,\
ALLOCATABLE:.status.allocatable.memory
```

**Acceptable thresholds per node:**

| Node Role | Healthy | Warning | Critical |
|-----------|---------|---------|----------|
| Control Plane | < 60% | 60-80% | > 80% |
| Worker | < 80% | 80-90% | > 90% |

### 3.3 Disk Utilization

- [ ] Root filesystem below 80% on all nodes
- [ ] /var/lib/kubelet below 80%
- [ ] /var/lib/containerd (or /var/lib/docker) below 80%
- [ ] etcd data directory below 70%

**How to measure:**
```bash
# Run on each node via SSH
df -h / /var/lib/kubelet /var/lib/containerd

# Check for disk pressure conditions
kubectl get nodes -o custom-columns=\
NAME:.metadata.name,\
DISK_PRESSURE:.status.conditions[?(@.type=="DiskPressure")].status
```

---

## 4. Pod Scheduling Latency

### 4.1 Scheduling Time

- [ ] Pod scheduling latency below 5 seconds for normal pods
- [ ] No pods stuck in Pending state
- [ ] Scheduler is healthy and responsive

**How to measure:**
```bash
# Check for pending pods
kubectl get pods -A --field-selector=status.phase=Pending

# Test scheduling latency
START=$(date +%s%N)
kubectl run sched-test --image=busybox:1.36 --restart=Never -- sleep 10
kubectl wait --for=condition=Ready pod/sched-test --timeout=30s
END=$(date +%s%N)
echo "Scheduling latency: $(( (END - START) / 1000000 ))ms"
kubectl delete pod sched-test --grace-period=0

# Via Prometheus (if available)
# PromQL: histogram_quantile(0.99, rate(scheduler_e2e_scheduling_duration_seconds_bucket[5m]))
```

### 4.2 Scheduler Queue

- [ ] Scheduler queue depth is 0 under normal conditions
- [ ] No scheduling failures in last hour
- [ ] Preemption events are rare or zero

**How to measure:**
```bash
# Check scheduler logs for failures
kubectl logs -n kube-system -l component=kube-scheduler --tail=50 | grep -i "fail\|error\|unable"

# Check events for scheduling issues
kubectl get events -A --field-selector reason=FailedScheduling
```

### 4.3 Resource Availability

- [ ] At least 20% CPU headroom across the cluster
- [ ] At least 20% memory headroom across the cluster
- [ ] All nodes are schedulable (not cordoned)

**How to measure:**
```bash
# Check for cordoned nodes
kubectl get nodes -o custom-columns=\
NAME:.metadata.name,\
SCHEDULABLE:.spec.unschedulable

# Check allocatable vs requested resources
kubectl describe nodes | grep -E "Name:|Allocated resources:" -A 6
```

---

## 5. Network Throughput

### 5.1 DNS Performance

- [ ] CoreDNS pod(s) running and healthy
- [ ] DNS resolution completes under 50ms
- [ ] Internal service resolution works (kubernetes.default.svc.cluster.local)
- [ ] External DNS resolution works

**How to measure:**
```bash
# Check CoreDNS status
kubectl get pods -n kube-system -l k8s-app=kube-dns

# Test DNS resolution
kubectl run dns-test --image=busybox:1.36 --rm -it --restart=Never -- \
  sh -c "time nslookup kubernetes.default.svc.cluster.local && time nslookup google.com"
```

### 5.2 Pod-to-Pod Connectivity

- [ ] Cross-node pod communication works
- [ ] Same-node pod communication works
- [ ] Service ClusterIP routing works
- [ ] CNI plugin pods are all healthy

**How to measure:**
```bash
# Verify CNI pods
kubectl get pods -n kube-system -l k8s-app=calico-node  # Calico
# or
kubectl get pods -n kube-system -l k8s-app=flannel       # Flannel

# Test cross-node connectivity
kubectl run net-test-1 --image=busybox:1.36 --restart=Never -- sleep 300
kubectl run net-test-2 --image=busybox:1.36 --restart=Never -- sleep 300
POD2_IP=$(kubectl get pod net-test-2 -o jsonpath='{.status.podIP}')
kubectl exec net-test-1 -- ping -c 3 "$POD2_IP"
kubectl delete pod net-test-1 net-test-2 --grace-period=0
```

### 5.3 Ingress Performance

- [ ] Ingress controller pods healthy
- [ ] Ingress endpoints responding
- [ ] TLS termination working
- [ ] Response time through ingress below 200ms for static content

**How to measure:**
```bash
# Check ingress controller
kubectl get pods -n traefik  # or nginx-ingress namespace

# Test ingress response time (from a node with access)
time curl -sk https://<ingress-endpoint>/healthz
```

---

## 6. Storage I/O

### 6.1 PersistentVolume Health

- [ ] All PVCs are in Bound state
- [ ] No PVCs stuck in Pending
- [ ] Storage provisioner is healthy
- [ ] Available storage capacity meets requirements

**How to measure:**
```bash
# Check PVC status
kubectl get pvc -A

# Check for unbound PVCs
kubectl get pvc -A | grep -v Bound

# Check StorageClasses
kubectl get storageclass
```

### 6.2 Storage Performance

- [ ] Sequential read throughput meets workload requirements
- [ ] Sequential write throughput meets workload requirements
- [ ] Random I/O latency below 5ms for SSD, below 20ms for HDD
- [ ] No I/O wait spikes on nodes

**How to measure:**
```bash
# On each node, check I/O wait
iostat -x 1 5

# Simple write test (on a node)
dd if=/dev/zero of=/tmp/test-write bs=1M count=1024 oflag=direct 2>&1 | tail -1

# Simple read test (on a node)
dd if=/tmp/test-write of=/dev/null bs=1M count=1024 iflag=direct 2>&1 | tail -1
rm /tmp/test-write
```

**Acceptable thresholds:**

| Metric | SSD | HDD |
|--------|-----|-----|
| Sequential read | > 400 MB/s | > 100 MB/s |
| Sequential write | > 300 MB/s | > 80 MB/s |
| Random read latency | < 1ms | < 10ms |
| I/O wait % | < 5% | < 15% |

### 6.3 Per-Service Storage Usage

- [ ] GitLab storage usage within allocated PVC bounds
- [ ] Jenkins workspace not exceeding limits
- [ ] Prometheus data retention within storage limits
- [ ] ArgoCD repo-server cache size reasonable

**How to measure:**
```bash
# Check PVC usage per namespace
for ns in gitlab jenkins monitoring argocd; do
  echo "=== $ns ==="
  kubectl get pvc -n $ns -o custom-columns=\
NAME:.metadata.name,\
STATUS:.status.phase,\
CAPACITY:.status.capacity.storage
done
```

---

## Baseline Capture Summary

### Capture Schedule

| Frequency | Purpose |
|-----------|---------|
| Weekly | Routine monitoring, trend detection |
| Before/after upgrades | Impact assessment |
| Before/after new workloads | Capacity impact |
| Monthly | Capacity planning report |

### Baseline Record

| Date | Trigger | File | Notes |
|------|---------|------|-------|
| ____-__-__ | Initial baseline | `baselines/baseline-initial.json` | |
| ____-__-__ | Pre-upgrade | `baselines/pre-upgrade-YYYYMMDD.json` | |
| ____-__-__ | Post-upgrade | `baselines/post-upgrade-YYYYMMDD.json` | |

### Red Flags

| Indicator | Possible Cause | Action |
|-----------|---------------|--------|
| API latency doubled | Overloaded API server, etcd issues | Check etcd health, API server resources |
| Memory usage jumped 20%+ | Memory leak, new workloads without limits | Review pod resource limits, check for OOMKills |
| etcd size grew rapidly | Too many objects, missing cleanup | Run compaction, review object counts |
| Node CPU consistently >80% | Insufficient capacity | Add worker node, optimize workloads |
| Pod restarts increasing | Application bugs, OOM kills, probe failures | Check logs, review resource limits |
| DNS resolution slow | CoreDNS overloaded, network issues | Scale CoreDNS, check CNI health |

---

**Last Captured:** ____-__-__
**Next Capture:** ____-__-__
**Reviewed By:** __________
