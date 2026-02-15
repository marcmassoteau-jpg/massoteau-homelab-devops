# Kubernetes Autoscale Node Terraform Module
#
# Extends the k8s-node concept for autoscaler-provisioned nodes.
# Creates a Proxmox VM with cloud-init that auto-joins the Kubernetes cluster.
# Includes kubeadm join command execution via cloud-init.
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

resource "proxmox_vm_qemu" "autoscale_node" {
  name        = var.node_name
  target_node = var.proxmox_node
  desc        = "Kubernetes Autoscale Worker - Managed by Terraform & Cluster Autoscaler"

  # Clone from template
  clone = var.vm_template_name

  # VM Resources
  cores   = var.cpu_cores
  sockets = 1
  memory  = var.memory_mb

  # Boot settings
  onboot = true
  agent  = 1  # QEMU Guest Agent

  # Disk configuration
  disk {
    size    = var.disk_size
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
  ipconfig0  = "ip=${var.node_ip}/24,gw=${var.gateway}"
  nameserver = var.nameserver

  sshkeys = var.ssh_public_key

  # Cloud-init user data for auto-joining the cluster
  # The join command is passed as a cloud-init script
  cicustom = var.join_command != "" ? "user=local:snippets/${var.node_name}-cloud-init.yaml" : ""

  tags = "kubernetes,worker,autoscale,terraform"

  # Lifecycle management
  lifecycle {
    ignore_changes = [
      network,
      disk,
    ]
  }
}

# Create cloud-init snippet for kubeadm join
resource "null_resource" "cloud_init_snippet" {
  count = var.join_command != "" ? 1 : 0

  triggers = {
    node_name    = var.node_name
    join_command = var.join_command
  }

  provisioner "remote-exec" {
    connection {
      type     = "ssh"
      host     = var.proxmox_host
      user     = var.proxmox_ssh_user
      password = var.proxmox_ssh_password
    }

    inline = [
      "mkdir -p /var/lib/vz/snippets",
      "cat > /var/lib/vz/snippets/${var.node_name}-cloud-init.yaml << 'CLOUDINIT'",
      "#cloud-config",
      "runcmd:",
      "  - echo 'Waiting for network...'",
      "  - sleep 30",
      "  - echo 'Joining Kubernetes cluster...'",
      "  - ${var.join_command}",
      "  - echo 'Node joined successfully'",
      "CLOUDINIT"
    ]
  }
}
