# Ansible Role: containerd

This role installs and configures containerd container runtime for Kubernetes.

## Description

Installs containerd with systemd cgroup driver configuration, which is required for Kubernetes. The role also configures necessary kernel modules and parameters for container networking.

## Requirements

- Ubuntu 22.04 LTS
- Root or sudo access
- Internet connectivity for package installation

## Role Variables

Available variables are listed below, along with default values (see `defaults/main.yml`):

### containerd Configuration

```yaml
# containerd version (empty = latest from repos)
containerd_version: ""

# Configuration directories
containerd_config_dir: "/etc/containerd"
containerd_state_dir: "/var/lib/containerd"

# Use systemd cgroup driver (required for Kubernetes)
containerd_use_systemd_cgroup: true

# Sandbox (pause) image for Kubernetes
containerd_sandbox_image: "registry.k8s.io/pause:3.9"
```

### Runtime Configuration

```yaml
# Snapshotter for container images
containerd_snapshotter: "overlayfs"

# Container runtime
containerd_runtime: "runc"

# Metrics endpoint
containerd_metrics_address: "127.0.0.1"
containerd_metrics_port: 1338
```

### Kernel Configuration

```yaml
# Kernel modules to load
containerd_kernel_modules:
  - overlay
  - br_netfilter

# Kernel parameters for Kubernetes
containerd_kernel_params:
  - { name: 'net.bridge.bridge-nf-call-iptables', value: '1' }
  - { name: 'net.bridge.bridge-nf-call-ip6tables', value: '1' }
  - { name: 'net.ipv4.ip_forward', value: '1' }
```

## Dependencies

None.

## Example Playbook

```yaml
---
- name: Install containerd on Kubernetes nodes
  hosts: all
  become: true
  roles:
    - containerd
```

### With Custom Variables

```yaml
---
- name: Install containerd with custom configuration
  hosts: all
  become: true
  roles:
    - role: containerd
      vars:
        containerd_sandbox_image: "registry.k8s.io/pause:3.10"
        containerd_metrics_port: 9338
```

## What This Role Does

1. **Loads Kernel Modules**
   - Loads `overlay` and `br_netfilter` modules
   - Configures modules to load at boot via `/etc/modules-load.d/containerd.conf`

2. **Configures Kernel Parameters**
   - Enables IP forwarding for Kubernetes
   - Configures bridge netfilter for iptables
   - Sets parameters in `/etc/sysctl.d/99-kubernetes.conf`

3. **Installs containerd**
   - Installs containerd and runc packages from Ubuntu repositories
   - Creates configuration directory

4. **Configures containerd**
   - Generates configuration with systemd cgroup driver
   - Sets Kubernetes sandbox (pause) image
   - Configures CNI plugin directories
   - Enables metrics endpoint

5. **Starts containerd Service**
   - Enables containerd to start at boot
   - Starts the containerd service
   - Verifies containerd is running

## Verification

After running this role, verify containerd is working:

```bash
# Check containerd service status
sudo systemctl status containerd

# Verify containerd version
sudo ctr version

# Check kernel modules are loaded
lsmod | grep -E 'overlay|br_netfilter'

# Verify kernel parameters
sysctl net.ipv4.ip_forward
sysctl net.bridge.bridge-nf-call-iptables
```

Expected output:
- containerd service: `active (running)`
- Kernel modules: overlay and br_netfilter loaded
- IP forwarding: `net.ipv4.ip_forward = 1`
- Bridge netfilter: `net.bridge.bridge-nf-call-iptables = 1`

## Tags

Available tags for selective execution:

- `containerd` - All containerd tasks
- `kernel` - Kernel module and parameter configuration
- `kubernetes` - Kubernetes-specific configuration
- `packages` - Package installation
- `config` - containerd configuration
- `service` - Service management
- `verify` - Verification tasks

### Usage Examples

```bash
# Run only kernel configuration
ansible-playbook playbook.yml --tags kernel

# Run only package installation
ansible-playbook playbook.yml --tags packages

# Skip verification
ansible-playbook playbook.yml --skip-tags verify
```

## Troubleshooting

### containerd service fails to start

Check the service logs:
```bash
sudo journalctl -u containerd -n 50
```

Verify configuration syntax:
```bash
sudo containerd config dump
```

### Kernel modules not loading

Manually load modules:
```bash
sudo modprobe overlay
sudo modprobe br_netfilter
```

Check if modules are available:
```bash
modinfo overlay
modinfo br_netfilter
```

### Kernel parameters not applied

Reload sysctl configuration:
```bash
sudo sysctl --system
```

Verify specific parameters:
```bash
sudo sysctl -a | grep -E 'ip_forward|bridge-nf-call'
```

## Important Notes

- **Systemd Cgroup Driver**: This role configures containerd to use the systemd cgroup driver, which is required for Kubernetes to work properly alongside systemd.

- **Kernel Parameters**: The role sets `net.ipv4.ip_forward=1` which is required for Kubernetes pod networking but may affect security posture. This is intentional for Kubernetes.

- **CNI Plugins**: This role configures CNI plugin directories but does not install CNI plugins. Those are typically installed by Kubernetes or separately.

- **Compatibility**: Tested with Ubuntu 22.04 LTS and Kubernetes 1.29+.

## License

MIT

## Author

Marc Massoteau (Homelab DevOps Pipeline series)

## References

- [containerd Documentation](https://containerd.io/docs/)
- [Kubernetes Container Runtimes](https://kubernetes.io/docs/setup/production-environment/container-runtimes/)
- [containerd systemd cgroup driver](https://kubernetes.io/docs/setup/production-environment/container-runtimes/#containerd-systemd)
