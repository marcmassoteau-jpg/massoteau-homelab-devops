# Ansible Role: Jenkins

Ansible role to deploy Jenkins on Kubernetes using the official Helm chart for CI/CD automation, optimized for homelab environments with Kubernetes plugin support.

## Description

This role automates the deployment of Jenkins on an existing Kubernetes cluster. It handles:
- Pre-flight checks (kubectl, Helm, cluster connectivity)
- Namespace creation
- Helm repository configuration
- Jenkins deployment via Helm chart with Configuration as Code (JCasC)
- Kubernetes plugin configuration for dynamic agent provisioning
- Jenkins CLI installation
- Post-deployment verification
- Optional GitLab integration
- Optional shared library configuration
- Traefik IngressRoute setup

## Requirements

### System Requirements
- Ansible 2.14 or higher
- Python 3.8 or higher

### Kubernetes Cluster Requirements
- Kubernetes v1.24+ (tested on v1.29.15)
- Helm 3 installed on the control node
- Minimum resources available:
  - 4GB RAM
  - 2 CPU cores
  - 20GB storage
- Traefik ingress controller (recommended)

### Control Node Requirements
- `kubectl` configured with cluster access
- `helm` v3 installed
- Network connectivity to Kubernetes cluster
- Java Runtime (for CLI operations, optional)

## Role Variables

### Core Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `jenkins_namespace` | `jenkins` | Kubernetes namespace |
| `jenkins_release_name` | `jenkins` | Helm release name |
| `jenkins_chart_version` | `5.7.18` | Helm chart version |
| `jenkins_domain` | `jenkins.homelab.local` | Jenkins web UI domain |

### Controller Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `jenkins_controller_image` | `jenkins/jenkins` | Controller Docker image |
| `jenkins_controller_tag` | `2.479-jdk17` | Controller image tag |
| `jenkins_admin_user` | `admin` | Admin username |
| `jenkins_admin_password` | *(auto-generated)* | Admin password |
| `jenkins_controller_executors` | `0` | Executors on controller |
| `jenkins_java_opts` | `-Xmx1536m ...` | Java JVM options |

### Resource Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `jenkins_controller_cpu_request` | `500m` | Controller CPU request |
| `jenkins_controller_memory_limit` | `2Gi` | Controller memory limit |
| `jenkins_agent_cpu_request` | `200m` | Agent CPU request |
| `jenkins_agent_memory_limit` | `1Gi` | Agent memory limit |

### Storage Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `jenkins_persistence_enabled` | `true` | Enable persistent storage |
| `jenkins_persistence_size` | `20Gi` | PVC size |
| `jenkins_persistence_storageclass` | `local-path` | Storage class |

### Plugins Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `jenkins_install_plugins` | `true` | Install plugins on deployment |
| `jenkins_plugins` | *(see defaults)* | List of plugins to install |

Essential plugins installed by default:
- `kubernetes` - Kubernetes plugin for dynamic agents
- `workflow-aggregator` - Pipeline plugin suite
- `git` - Git SCM integration
- `configuration-as-code` - JCasC support
- `credentials-binding` - Credentials management
- `blueocean` - Modern UI
- `job-dsl` - Job DSL plugin
- `docker-workflow` - Docker pipeline support
- `prometheus` - Metrics export

See `defaults/main.yml` for complete list of configurable variables.

### Feature Flags

| Variable | Default | Description |
|----------|---------|-------------|
| `jenkins_jcasc_enabled` | `true` | Enable Configuration as Code |
| `jenkins_kubernetes_plugin_enabled` | `true` | Enable Kubernetes plugin |
| `jenkins_pod_templates_enabled` | `true` | Create default pod templates |
| `jenkins_metrics_enabled` | `true` | Enable Prometheus metrics |
| `jenkins_servicemonitor_enabled` | `false` | Enable ServiceMonitor CRD |
| `jenkins_install_cli` | `true` | Install Jenkins CLI |

### Deployment Options

| Variable | Default | Description |
|----------|---------|-------------|
| `jenkins_helm_timeout` | `10m` | Helm deployment timeout |
| `jenkins_helm_wait` | `true` | Wait for resources ready |
| `jenkins_force_redeploy` | `false` | Force reinstall |
| `jenkins_wait_for_ready` | `true` | Wait for pods Running |
| `jenkins_ready_timeout` | `300` | Pod ready timeout (seconds) |

### GitLab Integration (Optional)

| Variable | Default | Description |
|----------|---------|-------------|
| `jenkins_configure_gitlab` | `false` | Configure GitLab integration |
| `jenkins_gitlab_url` | `http://gitlab.homelab.local:30080` | GitLab URL |
| `jenkins_gitlab_api_token` | *(unset)* | GitLab API token |
| `jenkins_gitlab_connection_name` | `homelab-gitlab` | Connection name |

### Shared Library (Optional)

| Variable | Default | Description |
|----------|---------|-------------|
| `jenkins_configure_shared_library` | `false` | Configure shared library |
| `jenkins_shared_library_name` | `jenkins-shared-library` | Library name |
| `jenkins_shared_library_repo` | *(see defaults)* | Library repository URL |
| `jenkins_shared_library_default_version` | `main` | Default branch/tag |

## Dependencies

None. This is a standalone role.

## Example Playbook

### Basic Usage

```yaml
---
- name: Deploy Jenkins on Kubernetes
  hosts: masters
  become: yes
  roles:
    - jenkins
```

### Custom Configuration

```yaml
---
- name: Deploy Jenkins with custom settings
  hosts: masters
  become: yes
  vars:
    jenkins_domain: ci.example.com
    jenkins_controller_memory_limit: 4Gi
    jenkins_persistence_size: 50Gi
    jenkins_admin_password: "{{ vault_jenkins_password }}"
  roles:
    - jenkins
```

### With GitLab Integration

```yaml
---
- name: Deploy Jenkins with GitLab integration
  hosts: masters
  become: yes
  vars:
    jenkins_configure_gitlab: true
    jenkins_gitlab_url: http://gitlab.homelab.local:30080
    jenkins_gitlab_api_token: "{{ vault_gitlab_token }}"
    jenkins_configure_shared_library: true
  roles:
    - jenkins
```

### High Availability Configuration

```yaml
---
- name: Deploy Jenkins HA
  hosts: masters
  become: yes
  vars:
    jenkins_controller_cpu_request: "1"
    jenkins_controller_cpu_limit: "4"
    jenkins_controller_memory_request: "2Gi"
    jenkins_controller_memory_limit: "8Gi"
    jenkins_persistence_size: 100Gi
  roles:
    - jenkins
```

## Usage

### Initial Deployment

```bash
ansible-playbook playbooks/05-deploy-jenkins.yml
```

### Upgrade Existing Deployment

```bash
ansible-playbook playbooks/05-deploy-jenkins.yml \
  -e jenkins_chart_version=5.8.0
```

### Force Redeployment

```bash
ansible-playbook playbooks/05-deploy-jenkins.yml \
  -e jenkins_force_redeploy=true
```

### Custom Domain

```bash
ansible-playbook playbooks/05-deploy-jenkins.yml \
  -e jenkins_domain=ci.mydomain.com
```

### With Specific Admin Password

```bash
ansible-playbook playbooks/05-deploy-jenkins.yml \
  -e jenkins_admin_password=mySecurePassword123
```

## Post-Deployment

After successful deployment, the role displays:
- Jenkins web UI URL
- Admin username
- Admin password (auto-generated or specified)
- CLI usage examples

### Access Jenkins

1. Navigate to `http://jenkins.homelab.local`
2. Login with username `admin` and the displayed password
3. **Important:** Store the admin password securely

### Verify Deployment

```bash
# Check all pods are Running
kubectl get pods -n jenkins

# Check services
kubectl get svc -n jenkins

# Check ingress
kubectl get ingress -n jenkins

# Check PVC
kubectl get pvc -n jenkins

# View logs
kubectl logs -n jenkins deployment/jenkins -f
```

### Test Kubernetes Plugin

1. Create a new Pipeline job
2. Use this test pipeline:

```groovy
pipeline {
    agent {
        kubernetes {
            yaml '''
apiVersion: v1
kind: Pod
spec:
  containers:
  - name: shell
    image: ubuntu
    command:
    - sleep
    args:
    - infinity
'''
        }
    }
    stages {
        stage('Test') {
            steps {
                container('shell') {
                    sh 'echo "Hello from Kubernetes!"'
                    sh 'hostname'
                }
            }
        }
    }
}
```

3. Run the job - it should create a pod dynamically

### Configure GitLab Integration (Manual)

If not configured via role variables:

1. Install GitLab plugin (if not auto-installed)
2. Manage Jenkins → Configure System → GitLab
3. Add GitLab server connection
4. Configure webhooks in GitLab projects

## Troubleshooting

### Pods Stuck in Pending

```bash
kubectl describe pod -n jenkins <pod-name>
kubectl top nodes
```

Check for:
- Insufficient resources
- Storage provisioner issues
- Node selectors/taints

### Deployment Timeout

- Increase timeout: `-e jenkins_helm_timeout=15m`
- Check cluster resources
- Monitor pod logs: `kubectl logs -n jenkins <pod-name> -f`

### UI Not Accessible

```bash
# Port-forward for direct access
kubectl port-forward -n jenkins svc/jenkins 8080:8080

# Check ingress
kubectl get ingress -n jenkins
kubectl describe ingress -n jenkins jenkins-server

# Check Traefik logs
kubectl logs -n kube-system -l app.kubernetes.io/name=traefik
```

### Agent Pods Not Starting

```bash
# Check RBAC
kubectl get rolebinding -n jenkins
kubectl get serviceaccount -n jenkins

# Check pod events
kubectl get events -n jenkins --sort-by='.lastTimestamp'

# Verify Kubernetes plugin config
# Manage Jenkins → Configure System → Cloud → Kubernetes
```

### Plugin Installation Issues

```bash
# Check plugin manager logs
kubectl logs -n jenkins deployment/jenkins | grep -i plugin

# List installed plugins
kubectl exec -n jenkins deployment/jenkins -- \
  java -jar /usr/share/jenkins/jenkins.war -s list-plugins
```

### Persistence Issues

```bash
# Check PVC status
kubectl get pvc -n jenkins
kubectl describe pvc -n jenkins jenkins

# Check storage class
kubectl get storageclass

# Verify mount
kubectl exec -n jenkins deployment/jenkins -- df -h /var/jenkins_home
```

## Configuration as Code (JCasC)

The role uses JCasC to configure Jenkins automatically. Configuration includes:
- Security realm (local users)
- Authorization strategy
- Kubernetes cloud configuration
- Pod templates for different build environments
- System message and build retention
- Optional GitLab integration
- Optional shared library

To modify JCasC configuration, edit the Helm values template in `tasks/main.yml`.

## Kubernetes Plugin Pod Templates

Default pod templates created:
- **default-agent**: Generic JNLP agent for any pipeline
- **maven-agent**: Maven builds (label: `maven`)
- **python-agent**: Python builds (label: `python`)

Usage in Jenkinsfile:

```groovy
pipeline {
    agent {
        label 'maven'  // or 'python'
    }
    stages {
        stage('Build') {
            steps {
                sh 'mvn clean package'
            }
        }
    }
}
```

## Security Considerations

1. **Change default admin password** after first login
2. **Use Kubernetes secrets** for sensitive credentials
3. **Enable RBAC** on the cluster
4. **Configure TLS** for production (set `jenkins_tls_enabled: true`)
5. **Limit controller executors** to 0 (use agents only)
6. **Enable CSRF protection** (enabled by default)
7. **Use approved script security** (enabled by default)

## Backup and Recovery

### Manual Backup

```bash
# Backup Jenkins home directory
kubectl exec -n jenkins deployment/jenkins -- tar czf /tmp/jenkins-backup.tar.gz /var/jenkins_home

# Copy from pod
kubectl cp jenkins/jenkins:/tmp/jenkins-backup.tar.gz ./jenkins-backup-$(date +%Y%m%d).tar.gz
```

### Restore from Backup

```bash
# Copy to pod
kubectl cp ./jenkins-backup.tar.gz jenkins/jenkins:/tmp/jenkins-backup.tar.gz

# Extract
kubectl exec -n jenkins deployment/jenkins -- tar xzf /tmp/jenkins-backup.tar.gz -C /
kubectl rollout restart deployment/jenkins -n jenkins
```

## Idempotence

This role is idempotent:
- Running multiple times will not cause issues
- Existing namespace is reused
- Helm upgrade is used if Jenkins already deployed
- Use `jenkins_force_redeploy: true` to force reinstall

## Removal

```bash
# Remove Helm release
helm uninstall jenkins -n jenkins

# Remove PVC (if desired)
kubectl delete pvc jenkins -n jenkins

# Remove namespace
kubectl delete namespace jenkins
```

## Performance Tuning

### For Large Workloads

```yaml
jenkins_controller_memory_limit: 8Gi
jenkins_java_opts: "-Xmx6g -XX:MaxRAM=8g"
jenkins_persistence_size: 100Gi
```

### For Resource-Constrained Environments

```yaml
jenkins_controller_cpu_request: "250m"
jenkins_controller_memory_limit: 1Gi
jenkins_java_opts: "-Xmx768m"
jenkins_agent_memory_limit: 512Mi
```

## Related Documentation

- **Article 15:** CI/CD with Jenkins
- **GitOps Workflow:** `examples/gitops-workflow/Jenkinsfile`
- **Jenkins Docs:** https://www.jenkins.io/doc/
- **Kubernetes Plugin:** https://plugins.jenkins.io/kubernetes/

## Version History

- **1.0.0** - Initial release (Phase 5)
  - Jenkins deployment via Helm
  - Kubernetes plugin with dynamic agents
  - JCasC configuration
  - Homelab-optimized settings
  - Traefik ingress integration
  - CLI installation
  - Optional GitLab integration
  - Default pod templates (maven, python)
