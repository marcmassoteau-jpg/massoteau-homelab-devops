# High Availability Assessment Template

Use this template to identify single points of failure (SPOFs) in your Kubernetes homelab, assess recovery time for each component, and plan remediation.

**Cluster context:** 5-node kubeadm cluster (1 control plane + 4 workers), Kubernetes 1.29

---

## 1. Control Plane HA

### Current Configuration

| Aspect | Value |
|--------|-------|
| Number of control plane nodes | 1 (single master) / 3 (multi-master) |
| etcd topology | Stacked / External |
| API server load balancing | None / HAProxy / kube-vip |
| Control plane node | k8s-cp01 |

### Control Plane Components

| Component | Instances | SPOF? | Recovery Time | Remediation |
|-----------|----------|-------|---------------|-------------|
| kube-apiserver | ___ | Yes/No | ___min | Add HA control plane |
| etcd | ___ | Yes/No | ___min | External etcd cluster |
| kube-scheduler | ___ | Yes/No | ___min | Multi-master with leader election |
| kube-controller-manager | ___ | Yes/No | ___min | Multi-master with leader election |

### HA Assessment

- [ ] Control plane survives single node failure (requires 3+ masters)
- [ ] etcd has quorum protection (requires 3+ members)
- [ ] API server is load balanced across multiple nodes
- [ ] Control plane certificates are backed up
- [ ] kubeadm join token or config is documented for node replacement

**How to verify:**
```bash
# Check control plane component status
kubectl get componentstatuses 2>/dev/null || echo "componentstatuses deprecated, checking pods"
kubectl get pods -n kube-system -l tier=control-plane

# Check etcd members
sudo ETCDCTL_API=3 etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  member list --write-out=table
```

**Single vs Multi-Master Trade-offs (Homelab):**

| Aspect | Single Master | Multi-Master (3) |
|--------|-------------|-----------------|
| Resource overhead | Low | 2x more control plane resources |
| Failure tolerance | None - cluster unusable | Survives 1 node failure |
| Complexity | Simple | Moderate (load balancer needed) |
| Recommended for | Dev/learning | Production-like workloads |

---

## 2. Worker Node Redundancy

### Node Inventory

| Node | Role | CPU | RAM | Key Workloads | Impact if Lost |
|------|------|-----|-----|---------------|---------------|
| k8s-cp01 | Control Plane | ___ cores | ___GB | API server, etcd, scheduler | Cluster management lost |
| k8s-w01 | Worker | ___ cores | ___GB | | |
| k8s-w02 | Worker | ___ cores | ___GB | | |
| k8s-w03 | Worker | ___ cores | ___GB | | |
| k8s-w04 | Worker | ___ cores | ___GB | | |

### Redundancy Checks

- [ ] Cluster has enough capacity to lose 1 worker and still run all workloads
- [ ] No workload pinned to a single node via nodeSelector/affinity
- [ ] Pod anti-affinity configured for critical multi-replica deployments
- [ ] PodDisruptionBudgets defined for services with replicas > 1
- [ ] Node taints/tolerations reviewed and documented

**How to verify:**
```bash
# Check node capacity and current usage
kubectl top nodes

# Check for node affinity rules
kubectl get pods -A -o json | jq -r '.items[] | select(.spec.nodeSelector != null) | "\(.metadata.namespace)/\(.metadata.name): \(.spec.nodeSelector)"'

# Check PodDisruptionBudgets
kubectl get pdb -A

# Simulate node loss: can remaining nodes handle the load?
kubectl describe nodes | grep -A 5 "Allocated resources"
```

---

## 3. Service Replication

### CI/CD Stack

| Service | Namespace | Replicas | Min Available | SPOF? | Data at Risk |
|---------|-----------|----------|--------------|-------|-------------|
| GitLab Webservice | gitlab | ___ | ___ | Yes/No | Web UI access |
| GitLab Sidekiq | gitlab | ___ | ___ | Yes/No | Background jobs |
| GitLab Gitaly | gitlab | ___ | ___ | Yes/No | Git repositories |
| GitLab PostgreSQL | gitlab | ___ | ___ | Yes/No | All GitLab data |
| GitLab Redis | gitlab | ___ | ___ | Yes/No | Session/cache data |
| GitLab MinIO | gitlab | ___ | ___ | Yes/No | Artifacts, uploads |
| GitLab Registry | gitlab | ___ | ___ | Yes/No | Container images |
| Jenkins Controller | jenkins | ___ | ___ | Yes/No | Job config, history |

### GitOps Stack

| Service | Namespace | Replicas | Min Available | SPOF? | Data at Risk |
|---------|-----------|----------|--------------|-------|-------------|
| ArgoCD Server | argocd | ___ | ___ | Yes/No | Web UI access |
| ArgoCD Repo Server | argocd | ___ | ___ | Yes/No | Cached repos |
| ArgoCD App Controller | argocd | ___ | ___ | Yes/No | Sync state |
| ArgoCD Redis | argocd | ___ | ___ | Yes/No | Cache data |

### Ingress and Networking

| Service | Namespace | Replicas | Min Available | SPOF? | Data at Risk |
|---------|-----------|----------|--------------|-------|-------------|
| Traefik | traefik | ___ | ___ | Yes/No | External access |
| CoreDNS | kube-system | ___ | ___ | Yes/No | DNS resolution |

### Monitoring Stack

| Service | Namespace | Replicas | Min Available | SPOF? | Data at Risk |
|---------|-----------|----------|--------------|-------|-------------|
| Prometheus | monitoring | ___ | ___ | Yes/No | Metrics history |
| Grafana | monitoring | ___ | ___ | Yes/No | Dashboards, config |
| AlertManager | monitoring | ___ | ___ | Yes/No | Alert silence state |
| Node Exporter | monitoring | ___ (DaemonSet) | N/A | No | N/A |

**How to verify:**
```bash
# Check replica counts for all deployments
kubectl get deployments -A -o custom-columns=\
NAMESPACE:.metadata.namespace,\
NAME:.metadata.name,\
DESIRED:.spec.replicas,\
READY:.status.readyReplicas

# Check statefulsets
kubectl get statefulsets -A

# Check DaemonSets
kubectl get daemonsets -A
```

---

## 4. Storage Redundancy

### Storage Infrastructure

| Component | Redundancy | SPOF? | Recovery Time | Remediation |
|-----------|-----------|-------|---------------|-------------|
| Node local disk | None / RAID1 / RAID5 | Yes/No | ___min | Add RAID or NAS |
| NFS/NAS (if used) | None / RAID | Yes/No | ___min | RAID + UPS |
| Storage provisioner | ___ replicas | Yes/No | ___min | |
| StorageClass | local-path / NFS / other | N/A | N/A | |

### PersistentVolume Assessment

| PVC | Namespace | Size | Storage Type | Redundant? | Backup? |
|-----|-----------|------|-------------|-----------|---------|
| gitlab-data | gitlab | ___Gi | local/NFS | Yes/No | Yes/No |
| gitlab-postgresql | gitlab | ___Gi | local/NFS | Yes/No | Yes/No |
| gitlab-minio | gitlab | ___Gi | local/NFS | Yes/No | Yes/No |
| jenkins-home | jenkins | ___Gi | local/NFS | Yes/No | Yes/No |
| prometheus-data | monitoring | ___Gi | local/NFS | Yes/No | Yes/No |
| grafana-data | monitoring | ___Gi | local/NFS | Yes/No | Yes/No |

**How to verify:**
```bash
# List all PVs with reclaim policy
kubectl get pv -o custom-columns=\
NAME:.metadata.name,\
CAPACITY:.spec.capacity.storage,\
RECLAIM:.spec.persistentVolumeReclaimPolicy,\
STORAGECLASS:.spec.storageClassName,\
STATUS:.status.phase

# Check volume expansion support
kubectl get storageclass -o custom-columns=\
NAME:.metadata.name,\
PROVISIONER:.provisioner,\
ALLOW_EXPANSION:.allowVolumeExpansion
```

---

## 5. Backup Coverage

### Backup Inventory

| What | Tool | Schedule | Retention | Last Verified |
|------|------|----------|-----------|--------------|
| etcd snapshot | etcdctl / script | Daily / Weekly | ___ copies | ____-__-__ |
| Kubernetes resources | Velero | Daily / Weekly | ___ days | ____-__-__ |
| GitLab data | Velero / GitLab backup | Daily / Weekly | ___ days | ____-__-__ |
| Jenkins config | Velero | Daily / Weekly | ___ days | ____-__-__ |
| Prometheus data | Velero | Weekly | ___ days | ____-__-__ |
| Grafana dashboards | Velero / JSON export | Daily / Weekly | ___ days | ____-__-__ |
| ArgoCD config | Velero / Git repo | Daily / Weekly | ___ days | ____-__-__ |

### Backup Verification Checklist

- [ ] etcd backup restore tested successfully
- [ ] Velero backup + restore cycle tested
- [ ] GitLab backup restore tested
- [ ] Backups stored off-cluster (different physical location)
- [ ] Backup encryption enabled (if storing off-site)
- [ ] Backup monitoring/alerting configured (alert on backup failure)

---

## 6. Recovery Time Objectives

### RTO/RPO Per Service

| Service | Target RTO | Actual RTO | Target RPO | Actual RPO | Gap |
|---------|-----------|-----------|-----------|-----------|-----|
| Control Plane | ___min | ___min | 0 min | ___min | |
| DNS/CoreDNS | ___min | ___min | N/A | N/A | |
| Ingress/Traefik | ___min | ___min | N/A | N/A | |
| GitLab | ___min | ___min | ___min | ___min | |
| Jenkins | ___min | ___min | ___min | ___min | |
| ArgoCD | ___min | ___min | ___min | ___min | |
| Prometheus | ___min | ___min | ___min | ___min | |
| Grafana | ___min | ___min | ___min | ___min | |

_RTO = Recovery Time Objective (maximum downtime)_
_RPO = Recovery Point Objective (maximum data loss window)_

### Recovery Priority Order

| Priority | Service | Reason |
|----------|---------|--------|
| 1 | Control Plane (API server, etcd) | All other services depend on it |
| 2 | Networking (CNI, CoreDNS, Traefik) | Required for service communication |
| 3 | ArgoCD | Can redeploy other services via GitOps |
| 4 | Monitoring (Prometheus, Grafana) | Needed to verify recovery health |
| 5 | GitLab | Source code and CI/CD pipelines |
| 6 | Jenkins | CI builds (can wait for GitLab) |

---

## 7. Single Points of Failure Identification

### SPOF Summary

| SPOF | Component | Severity | Impact | Likelihood |
|------|-----------|----------|--------|-----------|
| Single control plane node | k8s-cp01 | Critical | Full cluster management lost | Medium |
| Network switch | Physical switch | Critical | All inter-node communication lost | Low |
| Power supply | Single circuit | Critical | Full outage if no UPS | Low |
| Local storage on node | Node disk | High | PVs on that node unavailable | Medium |
| Single NFS server (if used) | NAS | High | All NFS-backed PVs unavailable | Medium |
| Single Traefik instance | Ingress | Medium | External access lost until rescheduled | Medium |
| Single GitLab Gitaly | gitlab | Medium | Git operations blocked | Medium |

### Failure Scenarios

#### Scenario 1: Single Worker Node Failure

| Aspect | Assessment |
|--------|-----------|
| **Trigger** | Hardware failure, kernel panic, network isolation |
| **Affected Services** | Pods scheduled on that node |
| **Detection Time** | ~5 min (node NotReady timeout) |
| **Auto-Recovery** | Pods rescheduled to other nodes (if resources available) |
| **Manual Steps** | Investigate root cause, replace/repair node |
| **Total Recovery Time** | 5-10 min (pods) / hours-days (hardware) |
| **Data Loss Risk** | Local PVs on that node are lost |

#### Scenario 2: Control Plane Node Failure

| Aspect | Assessment |
|--------|-----------|
| **Trigger** | Hardware failure, disk full, etcd corruption |
| **Affected Services** | All cluster management (no new scheduling, no API) |
| **Detection Time** | Immediate (kubectl fails) |
| **Auto-Recovery** | None (single master) |
| **Manual Steps** | Restore etcd backup, rebuild control plane |
| **Total Recovery Time** | 30-60 min (with backups) / hours (without) |
| **Data Loss Risk** | etcd data since last backup |

#### Scenario 3: Complete Power Outage

| Aspect | Assessment |
|--------|-----------|
| **Trigger** | Power failure beyond UPS capacity |
| **Affected Services** | All services |
| **Detection Time** | Immediate |
| **Auto-Recovery** | Nodes boot, kubelet starts, pods reschedule |
| **Manual Steps** | Verify all nodes come back, check etcd health |
| **Total Recovery Time** | 10-20 min (clean boot) / 30+ min (if etcd issues) |
| **Data Loss Risk** | In-flight writes during power loss |

---

## 8. Improvement Recommendations

### SPOF Remediation Plan

| SPOF | Remediation | Effort | Est. Cost | Priority |
|------|-------------|--------|----------|----------|
| Single control plane | Add 2 more CP nodes + load balancer | High | $$$  | P1 |
| Single network switch | Add redundant switch + bonded NICs | Medium | $$ | P2 |
| Local storage SPOFs | Migrate to NAS with RAID or replicated storage | High | $$ | P1 |
| Single Traefik replica | Scale to 2+ replicas with anti-affinity | Low | $0 | P1 |
| No UPS / short UPS | Add or upgrade UPS | Low | $ | P2 |
| Single GitLab Gitaly | Consider Gitaly cluster (requires license) | High | $$$ | P3 |

### Short-Term Improvements (1-2 weeks)

- [ ] Scale Traefik to 2+ replicas with pod anti-affinity
- [ ] Scale CoreDNS to 2+ replicas (if not already)
- [ ] Add PodDisruptionBudgets for critical services
- [ ] Verify all backup schedules are running
- [ ] Test etcd backup restore procedure

### Medium-Term Improvements (1-3 months)

- [ ] Set up automated etcd backup with off-cluster storage
- [ ] Implement monitoring alerts for node failures
- [ ] Add resource requests/limits to all pods
- [ ] Test full disaster recovery scenario
- [ ] Document node replacement procedure

### Long-Term Improvements (3-6 months)

- [ ] Migrate to multi-master control plane (3 nodes)
- [ ] Implement replicated storage solution
- [ ] Add network redundancy (bonded NICs, second switch)
- [ ] Implement automated failover testing
- [ ] Consider adding a 6th node for additional capacity

---

**Assessment Date:** ____-__-__
**Assessed By:** __________
**Next Review:** ____-__-__
