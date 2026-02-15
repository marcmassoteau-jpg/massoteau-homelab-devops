# Kubernetes Autoscale Node Module Variables
#
# Input variables for the autoscale node module

# ============================================
# Proxmox Configuration
# ============================================

variable "proxmox_node" {
  description = "Proxmox node where the VM will be created"
  type        = string
  default     = "pve"
}

variable "proxmox_storage" {
  description = "Storage pool for VM disk"
  type        = string
  default     = "local-lvm"
}

variable "proxmox_host" {
  description = "Proxmox host IP for SSH connection (cloud-init snippet upload)"
  type        = string
  default     = "192.168.1.222"
}

variable "proxmox_ssh_user" {
  description = "SSH user for Proxmox host"
  type        = string
  default     = "root"
}

variable "proxmox_ssh_password" {
  description = "SSH password for Proxmox host (use vault or environment variable)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "vm_template_name" {
  description = "Name of the VM template to clone (must have cloud-init configured)"
  type        = string
  default     = "ubuntu-2204-template"
}

# ============================================
# Node Identification
# ============================================

variable "node_name" {
  description = "Name of the autoscale worker node"
  type        = string
}

variable "node_ip" {
  description = "Static IP address for the autoscale node"
  type        = string
}

# ============================================
# Resource Allocation
# ============================================

variable "cpu_cores" {
  description = "Number of CPU cores for the autoscale node"
  type        = number
  default     = 4

  validation {
    condition     = var.cpu_cores >= 2 && var.cpu_cores <= 16
    error_message = "cpu_cores must be between 2 and 16"
  }
}

variable "memory_mb" {
  description = "Memory in MB for the autoscale node"
  type        = number
  default     = 16384

  validation {
    condition     = var.memory_mb >= 4096
    error_message = "memory_mb must be at least 4096 MB (4GB)"
  }
}

variable "disk_size" {
  description = "Disk size (e.g., '100G')"
  type        = string
  default     = "100G"
}

# ============================================
# Network Configuration
# ============================================

variable "network_bridge" {
  description = "Network bridge on Proxmox node"
  type        = string
  default     = "vmbr0"
}

variable "gateway" {
  description = "Network gateway IP address"
  type        = string
  default     = "192.168.1.1"
}

variable "nameserver" {
  description = "DNS nameserver"
  type        = string
  default     = "192.168.1.1"
}

# ============================================
# Kubernetes Join Configuration
# ============================================

variable "join_command" {
  description = "kubeadm join command to auto-join the cluster (including token and CA hash)"
  type        = string
  sensitive   = true
  default     = ""
}

# ============================================
# SSH Configuration
# ============================================

variable "ssh_public_key" {
  description = "SSH public key for VM access"
  type        = string
}
