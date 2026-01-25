## Ansible Role: kubernetes

This role installs Kubernetes packages (kubeadm, kubelet, kubectl) on Ubuntu 22.04 nodes in preparation for cluster initialization.

## Description

Installs Kubernetes components from the official Kubernetes package repository, pins package versions to prevent automatic updates, and enables the kubelet service. This role is part of the Kubernetes cluster setup process and should be run before initializing the cluster with kubeadm.

## Requirements

- Ubuntu 22.04 LTS
- Root or sudo access
- Internet connectivity for package installation
- containerd already installed and running
- Swap disabled on all nodes
- Required kernel modules loaded (br_netfilter, overlay)

**Prerequisites roles:**
- `common` - Disables swap and loads kernel modules
- `containerd` - Installs container runtime

## Role Variables

Available variables are listed below, along with default values (see `defaults/main.yml`):

### Kubernetes Version

```yaml
# Kubernetes version to install (major.minor)
kubernetes_version: "1.29"

# Specific package version
kubernetes_version_rhel_package: "1.29.1"
```

### Packages Configuration

```yaml
# Kubernetes packages to install
kubernetes_packages:
  - name: kubelet
    state: present
  - name: kubectl
    state: present
  - name: kubeadm
    state: present

# Pin packages to prevent automatic updates
kubernetes_pin_packages: true
kubernetes_pin_priority: 1000
```

### Repository Configuration

```yaml
# Kubernetes APT repository
kubernetes_apt_repository: "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v{{ kubernetes_version }}/deb/ /"
kubernetes_apt_key_url: "https://pkgs.k8s.io/core:/stable:/v{{ kubernetes_version }}/deb/Release.key"
kubernetes_apt_keyring_path: "/etc/apt/keyrings/kubernetes-apt-keyring.gpg"
```

### Kubelet Configuration

```yaml
# Kubelet extra arguments (optional)
kubernetes_kubelet_extra_args: ""
kubernetes_kubelet_config_file: "/etc/default/kubelet"

# Kubelet service settings
kubernetes_kubelet_enabled: true
kubernetes_kubelet_state: started
```

### Pre-flight Checks

```yaml
# Enable pre-flight checks
kubernetes_check_containerd: true
kubernetes_check_swap: true
kubernetes_check_kernel_modules: true
```

## Dependencies

This role depends on:
- **common** role - Must be run first to disable swap and load kernel modules
- **containerd** role - Must be run first to install container runtime

## Example Playbook

### Basic Usage

```yaml
---
- name: Install Kubernetes packages on all nodes
  hosts: k8s_cluster
  become: true
  roles:
    - common
    - containerd
    - kubernetes
```

### With Custom Version

```yaml
---
- name: Install specific Kubernetes version
  hosts: k8s_cluster
  become: true
  roles:
    - role: kubernetes
      vars:
        kubernetes_version: "1.30"
        kubernetes_version_rhel_package: "1.30.0"
```

### With Kubelet Arguments

```yaml
---
- name: Install Kubernetes with custom kubelet config
  hosts: k8s_cluster
  become: true
  roles:
    - role: kubernetes
      vars:
        kubernetes_kubelet_extra_args: "--node-ip={{ ansible_default_ipv4.address }}"
```

## What This Role Does

1. **Pre-flight Checks**
   - Verifies swap is disabled
   - Checks containerd is running
   - Validates required kernel modules are loaded
   - Fails early if prerequisites not met

2. **Repository Setup**
   - Installs prerequisite packages (apt-transport-https, curl, gpg)
   - Downloads Kubernetes GPG key
   - Adds official Kubernetes APT repository
   - Configures repository for specified version

3. **Package Installation**
   - Installs kubeadm (cluster bootstrapping tool)
   - Installs kubelet (node agent)
   - Installs kubectl (command-line tool)
   - Pins packages to prevent automatic updates

4. **Kubelet Configuration**
   - Creates kubelet configuration directory
   - Configures kubelet extra arguments (if specified)
   - Enables kubelet service

5. **Service Management**
   - Enables kubelet to start at boot
   - **Note:** kubelet will crash-loop until cluster is initialized with kubeadm init

## Verification

After running this role, verify Kubernetes is installed correctly:

### Check Package Versions

```bash
# Verify kubeadm version
kubeadm version

# Verify kubectl version
kubectl version --client

# Verify kubelet version
kubelet --version
```

Expected output:
```
kubeadm version: &version.Info{Major:"1", Minor:"29", ...}
Client Version: v1.29.1
Kubernetes v1.29.1
```

### Check Package Hold Status

```bash
# Verify packages are held (pinned)
apt-mark showhold | grep -E 'kubeadm|kubelet|kubectl'
```

Expected output:
```
kubeadm
kubectl
kubelet
```

### Check Kubelet Service

```bash
# Check kubelet service status
sudo systemctl status kubelet
```

**Expected behavior:**
- Service is enabled: `enabled`
- Service state: `activating` or `inactive` (will crash-loop until cluster init)
- This is **normal** before running `kubeadm init`

### Verify Repository

```bash
# Check Kubernetes repository
cat /etc/apt/sources.list.d/kubernetes.list

# Verify GPG key
ls -l /etc/apt/keyrings/kubernetes-apt-keyring.gpg
```

## Post-Installation Steps

After this role completes:

1. **On master node only:**
   ```bash
   # Initialize Kubernetes cluster
   sudo kubeadm init \
     --pod-network-cidr=10.244.0.0/16 \
     --apiserver-advertise-address=<master-ip>

   # Configure kubectl for user
   mkdir -p $HOME/.kube
   sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
   sudo chown $(id -u):$(id -g) $HOME/.kube/config
   ```

2. **Install CNI plugin (Calico):**
   ```bash
   kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml
   ```

3. **On worker nodes:**
   ```bash
   # Join cluster using token from master
   sudo kubeadm join <master-ip>:6443 \
     --token <token> \
     --discovery-token-ca-cert-hash sha256:<hash>
   ```

## Tags

Available tags for selective execution:

- `kubernetes` - All kubernetes tasks
- `preflight` - Pre-flight checks only
- `packages` - Package installation tasks
- `repository` - Repository setup tasks
- `config` - Configuration tasks
- `service` - Service management tasks
- `pin` - Package pinning tasks
- `verify` - Verification tasks

### Usage Examples

```bash
# Run only pre-flight checks
ansible-playbook playbook.yml --tags preflight

# Run only package installation
ansible-playbook playbook.yml --tags packages,repository

# Skip pre-flight checks (not recommended)
ansible-playbook playbook.yml --skip-tags preflight

# Run verification only
ansible-playbook playbook.yml --tags verify
```

## Troubleshooting

### Pre-flight Check Failures

**Swap is still enabled:**
```bash
# Error: "Swap is enabled. Kubernetes requires swap to be disabled."

# Solution: Run common role first
ansible-playbook playbooks/03-kubernetes-prereqs.yml --tags common
```

**containerd not running:**
```bash
# Error: "containerd is not running"

# Solution: Run containerd role first
ansible-playbook playbooks/03-kubernetes-prereqs.yml --tags containerd
```

**Kernel modules not loaded:**
```bash
# Error: "Required kernel modules (br_netfilter, overlay) are not loaded"

# Solution: Run containerd role which loads modules
ansible-playbook playbooks/03-kubernetes-prereqs.yml --tags containerd
```

### Repository Issues

**GPG key download fails:**
```bash
# Check internet connectivity
curl -I https://pkgs.k8s.io

# Manually download and inspect
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key
```

**Repository URL not accessible:**
```bash
# Verify repository configuration
cat /etc/apt/sources.list.d/kubernetes.list

# Test repository access
sudo apt update
```

### Package Installation Failures

**Packages not found:**
```bash
# Update apt cache
sudo apt update

# Search for available versions
apt-cache madison kubeadm
```

**Version mismatch:**
```bash
# Check installed versions
dpkg -l | grep -E 'kubeadm|kubelet|kubectl'

# Remove and reinstall if needed
sudo apt remove -y kubeadm kubelet kubectl
ansible-playbook playbook.yml --tags kubernetes
```

### Kubelet Service Issues

**Kubelet crash-looping:**

This is **expected behavior** before cluster initialization. The kubelet will continuously restart until you run `kubeadm init` on the master node.

Check logs to confirm it's waiting for cluster:
```bash
sudo journalctl -u kubelet -n 20
```

Expected message:
```
"Failed to run kubelet" err="failed to run Kubelet: could not init cloud provider"
```

This is normal and will resolve after `kubeadm init`.

**Kubelet not enabled:**
```bash
# Enable kubelet service
sudo systemctl enable kubelet

# Check status
sudo systemctl status kubelet
```

## Package Pinning

This role pins Kubernetes packages to prevent automatic updates, which could break the cluster. Kubernetes upgrades should be performed intentionally with proper testing.

### Check Pinned Packages

```bash
# Using apt-mark
apt-mark showhold

# Using dpkg
dpkg --get-selections | grep hold
```

### Unpin Packages (for upgrades)

```bash
# Unhold packages
sudo apt-mark unhold kubeadm kubelet kubectl

# Upgrade to specific version
sudo apt update
sudo apt install -y kubeadm=1.30.0-1.1 kubelet=1.30.0-1.1 kubectl=1.30.0-1.1

# Re-hold packages
sudo apt-mark hold kubeadm kubelet kubectl
```

## Important Notes

- **Kubelet Crash-Loop:** The kubelet service will crash-loop after installation until the cluster is initialized. This is expected and normal.

- **Version Pinning:** Packages are automatically held (pinned) to prevent accidental upgrades. Kubernetes clusters should be upgraded intentionally.

- **Prerequisites:** This role has strict prerequisites (swap disabled, containerd running, kernel modules loaded). Use pre-flight checks to validate.

- **Repository Updates:** Kubernetes changed repository URLs in September 2023. This role uses the new `pkgs.k8s.io` repository structure.

- **Cluster Initialization:** This role only installs packages. You must run `kubeadm init` separately on the master node to create the cluster.

- **CNI Plugin:** After cluster initialization, you must install a CNI plugin (like Calico) before worker nodes will become Ready.

## Compatibility

- **Tested on:** Ubuntu 22.04 LTS
- **Kubernetes versions:** 1.28, 1.29, 1.30
- **Container runtime:** containerd (with systemd cgroup driver)

## License

MIT

## Author

Marc Massoteau (Homelab DevOps Pipeline series)

## References

- [Kubernetes Installation Guide](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/)
- [Kubernetes Package Repository](https://kubernetes.io/blog/2023/08/15/pkgs-k8s-io-introduction/)
- [kubeadm Documentation](https://kubernetes.io/docs/reference/setup-tools/kubeadm/)
- [kubelet Configuration](https://kubernetes.io/docs/reference/command-line-tools-reference/kubelet/)
