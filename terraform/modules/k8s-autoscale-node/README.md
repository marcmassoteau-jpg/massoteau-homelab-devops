# Kubernetes Autoscale Node Terraform Module

> Reusable module for provisioning autoscaler-managed Kubernetes worker nodes on Proxmox VE

This Terraform module extends the k8s-node concept for autoscaler-provisioned nodes. It creates a Proxmox VM with cloud-init that automatically joins the Kubernetes cluster using a kubeadm join command.

## Usage

### Basic Autoscale Node

```hcl
module "autoscale_node_01" {
  source = "../../modules/k8s-autoscale-node"

  # Proxmox configuration
  proxmox_node     = "pve"
  proxmox_storage  = "local-lvm"
  vm_template_name = "ubuntu-2204-template"

  # Node identification
  node_name = "k8s-autoscale-01"
  node_ip   = "192.168.1.245"

  # Resources
  cpu_cores = 4
  memory_mb = 16384
  disk_size = "100G"

  # Network
  gateway    = "192.168.1.1"
  nameserver = "192.168.1.1"

  # Kubernetes join
  join_command = "kubeadm join 192.168.1.240:6443 --token <token> --discovery-token-ca-cert-hash sha256:<hash>"

  # SSH
  ssh_public_key = file("~/.ssh/id_rsa.pub")
}
```

### Multiple Autoscale Nodes

```hcl
module "autoscale_nodes" {
  source = "../../modules/k8s-autoscale-node"
  count  = 3

  # Proxmox configuration
  proxmox_node     = "pve"
  proxmox_storage  = "local-lvm"
  vm_template_name = "ubuntu-2204-template"

  # Node identification (IPs: 192.168.1.245-247)
  node_name = "k8s-autoscale-${format("%02d", count.index + 1)}"
  node_ip   = "192.168.1.${245 + count.index}"

  # Resources
  cpu_cores = 4
  memory_mb = 16384
  disk_size = "100G"

  # Network
  gateway    = "192.168.1.1"
  nameserver = "192.168.1.1"

  # Kubernetes join
  join_command = var.kubeadm_join_command

  # SSH
  ssh_public_key = file("~/.ssh/id_rsa.pub")
}
```

### With Proxmox SSH for Cloud-Init Snippets

```hcl
module "autoscale_node_with_cloudinit" {
  source = "../../modules/k8s-autoscale-node"

  # Proxmox configuration
  proxmox_node         = "pve"
  proxmox_host         = "192.168.1.222"
  proxmox_ssh_user     = "root"
  proxmox_ssh_password = var.proxmox_password

  # Node identification
  node_name = "k8s-autoscale-01"
  node_ip   = "192.168.1.245"

  # Kubernetes join (auto-joins via cloud-init)
  join_command = var.kubeadm_join_command

  # SSH
  ssh_public_key = file("~/.ssh/id_rsa.pub")
}
```

## Module Inputs

| Variable | Description | Type | Default | Required |
|----------|-------------|------|---------|----------|
| proxmox_node | Proxmox node name | string | `pve` | no |
| proxmox_storage | Storage pool | string | `local-lvm` | no |
| proxmox_host | Proxmox host IP (for SSH) | string | `192.168.1.222` | no |
| proxmox_ssh_user | SSH user for Proxmox | string | `root` | no |
| proxmox_ssh_password | SSH password for Proxmox | string | *(sensitive)* | no |
| vm_template_name | Template to clone | string | `ubuntu-2204-template` | no |
| node_name | Name of the node | string | - | yes |
| node_ip | Static IP address | string | - | yes |
| cpu_cores | CPU cores (2-16) | number | `4` | no |
| memory_mb | Memory in MB (min 4096) | number | `16384` | no |
| disk_size | Disk size | string | `100G` | no |
| network_bridge | Network bridge | string | `vmbr0` | no |
| gateway | Network gateway | string | `192.168.1.1` | no |
| nameserver | DNS nameserver | string | `192.168.1.1` | no |
| join_command | kubeadm join command | string | *(sensitive)* | no |
| ssh_public_key | SSH public key | string | - | yes |

## Module Outputs

| Output | Description |
|--------|-------------|
| vm_id | Proxmox VM ID |
| node_name | Name of the provisioned node |
| node_ip | IP address of the node |
| node_info | Complete node information object |
| ssh_connection | SSH connection command |
| ansible_host | Ansible host configuration |

## Features

- **Auto-Join**: Cloud-init executes kubeadm join on first boot
- **Validated**: Input validation for CPU and memory
- **Cloud-init**: Automatic network, SSH, and cluster join configuration
- **Autoscaler Integration**: Designed for cluster autoscaler provisioning
- **Rich Outputs**: Outputs for automation and Ansible integration

## Requirements

- Proxmox VE 8.x
- Terraform 1.5+
- Proxmox provider (telmate/proxmox) ~> 2.9
- VM template with cloud-init and kubeadm pre-installed
- Kubernetes cluster with valid join token

## IP Address Scheme

| Range | Purpose |
|-------|---------|
| 192.168.1.240 | Master node |
| 192.168.1.241-244 | Static worker nodes |
| 192.168.1.245-250 | Autoscale worker nodes |

## Notes

- **Join Token Expiry**: kubeadm tokens expire after 24 hours by default. Generate a new token before provisioning.
- **Cloud-init Snippets**: When `join_command` is provided, a cloud-init snippet is uploaded to Proxmox via SSH.
- **Lifecycle**: The module ignores changes to network and disk to prevent unintended rebuilds.
- **QEMU Agent**: Automatically enables QEMU guest agent for better integration.
- **Removal**: Drain and delete the node from Kubernetes before destroying the VM.

## License

MIT License - See LICENSE file for details

---

**Author**: Marc Massoteau
**Repository**: https://github.com/marcmassoteau-jpg/massoteau-homelab-devops
