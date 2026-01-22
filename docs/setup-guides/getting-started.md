# Getting Started with Homelab DevOps

This repository contains the complete automation code for the Homelab DevOps series, including Ansible playbooks, Terraform configurations, and helper scripts for building a production-ready Kubernetes cluster on Proxmox.

## Prerequisites

Before using this repository, ensure you have:

### Infrastructure
- **Proxmox VE** server (tested on Proxmox VE 8.x)
- **5 VMs** created from Ubuntu 22.04 cloud image:
  - 1 control plane node (k8s-master): 8GB RAM, 4 cores, 100GB disk
  - 4 worker nodes (k8s-worker-01 to 04): 16GB RAM, 4 cores, 200GB disk
- **Static IP addresses** configured:
  - k8s-master: 192.168.1.240
  - k8s-worker-01: 192.168.1.241
  - k8s-worker-02: 192.168.1.242
  - k8s-worker-03: 192.168.1.243
  - k8s-worker-04: 192.168.1.244

### Local Tools
- **Ansible** (2.14 or later): `pip install ansible`
- **Terraform** (1.5 or later): [Install Terraform](https://www.terraform.io/downloads)
- **SSH access** to all cluster nodes
- **SSH key pair** configured for passwordless authentication

### Network Access
- SSH access from your workstation to all cluster nodes
- Cluster nodes can reach the internet (for package installation)
- Cluster nodes can communicate with each other

## Quick Start

### 1. Clone the Repository

```bash
git clone https://github.com/marcmassoteau-jpg/massoteau-homelab-devops.git
cd massoteau-homelab-devops
```

### 2. Configure Ansible Inventory

Copy the example inventory and customize it:

```bash
cd ansible
cp inventory/hosts.ini.example inventory/hosts.ini
cp inventory/group_vars/all.yml.example inventory/group_vars/all.yml
```

Edit `inventory/hosts.ini` with your SSH key path:
```ini
[k8s_cluster:vars]
ansible_user=ubuntu
ansible_ssh_private_key_file=~/.ssh/your_key  # Update this
ansible_python_interpreter=/usr/bin/python3
```

### 3. Test Ansible Connectivity

Verify Ansible can connect to all nodes:

```bash
cd ansible
ansible all -m ping
```

You should see success messages for all 5 nodes.

### 4. Run Network Configuration

Configure hostnames, /etc/hosts, and firewall:

```bash
ansible-playbook playbooks/01-network-setup.yml
```

### 5. Verify Network Configuration

Run the network test script to verify everything works:

```bash
# Copy script to master node
scp ../scripts/network/test-network.sh ubuntu@192.168.1.240:/home/ubuntu/

# SSH into master and run
ssh ubuntu@192.168.1.240
chmod +x test-network.sh
./test-network.sh
```

All tests should pass with ✓ marks!

## What's Next?

After completing the network setup:

1. **Security Hardening** (Article 4): Run security hardening playbook
2. **Kubernetes Installation** (Articles 5-9): Install and configure Kubernetes
3. **Application Deployment** (Articles 13-21): Deploy applications on your cluster

## Repository Structure

```
.
├── ansible/              # Ansible automation
│   ├── inventory/        # Inventory and variables
│   ├── playbooks/        # Ansible playbooks
│   └── roles/            # Ansible roles
├── terraform/            # Terraform IaC
│   └── proxmox-vms/      # VM provisioning
├── scripts/              # Helper scripts
│   ├── proxmox/          # Proxmox management
│   ├── network/          # Network testing
│   └── kubernetes/       # Kubernetes utilities
└── docs/                 # Documentation
    ├── setup-guides/     # Setup guides
    └── architecture/     # Architecture docs
```

## Security Notes

⚠️ **IMPORTANT: Never commit secrets to the repository!**

- Use `.example` files as templates
- Copy and customize for your environment
- Add actual configuration files to `.gitignore`
- Use Ansible Vault for sensitive data

Files to keep private:
- `inventory/hosts.ini` (contains actual IPs and SSH keys)
- `group_vars/all.yml` (may contain sensitive variables)
- Any files with "secret", "password", or "key" in the name

## Getting Help

- **GitHub Issues**: [Report issues](https://github.com/marcmassoteau-jpg/massoteau-homelab-devops/issues)
- **Documentation**: Check `docs/` directory
- **Article Series**: Read the full article series for detailed explanations

## License

This project is licensed under the MIT License. See [LICENSE](../../LICENSE) for details.
