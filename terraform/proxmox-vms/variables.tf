# Terraform Variables for Proxmox Kubernetes Cluster
#
# Define all configurable parameters for the infrastructure.
# Override these values in terraform.tfvars or via command line.

# ============================================
# Proxmox Connection Variables
# ============================================

variable "proxmox_api_url" {
  description = "Proxmox API URL (e.g., https://192.168.1.222:8006/api2/json)"
  type        = string
}

variable "proxmox_api_token_id" {
  description = "Proxmox API token ID (e.g., terraform@pam!terraform)"
  type        = string
  sensitive   = true
}

variable "proxmox_api_token_secret" {
  description = "Proxmox API token secret"
  type        = string
  sensitive   = true
}

variable "proxmox_tls_insecure" {
  description = "Skip TLS verification for self-signed certificates (homelab use)"
  type        = bool
  default     = true
}

variable "proxmox_node" {
  description = "Proxmox node name where VMs will be created"
  type        = string
  default     = "pve"
}

variable "proxmox_storage" {
  description = "Storage pool for VM disks"
  type        = string
  default     = "local-lvm"
}

# ============================================
# VM Template Variables
# ============================================

variable "vm_template_name" {
  description = "Name of the VM template to clone (Ubuntu 22.04 cloud image)"
  type        = string
  default     = "ubuntu-2204-template"
}

# ============================================
# Network Variables
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

variable "dns_servers" {
  description = "DNS servers (space-separated)"
  type        = string
  default     = "192.168.1.1 8.8.8.8"
}

# ============================================
# SSH Configuration
# ============================================

variable "ssh_public_key" {
  description = "SSH public key for VM access (cloud-init)"
  type        = string
}

# ============================================
# Master Node Configuration
# ============================================

variable "master_node_name" {
  description = "Name for the Kubernetes master node"
  type        = string
  default     = "k8s-master-tf"
}

variable "master_ip" {
  description = "Static IP address for master node"
  type        = string
  default     = "192.168.1.250"
}

variable "master_cpu_cores" {
  description = "Number of CPU cores for master node"
  type        = number
  default     = 4
}

variable "master_memory_mb" {
  description = "Memory in MB for master node"
  type        = number
  default     = 8192
}

variable "master_disk_size" {
  description = "Disk size for master node (e.g., '100G')"
  type        = string
  default     = "100G"
}

# ============================================
# Worker Node Configuration
# ============================================

variable "worker_count" {
  description = "Number of worker nodes to create"
  type        = number
  default     = 4
}

variable "worker_node_prefix" {
  description = "Prefix for worker node names"
  type        = string
  default     = "k8s-worker-tf"
}

variable "worker_base_ip" {
  description = "Base IP for first worker (others increment from this)"
  type        = string
  default     = "192.168.1.251"
}

variable "worker_cpu_cores" {
  description = "Number of CPU cores per worker node"
  type        = number
  default     = 4
}

variable "worker_memory_mb" {
  description = "Memory in MB per worker node"
  type        = number
  default     = 16384
}

variable "worker_disk_size" {
  description = "Disk size per worker node (e.g., '200G')"
  type        = string
  default     = "200G"
}

# ============================================
# Tags and Metadata
# ============================================

variable "tags" {
  description = "Tags to apply to VMs (comma-separated)"
  type        = string
  default     = "kubernetes,terraform,homelab"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "homelab"
}
