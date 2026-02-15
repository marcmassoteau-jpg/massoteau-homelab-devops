# Ansible Role: ArgoCD

Ansible role to deploy ArgoCD on Kubernetes using the official Helm chart for GitOps-based continuous delivery, optimized for homelab environments.

## Description

This role automates the deployment of ArgoCD on an existing Kubernetes cluster. It handles:
- Pre-flight checks (kubectl, Helm, cluster connectivity)
- Namespace creation
- Helm repository configuration
- ArgoCD deployment via Helm chart
- ArgoCD CLI installation
- Post-deployment verification
- Optional repository and project configuration
- Traefik IngressRoute setup

## Requirements

### System Requirements
- Ansible 2.14 or higher
- Python 3.8 or higher

### Kubernetes Cluster Requirements
- Kubernetes v1.24+ (tested on v1.29.15)
- Helm 3 installed on the control node
- Minimum resources available:
  - 3GB RAM
  - 3 CPU cores
- Traefik ingress controller (recommended)

### Control Node Requirements
- `kubectl` configured with cluster access
- `helm` v3 installed
- Network connectivity to Kubernetes cluster

## Role Variables

### Core Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `argocd_namespace` | `argocd` | Kubernetes namespace |
| `argocd_release_name` | `argocd` | Helm release name |
| `argocd_chart_version` | `5.55.0` | Helm chart version |
| `argocd_domain` | `argocd.homelab.local` | ArgoCD web UI domain |

### Resource Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `argocd_server_cpu_request` | `100m` | Server CPU request |
| `argocd_server_memory_limit` | `512Mi` | Server memory limit |
| `argocd_controller_cpu_request` | `250m` | Controller CPU request |
| `argocd_controller_memory_limit` | `1Gi` | Controller memory limit |
| `argocd_reposerver_memory_limit` | `512Mi` | Repo server memory limit |

See `defaults/main.yml` for complete list of configurable variables.

### Feature Flags

| Variable | Default | Description |
|----------|---------|-------------|
| `argocd_dex_enabled` | `false` | Enable SSO via Dex |
| `argocd_notifications_enabled` | `false` | Enable notifications |
| `argocd_metrics_enabled` | `true` | Enable Prometheus metrics |
| `argocd_servicemonitor_enabled` | `false` | Enable ServiceMonitor CRD |
| `argocd_install_cli` | `true` | Install ArgoCD CLI |

### Deployment Options

| Variable | Default | Description |
|----------|---------|-------------|
| `argocd_helm_timeout` | `10m` | Helm deployment timeout |
| `argocd_helm_wait` | `true` | Wait for resources ready |
| `argocd_force_redeploy` | `false` | Force reinstall |
| `argocd_wait_for_ready` | `true` | Wait for pods Running |
| `argocd_ready_timeout` | `300` | Pod ready timeout (seconds) |

### Repository Configuration (Optional)

| Variable | Default | Description |
|----------|---------|-------------|
| `argocd_configure_repo` | `false` | Configure GitOps repo |
| `argocd_repo_url` | `http://gitlab.homelab.local:30080/...` | Repository URL |
| `argocd_repo_username` | `root` | Repository username |
| `argocd_repo_password` | *(unset)* | Repository password |

## Dependencies

None. This is a standalone role.

## Example Playbook

### Basic Usage

```yaml
---
- name: Deploy ArgoCD on Kubernetes
  hosts: masters
  become: yes
  roles:
    - argocd
```

### Custom Configuration

```yaml
---
- name: Deploy ArgoCD with custom settings
  hosts: masters
  become: yes
  vars:
    argocd_domain: argo.example.com
    argocd_controller_memory_limit: 2Gi
    argocd_app_resync_period: "60"
  roles:
    - argocd
```

### With Repository Configuration

```yaml
---
- name: Deploy ArgoCD with GitOps repo
  hosts: masters
  become: yes
  vars:
    argocd_configure_repo: true
    argocd_repo_url: http://gitlab.homelab.local:30080/homelab/gitops.git
    argocd_repo_username: root
    argocd_repo_password: "{{ vault_gitlab_password }}"
    argocd_create_project: true
  roles:
    - argocd
```

## Usage

### Initial Deployment

```bash
ansible-playbook playbooks/06-deploy-argocd.yml
```

### Upgrade Existing Deployment

```bash
ansible-playbook playbooks/06-deploy-argocd.yml \
  -e argocd_chart_version=5.56.0
```

### Force Redeployment

```bash
ansible-playbook playbooks/06-deploy-argocd.yml \
  -e argocd_force_redeploy=true
```

### Custom Domain

```bash
ansible-playbook playbooks/06-deploy-argocd.yml \
  -e argocd_domain=argo.mydomain.com
```

## Post-Deployment

After successful deployment, the role displays:
- ArgoCD web UI URL
- Initial admin password
- CLI login command

### Access ArgoCD

1. Navigate to `http://argocd.homelab.local`
2. Login with username `admin` and the displayed password
3. **Important:** Change the admin password immediately

### Verify Deployment

```bash
# Check all pods are Running
kubectl get pods -n argocd

# Check services
kubectl get svc -n argocd

# Check ingress
kubectl get ingress -n argocd

# CLI check
argocd app list
```

## Troubleshooting

### Pods Stuck in Pending

```bash
kubectl describe pod -n argocd <pod-name>
kubectl top nodes
```

### Deployment Timeout

- Increase timeout: `-e argocd_helm_timeout=15m`
- Check cluster resources
- Monitor pod logs: `kubectl logs -n argocd <pod-name>`

### UI Not Accessible

```bash
# Port-forward for direct access
kubectl port-forward svc/argocd-server -n argocd 8080:80

# Check ingress
kubectl get ingress -n argocd
kubectl describe ingress -n argocd argocd-server
```

### CLI Login Fails

```bash
# Reset admin password
kubectl -n argocd patch secret argocd-secret \
  -p '{"stringData": {"admin.password": "<bcrypt-hash>"}}'
```

## Idempotence

This role is idempotent:
- Running multiple times will not cause issues
- Existing namespace is reused
- Helm upgrade is used if ArgoCD already deployed
- Use `argocd_force_redeploy: true` to force reinstall

## Removal

```bash
# Remove Helm release
helm uninstall argocd -n argocd

# Remove namespace
kubectl delete namespace argocd
```

## Related Documentation

- **Article 17:** GitOps with ArgoCD
- **Helm Values:** `Kubernetes/manifests/argocd/argocd-values.yaml`
- **GitOps Repository:** `gitops/`
- **ArgoCD Docs:** https://argo-cd.readthedocs.io/

## Version History

- **1.0.0** - Initial release (Phase 6)
  - ArgoCD deployment via Helm
  - Homelab-optimized configuration
  - Traefik ingress integration
  - CLI installation
  - Optional repository configuration
