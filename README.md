# Homelab DevOps Pipeline

> Complete automation for building a production-grade Kubernetes cluster on Proxmox using Infrastructure as Code

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-1.29-blue.svg)](https://kubernetes.io/)
[![Proxmox](https://img.shields.io/badge/Proxmox-VE%208.x-orange.svg)](https://www.proxmox.com/)

This repository contains **production-ready automation code** for deploying and managing a complete Kubernetes homelab environment. All code is tested and documented in the companion [Medium article series](https://medium.com/@marcmassoteau).

## What's Included

- **Terraform Infrastructure**: Infrastructure as Code for Proxmox VM provisioning
- **Ansible Playbooks**: Automated configuration management for Kubernetes nodes (10 playbooks)
- **Integration Scripts**: One-command cluster deployment (Terraform + Ansible)
- **GitLab Platform**: Self-hosted Git repository and container registry on Kubernetes
- **Jenkins CI/CD**: Automated build, test, and deployment pipelines with shared libraries
- **Pipeline Templates**: Reusable Jenkins shared libraries and GitLab CI templates
- **Deployment Strategies**: Blue-green and canary deployments with automated rollback
- **GitOps with ArgoCD**: Declarative deployments with self-healing and drift detection
- **GitOps Repository**: Kustomize-based multi-environment management (dev/staging/prod)
- **Monitoring Stack**: Prometheus, Grafana dashboards, Loki log aggregation, and alerting
- **Backup & Recovery**: Velero with MinIO, etcd snapshots, and multi-layer disaster recovery
- **Cluster Autoscaling**: Dynamic worker node provisioning with Proxmox API integration
- **Troubleshooting**: Diagnostic scripts, troubleshooting guides, and production readiness assessments
- **Examples**: Sample applications, CI/CD pipelines, and GitOps workflow demos

## Infrastructure Overview

```
Proxmox Host (192.168.1.222)
    └── Kubernetes Cluster (5 VMs)
        ├── k8s-master (192.168.1.240)
        │   └── 4 vCPU / 8GB RAM / 100GB Disk
        └── k8s-worker-01 to 04 (192.168.1.241-244)
            └── 4 vCPU / 16GB RAM / 200GB Disk each

Services (via Traefik on NodePort 30080):
    ├── grafana.homelab.local     - Metrics dashboards & log viewer
    ├── prometheus.homelab.local  - Metrics collection & alerting
    ├── alertmanager.homelab.local - Alert routing & notification
    ├── gitlab.homelab.local      - Source control & container registry
    ├── jenkins.homelab.local     - CI/CD automation
    ├── argocd.homelab.local      - GitOps deployment
    ├── dashboard.homelab.local   - Kubernetes Dashboard
    └── traefik.homelab.local     - Ingress controller dashboard
```

## Quick Start

### Prerequisites

**Infrastructure:**
- Proxmox VE 8.x host
- 5 Ubuntu 22.04 VMs created from cloud image
- Static IP addresses configured
- SSH access from your workstation to all nodes

**Local Tools:**
- [Terraform](https://www.terraform.io/downloads) 1.5+ (for infrastructure provisioning)
- [Ansible](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html) 2.14+ (for configuration management)
- SSH key pair for passwordless authentication

### Quick Installation (Automated)

Deploy the complete cluster with a single script:

```bash
# Clone repository
git clone https://github.com/marcmassoteau-jpg/massoteau-homelab-devops.git
cd massoteau-homelab-devops

# Configure Terraform
cd terraform/proxmox-vms
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars  # Add your Proxmox API token and SSH key

# Run complete automation
cd ../..
./scripts/automation/provision-cluster.sh
```

This script:
1. Creates 5 VMs on Proxmox with Terraform
2. Waits for VMs to boot and cloud-init to complete
3. Runs all Ansible playbooks sequentially
4. Verifies cluster health
5. Provides connection details

### Manual Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/marcmassoteau-jpg/massoteau-homelab-devops.git
   cd massoteau-homelab-devops
   ```

2. **Install Ansible collections:**
   ```bash
   ansible-galaxy collection install community.general
   ansible-galaxy collection install ansible.posix
   ```

3. **Configure inventory:**
   ```bash
   cd ansible
   cp inventory/hosts.ini.example inventory/hosts.ini
   cp inventory/group_vars/all.yml.example inventory/group_vars/all.yml
   ```

   Edit `inventory/hosts.ini` and update:
   - Node IP addresses (if different)
   - SSH key path
   - Username (if not `ubuntu`)

4. **Test connectivity:**
   ```bash
   ansible all -m ping
   ```

5. **Run playbooks:**
   ```bash
   ansible-playbook playbooks/01-network-setup.yml
   ansible-playbook playbooks/02-security-hardening.yml
   ansible-playbook playbooks/03-kubernetes-prereqs.yml
   ansible-playbook playbooks/04-install-kubernetes.yml
   ansible-playbook playbooks/05-deploy-gitlab.yml
   ansible-playbook playbooks/06-deploy-argocd.yml
   ansible-playbook playbooks/07-deploy-jenkins.yml
   ansible-playbook playbooks/08-deploy-monitoring.yml
   ansible-playbook playbooks/09-deploy-velero.yml
   ansible-playbook playbooks/10-deploy-cluster-autoscaler.yml
   ```

## Documentation

### Setup Guides

- **[Terraform Setup](terraform/docs/terraform-setup.md)**: Complete Terraform installation and configuration
- **[Terraform README](terraform/proxmox-vms/README.md)**: Proxmox VM provisioning guide
- **[Getting Started](docs/setup-guides/getting-started.md)**: Complete setup guide
- **[Ansible Playbooks](docs/setup-guides/ansible-playbooks.md)**: How to use playbooks

### Architecture & Guides

- **[GitOps Architecture](docs/architecture/gitops-architecture.md)**: GitOps deployment architecture
- **[CI/CD vs GitOps](docs/comparisons/cicd-vs-gitops.md)**: Comparison and decision framework
- **[Production Readiness](docs/checklists/production-readiness.md)**: Production readiness checklist
- **[Security Audit](docs/checklists/security-audit.md)**: Security audit checklist

### Troubleshooting

- **[Networking Issues](docs/troubleshooting/networking-issues.md)**: DNS, pod connectivity, ingress
- **[Storage Issues](docs/troubleshooting/storage-issues.md)**: PV/PVC troubleshooting
- **[Certificate Issues](docs/troubleshooting/certificate-issues.md)**: TLS and kubeadm certs
- **[Common Errors](docs/troubleshooting/common-errors.md)**: Frequent Kubernetes errors
- **[Pod Scheduling](docs/troubleshooting/pod-scheduling.md)**: Scheduling failures
- **[Performance Guide](docs/troubleshooting/performance-guide.md)**: Performance optimization

### Article Series

This project is documented in a 22-article [Medium series](https://medium.com/@marcmassoteau) covering:

| Phase | Articles | Topics |
|-------|----------|--------|
| **1-2: Foundation** | 1-9 | Proxmox, networking, security, Kubernetes setup |
| **3: IaC** | 10-12 | Terraform, Ansible, integration pipeline |
| **4: CI/CD** | 13-14 | GitLab deployment, Jenkins pipelines |
| **5: Advanced CI/CD** | 15-16 | Pipeline templates, deployment strategies |
| **6: GitOps** | 17 | ArgoCD, Kustomize, multi-environment |
| **7: Observability** | 18 | Prometheus, Grafana, Loki, alerting |
| **8: Operations** | 19-21 | Disaster recovery, troubleshooting, production readiness |
| **9: Autoscaling** | 22 | Custom Proxmox-based cluster autoscaler |

## Project Structure

```
.
├── terraform/                  # Terraform Infrastructure as Code
│   ├── proxmox-vms/            # VM provisioning configuration
│   ├── modules/                # Reusable Terraform modules
│   │   ├── k8s-node/           # Standard K8s node module
│   │   └── k8s-autoscale-node/ # Auto-join node module
│   └── docs/                   # Terraform documentation
├── ansible/                    # Ansible configuration management
│   ├── inventory/              # Inventory and variables
│   ├── playbooks/              # Automation playbooks (01-10)
│   └── roles/                  # Reusable roles
│       ├── gitlab/             # GitLab CE deployment
│       ├── jenkins/            # Jenkins CI/CD
│       ├── argocd/             # ArgoCD GitOps
│       ├── monitoring/         # Prometheus + Grafana + Loki
│       ├── velero/             # Backup & restore
│       └── cluster-autoscaler/ # Proxmox autoscaler
├── gitops/                     # GitOps repository (ArgoCD)
│   ├── applications/           # ArgoCD Application manifests
│   ├── base/                   # Base Kustomize manifests
│   ├── environments/           # Per-environment overlays (dev/staging/prod)
│   └── scripts/                # GitOps automation scripts
├── scripts/                    # Operational scripts
│   ├── automation/             # Integration scripts (provision-cluster.sh)
│   ├── assessment/             # Production readiness & security audits
│   ├── autoscaling/            # Proxmox node provisioner & scaling tests
│   ├── backup/                 # etcd backup/restore & Velero status
│   ├── troubleshooting/        # Cluster diagnostic scripts
│   ├── proxmox/                # VM management
│   └── network/                # Network testing
├── examples/                   # Sample applications and workflows
│   ├── cicd-templates/         # GitLab CI & Jenkins templates
│   ├── deployment-strategies/  # Blue-green and canary examples
│   └── gitops-workflow/        # Hybrid CI/CD + GitOps example
└── docs/                       # Documentation
    ├── architecture/           # Architecture documentation
    ├── checklists/             # Production & security checklists
    ├── comparisons/            # Technology comparisons
    ├── templates/              # Assessment templates
    ├── troubleshooting/        # Troubleshooting guides
    └── setup-guides/           # Setup and usage guides
```

## Usage Examples

### Service Access

All services are accessible via Traefik on NodePort 30080. Add to your `/etc/hosts`:

```
192.168.1.240  grafana.homelab.local prometheus.homelab.local alertmanager.homelab.local argocd.homelab.local gitlab.homelab.local dashboard.homelab.local traefik.homelab.local jenkins.homelab.local
```

### Retrieve Service Credentials

```bash
# Grafana (default: admin/admin)
kubectl get secret -n monitoring kube-prometheus-stack-grafana \
  -o jsonpath="{.data.admin-password}" | base64 -d; echo

# ArgoCD
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d; echo

# GitLab
kubectl get secret -n gitlab gitlab-initial-root-password \
  -o jsonpath="{.data.password}" | base64 -d; echo

# Kubernetes Dashboard
kubectl create token admin-user -n kubernetes-dashboard
```

### Cluster Operations

```bash
# Run cluster diagnostics
./scripts/troubleshooting/diagnose-cluster.sh

# Run production readiness assessment
./scripts/assessment/readiness-check.sh

# Run security audit
./scripts/assessment/security-audit.sh

# Check backup status
./scripts/backup/velero-backup-status.sh

# Create etcd backup
./scripts/backup/etcd-backup.sh
```

### Terraform

```bash
cd terraform/proxmox-vms
terraform init && terraform plan && terraform apply
```

### GitOps

```bash
# Deploy your first GitOps application
kubectl apply -f gitops/applications/demo-app-dev.yaml
argocd app get demo-app-dev
```

## Roadmap

All phases complete:

- [x] **Phase 1-2**: Foundation & Kubernetes (Proxmox, networking, security, K8s v1.29)
- [x] **Phase 3**: Infrastructure as Code (Terraform + Ansible integration)
- [x] **Phase 4**: Self-Hosted GitLab & Jenkins
- [x] **Phase 5**: Advanced CI/CD Patterns & Deployment Strategies
- [x] **Phase 6**: GitOps with ArgoCD
- [x] **Phase 7**: Observability & Monitoring (Prometheus, Grafana, Loki)
- [x] **Phase 8**: Operations (Disaster recovery, troubleshooting, production readiness)
- [x] **Phase 9**: Cluster Autoscaling with Proxmox

**22 articles complete | ~132,000 words | Series complete**

## Security

**This repository is public. Never commit secrets!**

- Use `.example` files as templates and customize for your environment
- Use [Ansible Vault](https://docs.ansible.com/ansible/latest/user_guide/vault.html) for sensitive data
- Review `.gitignore` before committing

Files excluded from git: inventory files, SSH keys, Terraform state, articles, K8s manifests with secrets.

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Test your changes thoroughly
4. Commit your changes (`git commit -m 'Add amazing feature'`)
5. Push to the branch (`git push origin feature/amazing-feature`)
6. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

Inspired by:
- [Kubernetes the Hard Way](https://github.com/kelseyhightower/kubernetes-the-hard-way) by Kelsey Hightower
- The [r/homelab](https://reddit.com/r/homelab) community
- [Learn Linux TV](https://www.youtube.com/@LearnLinuxTV) Proxmox tutorials

## Support

- **Issues**: [GitHub Issues](https://github.com/marcmassoteau-jpg/massoteau-homelab-devops/issues)
- **Article Series**: [Medium](https://medium.com/@marcmassoteau)
- **Author**: Marc Massoteau

---

**Ready to build your homelab? Start with the [Getting Started Guide](docs/setup-guides/getting-started.md)!**
