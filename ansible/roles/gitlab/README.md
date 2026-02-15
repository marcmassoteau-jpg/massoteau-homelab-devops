# Ansible Role: GitLab

Ansible role to deploy GitLab Community Edition on Kubernetes using the official Helm chart, optimized for homelab environments.

## Description

This role automates the deployment of GitLab on an existing Kubernetes cluster. It handles:
- Pre-flight checks (kubectl, Helm, cluster connectivity)
- Namespace creation with ResourceQuota
- Helm repository configuration
- GitLab deployment via Helm chart
- Post-deployment verification
- Access information display

## Requirements

### System Requirements
- Ansible 2.14 or higher
- Python 3.8 or higher
- `kubernetes.core` Ansible collection

### Kubernetes Cluster Requirements
- Kubernetes v1.24+ (tested on v1.29.15)
- Helm 3 installed on the control node
- Storage class available (default: `local-path`)
- Minimum resources:
  - 8GB RAM available
  - 4 CPU cores available
  - 120GB storage available
- Ingress controller (Traefik recommended)

### Control Node Requirements
- `kubectl` configured with cluster access
- `helm` v3 installed
- Network connectivity to Kubernetes cluster

## Role Variables

### Core Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `gitlab_namespace` | `gitlab` | Kubernetes namespace for GitLab |
| `gitlab_release_name` | `gitlab` | Helm release name |
| `gitlab_chart_version` | `7.7.0` | GitLab Helm chart version |
| `gitlab_edition` | `ce` | GitLab edition (ce or ee) |

### Domain Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `gitlab_domain` | `gitlab.homelab.local` | GitLab web UI domain |
| `gitlab_registry_domain` | `registry.gitlab.homelab.local` | Container registry domain |
| `gitlab_minio_domain` | `minio.gitlab.homelab.local` | MinIO console domain |

### Resource Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `gitlab_webservice_cpu_request` | `500m` | Webservice CPU request |
| `gitlab_webservice_cpu_limit` | `2` | Webservice CPU limit |
| `gitlab_webservice_memory_request` | `2Gi` | Webservice memory request |
| `gitlab_webservice_memory_limit` | `4Gi` | Webservice memory limit |
| `gitlab_postgresql_storage_size` | `10Gi` | PostgreSQL PVC size |
| `gitlab_redis_storage_size` | `5Gi` | Redis PVC size |
| `gitlab_gitaly_storage_size` | `50Gi` | Git repository storage size |
| `gitlab_minio_storage_size` | `50Gi` | Object storage size |

See `defaults/main.yml` for complete list of configurable variables.

### Storage Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `gitlab_storage_class` | `local-path` | Kubernetes StorageClass name |

### Feature Flags

| Variable | Default | Description |
|----------|---------|-------------|
| `gitlab_registry_enabled` | `true` | Enable container registry |
| `gitlab_minio_enabled` | `true` | Enable bundled MinIO |
| `gitlab_tls_enabled` | `false` | Enable TLS/HTTPS |
| `gitlab_certmanager_enabled` | `false` | Enable cert-manager integration |

### Deployment Options

| Variable | Default | Description |
|----------|---------|-------------|
| `gitlab_helm_timeout` | `15m` | Helm deployment timeout |
| `gitlab_helm_wait` | `true` | Wait for resources to be ready |
| `gitlab_force_redeploy` | `false` | Force reinstall if already deployed |
| `gitlab_wait_for_ready` | `true` | Wait for pods to be Running |
| `gitlab_ready_timeout` | `900` | Pod ready timeout (seconds) |
| `gitlab_show_access_info` | `true` | Display access info after deployment |
| `gitlab_verify_health` | `true` | Verify health endpoint |

## Dependencies

None. This is a standalone role.

## Example Playbook

### Basic Usage

```yaml
---
- name: Deploy GitLab on Kubernetes
  hosts: masters
  become: yes
  roles:
    - gitlab
```

### Custom Configuration

```yaml
---
- name: Deploy GitLab with custom settings
  hosts: masters
  become: yes
  vars:
    gitlab_domain: git.example.com
    gitlab_storage_class: nfs-client
    gitlab_webservice_memory_limit: 6Gi
    gitlab_gitaly_storage_size: 100Gi
  roles:
    - gitlab
```

### Production Configuration

```yaml
---
- name: Deploy GitLab for production
  hosts: masters
  become: yes
  vars:
    gitlab_edition: ee
    gitlab_tls_enabled: true
    gitlab_certmanager_enabled: true
    gitlab_webservice_replicas: 2
    gitlab_sidekiq_replicas: 2
  roles:
    - gitlab
```

## Usage

### Initial Deployment

```bash
# From ansible directory
ansible-playbook playbooks/05-deploy-gitlab.yml
```

### Upgrade Existing Deployment

```bash
# Upgrade to new chart version
ansible-playbook playbooks/05-deploy-gitlab.yml \
  -e gitlab_chart_version=7.8.0
```

### Force Redeployment

```bash
# Force reinstall (careful - may cause downtime)
ansible-playbook playbooks/05-deploy-gitlab.yml \
  -e gitlab_force_redeploy=true
```

### Custom Domain

```bash
ansible-playbook playbooks/05-deploy-gitlab.yml \
  -e gitlab_domain=git.mydomain.com \
  -e gitlab_registry_domain=registry.mydomain.com
```

## Post-Deployment

After successful deployment, the role displays:
- GitLab web UI URL
- Initial root password
- Container registry URL
- MinIO console URL

### Access GitLab

1. Navigate to the URL shown (default: `http://gitlab.homelab.local:30080`)
2. Login with username `root` and the displayed password
3. **Important:** Change the root password immediately

### Verify Deployment

```bash
# Check all pods are Running
kubectl get pods -n gitlab

# Check services
kubectl get svc -n gitlab

# Check PVCs are Bound
kubectl get pvc -n gitlab

# Check health endpoint
curl http://gitlab.homelab.local:30080/-/health
```

## Customization

### Override Resource Limits

Create a vars file `gitlab-custom.yml`:

```yaml
---
gitlab_webservice_memory_limit: 6Gi
gitlab_postgresql_storage_size: 20Gi
gitlab_gitaly_storage_size: 200Gi
```

Use in playbook:

```bash
ansible-playbook playbooks/05-deploy-gitlab.yml \
  -e @gitlab-custom.yml
```

### Configure External Storage Class

If using NFS or other storage:

```yaml
gitlab_storage_class: nfs-client
```

## Troubleshooting

### Pods Stuck in Pending

**Symptoms:** Pods remain in `Pending` state after deployment.

**Common Causes:**
- Insufficient cluster resources
- Storage class not available
- PVC not binding

**Solutions:**

```bash
# Check pod events
kubectl describe pod <pod-name> -n gitlab

# Check PVC status
kubectl get pvc -n gitlab

# Check storage class
kubectl get storageclass

# Check node resources
kubectl top nodes
```

### Deployment Timeout

**Symptoms:** Helm deployment times out after 15 minutes.

**Solutions:**
- Increase timeout: `-e gitlab_helm_timeout=20m`
- Check cluster resources
- Monitor pod logs: `kubectl logs -n gitlab <pod-name>`

### Health Check Fails

**Symptoms:** Health endpoint verification fails.

**Solutions:**
- Wait longer for GitLab to start (can take 15-20 minutes)
- Check webservice pod logs
- Verify ingress configuration
- Test direct service access: `kubectl port-forward -n gitlab svc/gitlab-webservice-default 8080:8181`

### Storage Issues

**Symptoms:** PVCs stuck in `Pending` state.

**Solutions:**

```bash
# Verify storage class exists
kubectl get storageclass gitlab_storage_class

# Check provisioner logs
kubectl logs -n kube-system -l app=local-path-provisioner

# Check node disk space
df -h
```

## Files Generated

During deployment, the role creates temporary files:

- `/tmp/gitlab-namespace.yaml` - Namespace definition
- `/tmp/gitlab-resource-quota.yaml` - ResourceQuota
- `/tmp/gitlab-values.yaml` - Helm values (from template)

These can be reviewed for troubleshooting.

## Integration

### With Terraform

This role is designed to work with the existing Terraform/Ansible automation:

```bash
# After Terraform provisions VMs
cd ansible
ansible-playbook playbooks/04-install-kubernetes.yml  # Phase 3
ansible-playbook playbooks/05-deploy-gitlab.yml       # Phase 4
```

### With GitLab Runner

After GitLab is deployed, deploy the Runner (Phase 4, Article 14):

```yaml
---
- name: Deploy GitLab Runner
  hosts: masters
  become: yes
  roles:
    - gitlab-runner  # Future role
```

## Idempotence

This role is idempotent:
- Running multiple times will not cause issues
- Existing namespace is reused
- Helm upgrade is used if GitLab already deployed
- Use `gitlab_force_redeploy: true` to force reinstall

## Security Considerations

1. **Change default passwords** immediately after deployment
2. **Enable TLS** for production use (set `gitlab_tls_enabled: true`)
3. **Use cert-manager** for automatic certificate management
4. **Enable RBAC** (enabled by default)
5. **Use secrets** for sensitive data (auto-generated by Helm)
6. **Regular backups** - configure backup automation
7. **Update regularly** - keep GitLab chart version current

## Performance Tuning

For larger homelab clusters:

```yaml
# Increase resources
gitlab_webservice_replicas: 2
gitlab_sidekiq_replicas: 2
gitlab_webservice_memory_limit: 8Gi

# Increase storage
gitlab_gitaly_storage_size: 200Gi
gitlab_minio_storage_size: 100Gi
```

For smaller clusters:

```yaml
# Reduce resources
gitlab_webservice_memory_limit: 3Gi
gitlab_sidekiq_memory_limit: 1Gi
gitlab_postgresql_memory_limit: 768Mi
```

## Backup and Recovery

### Manual Backup

```bash
# Exec into webservice pod
kubectl exec -n gitlab -it <webservice-pod> -- gitlab-backup create

# Backups stored in MinIO bucket: gitlab-backups
```

### Automated Backups

Future enhancement: CronJob for scheduled backups.

## Removal

To uninstall GitLab:

```bash
# Remove Helm release (preserves PVCs)
helm uninstall gitlab -n gitlab

# Remove namespace and all resources
kubectl delete namespace gitlab
```

**Warning:** This deletes all GitLab data!

## License

MIT

## Author

Part of Kubernetes Homelab Automation project.

## Related Documentation

- **Article 13:** GitLab Deployment on Kubernetes with Helm
- **Article 14:** GitLab CI/CD: Runners and Container Registry
- **GitLab Chart:** https://docs.gitlab.com/charts/
- **Project Repo:** https://github.com/yourusername/kubernetes-homelab

## Version History

- **1.0.0** - Initial release (Phase 4)
  - GitLab CE deployment
  - Homelab optimized configuration
  - Comprehensive pre/post checks
  - Full documentation
