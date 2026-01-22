# Helper Scripts

This directory contains helper scripts for managing the homelab infrastructure.

## 📁 Directory Structure

```
scripts/
├── proxmox/        # Proxmox VM management
├── network/        # Network testing and configuration
└── kubernetes/     # Kubernetes utilities
```

## Proxmox Scripts

**Location**: `proxmox/`

Scripts for managing VMs on Proxmox host.

### create-template.sh

Creates Ubuntu 22.04 VM template for Kubernetes cluster.

**Usage** (run on Proxmox host):
```bash
ssh root@192.168.1.222
cd /root
./create-template.sh
```

**What it does**:
- Downloads Ubuntu 22.04 cloud image
- Creates VM template (ID 9000)
- Configures cloud-init
- Sets up SSH keys
- Resizes disk

### create-k8s-vms.sh

Creates all Kubernetes cluster VMs from template.

**Usage** (run on Proxmox host):
```bash
ssh root@192.168.1.222
./create-k8s-vms.sh
```

**What it does**:
- Clones template for 5 VMs
- Configures resources (RAM, CPU, disk)
- Sets static IPs
- Configures SSH keys

**Configuration**:
Edit the script to customize:
- `SSH_KEY`: Your SSH public key
- VM resources (RAM, cores, disk)
- IP addresses

### snapshot-all.sh

Takes snapshots of all Kubernetes cluster VMs.

**Usage** (run on Proxmox host):
```bash
# Default snapshot name (timestamp)
./snapshot-all.sh

# Custom snapshot name
./snapshot-all.sh "before-k8s-install" "Clean Ubuntu before K8s"

# Specific snapshot
./snapshot-all.sh "before-upgrade" "Before Kubernetes 1.28 upgrade"
```

**Examples**:
```bash
# Before Kubernetes installation
./snapshot-all.sh "before-k8s" "Clean state before K8s install"

# Before upgrades
./snapshot-all.sh "before-helm" "Before Helm charts"

# Before experiments
./snapshot-all.sh "working-state" "Known good configuration"
```

## Network Scripts

**Location**: `network/`

Scripts for network testing and configuration.

### test-network.sh

Comprehensive network verification for the cluster.

**Usage** (run from k8s-master or workstation):
```bash
# From workstation
scp scripts/network/test-network.sh ubuntu@192.168.1.240:/home/ubuntu/
ssh ubuntu@192.168.1.240

# On k8s-master
chmod +x test-network.sh
./test-network.sh
```

**Tests performed**:
1. Ping connectivity to all nodes
2. SSH connectivity to all nodes
3. Hostname resolution
4. Internet connectivity from each node
5. DNS resolution from each node
6. Firewall status
7. Time synchronization

**Expected**: All tests pass with ✓ marks

### configure-firewall.sh

Configures UFW firewall on all cluster nodes.

**Usage** (run from workstation):
```bash
cd scripts/network
./configure-firewall.sh
```

**What it does**:
- Installs UFW on all nodes
- Sets default policies (deny incoming, allow outgoing)
- Allows SSH access
- Allows traffic from cluster node IPs
- Enables firewall

**Note**: This is automated in Ansible playbooks. Use for manual setup only.

### deploy-hosts-file.sh

Deploys /etc/hosts configuration to all nodes.

**Usage** (run from workstation):
```bash
cd scripts/network
./deploy-hosts-file.sh
```

**What it does**:
- Generates /etc/hosts with cluster mappings
- Deploys to cloud-init template (for persistence)
- Updates /etc/hosts on all nodes
- Verifies deployment

**Note**: This is automated in Ansible playbooks. Use for manual setup only.

## Kubernetes Scripts

**Location**: `kubernetes/`

Utilities for Kubernetes cluster management.

### cluster-info.sh

Displays comprehensive cluster information.

**Usage** (run from k8s-master):
```bash
./cluster-info.sh
```

**Information displayed**:
- Cluster info
- Node status
- System pods
- Namespaces
- All resources

**Note**: Requires Kubernetes to be installed.

## 🔐 Security Notes

### SSH Keys

Scripts reference SSH keys. **Never commit private keys!**

Before using:
1. Update `SSH_KEY` variable in scripts
2. Use your actual public key
3. Verify key permissions: `chmod 600 ~/.ssh/your_key`

### Proxmox Access

Proxmox scripts must run on the Proxmox host (192.168.1.222):
- SSH as root: `ssh root@192.168.1.222`
- Transfer scripts: `scp script.sh root@192.168.1.222:/root/`
- Make executable: `chmod +x script.sh`

## 💡 Tips

### Making Scripts Executable

```bash
# Single script
chmod +x scripts/network/test-network.sh

# All scripts in directory
chmod +x scripts/network/*.sh
chmod +x scripts/proxmox/*.sh
```

### Running Scripts Safely

1. **Read the script first**: `cat script.sh`
2. **Understand what it does**: Review code
3. **Test on one node**: Comment out others
4. **Have backups**: Take snapshots before running

### Debugging Scripts

```bash
# Run with debug output
bash -x script.sh

# Check for syntax errors
bash -n script.sh
```

## 🔗 Automation

Most of these scripts are automated in Ansible playbooks:

- **Network configuration** → `ansible/playbooks/01-network-setup.yml`
- **Firewall setup** → `ansible/roles/firewall/`
- **System configuration** → `ansible/roles/common/`

**Recommendation**: Use Ansible for repeatable automation. Use scripts for:
- Initial setup on Proxmox
- Manual interventions
- Testing and verification
- One-off operations

## 📚 Related Documentation

- [Getting Started Guide](../docs/setup-guides/getting-started.md)
- [Ansible Playbooks Guide](../docs/setup-guides/ansible-playbooks.md)
- [Network Design](../docs/architecture/network-design.md)
- Article 2: Proxmox Setup & VM Provisioning
- Article 3: Network Planning

## 🤝 Contributing

When adding new scripts:

1. Add descriptive header comments
2. Include usage examples
3. Make scripts idempotent when possible
4. Handle errors gracefully (`set -e`)
5. Document in this README
6. Test thoroughly

## 📄 License

This project is licensed under the MIT License. See [LICENSE](../LICENSE) for details.
