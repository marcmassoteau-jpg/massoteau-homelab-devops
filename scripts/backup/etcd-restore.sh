#!/usr/bin/env bash
# =============================================================================
# etcd Restore Script
# =============================================================================
# Restores etcd from a snapshot file for disaster recovery.
# This is a DESTRUCTIVE operation that will replace the current etcd data.
#
# Usage:
#   sudo ./etcd-restore.sh --confirm /path/to/etcd-snapshot.db
#
# The script will:
#   1. Display a warning and require --confirm flag
#   2. Stop the kubelet service and etcd
#   3. Restore etcd from the specified snapshot
#   4. Restart kubelet
#   5. Wait for the API server to become available
#   6. Verify cluster health
# =============================================================================

set -euo pipefail

#===== Configuration =====
ETCD_DATA_DIR="/var/lib/etcd"
ETCD_RESTORE_DIR="/var/lib/etcd-restore"
ETCD_CACERT="/etc/kubernetes/pki/etcd/ca.crt"
ETCD_CERT="/etc/kubernetes/pki/etcd/server.crt"
ETCD_KEY="/etc/kubernetes/pki/etcd/server.key"

#===== Parse Arguments =====
CONFIRM=false
SNAPSHOT_FILE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --confirm)
            CONFIRM=true
            shift
            ;;
        *)
            SNAPSHOT_FILE="$1"
            shift
            ;;
    esac
done

#===== Warning Banner =====
echo ""
echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
echo "!                                                            !"
echo "!                    W A R N I N G                           !"
echo "!                                                            !"
echo "!   This script will REPLACE the current etcd database       !"
echo "!   with a snapshot. This is a DESTRUCTIVE operation.        !"
echo "!                                                            !"
echo "!   - All current cluster state will be replaced             !"
echo "!   - The kubelet and etcd will be stopped temporarily       !"
echo "!   - The API server will be unavailable during restore      !"
echo "!   - Resources created after the snapshot will be lost      !"
echo "!                                                            !"
echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
echo ""

#===== Validation =====
if [[ $EUID -ne 0 ]]; then
    echo "ERROR: This script must be run as root (sudo)"
    exit 1
fi

if [[ "$CONFIRM" != "true" ]]; then
    echo "ERROR: You must pass --confirm to proceed with the restore."
    echo ""
    echo "Usage: sudo $0 --confirm /path/to/etcd-snapshot.db"
    exit 1
fi

if [[ -z "$SNAPSHOT_FILE" ]]; then
    echo "ERROR: No snapshot file specified."
    echo ""
    echo "Usage: sudo $0 --confirm /path/to/etcd-snapshot.db"
    echo ""
    echo "Available snapshots in /var/backups/etcd:"
    ls -lh /var/backups/etcd/etcd-snapshot-*.db 2>/dev/null || echo "  (none found)"
    exit 1
fi

if [[ ! -f "$SNAPSHOT_FILE" ]]; then
    echo "ERROR: Snapshot file not found: $SNAPSHOT_FILE"
    exit 1
fi

if ! test -f /etc/kubernetes/manifests/etcd.yaml; then
    echo "ERROR: etcd manifest not found. This does not appear to be a master node."
    exit 1
fi

if ! command -v etcdctl &>/dev/null; then
    echo "ERROR: etcdctl not found."
    exit 1
fi

#===== Display Restore Plan =====
echo "Restore Plan:"
echo "  Snapshot: $SNAPSHOT_FILE"
echo "  Snapshot size: $(du -h "$SNAPSHOT_FILE" | cut -f1)"
echo "  Target data dir: $ETCD_DATA_DIR"
echo "  Hostname: $(hostname)"
echo "  Date: $(date)"
echo ""

# Final confirmation countdown
echo "Starting restore in 5 seconds... (Ctrl+C to abort)"
for i in 5 4 3 2 1; do
    echo "  $i..."
    sleep 1
done
echo ""

#===== Step 1: Stop kubelet =====
echo "Step 1/5: Stopping kubelet..."
systemctl stop kubelet
echo "  kubelet stopped"

# Wait for etcd to stop (static pod managed by kubelet)
echo "  Waiting for etcd to stop..."
sleep 5

# Move etcd manifest to stop the static pod if still running
if [[ -f /etc/kubernetes/manifests/etcd.yaml ]]; then
    mv /etc/kubernetes/manifests/etcd.yaml /etc/kubernetes/etcd.yaml.bak
    echo "  Moved etcd manifest to stop static pod"
    sleep 5
fi

#===== Step 2: Backup Current Data =====
echo ""
echo "Step 2/5: Backing up current etcd data..."
if [[ -d "$ETCD_DATA_DIR" ]]; then
    BACKUP_TIMESTAMP=$(date +%Y%m%d-%H%M%S)
    mv "$ETCD_DATA_DIR" "${ETCD_DATA_DIR}.pre-restore.${BACKUP_TIMESTAMP}"
    echo "  Current data moved to: ${ETCD_DATA_DIR}.pre-restore.${BACKUP_TIMESTAMP}"
else
    echo "  No existing etcd data directory found"
fi

#===== Step 3: Restore from Snapshot =====
echo ""
echo "Step 3/5: Restoring etcd from snapshot..."
ETCDCTL_API=3 etcdctl snapshot restore "$SNAPSHOT_FILE" \
    --data-dir="$ETCD_DATA_DIR" \
    --name="$(hostname)" \
    --initial-cluster="$(hostname)=https://127.0.0.1:2380" \
    --initial-advertise-peer-urls="https://127.0.0.1:2380"

echo "  etcd data restored to $ETCD_DATA_DIR"

#===== Step 4: Restart Services =====
echo ""
echo "Step 4/5: Restarting services..."

# Restore etcd manifest
if [[ -f /etc/kubernetes/etcd.yaml.bak ]]; then
    mv /etc/kubernetes/etcd.yaml.bak /etc/kubernetes/manifests/etcd.yaml
    echo "  etcd manifest restored"
fi

# Start kubelet
systemctl start kubelet
echo "  kubelet started"

#===== Step 5: Wait for API Server =====
echo ""
echo "Step 5/5: Waiting for API server to become available..."
MAX_WAIT=120
WAITED=0
while [[ $WAITED -lt $MAX_WAIT ]]; do
    if kubectl cluster-info &>/dev/null; then
        echo "  API server is available!"
        break
    fi
    echo "  Waiting... ($WAITED/${MAX_WAIT}s)"
    sleep 5
    WAITED=$((WAITED + 5))
done

if [[ $WAITED -ge $MAX_WAIT ]]; then
    echo "  WARNING: API server did not become available within ${MAX_WAIT}s"
    echo "  Check: systemctl status kubelet"
    echo "  Check: crictl ps | grep etcd"
    echo "  Check: crictl logs <etcd-container-id>"
    exit 1
fi

#===== Verify Cluster Health =====
echo ""
echo "Verifying cluster health..."
echo ""

echo "Nodes:"
kubectl get nodes -o wide 2>/dev/null || echo "  (unable to get nodes)"

echo ""
echo "System pods:"
kubectl get pods -n kube-system 2>/dev/null || echo "  (unable to get pods)"

echo ""
echo "============================================"
echo "  etcd Restore Completed!"
echo "============================================"
echo ""
echo "Next steps:"
echo "  1. Verify all nodes are Ready:  kubectl get nodes"
echo "  2. Check system pods:           kubectl get pods -n kube-system"
echo "  3. Check application pods:      kubectl get pods -A"
echo "  4. Verify services:             kubectl get svc -A"
echo ""
echo "NOTE: Resources created after the snapshot was taken will be missing."
echo "      You may need to re-apply recent changes."
