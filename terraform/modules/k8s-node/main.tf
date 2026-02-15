# Kubernetes Node Terraform Module
#
# Reusable module for provisioning Kubernetes nodes on Proxmox.
# Can be used for both master and worker nodes with different configurations.
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

resource "proxmox_vm_qemu" "node" {
  name        = var.node_name
  target_node = var.proxmox_node
  desc        = var.node_description

  # Clone from template
  clone = var.vm_template_name

  # VM Resources
  cores   = var.cpu_cores
  sockets = var.cpu_sockets
  memory  = var.memory_mb

  # Boot settings
  onboot = var.start_on_boot
  agent  = 1  # QEMU Guest Agent

  # Disk configuration
  disk {
    size    = var.disk_size
    type    = var.disk_type
    storage = var.proxmox_storage
    format  = var.disk_format
  }

  # Network configuration
  network {
    model  = var.network_model
    bridge = var.network_bridge
  }

  # Cloud-init configuration
  ipconfig0 = "ip=${var.ip_address}/24,gw=${var.gateway}"

  nameserver = var.dns_servers
  sshkeys    = var.ssh_public_key

  # Tags (if supported by provider version)
  tags = var.tags

  # Lifecycle management
  lifecycle {
    ignore_changes = [
      network,
      disk,
    ]
    create_before_destroy = var.create_before_destroy
  }
}
