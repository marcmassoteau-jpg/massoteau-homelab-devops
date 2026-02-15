#!/usr/bin/env bash
# =============================================================================
# etcd Backup Script
# =============================================================================
# Creates a snapshot of the etcd database for disaster recovery.
# Should be run on a Kubernetes master node with etcd access.
#
# Usage:
#   sudo ./etcd-backup.sh
#
# The script will:
#   1. Verify it is running on a master node with etcd
#   2. Create the backup directory if needed
#   3. Take an etcd snapshot with proper certificates
#   4. Name the snapshot with a timestamp
#   5. Retain only the last 7 backups
#   6. Display backup size and verification
# =============================================================================

set -euo pipefail

#===== Configuration =====
BACKUP_DIR="/var/backups/etcd"
RETENTION_COUNT=7
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_FILE="${BACKUP_DIR}/etcd-snapshot-${TIMESTAMP}.db"

# etcd certificate paths (kubeadm defaults)
ETCD_CACERT="/etc/kubernetes/pki/etcd/ca.crt"
ETCD_CERT="/etc/kubernetes/pki/etcd/server.crt"
ETCD_KEY="/etc/kubernetes/pki/etcd/server.key"
ETCD_ENDPOINT="https://127.0.0.1:2379"

#===== Pre-flight Checks =====
echo "============================================"
echo "  etcd Backup"
echo "  $(date)"
echo "============================================"
echo ""

# Must run as root
if [[ $EUID -ne 0 ]]; then
    echo "ERROR: This script must be run as root (sudo)"
    exit 1
fi

# Check if running on a master node
if ! test -f /etc/kubernetes/manifests/etcd.yaml; then
    echo "ERROR: etcd manifest not found. This does not appear to be a master node."
    exit 1
fi

# Verify etcd certificates exist
for cert_file in "$ETCD_CACERT" "$ETCD_CERT" "$ETCD_KEY"; do
    if [[ ! -f "$cert_file" ]]; then
        echo "ERROR: Certificate not found: $cert_file"
        exit 1
    fi
done

# Check etcdctl is available
if ! command -v etcdctl &>/dev/null; then
    echo "ERROR: etcdctl not found. Install it or use the etcd container."
    echo "  apt-get install etcd-client  OR"
    echo "  Use: kubectl exec -n kube-system etcd-<node> -- etcdctl ..."
    exit 1
fi

#===== Create Backup Directory =====
if [[ ! -d "$BACKUP_DIR" ]]; then
    echo "Creating backup directory: $BACKUP_DIR"
    mkdir -p "$BACKUP_DIR"
    chmod 700 "$BACKUP_DIR"
fi

#===== Take etcd Snapshot =====
echo "Taking etcd snapshot..."
echo "  Endpoint: $ETCD_ENDPOINT"
echo "  Output: $BACKUP_FILE"
echo ""

ETCDCTL_API=3 etcdctl snapshot save "$BACKUP_FILE" \
    --endpoints="$ETCD_ENDPOINT" \
    --cacert="$ETCD_CACERT" \
    --cert="$ETCD_CERT" \
    --key="$ETCD_KEY"

if [[ $? -ne 0 ]]; then
    echo "ERROR: etcd snapshot failed!"
    exit 1
fi

# Set secure permissions on backup file
chmod 600 "$BACKUP_FILE"

#===== Verify Snapshot =====
echo ""
echo "Verifying snapshot..."
ETCDCTL_API=3 etcdctl snapshot status "$BACKUP_FILE" --write-out=table

#===== Display Backup Info =====
BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
echo ""
echo "Backup Details:"
echo "  File: $BACKUP_FILE"
echo "  Size: $BACKUP_SIZE"
echo "  Date: $(date)"
echo ""

#===== Cleanup Old Backups =====
echo "Cleaning up old backups (keeping last $RETENTION_COUNT)..."
BACKUP_COUNT=$(ls -1 "${BACKUP_DIR}"/etcd-snapshot-*.db 2>/dev/null | wc -l)

if [[ "$BACKUP_COUNT" -gt "$RETENTION_COUNT" ]]; then
    REMOVE_COUNT=$((BACKUP_COUNT - RETENTION_COUNT))
    ls -1t "${BACKUP_DIR}"/etcd-snapshot-*.db | tail -n "$REMOVE_COUNT" | while read -r old_backup; do
        echo "  Removing: $(basename "$old_backup")"
        rm -f "$old_backup"
    done
    echo "  Removed $REMOVE_COUNT old backup(s)"
else
    echo "  No cleanup needed ($BACKUP_COUNT backups, limit: $RETENTION_COUNT)"
fi

#===== List Current Backups =====
echo ""
echo "Current backups in $BACKUP_DIR:"
ls -lh "${BACKUP_DIR}"/etcd-snapshot-*.db 2>/dev/null | while read -r line; do
    echo "  $line"
done

echo ""
echo "============================================"
echo "  etcd Backup Completed Successfully!"
echo "============================================"
