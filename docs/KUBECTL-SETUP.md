# Local kubectl and Kubernetes Dashboard Setup

This guide explains how to use kubectl from your local machine and access the Kubernetes Dashboard UI.

## Overview

Your Kubernetes cluster runs on VMs accessible through your Proxmox server. To access it from your local machine, we use:

1. **SSH Tunnel**: Routes traffic through Proxmox to the k8s-master node
2. **kubectl**: Configured to use the tunnel (localhost:6443 → k8s-master:6443)
3. **Kubernetes Dashboard**: Web UI accessible via port-forward

## Network Architecture

```
Your Mac (localhost:6443)
    ↓ SSH Tunnel
Proxmox Server (192.168.1.222)
    ↓ SSH Jump
k8s-master (192.168.1.240:6443)
```

## Prerequisites

✓ kubectl installed (v1.32.2)
✓ kubeconfig at `~/.kube/config`
✓ SSH key at `~/.ssh/proxmox_key`
✓ SSH tunnel script at `scripts/k8s-tunnel.sh`

## Managing the SSH Tunnel

The SSH tunnel must be running for kubectl to work.

### Start the Tunnel

```bash
./scripts/k8s-tunnel.sh start
```

### Check Tunnel Status

```bash
./scripts/k8s-tunnel.sh status
```

### Stop the Tunnel

```bash
./scripts/k8s-tunnel.sh stop
```

### Restart the Tunnel

```bash
./scripts/k8s-tunnel.sh restart
```

## Using kubectl

Once the tunnel is running, use kubectl normally:

```bash
# View cluster nodes
kubectl get nodes

# View all pods across all namespaces
kubectl get pods -A

# View cluster info
kubectl cluster-info

# View resource usage
kubectl top nodes
kubectl top pods -A

# View deployments
kubectl get deployments -A

# View services
kubectl get svc -A
```

## Accessing the Kubernetes Dashboard

### 1. Start Port Forward (if not already running)

The port forward should already be running in the background. To verify:

```bash
ps aux | grep "port-forward.*kubernetes-dashboard"
```

If not running, start it:

```bash
kubectl -n kubernetes-dashboard port-forward svc/kubernetes-dashboard 8443:443 &
```

### 2. Open Dashboard in Browser

Navigate to:

```
https://localhost:8443
```

**Note**: You'll see a security warning because the certificate is self-signed. Click "Advanced" and proceed.

### 3. Get Login Token

The dashboard requires token authentication. Your token is saved at:

```bash
cat ~/k8s-dashboard-token.txt
```

Or generate a new token:

```bash
kubectl -n kubernetes-dashboard create token admin-user --duration=8760h
```

### 4. Login

1. Select "Token" authentication method
2. Paste the token from above
3. Click "Sign In"

You now have full admin access to the cluster via the dashboard!

## Dashboard Features

The Kubernetes Dashboard provides:

- **Overview**: Cluster-wide resource status
- **Workloads**: Deployments, ReplicaSets, Pods, Jobs, etc.
- **Services**: Services, Ingresses, Network Policies
- **Config & Storage**: ConfigMaps, Secrets, PVCs
- **RBAC**: Roles, RoleBindings, ServiceAccounts
- **Logs & Exec**: View logs, exec into pods
- **Resource Metrics**: CPU/Memory usage graphs

## Troubleshooting

### kubectl: Connection Refused

Check if the SSH tunnel is running:

```bash
./scripts/k8s-tunnel.sh status
```

If not running, start it:

```bash
./scripts/k8s-tunnel.sh start
```

### kubectl: TLS Certificate Error

Ensure your kubeconfig has `insecure-skip-tls-verify: true`:

```bash
kubectl config view | grep insecure-skip-tls-verify
```

If not set:

```bash
kubectl config set-cluster kubernetes --insecure-skip-tls-verify=true
```

### Dashboard: Cannot Access localhost:8443

Check if port-forward is running:

```bash
ps aux | grep "port-forward.*kubernetes-dashboard"
```

If not running, start it:

```bash
kubectl -n kubernetes-dashboard port-forward svc/kubernetes-dashboard 8443:443 &
```

### Dashboard: Invalid Token

Generate a new token:

```bash
kubectl -n kubernetes-dashboard create token admin-user --duration=8760h > ~/k8s-dashboard-token.txt
```

### SSH Tunnel Dies Unexpectedly

The tunnel may drop if your network connection changes. Simply restart it:

```bash
./scripts/k8s-tunnel.sh restart
```

## Automatic Tunnel Startup

To automatically start the tunnel when needed, add this to your `~/.zshrc` or `~/.bashrc`:

```bash
# Auto-start k8s tunnel for kubectl
alias kubectl='(pgrep -f "ssh.*6443.*192.168.1.240" > /dev/null || ~/Documents/Project/scripts/k8s-tunnel.sh start > /dev/null 2>&1) && command kubectl'
```

This checks if the tunnel is running before each kubectl command and starts it if needed.

## Security Notes

- The tunnel uses SSH key authentication (`~/.ssh/proxmox_key`)
- TLS verification is disabled for the local tunnel (acceptable for homelab)
- Dashboard token provides full cluster-admin access
- Token expires after 1 year (8760 hours)
- Keep your token secure - it provides full cluster access

## Quick Reference

| Task | Command |
|------|---------|
| Start tunnel | `./scripts/k8s-tunnel.sh start` |
| Check tunnel status | `./scripts/k8s-tunnel.sh status` |
| Stop tunnel | `./scripts/k8s-tunnel.sh stop` |
| Get nodes | `kubectl get nodes` |
| Get all pods | `kubectl get pods -A` |
| Open dashboard | `https://localhost:8443` |
| Get token | `cat ~/k8s-dashboard-token.txt` |
| Port-forward dashboard | `kubectl -n kubernetes-dashboard port-forward svc/kubernetes-dashboard 8443:443` |

## Files Created

- `~/.kube/config` - kubectl configuration
- `~/.kube/config.backup` - Original kubeconfig backup
- `~/k8s-dashboard-token.txt` - Dashboard access token
- `~/k8s-dashboard-portforward.log` - Port-forward log file
- `scripts/k8s-tunnel.sh` - Tunnel management script
- `.ssh/config` - SSH tunnel configuration (k8s-api-tunnel host)

## Next Steps

Now that you have local kubectl access, you can:

1. Deploy applications using kubectl or Helm
2. Monitor cluster resources via the dashboard
3. View logs and troubleshoot pods
4. Manage ArgoCD, GitLab, and other services
5. Test deployments locally before pushing to GitOps

Enjoy your Kubernetes cluster! 🚀
