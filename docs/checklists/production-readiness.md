# Production Readiness Checklist

This master checklist covers all aspects of production readiness for a Kubernetes homelab cluster. Use this as a pre-production gate to ensure all critical areas have been addressed.

**Automated assessment:** Run `scripts/assessment/readiness-check.sh` for an automated version of this checklist.

---

## Security

- [ ] RBAC roles and bindings configured for all namespaces
- [ ] Cluster-admin access restricted to break-glass scenarios only
- [ ] Pod Security Standards (PSA) enforced on all user namespaces
- [ ] No containers running as privileged unless explicitly required
- [ ] No containers running as root (runAsNonRoot: true)
- [ ] Network Policies configured for all namespaces
- [ ] Default-deny ingress NetworkPolicy in place
- [ ] Secrets mounted as volumes (not environment variables)
- [ ] Default service account automountServiceAccountToken disabled
- [ ] Image pull policies set to Always or using digest-pinned images

## High Availability

- [ ] Cluster has 3+ nodes (minimum 1 control plane + 2 workers)
- [ ] All nodes in Ready state
- [ ] Critical deployments have replicas > 1
- [ ] Pod anti-affinity rules configured for critical workloads
- [ ] PodDisruptionBudgets defined for critical services
- [ ] Control plane components are healthy (kube-apiserver, etcd, scheduler, controller-manager)
- [ ] Resource requests and limits set on all pods

## Monitoring and Alerting

- [ ] Prometheus deployed and scraping targets
- [ ] Grafana deployed with dashboards for cluster overview
- [ ] AlertManager configured with notification channels
- [ ] ServiceMonitors configured for all critical services
- [ ] Metrics Server running (kubectl top works)
- [ ] Node-level monitoring (node-exporter) deployed
- [ ] Alert rules defined for: node down, pod crash, high CPU/memory, disk pressure
- [ ] Grafana dashboards for: cluster health, namespace resources, node metrics

## Backup and Recovery

- [ ] Velero installed and backup storage location available
- [ ] Automated backup schedules configured (daily/weekly)
- [ ] Recent backup completed successfully (within last 24 hours)
- [ ] Disaster recovery tested (backup + restore cycle verified)
- [ ] etcd backup script available and tested
- [ ] Backup retention policy configured
- [ ] Restore procedure documented and tested

## Networking

- [ ] CNI plugin healthy (all CNI pods running)
- [ ] CoreDNS running and resolving cluster services
- [ ] DNS resolution tested (kubernetes.default.svc.cluster.local)
- [ ] Ingress controller deployed and serving traffic
- [ ] TLS certificates configured for ingress endpoints
- [ ] External access verified (LoadBalancer or NodePort)
- [ ] Service mesh or mTLS considered for inter-service communication

## Storage

- [ ] At least one StorageClass defined
- [ ] Default StorageClass configured
- [ ] All PersistentVolumes in Bound state
- [ ] No PersistentVolumeClaims stuck in Pending
- [ ] Storage provisioner healthy and tested
- [ ] Volume expansion enabled on StorageClass (if supported)

## CI/CD Pipeline

- [ ] GitLab or equivalent source control running in cluster
- [ ] Jenkins or equivalent CI engine running
- [ ] CI runners/agents configured and available
- [ ] Build pipelines tested end-to-end
- [ ] Container image registry available (GitLab Registry or Harbor)
- [ ] Webhook integration configured between SCM and CI
- [ ] Pipeline templates standardized for common workflows

## GitOps

- [ ] ArgoCD installed and running
- [ ] ArgoCD Applications configured for all managed workloads
- [ ] All Applications in Synced state
- [ ] Self-healing enabled on critical applications
- [ ] Auto-prune enabled to remove stale resources
- [ ] Git repository structure follows Kustomize base/overlay pattern
- [ ] Application health checks configured

## Documentation

- [ ] Architecture diagram up to date
- [ ] Runbook for common operations documented
- [ ] Troubleshooting guide available
- [ ] Upgrade procedures documented
- [ ] Disaster recovery plan documented and tested

---

## Scoring Guide

| Score | Rating | Action |
|-------|--------|--------|
| 90-100% | Excellent | Production ready |
| 70-89% | Good | Address warnings before production |
| 50-69% | Fair | Significant gaps to address |
| Below 50% | Needs Work | Not ready for production workloads |

## How to Use

1. Work through each section, checking items as you verify them
2. Run the automated readiness check for a quick assessment
3. Address all FAIL items before considering production readiness
4. Review WARN items and create a plan to address them
5. Re-run the assessment after making changes
