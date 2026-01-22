#!/bin/bash
# create-k8s-vms.sh
# Script to create Kubernetes VMs from Proxmox template
# Run this script on the Proxmox host (192.168.1.222)
# Based on Article 2: Proxmox Setup & VM Provisioning

set -e

TEMPLATE_ID=9000
SSH_KEY="ssh-ed25519 AAAAC3Nza...your-key-here"
GATEWAY="192.168.1.1"
NAMESERVER="192.168.1.1"
SEARCH_DOMAIN="localdomain"

echo "====================================="
echo "Creating Kubernetes Cluster VMs"
echo "====================================="
echo ""

# Function to create VM
create_vm() {
    local vmid=$1
    local name=$2
    local ip=$3
    local memory=$4
    local cores=$5
    local disk=$6

    echo "Creating VM $vmid: $name with IP $ip..."

    # Clone template
    qm clone $TEMPLATE_ID $vmid --name $name --full

    # Configure resources
    qm set $vmid --memory $memory --cores $cores

    # Resize disk
    qm resize $vmid scsi0 ${disk}G

    # Configure network
    qm set $vmid --ipconfig0 ip=${ip}/24,gw=$GATEWAY
    qm set $vmid --nameserver $NAMESERVER
    qm set $vmid --searchdomain $SEARCH_DOMAIN

    # Set SSH key
    qm set $vmid --sshkeys <(echo "$SSH_KEY")

    echo "✓ VM $vmid created successfully!"
    echo ""
}

# Create control plane
echo "Creating Control Plane Node..."
create_vm 240 "k8s-master" "192.168.1.240" 8192 4 100

# Create worker nodes
echo "Creating Worker Nodes..."
create_vm 241 "k8s-worker-01" "192.168.1.241" 16384 4 200
create_vm 242 "k8s-worker-02" "192.168.1.242" 16384 4 200
create_vm 243 "k8s-worker-03" "192.168.1.243" 16384 4 200
create_vm 244 "k8s-worker-04" "192.168.1.244" 16384 4 200

echo "====================================="
echo "✓ All VMs created successfully!"
echo "====================================="
echo ""
echo "Start all VMs with:"
echo "  for vmid in 240 241 242 243 244; do qm start \$vmid; done"
echo ""
echo "Or start them individually:"
echo "  qm start 240  # k8s-master"
echo "  qm start 241  # k8s-worker-01"
echo "  qm start 242  # k8s-worker-02"
echo "  qm start 243  # k8s-worker-03"
echo "  qm start 244  # k8s-worker-04"
