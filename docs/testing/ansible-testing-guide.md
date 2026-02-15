# Ansible Testing Guide - Phase A

**Purpose:** This guide walks through testing all Ansible playbooks on the actual infrastructure.

**Prerequisites:**
- ✅ Inventory files created from templates (hosts.ini, all.yml)
- ✅ 5 VMs running on Proxmox (192.168.1.240-244)
- ✅ SSH access configured with key authentication
- ✅ Ansible 2.14+ installed on workstation

**Testing Environment:**
- Proxmox host: 192.168.1.222
- k8s-master: 192.168.1.240
- k8s-worker-01 to 04: 192.168.1.241-244
- SSH user: ubuntu
- SSH key: ~/.ssh/proxmox_key (or as configured in hosts.ini)

---

## Step 1: Verify Inventory Configuration

Before testing, verify your inventory files are correctly configured:

```bash
cd ~/homelab-devops/ansible

# Check hosts.ini
cat inventory/hosts.ini

# Check all.yml
cat inventory/group_vars/all.yml
```

**Verify:**
- IP addresses match your infrastructure (240-244)
- SSH key path is correct (`ansible_ssh_private_key_file`)
- SSH user is correct (`ansible_user=ubuntu`)
- Network settings match your environment (gateway, DNS)

---

## Step 2: Test Ansible Connectivity

Test that Ansible can reach all nodes:

```bash
cd ~/homelab-devops/ansible

# Test ping to all nodes
ansible all -m ping -i inventory/hosts.ini
```

**Expected Output:**
```
k8s-master | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
k8s-worker-01 | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
k8s-worker-02 | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
k8s-worker-03 | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
k8s-worker-04 | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
```

### Troubleshooting Connectivity Issues

**If connectivity fails:**

1. **Check SSH key permissions:**
   ```bash
   chmod 600 ~/.ssh/proxmox_key
   ls -l ~/.ssh/proxmox_key
   ```

2. **Test manual SSH:**
   ```bash
   ssh -i ~/.ssh/proxmox_key ubuntu@192.168.1.240
   ```

3. **Verify node IP addresses are reachable:**
   ```bash
   ping -c 3 192.168.1.240
   ping -c 3 192.168.1.241
   # ... etc
   ```

4. **Check inventory file syntax:**
   ```bash
   ansible-inventory -i inventory/hosts.ini --list
   ```

5. **Verify SSH config:**
   - Ensure SSH keys are installed on all nodes
   - Check that ubuntu user exists
   - Verify SSH service is running: `systemctl status ssh`

---

## Step 3: Network Setup Playbook (Dry Run)

Before making changes, test the playbook in check mode:

```bash
cd ~/homelab-devops/ansible

# Syntax check
ansible-playbook playbooks/01-network-setup.yml --syntax-check

# Check mode (dry run - no changes)
ansible-playbook playbooks/01-network-setup.yml --check -v
```

**What to look for:**
- ✓ No syntax errors
- ✓ Playbook would make expected changes
- ✓ No failed tasks
- ✓ Tasks show what WOULD change (green/yellow)

**Expected tasks to show changes:**
- Update /etc/hosts file
- Update /etc/cloud/templates/hosts.debian.tmpl
- Set hostname
- Configure UFW firewall rules
- Enable UFW firewall

---

## Step 4: Network Setup Playbook (Actual Execution)

Now run the playbook for real:

```bash
cd ~/homelab-devops/ansible

# Run the playbook
ansible-playbook playbooks/01-network-setup.yml -v
```

**Monitor output for:**
- Tasks completing successfully (green)
- Changes being applied (yellow/changed)
- No failed tasks (red)
- Recap shows: ok, changed, unreachable=0, failed=0

**What this playbook does:**
1. **Network configuration role:**
   - Updates /etc/hosts on all nodes with cluster hostnames
   - Configures /etc/cloud/templates/hosts.debian.tmpl for persistence
   - Sets proper hostnames on each node

2. **Firewall role:**
   - Installs UFW (Ubuntu Firewall)
   - Configures firewall rules:
     - Allow SSH (port 22) from anywhere
     - Allow cluster traffic between nodes (all ports)
     - Allow Kubernetes API (port 6443)
     - Allow etcd (ports 2379-2380)
     - Allow Kubernetes node ports (30000-32767)
   - Enables UFW firewall

**Playbook execution time:** Approximately 2-3 minutes for 5 nodes

---

## Step 5: Verify Network Configuration

### Method 1: Using Automated Network Test Script

```bash
# Copy test script to master node
scp scripts/network/test-network.sh ubuntu@192.168.1.240:/home/ubuntu/

# SSH into master
ssh -i ~/.ssh/proxmox_key ubuntu@192.168.1.240

# Run comprehensive network tests
chmod +x test-network.sh
./test-network.sh
```

**Expected results:**
```
=== Network Configuration Test Results ===

✓ Ping test: k8s-master [OK]
✓ Ping test: k8s-worker-01 [OK]
✓ Ping test: k8s-worker-02 [OK]
✓ Ping test: k8s-worker-03 [OK]
✓ Ping test: k8s-worker-04 [OK]

✓ SSH connectivity: k8s-master [OK]
✓ SSH connectivity: k8s-worker-01 [OK]
✓ SSH connectivity: k8s-worker-02 [OK]
✓ SSH connectivity: k8s-worker-03 [OK]
✓ SSH connectivity: k8s-worker-04 [OK]

✓ Hostname resolution: k8s-master → 192.168.1.240 [OK]
✓ Hostname resolution: k8s-worker-01 → 192.168.1.241 [OK]
✓ Hostname resolution: k8s-worker-02 → 192.168.1.242 [OK]
✓ Hostname resolution: k8s-worker-03 → 192.168.1.243 [OK]
✓ Hostname resolution: k8s-worker-04 → 192.168.1.244 [OK]

✓ Internet connectivity [OK]
✓ DNS resolution [OK]
✓ Firewall status: active [OK]

All tests passed! Network is properly configured.
```

### Method 2: Manual Verification

**Test hostname resolution:**
```bash
# From any cluster node
getent hosts k8s-master
getent hosts k8s-worker-01
getent hosts k8s-worker-02
getent hosts k8s-worker-03
getent hosts k8s-worker-04
```

**Expected output:**
```
192.168.1.240   k8s-master
192.168.1.241   k8s-worker-01
192.168.1.242   k8s-worker-02
192.168.1.243   k8s-worker-03
192.168.1.244   k8s-worker-04
```

**Check firewall status:**
```bash
sudo ufw status verbose
```

**Expected output:**
```
Status: active
Logging: on (low)

To                         Action      From
--                         ------      ----
22/tcp                     ALLOW IN    Anywhere
6443/tcp                   ALLOW IN    Anywhere
2379:2380/tcp              ALLOW IN    Anywhere
30000:32767/tcp            ALLOW IN    Anywhere
Anywhere                   ALLOW IN    192.168.1.240
Anywhere                   ALLOW IN    192.168.1.241
Anywhere                   ALLOW IN    192.168.1.242
Anywhere                   ALLOW IN    192.168.1.243
Anywhere                   ALLOW IN    192.168.1.244
```

**Check /etc/hosts persistence template:**
```bash
cat /etc/cloud/templates/hosts.debian.tmpl
```

**Should contain:**
```
# Kubernetes cluster hosts
192.168.1.240 k8s-master
192.168.1.241 k8s-worker-01
192.168.1.242 k8s-worker-02
192.168.1.243 k8s-worker-03
192.168.1.244 k8s-worker-04
```

**Verify hostname:**
```bash
hostname
hostname -f
```

---

## Step 6: Test Idempotency

Ansible playbooks should be idempotent - running them multiple times should not make changes after the first run.

```bash
cd ~/homelab-devops/ansible

# Run the playbook again
ansible-playbook playbooks/01-network-setup.yml -v
```

**Expected behavior:**
- All tasks show "ok" (green)
- Changed count = 0
- Recap: ok=X, changed=0, unreachable=0, failed=0

**This confirms:**
- Playbook is properly idempotent
- No unnecessary changes on subsequent runs
- Configuration is stable

---

## Step 7: Test Common System Role

Test the prerequisites playbook which uses the common system role:

```bash
cd ~/homelab-devops/ansible

# Run the prerequisites playbook
ansible-playbook playbooks/03-kubernetes-prereqs.yml -v
```

**What this playbook does (common role):**
1. Updates apt cache
2. Installs essential packages (curl, wget, vim, htop, etc.)
3. Configures timezone (UTC)
4. Disables swap (required for Kubernetes)
5. Sets kernel parameters for Kubernetes:
   - Enable IP forwarding
   - Enable bridge netfilter
   - Configure iptables for bridge traffic
6. Loads kernel modules:
   - overlay (for container storage)
   - br_netfilter (for bridge networking)

**Expected execution time:** 5-7 minutes (includes apt update/upgrade)

### Verification Commands

**Check swap is disabled:**
```bash
ansible all -a "swapon --show" -i inventory/hosts.ini --become
```
**Expected:** Empty output (no swap enabled)

**Check kernel parameters:**
```bash
ansible all -a "sysctl net.ipv4.ip_forward" -i inventory/hosts.ini --become
ansible all -a "sysctl net.bridge.bridge-nf-call-iptables" -i inventory/hosts.ini --become
```
**Expected:**
```
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-iptables = 1
```

**Check kernel modules loaded:**
```bash
ansible all -a "lsmod | grep overlay" -i inventory/hosts.ini --become
ansible all -a "lsmod | grep br_netfilter" -i inventory/hosts.ini --become
```
**Expected:** Modules listed in output

**Check sysctl configuration persists:**
```bash
ansible all -a "cat /etc/sysctl.d/99-kubernetes.conf" -i inventory/hosts.ini --become
```
**Expected:** File contains Kubernetes kernel parameters

**Check modules load at boot:**
```bash
ansible all -a "cat /etc/modules-load.d/k8s.conf" -i inventory/hosts.ini --become
```
**Expected:** File contains overlay and br_netfilter

---

## Step 8: Document Testing Results

Create a test results document:

```bash
cd ~/homelab-devops
```

Create file: `docs/testing/ansible-test-results.md`

**Use this template:**

```markdown
# Ansible Playbook Testing Results

**Date:** [Current Date]
**Tester:** Marc Massoteau
**Environment:** Proxmox 8.x with 5 Ubuntu 22.04 VMs

## Infrastructure Details

| Component | Details |
|-----------|---------|
| Proxmox Host | 192.168.1.222 |
| Master Node | k8s-master (192.168.1.240) |
| Worker Nodes | k8s-worker-01 to 04 (192.168.1.241-244) |
| OS | Ubuntu 22.04 LTS |
| Ansible Version | [Your version] |
| Python Version | [Your version] |

## Test Summary

| Test | Playbook/Command | Status | Execution Time | Notes |
|------|------------------|--------|----------------|-------|
| Connectivity | `ansible all -m ping` | ✅ Pass | <1s | All 5 nodes reachable |
| Network Setup (Syntax) | `--syntax-check` | ✅ Pass | <1s | No syntax errors |
| Network Setup (Dry Run) | `--check` | ✅ Pass | ~30s | No errors, changes identified |
| Network Setup (Execution) | `01-network-setup.yml` | ✅ Pass | ~2m | All tasks completed |
| Network Verification | `test-network.sh` | ✅ Pass | ~10s | All tests passed |
| Idempotency Test | `01-network-setup.yml` (2nd run) | ✅ Pass | ~1m | No changes (ok) |
| Common Role | `03-kubernetes-prereqs.yml` | ✅ Pass | ~6m | System prepared for K8s |
| Swap Disabled | `swapon --show` | ✅ Pass | <1s | No swap active |
| Kernel Parameters | `sysctl` verification | ✅ Pass | <1s | All parameters correct |
| Kernel Modules | `lsmod` verification | ✅ Pass | <1s | overlay, br_netfilter loaded |

## Detailed Results

### 1. Connectivity Test
```
[Paste output from: ansible all -m ping]
```

### 2. Network Setup Playbook
```
[Paste key output sections]
```

**Changes Applied:**
- /etc/hosts updated on all 5 nodes
- /etc/cloud/templates/hosts.debian.tmpl configured
- Hostnames set correctly
- UFW firewall installed and configured
- Firewall rules applied

### 3. Network Verification
```
[Paste output from: test-network.sh]
```

**Verification Results:**
- ✓ All ping tests passed
- ✓ All SSH connectivity tests passed
- ✓ All hostname resolution tests passed
- ✓ Internet connectivity working
- ✓ DNS resolution working
- ✓ Firewall active and configured

### 4. Idempotency Test
```
PLAY RECAP
k8s-master     : ok=10  changed=0  unreachable=0  failed=0
k8s-worker-01  : ok=10  changed=0  unreachable=0  failed=0
k8s-worker-02  : ok=10  changed=0  unreachable=0  failed=0
k8s-worker-03  : ok=10  changed=0  unreachable=0  failed=0
k8s-worker-04  : ok=10  changed=0  unreachable=0  failed=0
```

**Result:** ✅ Idempotent - No changes on second run

### 5. Common System Role Test
```
[Paste output from: ansible-playbook playbooks/03-kubernetes-prereqs.yml]
```

**Verification Results:**
- ✓ Swap disabled on all nodes
- ✓ Kernel parameter net.ipv4.ip_forward = 1
- ✓ Kernel parameter net.bridge.bridge-nf-call-iptables = 1
- ✓ overlay module loaded
- ✓ br_netfilter module loaded
- ✓ Configuration files persist across reboots

## Issues Found

[Document any issues encountered during testing]

**Example:**
- None

## Improvements Needed

[Document any improvements or enhancements identified]

**Example:**
- Consider adding more verbose output for firewall configuration
- Add task to verify DNS resolution in the playbook
- Consider adding handlers for service restarts

## Security Observations

- SSH configured with key-based authentication
- UFW firewall active on all nodes
- Cluster traffic restricted to known IPs
- No unnecessary ports exposed

## Performance Notes

- Network setup playbook: ~2 minutes for 5 nodes
- Common role playbook: ~6 minutes for 5 nodes (includes apt upgrade)
- Total testing time: ~30 minutes including verification

## Next Steps

1. ✅ Phase A Complete - All playbooks tested and working
2. 📝 Phase B - Update articles with GitHub repository references
3. 🔐 Phase C - Implement security-hardening role
4. 🚀 Ready for Kubernetes installation (Article 5)

## Rollback Testing

**Snapshot taken:** [before-ansible-test] at [timestamp]

**Rollback procedure verified:**
```bash
# On Proxmox host
for VMID in 240 241 242 243 244; do
  qm stop $VMID
  qm rollback $VMID before-ansible-test
  qm start $VMID
done
```

**Result:** Not needed - all tests passed

## Conclusion

All Ansible playbooks are working correctly on the actual infrastructure. The automation is:
- ✅ Functional - All playbooks execute successfully
- ✅ Idempotent - Safe to run multiple times
- ✅ Reliable - Consistent results across all nodes
- ✅ Complete - Network and system prerequisites configured

The infrastructure is ready for Kubernetes installation (Article 5).

---

**Signed:** Marc Massoteau
**Date:** [Date]
```

---

## Optional: Snapshot and Rollback Testing

### Take Snapshot Before Testing

```bash
# SSH to Proxmox host
ssh root@192.168.1.222

# Navigate to scripts directory
cd /path/to/scripts/proxmox

# Take snapshot of all VMs
./snapshot-all.sh "before-ansible-phase-a" "Before Phase A Ansible testing"
```

**Verify snapshots created:**
```bash
for VMID in 240 241 242 243 244; do
  echo "=== VM $VMID snapshots ==="
  qm listsnapshot $VMID
done
```

### Rollback if Needed

If something goes wrong during testing:

```bash
# Stop all VMs
for VMID in 240 241 242 243 244; do
  qm stop $VMID
done

# Wait for VMs to stop
sleep 10

# Rollback to snapshot
for VMID in 240 241 242 243 244; do
  qm rollback $VMID before-ansible-phase-a
done

# Start all VMs
for VMID in 240 241 242 243 244; do
  qm start $VMID
done

# Wait for VMs to boot
sleep 30

# Test connectivity
ansible all -m ping -i /path/to/ansible/inventory/hosts.ini
```

---

## Troubleshooting Guide

### Issue: "Permission denied (publickey)"

**Solution:**
```bash
# Verify SSH key exists
ls -l ~/.ssh/proxmox_key

# Set correct permissions
chmod 600 ~/.ssh/proxmox_key

# Test manual SSH
ssh -i ~/.ssh/proxmox_key ubuntu@192.168.1.240

# If still fails, ensure key is installed on node
ssh-copy-id -i ~/.ssh/proxmox_key.pub ubuntu@192.168.1.240
```

### Issue: "Failed to connect to the host via ssh"

**Solution:**
```bash
# Verify nodes are reachable
ping -c 3 192.168.1.240

# Check SSH service on node
ssh ubuntu@192.168.1.240 'systemctl status ssh'

# Verify inventory file has correct IPs
cat ansible/inventory/hosts.ini
```

### Issue: "Could not find role 'network-config'"

**Solution:**
```bash
# Verify roles directory structure
ls -la ansible/roles/

# Should see:
# - network-config/
# - firewall/
# - common/

# Check role path in ansible.cfg
cat ansible/ansible.cfg | grep roles_path
```

### Issue: UFW blocks SSH and locks you out

**Prevention:**
```bash
# Always ensure SSH rule is added first
sudo ufw allow 22/tcp
sudo ufw enable

# If locked out, use Proxmox console:
# 1. Open VM console in Proxmox web UI
# 2. Login as ubuntu
# 3. sudo ufw disable
# 4. sudo ufw allow 22/tcp
# 5. sudo ufw enable
```

### Issue: Kernel modules don't load

**Solution:**
```bash
# Check if modules exist
ls /lib/modules/$(uname -r)/kernel/net/netfilter/

# Load manually
sudo modprobe overlay
sudo modprobe br_netfilter

# Verify
lsmod | grep overlay
lsmod | grep br_netfilter

# Make persistent
echo "overlay" | sudo tee -a /etc/modules-load.d/k8s.conf
echo "br_netfilter" | sudo tee -a /etc/modules-load.d/k8s.conf
```

---

## Success Criteria

Phase A is complete when:

- ✅ Ansible can connect to all 5 nodes
- ✅ Network setup playbook runs without errors
- ✅ All network tests pass
- ✅ Playbook is idempotent (no changes on 2nd run)
- ✅ Common system role configures nodes correctly
- ✅ Swap is disabled on all nodes
- ✅ Kernel parameters are set correctly
- ✅ Kernel modules load properly
- ✅ Firewall is configured and active
- ✅ Test results are documented

---

## Next Phase

Once Phase A is complete and documented:

**Phase B:** Update articles with GitHub repository references
- Standardize GitHub URLs
- Add code references to Articles 0-3
- Add automation notes
- Update footers with repository links

---

*This testing guide is part of the Homelab DevOps Pipeline project.*
*Repository: https://github.com/marcmassoteau-jpg/massoteau-homelab-devops*
