# Terraform Outputs for Proxmox Kubernetes Cluster
#
# Export important values for use in automation and Ansible integration.

# ============================================
# Master Node Outputs
# ============================================

output "master_node_name" {
  description = "Name of the Kubernetes master node"
  value       = proxmox_vm_qemu.k8s_master.name
}

output "master_node_ip" {
  description = "IP address of the Kubernetes master node"
  value       = var.master_ip
}

output "master_vm_id" {
  description = "Proxmox VM ID of the master node"
  value       = proxmox_vm_qemu.k8s_master.vmid
}

# ============================================
# Worker Node Outputs
# ============================================

output "worker_node_names" {
  description = "List of worker node names"
  value       = proxmox_vm_qemu.k8s_workers[*].name
}

output "worker_node_ips" {
  description = "List of worker node IP addresses"
  value       = [for i in range(var.worker_count) : cidrhost("${var.worker_base_ip}/24", i)]
}

output "worker_vm_ids" {
  description = "List of Proxmox VM IDs for worker nodes"
  value       = proxmox_vm_qemu.k8s_workers[*].vmid
}

# ============================================
# Cluster Information
# ============================================

output "cluster_info" {
  description = "Complete cluster information"
  value = {
    master = {
      name = proxmox_vm_qemu.k8s_master.name
      ip   = var.master_ip
      vmid = proxmox_vm_qemu.k8s_master.vmid
    }
    workers = [
      for i in range(var.worker_count) : {
        name = proxmox_vm_qemu.k8s_workers[i].name
        ip   = cidrhost("${var.worker_base_ip}/24", i)
        vmid = proxmox_vm_qemu.k8s_workers[i].vmid
      }
    ]
    total_nodes = var.worker_count + 1
  }
}

# ============================================
# Ansible Inventory Output (JSON)
# ============================================

output "ansible_inventory_json" {
  description = "Ansible inventory in JSON format for dynamic integration"
  value = jsonencode({
    all = {
      hosts = merge(
        {
          "${proxmox_vm_qemu.k8s_master.name}" = {
            ansible_host = var.master_ip
            ansible_user = "ubuntu"
          }
        },
        {
          for i in range(var.worker_count) :
          proxmox_vm_qemu.k8s_workers[i].name => {
            ansible_host = cidrhost("${var.worker_base_ip}/24", i)
            ansible_user = "ubuntu"
          }
        }
      )
      children = {
        masters = {
          hosts = {
            "${proxmox_vm_qemu.k8s_master.name}" = {}
          }
        }
        workers = {
          hosts = {
            for i in range(var.worker_count) :
            proxmox_vm_qemu.k8s_workers[i].name => {}
          }
        }
      }
    }
  })
  sensitive = false
}

# ============================================
# Quick Reference Outputs
# ============================================

output "ssh_connection_master" {
  description = "SSH connection command for master node"
  value       = "ssh ubuntu@${var.master_ip}"
}

output "ssh_connection_workers" {
  description = "SSH connection commands for worker nodes"
  value = [
    for i in range(var.worker_count) :
    "ssh ubuntu@${cidrhost("${var.worker_base_ip}/24", i)}"
  ]
}

output "deployment_summary" {
  description = "Summary of deployed infrastructure"
  value = <<-EOT

  ╔════════════════════════════════════════════════════════════╗
  ║  Kubernetes Cluster - Terraform Deployment Summary        ║
  ╚════════════════════════════════════════════════════════════╝

  Master Node:
    Name: ${proxmox_vm_qemu.k8s_master.name}
    IP:   ${var.master_ip}
    VMID: ${proxmox_vm_qemu.k8s_master.vmid}
    SSH:  ssh ubuntu@${var.master_ip}

  Worker Nodes:
  %{for i in range(var.worker_count)~}
    ${proxmox_vm_qemu.k8s_workers[i].name}: ${cidrhost("${var.worker_base_ip}/24", i)} (VMID: ${proxmox_vm_qemu.k8s_workers[i].vmid})
  %{endfor~}

  Total Nodes: ${var.worker_count + 1}
  Environment: ${var.environment}

  Next Steps:
    1. Wait ~60 seconds for VMs to complete cloud-init
    2. Test connectivity: ansible all -m ping -i inventory
    3. Run Ansible playbooks to configure cluster

  ╚════════════════════════════════════════════════════════════╝
  EOT
}
