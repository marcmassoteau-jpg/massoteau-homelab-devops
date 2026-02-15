# Kubernetes Autoscale Node Module Outputs
#
# Output values from the k8s-autoscale-node module

output "vm_id" {
  description = "Proxmox VM ID of the autoscaled node"
  value       = proxmox_vm_qemu.autoscale_node.vmid
}

output "node_name" {
  description = "Name of the autoscaled node"
  value       = proxmox_vm_qemu.autoscale_node.name
}

output "node_ip" {
  description = "IP address of the autoscaled node"
  value       = var.node_ip
}

output "node_info" {
  description = "Complete autoscale node information"
  value = {
    name      = proxmox_vm_qemu.autoscale_node.name
    ip        = var.node_ip
    vmid      = proxmox_vm_qemu.autoscale_node.vmid
    cpu_cores = var.cpu_cores
    memory_mb = var.memory_mb
    disk_size = var.disk_size
    role      = "autoscale-worker"
  }
}

output "ssh_connection" {
  description = "SSH connection command"
  value       = "ssh ubuntu@${var.node_ip}"
}

output "ansible_host" {
  description = "Ansible host configuration"
  value = {
    ansible_host = var.node_ip
    ansible_user = "ubuntu"
  }
}
