# Homelab DevOps Pipeline

> Complete automation for building a production-grade Kubernetes cluster on Proxmox using Infrastructure as Code

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-1.29-blue.svg)](https://kubernetes.io/)
[![Proxmox](https://img.shields.io/badge/Proxmox-VE%208.x-orange.svg)](https://www.proxmox.com/)

This repository contains **production-ready automation code** for deploying and managing a complete Kubernetes homelab environment. All code is tested and documented in the companion [Medium article series](https://medium.com/@marcmassoteau).

## 📋 What's Included

- **Terraform Infrastructure**: Infrastructure as Code for Proxmox VM provisioning
- **Ansible Playbooks**: Automated configuration management for Kubernetes nodes
- **Integration Scripts**: One-command cluster deployment (Terraform + Ansible)
- **GitLab Platform**: Self-hosted Git repository and container registry on Kubernetes
- **Jenkins CI/CD**: Automated build, test, and deployment pipelines with shared libraries
- **CI/CD Pipelines**: Automated build, test, and deployment workflows
- **Pipeline Templates**: Reusable Jenkins shared libraries and GitLab CI templates for comparison
- **Deployment Strategies**: Blue-green and canary deployments with automated rollback
- **GitOps with ArgoCD**: Declarative deployments with self-healing and drift detection
- **GitOps Repository**: Kustomize-based multi-environment management (dev/staging/prod)
- **Monitoring Stack**: Prometheus, Grafana dashboards, Loki log aggregation, and alerting
- **Backup & Recovery**: Velero with MinIO, etcd snapshots, and multi-layer disaster recovery
- **Cluster Autoscaling**: Dynamic worker node provisioning with Proxmox API integration
- **Helper Scripts**: Proxmox VM management, network testing, and utilities
- **Documentation**: Comprehensive guides, articles, and troubleshooting
- **Examples**: Sample applications, Jenkins pipelines, and GitOps workflow demos

## 🏗️ Infrastructure Overview

```
Proxmox Host
    └── Kubernetes Cluster (5 VMs)
        ├── k8s-master (192.168.1.240)
        │   └── 4 vCPU / 8GB RAM / 100GB Disk
        └── k8s-worker-01 to 04 (192.168.1.241-244)
            └── 4 vCPU / 16GB RAM / 200GB Disk each

Services:
    ├── gitlab.homelab.local - Source control & container registry
    ├── jenkins.homelab.local - CI/CD automation
    ├── argocd.homelab.local - GitOps deployment
    ├── grafana.homelab.local - Metrics dashboards & log viewer
    ├── prometheus.homelab.local - Metrics collection & alerting
    └── alertmanager.homelab.local - Alert routing & notification
```

## 🚀 Quick Start

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

**Option 1: One-Command Deployment** (Recommended)

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

**Total deployment time:** ~10-15 minutes

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

## 📚 Documentation

### Setup Guides

- **[Terraform Setup](terraform/docs/terraform-setup.md)**: Complete Terraform installation and configuration
- **[Terraform README](terraform/proxmox-vms/README.md)**: Proxmox VM provisioning guide
- **[Getting Started](docs/setup-guides/getting-started.md)**: Complete setup guide
- **[Ansible Playbooks](docs/setup-guides/ansible-playbooks.md)**: How to use playbooks
- **[Ansible README](ansible/README.md)**: Ansible automation details

### Article Series

**Phase 1-2: Foundation & Kubernetes (Articles 1-9)**
- Articles 1-5: Proxmox, Network, Security, Kubernetes

**Phase 3: Infrastructure as Code (Articles 10-12)** ✅
- **[Article 10](docs/articles/Article-10-Terraform-Proxmox.md)**: Terraform Foundations (9,657 words)
- **[Article 11](docs/articles/Article-11-Ansible-Configuration.md)**: Ansible Configuration Management (13,803 words)
- **[Article 12](docs/articles/Article-12-Terraform-Ansible-Integration.md)**: Terraform + Ansible Integration (10,465 words)

**Phase 4: Self-Hosted GitLab & Jenkins (Articles 13-14)** ✅
- **[Article 13](docs/articles/Article-13-GitLab-Deployment.md)**: GitLab Deployment on Kubernetes with Helm (5,487 words)
- **[Article 14](docs/articles/Article-14-Jenkins-CICD.md)**: Jenkins CI/CD: Pipelines and Integration (5,621 words)

**Phase 5: Advanced CI/CD Patterns (Articles 15-16)** ✅
- **[Article 15](docs/articles/Article-15-Advanced-CICD-Patterns.md)**: Advanced CI/CD Patterns (8,795 words)
- **[Article 16](docs/articles/Article-16-Deployment-Strategies.md)**: Deployment Strategies and Automation (6,564 words)

**Phase 6: GitOps with ArgoCD (Article 17)** ✅
- **[Article 17](docs/articles/Article-17-GitOps-ArgoCD.md)**: GitOps with ArgoCD (~9,200 words)

**Phase 7: Observability & Monitoring (Article 18)** ✅
- **[Article 18](docs/articles/Article-18-Observability-Stack.md)**: Complete Observability Stack (~8,500 words)

**Phase 8: Operations & Troubleshooting (Articles 19-21)** ✅
- **[Article 19](docs/articles/Article-19-Disaster-Recovery.md)**: Disaster Recovery (~9,100 words)
- **[Article 20](docs/articles/Article-20-Troubleshooting-Guide.md)**: Troubleshooting Guide (~7,800 words)
- **[Article 21](docs/articles/Article-21-Production-Readiness.md)**: Production Readiness (~8,100 words)

**Phase 9: Advanced Topics (Article 22)** ✅
- **[Article 22](docs/articles/Article-22-Cluster-Autoscaler.md)**: Cluster Autoscaler with Proxmox (~8,500 words)

### Architecture

- **[Network Design](docs/architecture/network-design.md)**: Network architecture details
- **[GitOps Architecture](docs/architecture/gitops-architecture.md)**: GitOps deployment architecture
- **[CI/CD vs GitOps](docs/comparisons/cicd-vs-gitops.md)**: Comparison and decision framework
- **[Scripts README](scripts/README.md)**: Helper scripts documentation

## 🔧 Project Structure

```
.
├── terraform/            # Terraform Infrastructure as Code
│   ├── proxmox-vms/      # VM provisioning configuration
│   ├── modules/          # Reusable Terraform modules
│   └── docs/             # Terraform documentation
├── ansible/              # Ansible configuration management
│   ├── inventory/        # Inventory and variables
│   ├── playbooks/        # Automation playbooks (01-06)
│   └── roles/            # Reusable roles (gitlab, argocd, etc.)
├── Kubernetes/           # Kubernetes manifests
│   └── manifests/        # Application deployments
│       ├── gitlab/       # GitLab deployment configurations
│       └── argocd/       # ArgoCD deployment configurations
├── gitops/               # GitOps repository (ArgoCD)
│   ├── applications/     # ArgoCD Application manifests
│   ├── base/             # Base Kustomize manifests
│   ├── environments/     # Per-environment overlays (dev/staging/prod)
│   └── scripts/          # GitOps automation scripts
├── scripts/              # Helper scripts
│   ├── automation/       # Integration scripts (provision-cluster.sh)
│   ├── proxmox/          # VM management
│   ├── network/          # Network testing
│   └── kubernetes/       # K8s utilities
├── docs/                 # Documentation
│   ├── articles/         # Blog article series (Articles 1-17)
│   ├── setup-guides/     # Setup and usage guides
│   ├── architecture/     # Architecture documentation
│   └── comparisons/      # Technology comparison guides
└── examples/             # Sample applications and workflows
    ├── cicd-templates/   # GitLab CI/CD templates
    ├── deployment-strategies/  # Blue-green and canary examples
    └── gitops-workflow/  # Hybrid CI/CD + GitOps example
```

## 🎯 Roadmap

### Completed ✅
- [x] **Phase 1**: Foundation (Proxmox, Network, Security)
- [x] **Phase 2**: Kubernetes Cluster (v1.29.15 with Calico CNI)
- [x] **Phase 3**: Infrastructure as Code (Terraform + Ansible)
  - [x] Terraform for VM provisioning
  - [x] Ansible configuration management
  - [x] Complete automation pipeline (provision-cluster.sh)
  - [x] Articles 10-12 (33,925 words)
- [x] **Phase 4**: Self-Hosted GitLab & Jenkins (Articles 13-14)
  - [x] GitLab CE deployment on Kubernetes via Helm (source control)
  - [x] Private container registry in GitLab
  - [x] Jenkins deployment on Kubernetes via Helm (CI engine)
  - [x] Jenkins shared libraries and pipeline integration
  - [x] Complete CI/CD pipelines (build → test → containerize → deploy)
  - [x] Articles 13-14 (11,108 words)

- [x] **Phase 5**: Advanced CI/CD Patterns & Deployment Strategies (Articles 15-16)
  - [x] Pipeline templates and includes
  - [x] Matrix builds and dynamic environments
  - [x] Blue-green and canary deployments
  - [x] Security scanning automation (Trivy, Semgrep)
  - [x] Automated monitoring and rollback
  - [x] Articles 15-16 (15,359 words)

- [x] **Phase 6**: GitOps with ArgoCD (Article 17)
  - [x] ArgoCD deployment via Helm with Ansible automation
  - [x] GitOps repository with Kustomize (base + overlay pattern)
  - [x] Multi-environment management (dev/staging/prod)
  - [x] Hybrid CI/CD + GitOps workflow (Jenkins builds, ArgoCD deploys)
  - [x] Blue-green and canary deployments adapted for GitOps
  - [x] Self-healing and drift detection
  - [x] Article 17 (~8,046 words)

- [x] **Phase 7**: Observability & Monitoring (Article 18)
  - [x] kube-prometheus-stack deployment via Ansible
  - [x] ServiceMonitors for GitLab, Jenkins, ArgoCD, Traefik
  - [x] Grafana dashboards and Loki log aggregation
  - [x] PrometheusRule-based alerting
  - [x] Article 18 (~8,500 words)

- [x] **Phase 8**: Operations & Troubleshooting (Articles 19-21)
  - [x] Velero backup with MinIO S3-compatible storage
  - [x] Etcd snapshots and multi-layer disaster recovery
  - [x] Systematic troubleshooting methodology and diagnostic scripts
  - [x] Production readiness assessment with CIS benchmarks
  - [x] Articles 19-21 (~25,000 words)

- [x] **Phase 9**: Advanced Topics (Article 22)
  - [x] Custom cluster autoscaling with Proxmox API integration
  - [x] Metrics Server for HPA and CronJob-based scaling
  - [x] Dynamic worker node provisioning with cloud-init auto-join
  - [x] Autoscaler monitoring with Prometheus
  - [x] Article 22 (~8,500 words)

**Progress**: 22/22 articles complete (100%) | ~132,000 words ✅ SERIES COMPLETE

## 🔐 Security

**⚠️ IMPORTANT: This repository is public. Never commit secrets!**

- Use `.example` files as templates
- Copy and customize for your environment
- Never commit `hosts.ini` or `all.yml` with actual values
- Use [Ansible Vault](https://docs.ansible.com/ansible/latest/user_guide/vault.html) for sensitive data
- Review `.gitignore` before committing

Files excluded from git:
- Actual inventory files (`.example` versions provided)
- SSH private keys
- Terraform state files
- Any files with "secret", "password", or "key" in the name

## 💡 Usage Examples

### Complete Cluster Deployment

**One-command deployment:**
```bash
./scripts/automation/provision-cluster.sh
```

**Destroy cluster:**
```bash
./scripts/automation/provision-cluster.sh --destroy
```

### Terraform Only

**Create VMs:**
```bash
cd terraform/proxmox-vms
terraform init
terraform plan
terraform apply
```

**View outputs:**
```bash
terraform output deployment_summary
```

### Ansible Only

**Run network setup:**
```bash
cd ansible
ansible-playbook playbooks/01-network-setup.yml
```

**Run all playbooks:**
```bash
ansible-playbook playbooks/01-network-setup.yml
ansible-playbook playbooks/02-security-hardening.yml
ansible-playbook playbooks/03-kubernetes-prereqs.yml
ansible-playbook playbooks/04-install-kubernetes.yml
ansible-playbook playbooks/05-deploy-gitlab.yml
ansible-playbook playbooks/06-deploy-argocd.yml
```

**Run specific role:**
```bash
ansible-playbook playbooks/01-network-setup.yml --tags firewall
```

**Dry run (check mode):**
```bash
ansible-playbook playbooks/01-network-setup.yml --check
```

### GitLab Deployment

**Deploy GitLab:**
```bash
cd ansible
ansible-playbook playbooks/05-deploy-gitlab.yml
```

**Access GitLab:**
```bash
# Get initial root password
kubectl get secret gitlab-gitlab-initial-root-password \
  -n gitlab \
  -o jsonpath="{.data.password}" | base64 --decode; echo

# Access at: http://gitlab.homelab.local:30080
```

**Deploy GitLab Runner:**
```bash
cd Kubernetes/manifests/gitlab/runner
helm install gitlab-runner gitlab/gitlab-runner \
  --namespace gitlab-runner \
  --values runner-values.yaml
```

### ArgoCD Deployment

**Deploy ArgoCD:**
```bash
cd ansible
ansible-playbook playbooks/06-deploy-argocd.yml
```

**Access ArgoCD:**
```bash
# Get initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 --decode; echo

# Access at: http://argocd.homelab.local
```

**Deploy your first GitOps application:**
```bash
kubectl apply -f gitops/applications/demo-app-dev.yaml
argocd app get demo-app-dev
```

### Jenkins Deployment

**Deploy Jenkins:**
```bash
cd ansible
ansible-playbook playbooks/07-deploy-jenkins.yml
```

**Access Jenkins:**
```bash
# Get initial admin password
kubectl -n jenkins exec -it \
  $(kubectl get pods -n jenkins -l app.kubernetes.io/component=jenkins-controller -o name) \
  -- cat /run/secrets/additional/chart-admin-password; echo

# Access at: http://jenkins.homelab.local
```

**Configure Jenkins:**
- Install suggested plugins
- Connect to GitLab (OAuth integration)
- Set up shared libraries from GitLab
- Create first pipeline

**Create Proxmox VMs:**
```bash
# On Proxmox host
./scripts/proxmox/create-k8s-vms.sh
```

**Test network connectivity:**
```bash
# On k8s-master node
./scripts/network/test-network.sh
```

## 📖 Article Series

This code accompanies a comprehensive [Medium article series](https://medium.com/@marcmassoteau) that explains:
- Why each decision was made
- Step-by-step implementation
- Troubleshooting common issues
- Production best practices

## 🤝 Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Test your changes thoroughly
4. Commit your changes (`git commit -m 'Add amazing feature'`)
5. Push to the branch (`git push origin feature/amazing-feature`)
6. Open a Pull Request

## 🐛 Bug Reports

Found a bug? Please [open an issue](https://github.com/marcmassoteau-jpg/massoteau-homelab-devops/issues) with:
- Description of the problem
- Steps to reproduce
- Expected vs actual behavior
- Environment details (OS, Ansible version, etc.)

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

Inspired by:
- [Kubernetes the Hard Way](https://github.com/kelseyhightower/kubernetes-the-hard-way) by Kelsey Hightower
- The [r/homelab](https://reddit.com/r/homelab) community
- [Learn Linux TV](https://www.youtube.com/@LearnLinuxTV) Proxmox tutorials

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/marcmassoteau-jpg/massoteau-homelab-devops/issues)
- **Discussions**: [GitHub Discussions](https://github.com/marcmassoteau-jpg/massoteau-homelab-devops/discussions)
- **Article Series**: [Medium](https://medium.com/@marcmassoteau)
- **Author**: Marc Massoteau

## ⭐ Show Your Support

If this project helps you, please:
- ⭐ Star this repository
- 🔀 Fork and customize for your needs
- 📤 Share with others building homelabs
- 🐛 Report issues to help improve
- 💬 Contribute improvements

---

**Ready to build your homelab? Start with the [Getting Started Guide](docs/setup-guides/getting-started.md)!**
