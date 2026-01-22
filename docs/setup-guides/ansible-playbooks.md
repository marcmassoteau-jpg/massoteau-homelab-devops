# Ansible Playbooks Guide

This guide explains how to use the Ansible playbooks in this repository to automate your Kubernetes cluster setup.

## Prerequisites

1. **Ansible installed**: `pip install ansible`
2. **Ansible Collections installed**:
   ```bash
   ansible-galaxy collection install community.general
   ansible-galaxy collection install ansible.posix
   ```
3. **SSH access** configured to all cluster nodes
4. **Inventory configured**: `inventory/hosts.ini` with your nodes

## Available Playbooks

### 1. Network Setup (`01-network-setup.yml`)

**Purpose**: Configure network settings, /etc/hosts, and firewall rules.

**What it does**:
- Updates /etc/hosts with cluster node entries
- Configures cloud-init template for persistence
- Sets up UFW firewall rules
- Allows SSH and cluster node communication
- Verifies network connectivity

**Usage**:
```bash
cd ansible
ansible-playbook playbooks/01-network-setup.yml
```

**Check mode** (dry run):
```bash
ansible-playbook playbooks/01-network-setup.yml --check
```

**Expected output**: All tasks should complete successfully with changed/ok status.

### 2. Security Hardening (`02-security-hardening.yml`)

**Purpose**: Harden system security (to be implemented in Article 4).

**Status**: Placeholder - will be implemented in Article 4

### 3. Kubernetes Prerequisites (`03-kubernetes-prereqs.yml`)

**Purpose**: Install and configure prerequisites for Kubernetes.

**What it does**:
- Runs common system configuration role
- Updates packages
- Installs essential utilities
- Configures kernel parameters
- Disables swap

**Usage**:
```bash
ansible-playbook playbooks/03-kubernetes-prereqs.yml
```

### 4. Install Kubernetes (`04-install-kubernetes.yml`)

**Purpose**: Install and initialize Kubernetes cluster.

**Status**: Placeholder - will be implemented in upcoming articles

### 5. Verify Cluster (`99-verify-cluster.yml`)

**Purpose**: Verify Kubernetes cluster health and configuration.

**Status**: Placeholder - will be implemented in upcoming articles

### 6. Site Playbook (`site.yml`)

**Purpose**: Run all playbooks in the correct order.

**Usage**:
```bash
ansible-playbook playbooks/site.yml
```

This will execute all playbooks sequentially.

## Ansible Roles

### Common Role

**Location**: `roles/common/`

**Purpose**: Basic system configuration for all nodes.

**Tasks**:
- Update apt cache and upgrade packages
- Install essential packages
- Configure timezone
- Disable swap (required for Kubernetes)
- Enable IP forwarding
- Load kernel modules (overlay, br_netfilter)

**Variables** (in `roles/common/defaults/main.yml`):
- `common_upgrade_packages`: Whether to upgrade packages (default: true)
- `common_essential_packages`: List of packages to install
- `common_timezone`: System timezone (default: UTC)
- `common_disable_swap`: Disable swap (default: true)

### Network Config Role

**Location**: `roles/network-config/`

**Purpose**: Configure /etc/hosts and hostname resolution.

**Tasks**:
- Update /etc/cloud/templates/hosts.debian.tmpl
- Regenerate /etc/hosts from template
- Set hostname
- Verify hostname resolution

**Variables**:
- `cluster_nodes`: List of cluster nodes with names and IPs
- `network_gateway`: Default gateway
- `network_dns_servers`: DNS servers

### Firewall Role

**Location**: `roles/firewall/`

**Purpose**: Configure UFW firewall.

**Tasks**:
- Install UFW
- Set default policies (deny incoming, allow outgoing)
- Allow SSH
- Allow traffic from cluster node IPs
- Enable firewall

**Variables**:
- `firewall_allowed_cluster_ips`: List of cluster IPs to allow
- `firewall_ssh_port`: SSH port (default: 22)
- `k8s_control_plane`: Whether node is control plane

## Configuration

### Inventory

**File**: `inventory/hosts.ini`

```ini
[masters]
k8s-master ansible_host=192.168.1.240

[workers]
k8s-worker-01 ansible_host=192.168.1.241
k8s-worker-02 ansible_host=192.168.1.242
k8s-worker-03 ansible_host=192.168.1.243
k8s-worker-04 ansible_host=192.168.1.244

[k8s_cluster:children]
masters
workers

[k8s_cluster:vars]
ansible_user=ubuntu
ansible_ssh_private_key_file=~/.ssh/proxmox_key
ansible_python_interpreter=/usr/bin/python3
```

### Group Variables

**File**: `inventory/group_vars/all.yml`

```yaml
---
# Network configuration
network_gateway: 192.168.1.1
network_dns_servers:
  - 192.168.1.1
  - 8.8.8.8

# Cluster nodes
cluster_nodes:
  - { name: k8s-master, ip: 192.168.1.240, role: master }
  - { name: k8s-worker-01, ip: 192.168.1.241, role: worker }
  # ... etc

# Firewall configuration
firewall_allowed_cluster_ips:
  - 192.168.1.240
  - 192.168.1.241
  # ... etc
```

## Common Tasks

### Check Playbook Syntax

```bash
ansible-playbook playbooks/01-network-setup.yml --syntax-check
```

### Run in Check Mode (Dry Run)

```bash
ansible-playbook playbooks/01-network-setup.yml --check
```

### Run on Specific Hosts

```bash
ansible-playbook playbooks/01-network-setup.yml --limit k8s-master
```

### Run with Verbose Output

```bash
ansible-playbook playbooks/01-network-setup.yml -v   # verbose
ansible-playbook playbooks/01-network-setup.yml -vv  # more verbose
ansible-playbook playbooks/01-network-setup.yml -vvv # debug
```

### Test Connectivity

```bash
ansible all -m ping
ansible masters -m ping
ansible workers -m ping
```

### Run Ad-Hoc Commands

```bash
# Check hostname on all nodes
ansible all -a "hostname"

# Check firewall status
ansible all -a "sudo ufw status" --become

# Check /etc/hosts
ansible all -a "cat /etc/hosts"
```

## Troubleshooting

### Cannot Connect to Hosts

**Problem**: `ansible all -m ping` fails

**Solutions**:
1. Verify SSH key path in `inventory/hosts.ini`
2. Test SSH manually: `ssh -i ~/.ssh/your_key ubuntu@192.168.1.240`
3. Check SSH key permissions: `chmod 600 ~/.ssh/your_key`

### Permission Denied Errors

**Problem**: Tasks fail with permission denied

**Solutions**:
1. Verify `become: true` is set in playbook/task
2. Check sudo access: `ssh ubuntu@192.168.1.240 'sudo -v'`
3. Review `ansible.cfg` privilege escalation settings

### Playbook Hangs or Times Out

**Problem**: Playbook stops responding

**Solutions**:
1. Check node is accessible: `ping 192.168.1.240`
2. Verify SSH connection: `ssh ubuntu@192.168.1.240`
3. Increase timeout in `ansible.cfg`:
   ```ini
   [defaults]
   timeout = 30
   ```

### Changes Not Applied

**Problem**: Playbook runs but changes don't persist

**Solutions**:
1. Run playbook again - Ansible is idempotent
2. Check for errors in task output
3. Verify variables are set correctly
4. SSH into node and check manually

## Best Practices

1. **Always run in check mode first**: `--check` to preview changes
2. **Use version control**: Commit playbooks to git
3. **Test on one node first**: `--limit k8s-master` before running on all
4. **Keep secrets separate**: Use Ansible Vault for sensitive data
5. **Document variables**: Comment your variable files
6. **Make playbooks idempotent**: They should be safe to run multiple times

## Next Steps

After configuring the network:
1. Run security hardening playbook (Article 4)
2. Install Kubernetes prerequisites (Articles 5-7)
3. Initialize Kubernetes cluster (Articles 8-9)

## Additional Resources

- [Ansible Documentation](https://docs.ansible.com/)
- [Ansible Best Practices](https://docs.ansible.com/ansible/latest/user_guide/playbooks_best_practices.html)
- [Ansible Galaxy](https://galaxy.ansible.com/) - Community roles
