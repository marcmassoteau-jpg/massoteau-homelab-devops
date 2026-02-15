# Terraform Configuration for Proxmox Kubernetes VMs
#
# This configuration provisions virtual machines on Proxmox VE for a Kubernetes cluster.
# Designed for homelab environments with local state management.
#
# Author: Marc Massoteau
# Repository: https://github.com/marcmassoteau-jpg/massoteau-homelab-devops

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    proxmox = {
      source  = "telmate/proxmox"
      version = "~> 2.9"
    }
  }
}

# Proxmox Provider Configuration
provider "proxmox" {
  pm_api_url          = var.proxmox_api_url
  pm_api_token_id     = var.proxmox_api_token_id
  pm_api_token_secret = var.proxmox_api_token_secret
  pm_tls_insecure     = var.proxmox_tls_insecure
  pm_timeout          = 600
  pm_parallel         = 2
}

# Kubernetes Master Node
resource "proxmox_vm_qemu" "k8s_master" {
  name        = var.master_node_name
  target_node = var.proxmox_node
  desc        = "Kubernetes Master Node - Managed by Terraform"

  # Clone from template
  clone = var.vm_template_name

  # VM Resources
  cores   = var.master_cpu_cores
  sockets = 1
  memory  = var.master_memory_mb

  # Boot settings
  onboot  = true
  agent   = 1

  # Disk configuration
  disk {
    size    = var.master_disk_size
    type    = "scsi"
    storage = var.proxmox_storage
    format  = "raw"
  }

  # Network configuration
  network {
    model  = "virtio"
    bridge = var.network_bridge
  }

  # Cloud-init configuration
  ipconfig0 = "ip=${var.master_ip}/24,gw=${var.gateway}"

  nameserver = var.dns_servers
  sshkeys    = var.ssh_public_key

  # Lifecycle management
  lifecycle {
    ignore_changes = [
      network,
      disk,
    ]
  }
}

# Kubernetes Worker Nodes
resource "proxmox_vm_qemu" "k8s_workers" {
  count = var.worker_count

  name        = "${var.worker_node_prefix}-${format("%02d", count.index + 1)}"
  target_node = var.proxmox_node
  desc        = "Kubernetes Worker Node ${count.index + 1} - Managed by Terraform"

  # Clone from template
  clone = var.vm_template_name

  # VM Resources
  cores   = var.worker_cpu_cores
  sockets = 1
  memory  = var.worker_memory_mb

  # Boot settings
  onboot  = true
  agent   = 1

  # Disk configuration
  disk {
    size    = var.worker_disk_size
    type    = "scsi"
    storage = var.proxmox_storage
    format  = "raw"
  }

  # Network configuration
  network {
    model  = "virtio"
    bridge = var.network_bridge
  }

  # Cloud-init configuration
  # IP addresses increment from base worker IP
  ipconfig0 = "ip=${cidrhost("${var.worker_base_ip}/24", count.index)}/24,gw=${var.gateway}"

  nameserver = var.dns_servers
  sshkeys    = var.ssh_public_key

  # Lifecycle management
  lifecycle {
    ignore_changes = [
      network,
      disk,
    ]
  }
}
