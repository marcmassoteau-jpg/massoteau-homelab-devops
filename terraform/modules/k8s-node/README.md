# Kubernetes Node Terraform Module

> Reusable module for provisioning Kubernetes nodes on Proxmox VE

This Terraform module provides a consistent, reusable way to provision Kubernetes nodes (master or worker) on Proxmox VE with cloud-init configuration.

## Usage

### Master Node Example

```hcl
module "k8s_master" {
  source = "../../modules/k8s-node"

  # Proxmox configuration
  proxmox_node     = "pve"
  proxmox_storage  = "local-lvm"
  vm_template_name = "ubuntu-2204-template"

  # Node identification
  node_name        = "k8s-master-01"
  node_description = "Kubernetes Master Node"
  node_role        = "master"

  # Resources
  cpu_cores  = 4
  memory_mb  = 8192
  disk_size  = "100G"

  # Network
  network_bridge = "vmbr0"
  ip_address     = "192.168.1.240"
  gateway        = "192.168.1.1"
  dns_servers    = "192.168.1.1 8.8.8.8"

  # Cloud-init
  ssh_public_key = file("~/.ssh/id_rsa.pub")

  # Metadata
  environment = "production"
  tags        = "kubernetes,master,terraform"
}
```

### Worker Node Example

```hcl
module "k8s_worker" {
  source = "../../modules/k8s-node"

  # Proxmox configuration
  proxmox_node     = "pve"
  proxmox_storage  = "local-lvm"
  vm_template_name = "ubuntu-2204-template"

  # Node identification
  node_name        = "k8s-worker-01"
  node_description = "Kubernetes Worker Node"
  node_role        = "worker"

  # Resources (workers typically have more resources)
  cpu_cores  = 4
  memory_mb  = 16384
  disk_size  = "200G"

  # Network
  network_bridge = "vmbr0"
  ip_address     = "192.168.1.241"
  gateway        = "192.168.1.1"
  dns_servers    = "192.168.1.1 8.8.8.8"

  # Cloud-init
  ssh_public_key = file("~/.ssh/id_rsa.pub")

  # Metadata
  environment = "production"
  tags        = "kubernetes,worker,terraform"
}
```

### Multiple Workers with Count

```hcl
module "k8s_workers" {
  source = "../../modules/k8s-node"
  count  = 4

  # Proxmox configuration
  proxmox_node     = "pve"
  proxmox_storage  = "local-lvm"
  vm_template_name = "ubuntu-2204-template"

  # Node identification
  node_name        = "k8s-worker-${format("%02d", count.index + 1)}"
  node_description = "Kubernetes Worker Node ${count.index + 1}"
  node_role        = "worker"

  # Resources
  cpu_cores  = 4
  memory_mb  = 16384
  disk_size  = "200G"

  # Network (IPs increment)
  network_bridge = "vmbr0"
  ip_address     = "192.168.1.${241 + count.index}"
  gateway        = "192.168.1.1"
  dns_servers    = "192.168.1.1 8.8.8.8"

  # Cloud-init
  ssh_public_key = file("~/.ssh/id_rsa.pub")

  # Metadata
  environment = "production"
  tags        = "kubernetes,worker,terraform"
}
```

## Module Inputs

| Variable | Description | Type | Default | Required |
|----------|-------------|------|---------|----------|
| proxmox_node | Proxmox node name | string | - | yes |
| proxmox_storage | Storage pool | string | "local-lvm" | no |
| vm_template_name | Template to clone | string | - | yes |
| node_name | Name of the node | string | - | yes |
| node_description | Node description | string | "Kubernetes Node - Managed by Terraform" | no |
| node_role | Role (master/worker) | string | "worker" | no |
| cpu_cores | CPU cores | number | 4 | no |
| cpu_sockets | CPU sockets | number | 1 | no |
| memory_mb | Memory in MB | number | 8192 | no |
| disk_size | Disk size (e.g., "100G") | string | "100G" | no |
| disk_type | Disk type | string | "scsi" | no |
| disk_format | Disk format | string | "raw" | no |
| network_bridge | Network bridge | string | "vmbr0" | no |
| network_model | Network model | string | "virtio" | no |
| ip_address | Static IP address | string | - | yes |
| gateway | Network gateway | string | - | yes |
| dns_servers | DNS servers | string | "8.8.8.8 8.8.4.4" | no |
| ssh_public_key | SSH public key | string | - | yes |
| start_on_boot | Auto-start on boot | bool | true | no |
| create_before_destroy | Lifecycle setting | bool | false | no |
| tags | VM tags | string | "kubernetes,terraform" | no |
| environment | Environment name | string | "homelab" | no |

## Module Outputs

| Output | Description |
|--------|-------------|
| node_name | Name of the provisioned node |
| node_ip | IP address of the node |
| vm_id | Proxmox VM ID |
| node_role | Role of the node |
| node_info | Complete node information object |
| ssh_connection | SSH connection command |
| ansible_host | Ansible host configuration |

## Features

- **Reusable**: Use for both master and worker nodes
- **Validated**: Input validation for critical parameters
- **Cloud-init**: Automatic network and SSH configuration
- **Flexible**: Fully parameterized for different use cases
- **Outputs**: Rich outputs for automation integration

## Requirements

- Proxmox VE 8.x
- Terraform 1.5+
- Proxmox provider (telmate/proxmox) ~> 2.9
- VM template with cloud-init support

## Example Use Case

This module is designed to be consumed by higher-level configurations like `terraform/proxmox-vms/`. It abstracts the common VM provisioning logic, allowing you to focus on cluster topology and configuration.

## Notes

- **IP Address Management**: This module does not handle IP allocation - you must provide static IPs
- **Lifecycle**: The module ignores changes to network and disk to prevent unintended rebuilds
- **Cloud-init**: Expects the template to have cloud-init configured
- **QEMU Agent**: Automatically enables QEMU guest agent for better integration

## License

MIT License - See LICENSE file for details

---

**Author**: Marc Massoteau
**Repository**: https://github.com/marcmassoteau-jpg/massoteau-homelab-devops
