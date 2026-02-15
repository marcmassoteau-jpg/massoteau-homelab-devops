# Kubernetes Node Module Outputs
#
# Output values from the k8s-node module

output "node_name" {
  description = "Name of the provisioned node"
  value       = proxmox_vm_qemu.node.name
}

output "node_ip" {
  description = "IP address of the node"
  value       = var.ip_address
}

output "vm_id" {
  description = "Proxmox VM ID"
  value       = proxmox_vm_qemu.node.vmid
}

output "node_role" {
  description = "Role of the node (master or worker)"
  value       = var.node_role
}

output "node_info" {
  description = "Complete node information"
  value = {
    name        = proxmox_vm_qemu.node.name
    ip          = var.ip_address
    vmid        = proxmox_vm_qemu.node.vmid
    role        = var.node_role
    cpu_cores   = var.cpu_cores
    memory_mb   = var.memory_mb
    disk_size   = var.disk_size
    environment = var.environment
  }
}

output "ssh_connection" {
  description = "SSH connection command"
  value       = "ssh ubuntu@${var.ip_address}"
}

output "ansible_host" {
  description = "Ansible host configuration"
  value = {
    ansible_host = var.ip_address
    ansible_user = "ubuntu"
  }
}
