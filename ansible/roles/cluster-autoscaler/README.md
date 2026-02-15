# Ansible Role: Cluster Autoscaler

Ansible role to deploy a custom Proxmox-based cluster autoscaler on Kubernetes, enabling automatic node scaling based on pod demand and resource utilization.

## Description

This role automates the deployment of a custom cluster autoscaler designed for Proxmox homelab environments. Since no native Proxmox provider exists for the Kubernetes Cluster Autoscaler, this solution uses CronJobs to monitor cluster state and trigger VM provisioning via the Proxmox API. It handles:
- Pre-flight checks (kubectl, Helm, cluster connectivity)
- Metrics-server deployment (required for HPA and node metrics)
- Namespace creation for autoscaling components
- RBAC configuration (ServiceAccount, ClusterRole, ClusterRoleBinding)
- Proxmox configuration via ConfigMap
- Scale-up CronJob (detects pending pods, triggers VM provisioning)
- Scale-down CronJob (detects underutilized nodes, cordons and drains)
- Optional HPA example resources for testing

## Requirements

### System Requirements
- Ansible 2.14 or higher
- Python 3.8 or higher

### Kubernetes Cluster Requirements
- Kubernetes v1.24+ (tested on v1.29.15)
- Helm 3 installed on the control node
- Minimum 4 worker nodes (default minimum)
- Traefik ingress controller (recommended)

### Proxmox Requirements
- Proxmox VE 8.x with API access
- VM template with cloud-init support (template ID configured)
- Reserved IP range for autoscaled nodes (default: 192.168.1.245-250)

### Control Node Requirements
- `kubectl` configured with cluster access
- `helm` v3 installed
- `jq` installed (used by autoscaler scripts)
- Network connectivity to Kubernetes cluster and Proxmox API

## Role Variables

### Core Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `cluster_autoscaler_namespace` | `autoscaling` | Kubernetes namespace |
| `cluster_autoscaler_metrics_server_version` | `v0.7.1` | Metrics-server Helm chart version |
| `cluster_autoscaler_deploy_hpa_examples` | `true` | Deploy example HPA resources |
| `cluster_autoscaler_service_account` | `cluster-autoscaler` | ServiceAccount name |
| `cluster_autoscaler_image` | `bitnami/kubectl:1.29` | Container image for CronJobs |

### Scaling Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `cluster_autoscaler_min_nodes` | `4` | Minimum worker nodes |
| `cluster_autoscaler_max_nodes` | `8` | Maximum worker nodes |
| `cluster_autoscaler_scale_up_threshold` | `80` | CPU % that triggers scale-up |
| `cluster_autoscaler_scale_down_threshold` | `30` | CPU % below which node is underutilized |
| `cluster_autoscaler_scale_down_delay` | `300` | Seconds before scaling down |
| `cluster_autoscaler_check_interval` | `*/2 * * * *` | Scale-up check schedule |
| `cluster_autoscaler_scale_down_interval` | `*/5 * * * *` | Scale-down check schedule |

### Proxmox Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `cluster_autoscaler_proxmox_api_url` | `https://192.168.1.222:8006/api2/json` | Proxmox API endpoint |
| `cluster_autoscaler_proxmox_node` | `pve` | Proxmox node name |
| `cluster_autoscaler_vm_template_id` | `9000` | VM template to clone |

### Node Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `cluster_autoscaler_node_cpus` | `4` | CPUs per autoscaled node |
| `cluster_autoscaler_node_memory` | `16384` | Memory (MB) per autoscaled node |
| `cluster_autoscaler_node_disk` | `100G` | Disk size per autoscaled node |
| `cluster_autoscaler_ip_range_start` | `192.168.1.245` | First IP in autoscale range |
| `cluster_autoscaler_ip_range_end` | `192.168.1.250` | Last IP in autoscale range |
| `cluster_autoscaler_gateway` | `192.168.1.1` | Network gateway |

See `defaults/main.yml` for complete list of configurable variables.

## Dependencies

None. This is a standalone role.

## Example Playbook

### Basic Usage

```yaml
---
- name: Deploy Cluster Autoscaler
  hosts: masters
  become: yes
  roles:
    - cluster-autoscaler
```

### Custom Configuration

```yaml
---
- name: Deploy Cluster Autoscaler with custom settings
  hosts: masters
  become: yes
  vars:
    cluster_autoscaler_max_nodes: 10
    cluster_autoscaler_scale_up_threshold: 70
    cluster_autoscaler_scale_down_delay: 600
  roles:
    - cluster-autoscaler
```

### Without HPA Examples

```yaml
---
- name: Deploy Cluster Autoscaler (no examples)
  hosts: masters
  become: yes
  vars:
    cluster_autoscaler_deploy_hpa_examples: false
  roles:
    - cluster-autoscaler
```

## Usage

### Initial Deployment

```bash
ansible-playbook playbooks/10-deploy-cluster-autoscaler.yml
```

### Custom Scaling Thresholds

```bash
ansible-playbook playbooks/10-deploy-cluster-autoscaler.yml \
  -e cluster_autoscaler_scale_up_threshold=70 \
  -e cluster_autoscaler_max_nodes=10
```

### Test Autoscaling

```bash
# Test scale-up with stress deployment
scripts/autoscaling/test-scale-up.sh

# Test scale-down by reducing replicas
scripts/autoscaling/test-scale-down.sh
```

## Post-Deployment

After successful deployment, the role displays:
- Component summary (CronJobs, RBAC, ConfigMap)
- Scaling configuration (min/max nodes, thresholds)
- Proxmox configuration (API, template, IP range)

### Verify Deployment

```bash
# Check CronJobs
kubectl get cronjobs -n autoscaling

# Check recent scale check results
kubectl get jobs -n autoscaling

# View scale-up logs
kubectl logs -n autoscaling job/cluster-autoscaler-check-<id>

# Check node metrics
kubectl top nodes

# Check HPA status
kubectl get hpa
```

## Troubleshooting

### Metrics-Server Not Providing Data

```bash
# Check metrics-server pods
kubectl get pods -n kube-system -l app.kubernetes.io/name=metrics-server

# Check metrics-server logs
kubectl logs -n kube-system -l app.kubernetes.io/name=metrics-server

# Verify metrics API
kubectl get --raw /apis/metrics.k8s.io/v1beta1/nodes
```

### CronJob Not Running

```bash
# Check CronJob status
kubectl describe cronjob cluster-autoscaler-check -n autoscaling

# Check for failed jobs
kubectl get jobs -n autoscaling --sort-by=.metadata.creationTimestamp
```

### Scale-Up Not Triggering

```bash
# Check for pending pods
kubectl get pods --all-namespaces --field-selector=status.phase=Pending

# Check autoscaler logs
kubectl logs -n autoscaling -l app.kubernetes.io/component=scale-up --tail=50
```

## Idempotence

This role is idempotent:
- Running multiple times will not cause issues
- Existing namespace is reused
- RBAC and ConfigMap are updated via `kubectl apply`
- CronJobs are updated in place

## Removal

```bash
# Remove autoscaler components
kubectl delete namespace autoscaling

# Remove ClusterRole and ClusterRoleBinding
kubectl delete clusterrole cluster-autoscaler-role
kubectl delete clusterrolebinding cluster-autoscaler-binding

# Optionally remove metrics-server
helm uninstall metrics-server -n kube-system

# Optionally remove HPA examples
kubectl delete hpa webapp-example-hpa
kubectl delete deployment webapp-example
kubectl delete service webapp-example
```

## Related Documentation

- **Article 22:** Cluster Autoscaler with Proxmox
- **Scripts:** `scripts/autoscaling/`
- **Terraform Module:** `terraform/modules/k8s-autoscale-node/`
- **Manifests:** `Kubernetes/manifests/cluster-autoscaler/`
- **GitOps:** `gitops/base/cluster-autoscaler/`

## Version History

- **1.0.0** - Initial release (Article 22)
  - Custom Proxmox-based autoscaler
  - CronJob-based scale-up and scale-down
  - Metrics-server integration
  - HPA example resources
  - RBAC and ConfigMap configuration
