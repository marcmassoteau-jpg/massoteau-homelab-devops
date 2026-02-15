# Ansible Role: Monitoring Stack

Ansible role to deploy a complete monitoring stack (Prometheus, Grafana, AlertManager, Loki, Promtail) on Kubernetes using official Helm charts, optimized for homelab environments.

## Description

This role automates the deployment of a full observability stack on an existing Kubernetes cluster. It handles:
- Pre-flight checks (kubectl, Helm, cluster connectivity)
- Namespace creation with appropriate labels
- Helm repository configuration (prometheus-community, grafana)
- kube-prometheus-stack deployment (Prometheus, Grafana, AlertManager, Node Exporter, Kube State Metrics)
- Loki deployment for log aggregation
- Promtail deployment for log collection
- ServiceMonitor creation for GitLab, Jenkins, ArgoCD, and Traefik
- PrometheusRule creation for homelab alerting
- Traefik IngressRoute setup for all web UIs
- Post-deployment verification

## Requirements

### System Requirements
- Ansible 2.14 or higher
- Python 3.8 or higher

### Kubernetes Cluster Requirements
- Kubernetes v1.24+ (tested on v1.29.15)
- Helm 3 installed on the control node
- Minimum resources available:
  - 4GB RAM
  - 4 CPU cores
- Traefik ingress controller (recommended)
- StorageClass available for persistent volumes

### Control Node Requirements
- `kubectl` configured with cluster access
- `helm` v3 installed
- Network connectivity to Kubernetes cluster

## Role Variables

### Core Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `monitoring_namespace` | `monitoring` | Kubernetes namespace |
| `monitoring_release_name` | `kube-prometheus-stack` | Helm release name |
| `monitoring_prometheus_chart_version` | `65.1.0` | kube-prometheus-stack chart version |
| `monitoring_loki_chart_version` | `6.22.0` | Loki chart version |
| `monitoring_promtail_chart_version` | `6.16.6` | Promtail chart version |

### Domain Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `monitoring_grafana_domain` | `grafana.homelab.local` | Grafana web UI domain |
| `monitoring_prometheus_domain` | `prometheus.homelab.local` | Prometheus web UI domain |
| `monitoring_alertmanager_domain` | `alertmanager.homelab.local` | AlertManager web UI domain |

### Prometheus Resources

| Variable | Default | Description |
|----------|---------|-------------|
| `monitoring_prometheus_cpu_request` | `250m` | Prometheus CPU request |
| `monitoring_prometheus_cpu_limit` | `1` | Prometheus CPU limit |
| `monitoring_prometheus_memory_request` | `512Mi` | Prometheus memory request |
| `monitoring_prometheus_memory_limit` | `2Gi` | Prometheus memory limit |
| `monitoring_prometheus_retention` | `15d` | Metrics retention period |
| `monitoring_prometheus_storage_size` | `10Gi` | Prometheus PV size |

### Grafana Resources

| Variable | Default | Description |
|----------|---------|-------------|
| `monitoring_grafana_cpu_request` | `100m` | Grafana CPU request |
| `monitoring_grafana_cpu_limit` | `500m` | Grafana CPU limit |
| `monitoring_grafana_memory_request` | `128Mi` | Grafana memory request |
| `monitoring_grafana_memory_limit` | `512Mi` | Grafana memory limit |
| `monitoring_grafana_admin_password` | `admin` | Initial admin password |

### AlertManager Resources

| Variable | Default | Description |
|----------|---------|-------------|
| `monitoring_alertmanager_cpu_request` | `50m` | AlertManager CPU request |
| `monitoring_alertmanager_cpu_limit` | `200m` | AlertManager CPU limit |
| `monitoring_alertmanager_memory_request` | `64Mi` | AlertManager memory request |
| `monitoring_alertmanager_memory_limit` | `256Mi` | AlertManager memory limit |

### Loki Resources

| Variable | Default | Description |
|----------|---------|-------------|
| `monitoring_loki_cpu_request` | `100m` | Loki CPU request |
| `monitoring_loki_cpu_limit` | `500m` | Loki CPU limit |
| `monitoring_loki_memory_request` | `128Mi` | Loki memory request |
| `monitoring_loki_memory_limit` | `512Mi` | Loki memory limit |
| `monitoring_loki_retention` | `168h` | Log retention period (7 days) |
| `monitoring_loki_storage_size` | `10Gi` | Loki PV size |

### Promtail Resources

| Variable | Default | Description |
|----------|---------|-------------|
| `monitoring_promtail_cpu_request` | `50m` | Promtail CPU request |
| `monitoring_promtail_cpu_limit` | `200m` | Promtail CPU limit |
| `monitoring_promtail_memory_request` | `64Mi` | Promtail memory request |
| `monitoring_promtail_memory_limit` | `128Mi` | Promtail memory limit |

### Feature Flags

| Variable | Default | Description |
|----------|---------|-------------|
| `monitoring_servicemonitor_gitlab` | `true` | Create GitLab ServiceMonitor |
| `monitoring_servicemonitor_jenkins` | `true` | Create Jenkins ServiceMonitor |
| `monitoring_servicemonitor_argocd` | `true` | Create ArgoCD ServiceMonitor |
| `monitoring_servicemonitor_traefik` | `true` | Create Traefik ServiceMonitor |
| `monitoring_alerting_enabled` | `true` | Deploy PrometheusRule alerts |
| `monitoring_ingress_enabled` | `true` | Deploy Traefik IngressRoutes |

### Deployment Options

| Variable | Default | Description |
|----------|---------|-------------|
| `monitoring_helm_timeout` | `10m` | Helm deployment timeout |
| `monitoring_helm_wait` | `true` | Wait for resources ready |
| `monitoring_force_redeploy` | `false` | Force reinstall |
| `monitoring_create_namespace` | `true` | Create namespace if missing |
| `monitoring_wait_for_ready` | `true` | Wait for pods Running |
| `monitoring_ready_timeout` | `300` | Pod ready timeout (seconds) |

See `defaults/main.yml` for the complete list of configurable variables.

## Dependencies

None. This is a standalone role.

## Example Playbook

### Basic Usage

```yaml
---
- name: Deploy monitoring stack on Kubernetes
  hosts: masters
  become: yes
  roles:
    - monitoring
```

### Custom Configuration

```yaml
---
- name: Deploy monitoring stack with custom settings
  hosts: masters
  become: yes
  vars:
    monitoring_grafana_domain: grafana.example.com
    monitoring_prometheus_memory_limit: 4Gi
    monitoring_prometheus_retention: "30d"
    monitoring_grafana_admin_password: "{{ vault_grafana_password }}"
  roles:
    - monitoring
```

### Minimal Deployment (Prometheus Stack Only)

```yaml
---
- name: Deploy Prometheus stack without Loki
  hosts: masters
  become: yes
  vars:
    monitoring_servicemonitor_gitlab: false
    monitoring_servicemonitor_jenkins: false
  roles:
    - monitoring
```

## Usage

### Initial Deployment

```bash
ansible-playbook playbooks/08-deploy-monitoring.yml
```

### Upgrade Existing Deployment

```bash
ansible-playbook playbooks/08-deploy-monitoring.yml \
  -e monitoring_prometheus_chart_version=66.0.0
```

### Force Redeployment

```bash
ansible-playbook playbooks/08-deploy-monitoring.yml \
  -e monitoring_force_redeploy=true
```

### Custom Domain

```bash
ansible-playbook playbooks/08-deploy-monitoring.yml \
  -e monitoring_grafana_domain=grafana.mydomain.com
```

## Post-Deployment

After successful deployment, the role displays:
- Component versions deployed
- Access URLs for Grafana, Prometheus, AlertManager
- Grafana default credentials

### Access Grafana

1. Navigate to `http://grafana.homelab.local`
2. Login with username `admin` and the displayed password
3. **Important:** Change the admin password immediately

### Access Prometheus

1. Navigate to `http://prometheus.homelab.local`
2. Verify targets are being scraped under Status > Targets

### Access AlertManager

1. Navigate to `http://alertmanager.homelab.local`
2. Review active alerts and silences

### Verify Deployment

```bash
# Check all pods are Running
kubectl get pods -n monitoring

# Check services
kubectl get svc -n monitoring

# Check ServiceMonitors
kubectl get servicemonitors -n monitoring

# Check PrometheusRules
kubectl get prometheusrules -n monitoring

# Check IngressRoutes
kubectl get ingressroutes -n monitoring

# Verify Prometheus targets
kubectl port-forward svc/kube-prometheus-stack-prometheus -n monitoring 9090:9090
# Then open http://localhost:9090/targets
```

## Troubleshooting

### Pods Stuck in Pending

```bash
kubectl describe pod -n monitoring <pod-name>
kubectl top nodes
```

Check if StorageClass is available for PersistentVolumeClaims:
```bash
kubectl get pvc -n monitoring
kubectl get sc
```

### Deployment Timeout

- Increase timeout: `-e monitoring_helm_timeout=15m`
- Check cluster resources
- Monitor pod logs: `kubectl logs -n monitoring <pod-name>`

### Grafana UI Not Accessible

```bash
# Port-forward for direct access
kubectl port-forward svc/kube-prometheus-stack-grafana -n monitoring 3000:80

# Check IngressRoute
kubectl get ingressroutes -n monitoring
kubectl describe ingressroute grafana -n monitoring
```

### Prometheus Not Scraping Targets

```bash
# Check ServiceMonitor resources
kubectl get servicemonitors -n monitoring
kubectl describe servicemonitor <name> -n monitoring

# Check Prometheus configuration
kubectl port-forward svc/kube-prometheus-stack-prometheus -n monitoring 9090:9090
# Navigate to http://localhost:9090/config
```

### Loki Not Receiving Logs

```bash
# Check Promtail logs
kubectl logs -n monitoring -l app.kubernetes.io/name=promtail

# Check Loki health
kubectl port-forward svc/loki-gateway -n monitoring 3100:80
curl http://localhost:3100/ready
```

## Idempotence

This role is idempotent:
- Running multiple times will not cause issues
- Existing namespace is reused
- Helm upgrade is used if components are already deployed
- ServiceMonitors and PrometheusRules use `kubectl apply`
- Use `monitoring_force_redeploy: true` to force reinstall

## Removal

```bash
# Remove Helm releases
helm uninstall kube-prometheus-stack -n monitoring
helm uninstall loki -n monitoring
helm uninstall promtail -n monitoring

# Remove CRDs (optional - removes all Prometheus Operator CRDs)
kubectl delete crd alertmanagerconfigs.monitoring.coreos.com
kubectl delete crd alertmanagers.monitoring.coreos.com
kubectl delete crd podmonitors.monitoring.coreos.com
kubectl delete crd probes.monitoring.coreos.com
kubectl delete crd prometheusagents.monitoring.coreos.com
kubectl delete crd prometheuses.monitoring.coreos.com
kubectl delete crd prometheusrules.monitoring.coreos.com
kubectl delete crd scrapeconfigs.monitoring.coreos.com
kubectl delete crd servicemonitors.monitoring.coreos.com
kubectl delete crd thanosrulers.monitoring.coreos.com

# Remove namespace
kubectl delete namespace monitoring
```

## Related Documentation

- **Article 18:** Monitoring with Prometheus & Grafana
- **Kubernetes Manifests:** `Kubernetes/manifests/monitoring/`
- **GitOps Overlays:** `gitops/overlays/*/monitoring/`
- **Prometheus Docs:** https://prometheus.io/docs/
- **Grafana Docs:** https://grafana.com/docs/grafana/latest/
- **Loki Docs:** https://grafana.com/docs/loki/latest/

## Version History

- **1.0.0** - Initial release (Phase 7)
  - kube-prometheus-stack deployment via Helm
  - Loki and Promtail for log aggregation
  - Homelab-optimized resource configuration
  - ServiceMonitors for GitLab, Jenkins, ArgoCD, Traefik
  - PrometheusRule alerts for node and pod health
  - Traefik IngressRoute integration
  - Grafana with Loki datasource pre-configured
