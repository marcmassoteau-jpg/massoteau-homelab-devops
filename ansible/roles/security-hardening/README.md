# Security Hardening Role

This Ansible role provides comprehensive security hardening for Ubuntu servers in a Kubernetes cluster environment.

## Features

- **SSH Hardening**
  - Disable root login
  - Disable password authentication
  - Configure secure SSH settings
  - Customizable SSH port

- **fail2ban Configuration**
  - Protect against brute-force attacks
  - Automatic IP banning
  - Email notifications
  - Configurable ban times and thresholds

- **Kernel Security Parameters**
  - Network security settings
  - IP forwarding configuration
  - Protection against common attacks
  - SYN flood protection

- **Automatic Security Updates**
  - Unattended upgrades for security patches
  - Optional automatic reboot
  - Email notifications

- **Audit Logging**
  - System file monitoring
  - SSH access logging
  - Sudo command auditing
  - Network configuration changes

- **AppArmor**
  - Enable security profiles
  - Application confinement

- **System Resource Limits**
  - Configure file descriptor limits
  - Process limits

## Requirements

- Ansible 2.9 or higher
- Ubuntu 20.04 or 22.04
- Root or sudo access on target hosts

## Role Variables

### SSH Configuration

```yaml
security_ssh_port: 22
security_ssh_permit_root_login: false
security_ssh_password_authentication: false
security_ssh_allow_users: []  # Restrict SSH access to specific users
```

### fail2ban Configuration

```yaml
security_fail2ban_enabled: true
security_fail2ban_bantime: 3600        # Ban duration in seconds
security_fail2ban_findtime: 600        # Time window for counting failures
security_fail2ban_maxretry: 5          # Number of failures before ban
security_fail2ban_destemail: "root@localhost"
```

### Automatic Updates

```yaml
security_unattended_upgrades: true
security_auto_reboot: false            # Automatically reboot if required
security_auto_reboot_time: "03:00"     # Time for automatic reboots
```

### Audit Logging

```yaml
security_auditd_enabled: true
```

### Kernel Parameters

```yaml
security_kernel_params:
  - { name: 'net.ipv4.conf.all.rp_filter', value: '1' }
  - { name: 'net.ipv4.tcp_syncookies', value: '1' }
  # ... additional parameters
```

### Resource Limits

```yaml
security_limits:
  - { domain: '*', type: 'soft', item: 'nofile', value: '65536' }
  - { domain: '*', type: 'hard', item: 'nofile', value: '65536' }
```

## Dependencies

This role requires the `ansible.posix` collection for the `sysctl` module:

```bash
ansible-galaxy collection install ansible.posix
```

## Example Playbook

```yaml
---
- name: Security hardening for Kubernetes cluster
  hosts: k8s_cluster
  become: true
  gather_facts: true

  roles:
    - security-hardening

  # Optional: Override variables
  vars:
    security_ssh_port: 22
    security_fail2ban_enabled: true
    security_unattended_upgrades: true
    security_auto_reboot: false
```

## Example with Custom Variables

```yaml
---
- name: Security hardening with custom settings
  hosts: k8s_cluster
  become: true
  gather_facts: true

  roles:
    - role: security-hardening
      vars:
        security_ssh_port: 22
        security_ssh_allow_users:
          - ubuntu
          - admin
        security_fail2ban_bantime: 7200
        security_fail2ban_maxretry: 3
        security_auto_reboot: true
        security_auto_reboot_time: "02:00"
```

## Usage

### 1. Add Role to Playbook

Create or update `playbooks/02-security-hardening.yml`:

```yaml
---
- name: Security hardening for Kubernetes cluster
  hosts: k8s_cluster
  become: true
  gather_facts: true

  roles:
    - security-hardening
```

### 2. Run the Playbook

```bash
# Check mode (dry run)
ansible-playbook playbooks/02-security-hardening.yml --check

# Execute
ansible-playbook playbooks/02-security-hardening.yml
```

### 3. Run Specific Tags

```bash
# Only configure SSH
ansible-playbook playbooks/02-security-hardening.yml --tags ssh

# Only configure fail2ban
ansible-playbook playbooks/02-security-hardening.yml --tags fail2ban

# Only kernel parameters
ansible-playbook playbooks/02-security-hardening.yml --tags kernel
```

## Available Tags

- `security` - All security tasks
- `packages` - Package installation
- `ssh` - SSH configuration
- `fail2ban` - fail2ban configuration
- `kernel` - Kernel parameter configuration
- `limits` - Resource limits
- `updates` - Unattended upgrades
- `audit` - Audit logging
- `apparmor` - AppArmor configuration
- `sudo` - Sudo configuration
- `services` - Service management
- `permissions` - File permissions
- `summary` - Display summary

## Verification

### Check SSH Configuration

```bash
# Verify SSH configuration
ansible all -m command -a "sshd -T" --become

# Check SSH service status
ansible all -m systemd -a "name=ssh state=started" --become
```

### Check fail2ban Status

```bash
# Check fail2ban status
ansible all -m command -a "fail2ban-client status" --become

# Check SSH jail status
ansible all -m command -a "fail2ban-client status sshd" --become
```

### Check Kernel Parameters

```bash
# Verify kernel parameters
ansible all -m command -a "sysctl net.ipv4.ip_forward" --become
ansible all -m command -a "sysctl net.ipv4.tcp_syncookies" --become
```

### Check Audit Rules

```bash
# List audit rules
ansible all -m command -a "auditctl -l" --become
```

## Post-Hardening Checks

After running the role, verify:

1. **SSH Access Still Works**
   ```bash
   ssh ubuntu@192.168.1.240
   ```

2. **fail2ban is Running**
   ```bash
   sudo systemctl status fail2ban
   ```

3. **Unattended Upgrades Configured**
   ```bash
   cat /etc/apt/apt.conf.d/20auto-upgrades
   ```

4. **Audit Logging Active**
   ```bash
   sudo systemctl status auditd
   ```

## Security Considerations

- **SSH Keys**: Ensure SSH keys are properly distributed before disabling password authentication
- **Backup Access**: Always have an alternative access method (console, out-of-band management)
- **Testing**: Test in a non-production environment first
- **Monitoring**: Monitor fail2ban logs for legitimate lockouts

## Troubleshooting

### Locked Out of SSH

If you get locked out:

1. Use Proxmox console to access the VM
2. Edit `/etc/ssh/sshd_config` and temporarily enable password auth
3. Restart SSH: `sudo systemctl restart ssh`
4. Fix SSH key issues
5. Re-run the playbook

### fail2ban Not Starting

```bash
# Check fail2ban logs
sudo journalctl -u fail2ban -n 50

# Test configuration
sudo fail2ban-client -t

# Check jail configuration
sudo fail2ban-client status
```

### Audit Rules Not Loading

```bash
# Check auditd status
sudo systemctl status auditd

# Reload rules
sudo augenrules --load

# Check for errors
sudo ausearch -m avc
```

## License

MIT

## Author

Marc Massoteau - Homelab DevOps Pipeline Series
