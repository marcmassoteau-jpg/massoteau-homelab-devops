# Kubernetes Node Module Variables
#
# Input variables for the reusable k8s-node module

# ============================================
# Proxmox Configuration
# ============================================

variable "proxmox_node" {
  description = "Proxmox node where the VM will be created"
  type        = string
}

variable "proxmox_storage" {
  description = "Storage pool for VM disk"
  type        = string
  default     = "local-lvm"
}

variable "vm_template_name" {
  description = "Name of the VM template to clone"
  type        = string
}

# ============================================
# Node Identification
# ============================================

variable "node_name" {
  description = "Name of the Kubernetes node"
  type        = string
}

variable "node_description" {
  description = "Description for the node"
  type        = string
  default     = "Kubernetes Node - Managed by Terraform"
}

variable "node_role" {
  description = "Role of the node (master or worker)"
  type        = string
  default     = "worker"

  validation {
    condition     = contains(["master", "worker"], var.node_role)
    error_message = "node_role must be either 'master' or 'worker'"
  }
}

# ============================================
# Resource Allocation
# ============================================

variable "cpu_cores" {
  description = "Number of CPU cores for the node"
  type        = number
  default     = 4

  validation {
    condition     = var.cpu_cores >= 2 && var.cpu_cores <= 32
    error_message = "cpu_cores must be between 2 and 32"
  }
}

variable "cpu_sockets" {
  description = "Number of CPU sockets"
  type        = number
  default     = 1
}

variable "memory_mb" {
  description = "Memory in MB for the node"
  type        = number
  default     = 8192

  validation {
    condition     = var.memory_mb >= 2048
    error_message = "memory_mb must be at least 2048 MB (2GB)"
  }
}

variable "disk_size" {
  description = "Disk size (e.g., '100G', '200G')"
  type        = string
  default     = "100G"
}

variable "disk_type" {
  description = "Disk type (scsi, sata, virtio)"
  type        = string
  default     = "scsi"
}

variable "disk_format" {
  description = "Disk format (raw, qcow2)"
  type        = string
  default     = "raw"
}

# ============================================
# Network Configuration
# ============================================

variable "network_bridge" {
  description = "Network bridge on Proxmox node"
  type        = string
  default     = "vmbr0"
}

variable "network_model" {
  description = "Network model (virtio, e1000, rtl8139)"
  type        = string
  default     = "virtio"
}

variable "ip_address" {
  description = "Static IP address for the node"
  type        = string
}

variable "gateway" {
  description = "Network gateway IP address"
  type        = string
}

variable "dns_servers" {
  description = "DNS servers (space-separated)"
  type        = string
  default     = "8.8.8.8 8.8.4.4"
}

# ============================================
# Cloud-init Configuration
# ============================================

variable "ssh_public_key" {
  description = "SSH public key for VM access"
  type        = string
}

# ============================================
# Boot Configuration
# ============================================

variable "start_on_boot" {
  description = "Start VM automatically on Proxmox boot"
  type        = bool
  default     = true
}

# ============================================
# Lifecycle Configuration
# ============================================

variable "create_before_destroy" {
  description = "Create replacement before destroying"
  type        = bool
  default     = false
}

# ============================================
# Tags and Metadata
# ============================================

variable "tags" {
  description = "Tags for the VM (comma-separated)"
  type        = string
  default     = "kubernetes,terraform"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "homelab"
}
