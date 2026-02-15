#!/usr/bin/env bash
# =============================================================================
# Velero Backup Status Script
# =============================================================================
# Displays a comprehensive overview of Velero backup status including
# schedules, recent backups, storage locations, and any failures.
#
# Usage:
#   ./velero-backup-status.sh
# =============================================================================

set -euo pipefail

VELERO_NAMESPACE="velero"

echo "============================================"
echo "  Velero Backup Status Report"
echo "  $(date)"
echo "============================================"
echo ""

#===== Check Velero is Running =====
if ! kubectl get namespace "$VELERO_NAMESPACE" &>/dev/null; then
    echo "ERROR: Velero namespace '$VELERO_NAMESPACE' not found."
    echo "       Is Velero installed?"
    exit 1
fi

VELERO_PODS=$(kubectl get pods -n "$VELERO_NAMESPACE" -l app.kubernetes.io/name=velero --no-headers 2>/dev/null)
if [[ -z "$VELERO_PODS" ]]; then
    echo "ERROR: No Velero pods found in namespace '$VELERO_NAMESPACE'."
    exit 1
fi

#===== Backup Storage Locations =====
echo "--------------------------------------------"
echo "  Backup Storage Locations"
echo "--------------------------------------------"
kubectl get backupstoragelocation -n "$VELERO_NAMESPACE" -o wide 2>/dev/null || echo "  (none found)"
echo ""

# Check for unavailable BSLs
UNAVAILABLE_BSL=$(kubectl get backupstoragelocation -n "$VELERO_NAMESPACE" -o json 2>/dev/null | \
    jq -r '.items[] | select(.status.phase != "Available") | .metadata.name' 2>/dev/null || true)
if [[ -n "$UNAVAILABLE_BSL" ]]; then
    echo "  ** WARNING: The following storage locations are NOT Available:"
    echo "$UNAVAILABLE_BSL" | while read -r bsl; do
        echo "     - $bsl"
    done
    echo ""
fi

#===== Backup Schedules =====
echo "--------------------------------------------"
echo "  Backup Schedules"
echo "--------------------------------------------"
kubectl get schedules.velero.io -n "$VELERO_NAMESPACE" 2>/dev/null || echo "  (none found)"
echo ""

#===== Last 5 Backups =====
echo "--------------------------------------------"
echo "  Last 5 Backups"
echo "--------------------------------------------"
kubectl get backups.velero.io -n "$VELERO_NAMESPACE" \
    --sort-by=.metadata.creationTimestamp 2>/dev/null | tail -6 || echo "  (none found)"
echo ""

#===== Failed Backups =====
echo "--------------------------------------------"
echo "  Failed / Partially Failed Backups"
echo "--------------------------------------------"
FAILED_BACKUPS=$(kubectl get backups.velero.io -n "$VELERO_NAMESPACE" -o json 2>/dev/null | \
    jq -r '.items[] | select(.status.phase == "Failed" or .status.phase == "PartiallyFailed") | "\(.metadata.name)\t\(.status.phase)\t\(.metadata.creationTimestamp)"' 2>/dev/null || true)

if [[ -n "$FAILED_BACKUPS" ]]; then
    echo "  ** WARNING: Failed backups detected!"
    echo ""
    printf "  %-40s %-20s %s\n" "NAME" "STATUS" "CREATED"
    echo "$FAILED_BACKUPS" | while IFS=$'\t' read -r name phase created; do
        printf "  %-40s %-20s %s\n" "$name" "$phase" "$created"
    done
else
    echo "  No failed backups found."
fi
echo ""

#===== Recent Restores =====
echo "--------------------------------------------"
echo "  Recent Restores"
echo "--------------------------------------------"
kubectl get restores.velero.io -n "$VELERO_NAMESPACE" \
    --sort-by=.metadata.creationTimestamp 2>/dev/null | tail -6 || echo "  (none found)"
echo ""

#===== Velero Pod Status =====
echo "--------------------------------------------"
echo "  Velero Pods"
echo "--------------------------------------------"
kubectl get pods -n "$VELERO_NAMESPACE" -o wide 2>/dev/null || echo "  (none found)"
echo ""

#===== Summary =====
TOTAL_BACKUPS=$(kubectl get backups.velero.io -n "$VELERO_NAMESPACE" --no-headers 2>/dev/null | wc -l | tr -d ' ')
TOTAL_SCHEDULES=$(kubectl get schedules.velero.io -n "$VELERO_NAMESPACE" --no-headers 2>/dev/null | wc -l | tr -d ' ')
FAILED_COUNT=$(kubectl get backups.velero.io -n "$VELERO_NAMESPACE" -o json 2>/dev/null | \
    jq '[.items[] | select(.status.phase == "Failed" or .status.phase == "PartiallyFailed")] | length' 2>/dev/null || echo "0")

echo "============================================"
echo "  Summary"
echo "============================================"
echo "  Total Backups:    $TOTAL_BACKUPS"
echo "  Total Schedules:  $TOTAL_SCHEDULES"
echo "  Failed Backups:   $FAILED_COUNT"
echo ""

if [[ "$FAILED_COUNT" -gt 0 ]]; then
    echo "  ** ACTION REQUIRED: Check failed backups above!"
else
    echo "  All backups healthy."
fi
echo "============================================"
