# Homelab DevOps Pipeline

> Complete automation for building a production-grade Kubernetes cluster on Proxmox using Infrastructure as Code

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-1.29-blue.svg)](https://kubernetes.io/)
[![Proxmox](https://img.shields.io/badge/Proxmox-VE%208.x-orange.svg)](https://www.proxmox.com/)

This repository contains **production-ready automation code** for deploying and managing a complete Kubernetes homelab environment. All code is tested and documented in the companion [Medium article series](https://medium.com/@marcmassoteau).

## 📋 What's Included

- **Ansible Playbooks**: Automated configuration management for Kubernetes nodes
- **Terraform Configurations**: Infrastructure as Code for VM provisioning (coming soon)
- **Helper Scripts**: Proxmox VM management, network testing, and utilities
- **Documentation**: Comprehensive guides for setup and troubleshooting
- **Examples**: Sample applications and test workloads

## 🏗️ Infrastructure Overview

```
Proxmox Host
    └── Kubernetes Cluster (5 VMs)
        ├── k8s-master (192.168.1.240)
        │   └── 4 vCPU / 8GB RAM / 100GB Disk
        └── k8s-worker-01 to 04 (192.168.1.241-244)
            └── 4 vCPU / 16GB RAM / 200GB Disk each
```

## 🚀 Quick Start

### Prerequisites

**Infrastructure:**
- Proxmox VE 8.x host
- 5 Ubuntu 22.04 VMs created from cloud image
- Static IP addresses configured
- SSH access from your workstation to all nodes

**Local Tools:**
- [Ansible](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html) 2.14+
- [Terraform](https://www.terraform.io/downloads) 1.5+ (optional)
- SSH key pair for passwordless authentication

### Installation

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

5. **Run network configuration:**
   ```bash
   ansible-playbook playbooks/01-network-setup.yml
   ```

## 📚 Documentation

Comprehensive documentation is available in the `docs/` directory:

- **[Getting Started](docs/setup-guides/getting-started.md)**: Complete setup guide
- **[Ansible Playbooks](docs/setup-guides/ansible-playbooks.md)**: How to use playbooks
- **[Network Design](docs/architecture/network-design.md)**: Network architecture details
- **[Ansible README](ansible/README.md)**: Ansible automation details
- **[Scripts README](scripts/README.md)**: Helper scripts documentation

## 🔧 Project Structure

```
.
├── ansible/              # Ansible automation
│   ├── inventory/        # Inventory and variables
│   ├── playbooks/        # Automation playbooks
│   └── roles/            # Reusable roles
├── terraform/            # Terraform IaC (coming soon)
├── scripts/              # Helper scripts
│   ├── proxmox/          # VM management
│   ├── network/          # Network testing
│   └── kubernetes/       # K8s utilities
├── docs/                 # Documentation
│   ├── setup-guides/     # Setup and usage guides
│   └── architecture/     # Architecture documentation
└── examples/             # Sample applications
```

## 🎯 Roadmap

- [x] Ansible automation for network configuration
- [x] Firewall configuration (UFW)
- [x] Common system setup
- [ ] Security hardening (Article 4)
- [ ] Kubernetes installation (Articles 5-9)
- [ ] Terraform VM provisioning (Article 10)
- [ ] Complete CI/CD pipeline (Articles 15-17)
- [ ] Monitoring stack (Article 18)

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

**Run network setup:**
```bash
cd ansible
ansible-playbook playbooks/01-network-setup.yml
```

**Run specific role:**
```bash
ansible-playbook playbooks/01-network-setup.yml --tags firewall
```

**Dry run (check mode):**
```bash
ansible-playbook playbooks/01-network-setup.yml --check
```

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
