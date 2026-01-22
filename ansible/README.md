# Ansible Automation for Kubernetes Cluster

This directory contains Ansible playbooks and roles for automating the setup and configuration of a Kubernetes cluster on Proxmox.

## 📁 Directory Structure

```
ansible/
├── ansible.cfg              # Ansible configuration
├── inventory/               # Inventory and variables
│   ├── hosts.ini.example    # Example inventory file
│   └── group_vars/          # Group variables
│       ├── all.yml.example  # Example variables (all nodes)
│       ├── masters.yml      # Master node variables
│       └── workers.yml      # Worker node variables
├── playbooks/               # Ansible playbooks
│   ├── site.yml             # Main playbook (runs all)
│   ├── 01-network-setup.yml # Network configuration
│   ├── 02-security-hardening.yml
│   ├── 03-kubernetes-prereqs.yml
│   ├── 04-install-kubernetes.yml
│   └── 99-verify-cluster.yml
└── roles/                   # Ansible roles
    ├── common/              # Common system configuration
    ├── network-config/      # Network and hostname setup
    ├── firewall/            # UFW firewall configuration
    ├── security-hardening/  # Security hardening (TBD)
    ├── containerd/          # Containerd runtime (TBD)
    ├── kubernetes/          # Kubernetes installation (TBD)
    └── monitoring-agent/    # Monitoring agents (TBD)
```

## 🚀 Quick Start

### 1. Prerequisites

Install Ansible and required collections:

```bash
# Install Ansible
pip install ansible

# Install required collections
ansible-galaxy collection install community.general
ansible-galaxy collection install ansible.posix
```

### 2. Configure Inventory

Copy and customize the inventory files:

```bash
# Copy inventory template
cp inventory/hosts.ini.example inventory/hosts.ini

# Copy variables template
cp inventory/group_vars/all.yml.example inventory/group_vars/all.yml

# Edit with your actual configuration
vim inventory/hosts.ini
```

**Important**: Update `ansible_ssh_private_key_file` with your SSH key path!

### 3. Test Connectivity

Verify Ansible can connect to all nodes:

```bash
ansible all -m ping
```

Expected output:
```
k8s-master | SUCCESS => { "ping": "pong" }
k8s-worker-01 | SUCCESS => { "ping": "pong" }
...
```

### 4. Run Playbooks

Execute playbooks in order:

```bash
# Network configuration
ansible-playbook playbooks/01-network-setup.yml

# Kubernetes prerequisites
ansible-playbook playbooks/03-kubernetes-prereqs.yml

# Or run all at once
ansible-playbook playbooks/site.yml
```

## 📚 Available Playbooks

### 01-network-setup.yml

**Status**: ✅ Ready to use

Configures network settings for the Kubernetes cluster.

**What it does**:
- Updates /etc/hosts with cluster node mappings
- Configures cloud-init template for persistence
- Sets up UFW firewall rules
- Verifies network connectivity

**Usage**:
```bash
ansible-playbook playbooks/01-network-setup.yml
```

**Dry run** (recommended first):
```bash
ansible-playbook playbooks/01-network-setup.yml --check
```

### 02-security-hardening.yml

**Status**: 🚧 To be implemented (Article 4)

Will include:
- SSH hardening
- Fail2ban installation
- Audit logging
- Sudo configuration

### 03-kubernetes-prereqs.yml

**Status**: ⚠️ Partially implemented

Installs Kubernetes prerequisites.

**Current features**:
- Common system configuration
- Package updates
- Kernel parameters
- Swap disable

**To be added**:
- Containerd installation
- Kubernetes package installation

### 04-install-kubernetes.yml

**Status**: 🚧 To be implemented (Articles 5-9)

Will install and configure Kubernetes.

### 99-verify-cluster.yml

**Status**: 🚧 To be implemented

Will verify cluster health and configuration.

## 🔧 Ansible Roles

### common

**Purpose**: Basic system configuration for all nodes

**Tasks**:
- Update packages
- Install essential utilities
- Configure timezone
- Disable swap (required for Kubernetes)
- Enable IP forwarding
- Load kernel modules (overlay, br_netfilter)

**Variables**: See `roles/common/defaults/main.yml`

### network-config

**Purpose**: Configure hostnames and /etc/hosts

**Tasks**:
- Update /etc/cloud/templates/hosts.debian.tmpl
- Update /etc/hosts
- Set hostname
- Verify hostname resolution

**Variables**:
- `cluster_nodes`: List of nodes with IPs
- `network_gateway`: Default gateway
- `network_dns_servers`: DNS servers

### firewall

**Purpose**: Configure UFW firewall

**Tasks**:
- Install UFW
- Set default policies
- Allow SSH
- Allow cluster node traffic
- Enable firewall

**Variables**:
- `firewall_allowed_cluster_ips`: Cluster IPs
- `firewall_ssh_port`: SSH port (default: 22)

## 🔐 Security

### Never Commit Secrets!

⚠️ **CRITICAL**: Never commit sensitive files to git!

**Files to keep private**:
- `inventory/hosts.ini` (contains IPs and SSH key paths)
- `inventory/group_vars/all.yml` (may contain passwords)
- Any files with "secret", "password", or "key" in the name

**Safe to commit**:
- `*.example` files
- Role defaults
- Playbooks (without secrets)
- Documentation

### Using Ansible Vault

For sensitive data, use Ansible Vault:

```bash
# Create encrypted file
ansible-vault create inventory/group_vars/secrets.yml

# Edit encrypted file
ansible-vault edit inventory/group_vars/secrets.yml

# Run playbook with vault
ansible-playbook playbooks/site.yml --ask-vault-pass
```

## 💡 Usage Tips

### Check Mode (Dry Run)

Always test with `--check` first:

```bash
ansible-playbook playbooks/01-network-setup.yml --check
```

### Syntax Check

Verify playbook syntax:

```bash
ansible-playbook playbooks/01-network-setup.yml --syntax-check
```

### Run on Specific Hosts

Limit execution to specific nodes:

```bash
# Only master node
ansible-playbook playbooks/01-network-setup.yml --limit k8s-master

# Only workers
ansible-playbook playbooks/01-network-setup.yml --limit workers

# Specific node
ansible-playbook playbooks/01-network-setup.yml --limit k8s-worker-01
```

### Verbose Output

Increase verbosity for debugging:

```bash
ansible-playbook playbooks/01-network-setup.yml -v    # verbose
ansible-playbook playbooks/01-network-setup.yml -vv   # more verbose
ansible-playbook playbooks/01-network-setup.yml -vvv  # debug
```

### Ad-Hoc Commands

Run one-off commands:

```bash
# Check hostname
ansible all -a "hostname"

# Check firewall status
ansible all -a "sudo ufw status" --become

# Reboot all nodes
ansible all -a "sudo reboot" --become
```

## 🔍 Troubleshooting

### Cannot Connect to Hosts

**Problem**: `ansible all -m ping` fails

**Solutions**:
1. Check SSH key: `ssh -i ~/.ssh/your_key ubuntu@192.168.1.240`
2. Verify key permissions: `chmod 600 ~/.ssh/your_key`
3. Check `inventory/hosts.ini` has correct key path

### Permission Denied

**Problem**: Tasks fail with permission errors

**Solutions**:
1. Ensure `become: true` is set
2. Verify sudo works: `ssh ubuntu@192.168.1.240 'sudo -v'`
3. Check user has sudo rights

### Playbook Hangs

**Problem**: Playbook stops responding

**Solutions**:
1. Check node is accessible: `ping 192.168.1.240`
2. Verify SSH works: `ssh ubuntu@192.168.1.240`
3. Increase timeout in `ansible.cfg`

## 📖 Variables Reference

### Global Variables (group_vars/all.yml)

```yaml
# Network configuration
network_gateway: 192.168.1.1
network_dns_servers:
  - 192.168.1.1
  - 8.8.8.8

# Cluster nodes
cluster_nodes:
  - { name: k8s-master, ip: 192.168.1.240, role: master }
  - { name: k8s-worker-01, ip: 192.168.1.241, role: worker }
  # ...

# Firewall
firewall_allowed_cluster_ips:
  - 192.168.1.240
  - 192.168.1.241
  # ...
```

### Role-Specific Variables

See `roles/<role_name>/defaults/main.yml` for each role's variables.

## 🎯 Best Practices

1. **Always test with --check first**
2. **Use version control** for playbooks and roles
3. **Test on one node** before running on all
4. **Keep secrets in Ansible Vault**
5. **Document your variables**
6. **Make playbooks idempotent**
7. **Use roles for reusability**

## 🔗 Related Resources

- [Getting Started Guide](../docs/setup-guides/getting-started.md)
- [Ansible Playbooks Guide](../docs/setup-guides/ansible-playbooks.md)
- [Network Design](../docs/architecture/network-design.md)
- [Article Series Index](../Article-00-Series-Index.md)

## 📝 Contributing

When adding new playbooks or roles:

1. Follow the existing structure
2. Document variables in `defaults/main.yml`
3. Include README in complex roles
4. Test thoroughly before committing
5. Update this README

## 📄 License

This project is licensed under the MIT License. See [LICENSE](../LICENSE) for details.
