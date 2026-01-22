#!/bin/bash
# create-template.sh
# Creates Ubuntu 22.04 VM template for Kubernetes cluster
# Run this script on the Proxmox host (192.168.1.222)
# Based on Article 2: Proxmox Setup & VM Provisioning

set -e

TEMPLATE_ID=9000
IMAGE_URL="https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
IMAGE_DIR="/var/lib/vz/template/iso"
IMAGE_FILE="jammy-server-cloudimg-amd64.img"
STORAGE="local-lvm"

echo "====================================="
echo "Creating Ubuntu 22.04 VM Template"
echo "Template ID: $TEMPLATE_ID"
echo "====================================="

# Step 1: Download Ubuntu cloud image
echo ""
echo "Step 1: Downloading Ubuntu 22.04 cloud image..."
cd "$IMAGE_DIR"
if [ -f "$IMAGE_FILE" ]; then
    echo "Image already exists. Skipping download."
else
    wget "$IMAGE_URL"
    echo "Download complete: $(ls -lh $IMAGE_FILE)"
fi

# Step 2: Create VM
echo ""
echo "Step 2: Creating VM template..."
qm create $TEMPLATE_ID \
    --name ubuntu-22.04-template \
    --memory 2048 \
    --cores 2 \
    --net0 virtio,bridge=vmbr0

# Step 3: Import disk
echo ""
echo "Step 3: Importing cloud image to VM disk..."
qm importdisk $TEMPLATE_ID "$IMAGE_DIR/$IMAGE_FILE" $STORAGE

# Step 4: Configure VM
echo ""
echo "Step 4: Configuring VM..."
qm set $TEMPLATE_ID --scsihw virtio-scsi-pci --scsi0 $STORAGE:vm-$TEMPLATE_ID-disk-0
qm set $TEMPLATE_ID --ide2 $STORAGE:cloudinit
qm set $TEMPLATE_ID --boot c --bootdisk scsi0
qm set $TEMPLATE_ID --serial0 socket --vga serial0
qm set $TEMPLATE_ID --agent enabled=1

# Step 5: Configure Cloud-Init defaults
echo ""
echo "Step 5: Configuring Cloud-Init defaults..."
qm set $TEMPLATE_ID --ciuser ubuntu
qm set $TEMPLATE_ID --cipassword $(openssl passwd -6 "ubuntu")

# SSH key configuration
if [ -f ~/.ssh/id_ed25519.pub ]; then
    echo "Using SSH key from ~/.ssh/id_ed25519.pub"
    qm set $TEMPLATE_ID --sshkeys ~/.ssh/id_ed25519.pub
elif [ -f ~/.ssh/id_rsa.pub ]; then
    echo "Using SSH key from ~/.ssh/id_rsa.pub"
    qm set $TEMPLATE_ID --sshkeys ~/.ssh/id_rsa.pub
else
    echo "WARNING: No SSH key found. You'll need to add it manually:"
    echo "  qm set $TEMPLATE_ID --sshkeys ~/.ssh/your_key.pub"
fi

qm set $TEMPLATE_ID --ipconfig0 ip=dhcp

# Step 6: Resize disk
echo ""
echo "Step 6: Resizing disk..."
qm resize $TEMPLATE_ID scsi0 +95G

# Step 7: Convert to template
echo ""
echo "Step 7: Converting VM to template..."
qm template $TEMPLATE_ID

echo ""
echo "====================================="
echo "✓ Template created successfully!"
echo "====================================="
echo "Template ID: $TEMPLATE_ID"
echo "Template Name: ubuntu-22.04-template"
echo ""
echo "You can now create VMs from this template using:"
echo "  ./create-k8s-vms.sh"
