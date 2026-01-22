#!/bin/bash
# snapshot-all.sh
# Take snapshots of all Kubernetes cluster VMs
# Run this script on the Proxmox host (192.168.1.222)
# Based on Article 2: Proxmox Setup & VM Provisioning

SNAPSHOT_NAME="${1:-manual-snapshot-$(date +%Y%m%d-%H%M)}"
DESCRIPTION="${2:-Manual snapshot taken on $(date)}"

echo "====================================="
echo "Creating Snapshots for All K8s VMs"
echo "====================================="
echo "Snapshot Name: $SNAPSHOT_NAME"
echo "Description: $DESCRIPTION"
echo ""

for VMID in 240 241 242 243 244; do
    echo "Creating snapshot '$SNAPSHOT_NAME' for VM $VMID..."
    qm snapshot $VMID "$SNAPSHOT_NAME" --description "$DESCRIPTION"
    echo "✓ Snapshot created for VM $VMID"
done

echo ""
echo "====================================="
echo "✓ All snapshots created successfully!"
echo "====================================="
echo ""
echo "List snapshots with:"
echo "  qm listsnapshot <vmid>"
echo ""
echo "Rollback to snapshot:"
echo "  qm stop <vmid>"
echo "  qm rollback <vmid> $SNAPSHOT_NAME"
echo "  qm start <vmid>"
