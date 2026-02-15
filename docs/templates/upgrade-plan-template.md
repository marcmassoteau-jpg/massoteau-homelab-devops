# Kubernetes Upgrade Plan Template

Use this template to plan, execute, and verify Kubernetes version upgrades for your homelab cluster.

**Cluster context:** 5-node kubeadm cluster (1 control plane + 4 workers), Kubernetes 1.29

---

## Upgrade Details

| Field | Value |
|-------|-------|
| **Current Version** | v1.__.__ |
| **Target Version** | v1.__.__ |
| **Upgrade Type** | Patch / Minor / Major |
| **Planned Date** | ____-__-__ |
| **Planned Window** | __:__ to __:__ |
| **Estimated Duration** | ___ hours |
| **Performed By** | __________ |
| **Approved By** | __________ |

---

## Component Compatibility Matrix

Verify all cluster components are compatible with the target Kubernetes version before upgrading.

### Core Components

| Component | Current Version | Compatible with Target K8s? | Target Version | Notes |
|-----------|----------------|---------------------------|----------------|-------|
| kubeadm | v1.__.__ | Yes/No | v1.__.__ | Must match K8s version |
| kubelet | v1.__.__ | Yes/No | v1.__.__ | Must match K8s version |
| kubectl | v1.__.__ | Yes/No | v1.__.__ | +/- 1 minor version |
| containerd | v___.__ | Yes/No | v___.__ | Check release notes |
| etcd | v___.__ | Yes/No | v___.__ | Bundled with kubeadm |

### CNI and Networking

| Component | Current Version | Compatible with Target K8s? | Target Version | Upgrade Required? |
|-----------|----------------|---------------------------|----------------|-------------------|
| Calico / Flannel | v___.__ | Yes/No | v___.__ | Yes/No |
| CoreDNS | v___.__ | Yes/No | v___.__ | Auto-upgraded by kubeadm |
| Traefik (Ingress) | v___.__ | Yes/No | v___.__ | Yes/No |

### Helm Charts

| Chart | Current Chart Version | Current App Version | Compatible? | Target Chart Version |
|-------|----------------------|--------------------|-----------|--------------------|
| GitLab | ___.__ | ___.__ | Yes/No | ___.__ |
| Jenkins | ___.__ | ___.__ | Yes/No | ___.__ |
| ArgoCD | ___.__ | ___.__ | Yes/No | ___.__ |
| Prometheus Stack | ___.__ | ___.__ | Yes/No | ___.__ |
| Grafana | ___.__ | ___.__ | Yes/No | ___.__ |

**How to check Helm chart compatibility:**
```bash
# List installed Helm releases with versions
helm list -A

# Check chart documentation for Kubernetes version requirements
# GitLab: https://docs.gitlab.com/charts/installation/cloud/
# ArgoCD: https://argo-cd.readthedocs.io/en/stable/operator-manual/installation/
```

### Deprecated/Removed APIs

- [ ] Checked for deprecated APIs in target version
- [ ] No manifests use removed API versions
- [ ] Helm charts updated to use current API versions

**How to check:**
```bash
# Install and run kubent (kube-no-trouble)
# https://github.com/doitintl/kube-no-trouble
kubent

# Or manually check for common deprecations
kubectl get all -A -o json | grep "apiVersion" | sort | uniq -c | sort -rn
```

---

## Pre-Upgrade Checklist

### Research and Planning

- [ ] Read Kubernetes release notes for target version
- [ ] Review changelog for breaking changes and deprecations
- [ ] Check deprecated API versions that will be removed
- [ ] Verify all add-ons and CNI are compatible (see matrix above)
- [ ] Verify all Helm charts are compatible (see matrix above)
- [ ] Confirm upgrade path: v1.__.__ -> v1.__.__ (only +1 minor at a time)
- [ ] Upgrade plan reviewed and approved

### Cluster Health Verification

- [ ] All nodes in Ready state
  ```bash
  kubectl get nodes
  ```
- [ ] All system pods running
  ```bash
  kubectl get pods -n kube-system
  ```
- [ ] No pending PVCs
  ```bash
  kubectl get pvc -A | grep -v Bound
  ```
- [ ] No CrashLoopBackOff pods
  ```bash
  kubectl get pods -A | grep CrashLoop
  ```
- [ ] No pods in error state
  ```bash
  kubectl get pods -A | grep -v Running | grep -v Completed
  ```
- [ ] Run readiness check
  ```bash
  ./scripts/assessment/readiness-check.sh
  ```
- [ ] Capture performance baseline
  ```bash
  ./scripts/assessment/performance-baseline.sh --save baselines/pre-upgrade-$(date +%Y%m%d).json
  ```

### Backup

- [ ] etcd backup taken and verified
  ```bash
  ./scripts/backup/etcd-backup.sh
  ls -la /var/backups/etcd/
  ```
- [ ] Velero backup of all namespaces
  ```bash
  velero backup create pre-upgrade-$(date +%Y%m%d) --wait
  ```
- [ ] Backup verification (list and check status)
  ```bash
  velero backup get
  velero backup describe pre-upgrade-$(date +%Y%m%d)
  ```
- [ ] Kubernetes manifests exported
  ```bash
  kubectl get all -A -o yaml > pre-upgrade-manifests.yaml
  ```
- [ ] Document current component versions
  ```bash
  kubectl version
  kubeadm version
  kubelet --version
  helm list -A
  ```
- [ ] Backups stored in a safe location (off-cluster if possible)

---

## Timeline and Communication Plan

### Upgrade Timeline

| Time | Phase | Duration | Action |
|------|-------|----------|--------|
| T-7 days | Planning | -- | Finalize upgrade plan, verify compatibility matrix |
| T-3 days | Communication | -- | Notify stakeholders of maintenance window |
| T-1 day | Pre-checks | 30 min | Run full cluster health check |
| T-1 day | Backups | 30 min | Take etcd + Velero backups |
| T+0:00 | Start | -- | Begin maintenance window |
| T+0:05 | Backup verify | 5 min | Verify backup integrity |
| T+0:10 | Control plane | 15-20 min | Upgrade control plane node |
| T+0:30 | Worker 1 | 10-15 min | Drain, upgrade, uncordon k8s-w01 |
| T+0:45 | Worker 2 | 10-15 min | Drain, upgrade, uncordon k8s-w02 |
| T+1:00 | Worker 3 | 10-15 min | Drain, upgrade, uncordon k8s-w03 |
| T+1:15 | Worker 4 | 10-15 min | Drain, upgrade, uncordon k8s-w04 |
| T+1:30 | Verification | 15 min | Post-upgrade checks, service verification |
| T+1:45 | Baseline | 10 min | Capture post-upgrade performance baseline |
| T+2:00 | Complete | -- | End maintenance window, send completion notice |

### Communication Plan

| When | Audience | Channel | Message |
|------|----------|---------|---------|
| T-7 days | All stakeholders | Email/Slack | Upgrade planned for [date], [time window] |
| T-3 days | All stakeholders | Email/Slack | Reminder: maintenance window in 3 days |
| T+0:00 | All stakeholders | Email/Slack | Maintenance started, services may be temporarily unavailable |
| T+2:00 | All stakeholders | Email/Slack | Upgrade complete, all services verified |
| If rollback | All stakeholders | Email/Slack | Issue encountered, rolling back to previous version |

---

## Upgrade Steps

### Phase 1: Upgrade Control Plane

**Node:** k8s-cp01

```bash
# 1. Check available versions
sudo apt-cache madison kubeadm | head

# 2. Upgrade kubeadm
sudo apt-mark unhold kubeadm
sudo apt-get update
sudo apt-get install -y kubeadm=1.__.__-*
sudo apt-mark hold kubeadm

# 3. Verify kubeadm version
kubeadm version

# 4. Check upgrade plan (shows what will change)
sudo kubeadm upgrade plan

# 5. Apply upgrade
sudo kubeadm upgrade apply v1.__.__

# 6. Upgrade kubelet and kubectl
sudo apt-mark unhold kubelet kubectl
sudo apt-get install -y kubelet=1.__.__-* kubectl=1.__.__-*
sudo apt-mark hold kubelet kubectl

# 7. Restart kubelet
sudo systemctl daemon-reload
sudo systemctl restart kubelet
```

**Verification after control plane upgrade:**
- [ ] `kubectl get nodes` shows upgraded control plane version
- [ ] `kubectl get pods -n kube-system` all pods running
- [ ] `kubectl version` shows correct server version
- [ ] `kubectl get --raw /healthz` returns ok

**Time completed:** __:__
**Status:** Pass / Fail

### Phase 2: Upgrade Worker Nodes

Upgrade one worker node at a time. Wait for each node to be fully Ready before proceeding.

#### Worker Node: k8s-w01

```bash
# 1. Drain the node (from control plane)
kubectl drain k8s-w01 --ignore-daemonsets --delete-emptydir-data

# 2. SSH to worker node and upgrade kubeadm
sudo apt-mark unhold kubeadm
sudo apt-get update
sudo apt-get install -y kubeadm=1.__.__-*
sudo apt-mark hold kubeadm

# 3. Upgrade node config
sudo kubeadm upgrade node

# 4. Upgrade kubelet and kubectl
sudo apt-mark unhold kubelet kubectl
sudo apt-get install -y kubelet=1.__.__-* kubectl=1.__.__-*
sudo apt-mark hold kubelet kubectl

# 5. Restart kubelet
sudo systemctl daemon-reload
sudo systemctl restart kubelet

# 6. Uncordon the node (from control plane)
kubectl uncordon k8s-w01
```

**Verification:**
- [ ] Node shows correct version in `kubectl get nodes`
- [ ] Node is Ready
- [ ] Pods rescheduled back to node
- [ ] Wait for all pods Running before next node

**Time completed:** __:__  |  **Status:** Pass / Fail

#### Worker Node: k8s-w02

_(Repeat steps above for k8s-w02)_

**Time completed:** __:__  |  **Status:** Pass / Fail

#### Worker Node: k8s-w03

_(Repeat steps above for k8s-w03)_

**Time completed:** __:__  |  **Status:** Pass / Fail

#### Worker Node: k8s-w04

_(Repeat steps above for k8s-w04)_

**Time completed:** __:__  |  **Status:** Pass / Fail

---

## Rollback Plan

If the upgrade fails or causes critical issues, follow the rollback procedure.

### Decision Criteria for Rollback

| Condition | Action |
|-----------|--------|
| Control plane upgrade fails | Restore etcd backup, downgrade kubeadm |
| Worker upgrade fails | Downgrade that worker, uncordon |
| Services not recovering after 15 min | Begin rollback |
| Data corruption detected | Immediate rollback + etcd restore |

### Control Plane Rollback

```bash
# 1. Restore etcd from backup
./scripts/backup/etcd-restore.sh <backup-file>

# 2. Downgrade kubeadm, kubelet, kubectl
sudo apt-mark unhold kubeadm kubelet kubectl
sudo apt-get install -y kubeadm=<old-version> kubelet=<old-version> kubectl=<old-version>
sudo apt-mark hold kubeadm kubelet kubectl
sudo systemctl daemon-reload
sudo systemctl restart kubelet
```

### Worker Node Rollback

```bash
# Drain and downgrade each upgraded worker
kubectl drain <node> --ignore-daemonsets --delete-emptydir-data

# SSH to node, downgrade packages
sudo apt-mark unhold kubeadm kubelet kubectl
sudo apt-get install -y kubeadm=<old-version> kubelet=<old-version> kubectl=<old-version>
sudo apt-mark hold kubeadm kubelet kubectl
sudo kubeadm upgrade node
sudo systemctl daemon-reload
sudo systemctl restart kubelet

# Uncordon
kubectl uncordon <node>
```

### Full Cluster Restore (Last Resort)

1. Restore etcd backup to control plane
2. Downgrade all node packages
3. Verify cluster health
4. Restore workloads from Velero backup if needed
5. Verify all services operational

---

## Post-Upgrade Verification

### Cluster Health

- [ ] All nodes show target version
  ```bash
  kubectl get nodes -o wide
  ```
- [ ] All nodes in Ready state
- [ ] All system pods running
  ```bash
  kubectl get pods -n kube-system
  ```
- [ ] API server responding
  ```bash
  kubectl get --raw /healthz
  kubectl get --raw /readyz
  ```

### Workload Health

- [ ] All deployments available
  ```bash
  kubectl get deployments -A
  ```
- [ ] No pods in error state
  ```bash
  kubectl get pods -A | grep -v Running | grep -v Completed
  ```
- [ ] DNS resolution working
  ```bash
  kubectl run dns-test --image=busybox:1.36 --rm -it --restart=Never -- nslookup kubernetes.default
  ```

### Service Verification

- [ ] GitLab accessible and functional (web UI, git push/pull)
- [ ] Jenkins accessible and functional (run a test build)
- [ ] ArgoCD accessible, all applications synced
- [ ] Traefik serving ingress traffic
- [ ] Prometheus scraping targets successfully
- [ ] Grafana dashboards loading with data
- [ ] Velero backups working (trigger a test backup)

### Performance Baseline Comparison

- [ ] Capture post-upgrade baseline
  ```bash
  ./scripts/assessment/performance-baseline.sh --save baselines/post-upgrade-$(date +%Y%m%d).json
  ```
- [ ] Compare with pre-upgrade baseline
- [ ] No significant performance degradation (API latency, resource usage)
- [ ] etcd database size unchanged or smaller

---

## Upgrade Log

| Time | Action | Result | Notes |
|------|--------|--------|-------|
| __:__ | Started upgrade | | |
| __:__ | etcd backup completed | Pass/Fail | |
| __:__ | Velero backup completed | Pass/Fail | |
| __:__ | Control plane upgraded | Pass/Fail | |
| __:__ | k8s-w01 upgraded | Pass/Fail | |
| __:__ | k8s-w02 upgraded | Pass/Fail | |
| __:__ | k8s-w03 upgraded | Pass/Fail | |
| __:__ | k8s-w04 upgraded | Pass/Fail | |
| __:__ | Post-upgrade verification | Pass/Fail | |
| __:__ | Performance baseline captured | Pass/Fail | |
| __:__ | Upgrade complete | Pass/Fail | |

---

## Lessons Learned

_Record any issues encountered and how they were resolved:_

1.
2.
3.

---

**Plan Created:** ____-__-__
**Plan Reviewed By:** __________
**Upgrade Completed:** ____-__-__
