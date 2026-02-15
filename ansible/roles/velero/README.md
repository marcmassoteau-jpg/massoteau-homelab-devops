# Ansible Role: Velero Backup & Disaster Recovery

Ansible role to deploy Velero on Kubernetes using the official Helm chart with MinIO as S3-compatible backup storage, optimized for homelab environments.

## Description

This role automates the deployment of Velero for Kubernetes backup and disaster recovery. It handles:
- Pre-flight checks (kubectl, Helm, cluster connectivity)
- Namespace creation with appropriate labels
- Helm repository configuration (vmware-tanzu)
- MinIO credentials secret creation
- Velero deployment with AWS plugin for S3 storage
- Velero CLI installation on the control node
- Backup schedule creation (full-cluster, per-namespace)
- BackupStorageLocation verification
- Post-deployment verification

## Requirements

### System Requirements
- Ansible 2.14 or higher
- Python 3.8 or higher

### Kubernetes Cluster Requirements
- Kubernetes v1.24+ (tested on v1.29.15)
- Helm 3 installed on the control node
- MinIO or S3-compatible storage accessible from the cluster
- StorageClass available for persistent volumes

### Control Node Requirements
- `kubectl` configured with cluster access
- `helm` v3 installed
- Network connectivity to Kubernetes cluster
- Internet access for Velero CLI download

## Role Variables

### Core Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `velero_namespace` | `velero` | Kubernetes namespace |
| `velero_release_name` | `velero` | Helm release name |
| `velero_chart_repo` | `https://vmware-tanzu.github.io/helm-charts` | Helm chart repository |
| `velero_chart_name` | `velero` | Helm chart name |
| `velero_chart_version` | `7.2.1` | Velero Helm chart version |
| `velero_aws_plugin_version` | `v1.10.1` | AWS plugin version for S3 |

### MinIO Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `velero_minio_url` | `http://minio.gitlab.svc:9000` | MinIO endpoint URL |
| `velero_minio_bucket` | `velero-backups` | S3 bucket name |
| `velero_minio_region` | `minio` | S3 region |
| `velero_minio_access_key` | `minioadmin` | MinIO access key |
| `velero_minio_secret_key` | `minioadmin` | MinIO secret key |

### Resource Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `velero_cpu_request` | `250m` | Velero server CPU request |
| `velero_cpu_limit` | `1` | Velero server CPU limit |
| `velero_memory_request` | `512Mi` | Velero server memory request |
| `velero_memory_limit` | `1Gi` | Velero server memory limit |

### Backup Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `velero_backup_schedule` | `0 2 * * *` | Default backup cron schedule |
| `velero_retention_days` | `30` | Backup retention in days |
| `velero_default_volumes_to_fs_backup` | `true` | Use filesystem backup for volumes |
| `velero_backup_schedules` | (see defaults) | List of backup schedule definitions |

### Feature Flags

| Variable | Default | Description |
|----------|---------|-------------|
| `velero_create_schedules` | `true` | Create backup schedules |
| `velero_install_cli` | `true` | Install Velero CLI binary |
| `velero_cli_version` | `v1.14.0` | Velero CLI version |

### Deployment Options

| Variable | Default | Description |
|----------|---------|-------------|
| `velero_helm_timeout` | `10m` | Helm deployment timeout |
| `velero_helm_wait` | `true` | Wait for resources ready |
| `velero_force_redeploy` | `false` | Force reinstall |
| `velero_create_namespace` | `true` | Create namespace if missing |
| `velero_wait_for_ready` | `true` | Wait for pods Running |
| `velero_ready_timeout` | `300` | Pod ready timeout (seconds) |

See `defaults/main.yml` for the complete list of configurable variables.

## Dependencies

None. This is a standalone role.

## Example Playbook

### Basic Usage

```yaml
---
- name: Deploy Velero backup on Kubernetes
  hosts: masters
  become: yes
  roles:
    - velero
```

### Custom Configuration

```yaml
---
- name: Deploy Velero with custom settings
  hosts: masters
  become: yes
  vars:
    velero_minio_url: "http://minio.storage.svc:9000"
    velero_minio_access_key: "{{ vault_minio_access_key }}"
    velero_minio_secret_key: "{{ vault_minio_secret_key }}"
    velero_retention_days: 60
    velero_backup_schedule: "0 1 * * *"
  roles:
    - velero
```

### Minimal Deployment (No Schedules)

```yaml
---
- name: Deploy Velero without backup schedules
  hosts: masters
  become: yes
  vars:
    velero_create_schedules: false
    velero_install_cli: false
  roles:
    - velero
```

## Usage

### Initial Deployment

```bash
ansible-playbook playbooks/09-deploy-velero.yml
```

### Upgrade Existing Deployment

```bash
ansible-playbook playbooks/09-deploy-velero.yml \
  -e velero_chart_version=8.0.0
```

### Force Redeployment

```bash
ansible-playbook playbooks/09-deploy-velero.yml \
  -e velero_force_redeploy=true
```

### Custom MinIO Credentials

```bash
ansible-playbook playbooks/09-deploy-velero.yml \
  -e velero_minio_access_key=mykey \
  -e velero_minio_secret_key=mysecret
```

## Post-Deployment

After successful deployment, the role displays:
- Velero server and plugin versions
- Backup storage endpoint and status
- Configured backup schedules
- Useful Velero CLI commands

### Create a Test Backup

```bash
# Create an on-demand backup
velero backup create test-backup --include-namespaces default

# Check backup status
velero backup get

# View backup details
velero backup describe test-backup

# View backup logs
velero backup logs test-backup
```

### Restore from Backup

```bash
# List available backups
velero backup get

# Restore entire backup
velero restore create --from-backup test-backup

# Restore specific namespace
velero restore create --from-backup full-cluster-daily-20240101020000 \
  --include-namespaces gitlab

# Check restore status
velero restore get
velero restore describe <restore-name>
```

### Manage Schedules

```bash
# List schedules
velero schedule get

# Describe a schedule
velero schedule describe full-cluster-daily

# Trigger a schedule manually
velero backup create --from-schedule full-cluster-daily

# Pause a schedule
kubectl patch schedule full-cluster-daily -n velero \
  --type merge -p '{"spec":{"paused":true}}'
```

### Verify Deployment

```bash
# Check all pods are Running
kubectl get pods -n velero

# Check BackupStorageLocation
velero backup-location get

# Check backup schedules
velero schedule get

# Check recent backups
velero backup get

# Check Velero server logs
kubectl logs deployment/velero -n velero
```

## Troubleshooting

### BackupStorageLocation Not Available

```bash
# Check BSL status
velero backup-location get
kubectl describe backupstoragelocation default -n velero

# Verify MinIO connectivity
kubectl run minio-test --image=busybox --rm -it --restart=Never -- \
  wget -qO- http://minio.gitlab.svc:9000/minio/health/live

# Check Velero logs for S3 errors
kubectl logs deployment/velero -n velero | grep -i error
```

### Backups Failing

```bash
# Check backup status
velero backup describe <backup-name> --details

# View backup logs
velero backup logs <backup-name>

# Check if node agent is running (for volume backups)
kubectl get pods -n velero -l name=node-agent
```

### Velero CLI Not Connecting

```bash
# Verify Velero server is running
kubectl get deployment velero -n velero

# Check Velero API connectivity
velero version

# Use kubectl directly
kubectl get backups -n velero
kubectl get schedules -n velero
```

### Deployment Timeout

- Increase timeout: `-e velero_helm_timeout=15m`
- Check cluster resources: `kubectl top nodes`
- Monitor pod logs: `kubectl logs -n velero -l app.kubernetes.io/name=velero`

## Idempotence

This role is idempotent:
- Running multiple times will not cause issues
- Existing namespace is reused
- Helm upgrade is used if Velero is already deployed
- Backup schedules use `kubectl apply`
- Credentials secret is recreated on each run
- Use `velero_force_redeploy: true` to force reinstall

## Removal

```bash
# Remove backup schedules
velero schedule delete --all --confirm

# Remove Helm release
helm uninstall velero -n velero

# Remove CRDs (optional - removes all Velero CRDs)
kubectl delete crd backups.velero.io
kubectl delete crd backupstoragelocations.velero.io
kubectl delete crd deletebackuprequests.velero.io
kubectl delete crd downloadrequests.velero.io
kubectl delete crd podvolumebackups.velero.io
kubectl delete crd podvolumerestores.velero.io
kubectl delete crd restores.velero.io
kubectl delete crd schedules.velero.io
kubectl delete crd serverstatusrequests.velero.io
kubectl delete crd volumesnapshotlocations.velero.io

# Remove namespace
kubectl delete namespace velero
```

## Related Documentation

- **Article 20:** Backup & Disaster Recovery with Velero
- **Velero Docs:** https://velero.io/docs/
- **Velero Helm Chart:** https://github.com/vmware-tanzu/helm-charts/tree/main/charts/velero
- **MinIO Docs:** https://min.io/docs/minio/kubernetes/upstream/

## Version History

- **1.0.0** - Initial release (Phase 8)
  - Velero deployment via Helm with MinIO backend
  - AWS plugin for S3-compatible storage
  - Automated backup schedule creation
  - Velero CLI installation
  - Full-cluster and per-namespace backup schedules
  - BackupStorageLocation verification
