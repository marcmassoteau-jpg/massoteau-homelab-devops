#!/usr/bin/env bash
# =============================================================================
# Storage Diagnostic Script
# =============================================================================
# Diagnoses Kubernetes storage issues including PV/PVC status, storage
# classes, disk usage, and capacity problems.
#
# Usage:
#   ./diagnose-storage.sh
#   ./diagnose-storage.sh -h
#
# Requirements:
#   - kubectl configured with cluster access
# =============================================================================

set -euo pipefail

#===== Colors =====
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

#===== Counters =====
PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0

#===== Functions =====
pass() {
    echo -e "  ${GREEN}[PASS]${NC} $1"
    ((PASS_COUNT++)) || true
}

fail() {
    echo -e "  ${RED}[FAIL]${NC} $1"
    ((FAIL_COUNT++)) || true
}

warn() {
    echo -e "  ${YELLOW}[WARN]${NC} $1"
    ((WARN_COUNT++)) || true
}

info() {
    echo -e "  ${CYAN}[INFO]${NC} $1"
}

section() {
    echo ""
    echo "============================================"
    echo "  $1"
    echo "============================================"
}

show_help() {
    echo "Usage: $(basename "$0") [-h]"
    echo ""
    echo "Diagnoses Kubernetes storage issues."
    echo ""
    echo "Options:"
    echo "  -h    Show this help message"
    echo ""
    echo "Checks performed:"
    echo "  - PersistentVolume (PV) status"
    echo "  - PersistentVolumeClaim (PVC) status"
    echo "  - Unbound PVCs"
    echo "  - Storage classes"
    echo "  - Node disk usage"
    echo "  - PVC capacity utilization"
    exit 0
}

#===== Parse Arguments =====
while getopts "h" opt; do
    case ${opt} in
        h) show_help ;;
        *) show_help ;;
    esac
done

#===== Pre-flight =====
if ! command -v kubectl &>/dev/null; then
    echo -e "${RED}ERROR: kubectl not found in PATH${NC}"
    exit 1
fi

if ! kubectl cluster-info &>/dev/null; then
    echo -e "${RED}ERROR: Cannot connect to Kubernetes cluster${NC}"
    exit 1
fi

echo "============================================"
echo "  Storage Diagnostics"
echo "  $(date)"
echo "============================================"

#===== 1. Storage Classes =====
section "Storage Classes"

SC_OUTPUT=$(kubectl get storageclass 2>/dev/null || true)
if [[ -n "$SC_OUTPUT" ]]; then
    echo "$SC_OUTPUT"
    echo ""

    # Check for default storage class
    DEFAULT_SC=$(kubectl get storageclass -o jsonpath='{.items[?(@.metadata.annotations.storageclass\.kubernetes\.io/is-default-class=="true")].metadata.name}' 2>/dev/null || true)
    if [[ -n "$DEFAULT_SC" ]]; then
        pass "Default storage class: $DEFAULT_SC"
    else
        warn "No default storage class configured"
    fi
else
    warn "No storage classes found"
fi

#===== 2. PersistentVolumes =====
section "PersistentVolumes (PV)"

PV_OUTPUT=$(kubectl get pv --no-headers 2>/dev/null || true)
if [[ -n "$PV_OUTPUT" ]]; then
    kubectl get pv 2>/dev/null
    echo ""

    PV_TOTAL=$(echo "$PV_OUTPUT" | wc -l | tr -d ' ')
    PV_BOUND=$(echo "$PV_OUTPUT" | grep -c "Bound" || true)
    PV_AVAILABLE=$(echo "$PV_OUTPUT" | grep -c "Available" || true)
    PV_RELEASED=$(echo "$PV_OUTPUT" | grep -c "Released" || true)
    PV_FAILED=$(echo "$PV_OUTPUT" | grep -c "Failed" || true)

    info "Total PVs: $PV_TOTAL"
    info "Bound: $PV_BOUND | Available: $PV_AVAILABLE | Released: $PV_RELEASED | Failed: $PV_FAILED"

    if [[ "$PV_FAILED" -gt 0 ]]; then
        fail "$PV_FAILED PV(s) in Failed state:"
        echo "$PV_OUTPUT" | grep "Failed" | while IFS= read -r line; do
            echo -e "    ${RED}$line${NC}"
        done
    fi

    if [[ "$PV_RELEASED" -gt 0 ]]; then
        warn "$PV_RELEASED PV(s) in Released state (data may need reclaim):"
        echo "$PV_OUTPUT" | grep "Released" | while IFS= read -r line; do
            echo -e "    ${YELLOW}$line${NC}"
        done
    fi

    if [[ "$PV_FAILED" -eq 0 ]]; then
        pass "No PVs in Failed state"
    fi
else
    info "No PersistentVolumes found"
fi

#===== 3. PersistentVolumeClaims =====
section "PersistentVolumeClaims (PVC)"

PVC_OUTPUT=$(kubectl get pvc -A --no-headers 2>/dev/null || true)
if [[ -n "$PVC_OUTPUT" ]]; then
    kubectl get pvc -A 2>/dev/null
    echo ""

    PVC_TOTAL=$(echo "$PVC_OUTPUT" | wc -l | tr -d ' ')
    PVC_BOUND=$(echo "$PVC_OUTPUT" | grep -c "Bound" || true)
    PVC_PENDING=$(echo "$PVC_OUTPUT" | grep -c "Pending" || true)
    PVC_LOST=$(echo "$PVC_OUTPUT" | grep -c "Lost" || true)

    info "Total PVCs: $PVC_TOTAL"
    info "Bound: $PVC_BOUND | Pending: $PVC_PENDING | Lost: $PVC_LOST"

    if [[ "$PVC_PENDING" -gt 0 ]]; then
        fail "$PVC_PENDING PVC(s) stuck in Pending state:"
        echo "$PVC_OUTPUT" | grep "Pending" | while IFS= read -r line; do
            NS=$(echo "$line" | awk '{print $1}')
            PVC_NAME=$(echo "$line" | awk '{print $2}')
            echo -e "    ${RED}$line${NC}"
            # Show events for pending PVC
            EVENTS=$(kubectl get events -n "$NS" --field-selector "involvedObject.name=$PVC_NAME,involvedObject.kind=PersistentVolumeClaim" --no-headers 2>/dev/null | tail -3)
            if [[ -n "$EVENTS" ]]; then
                echo "    Recent events:"
                echo "$EVENTS" | sed 's/^/      /'
            fi
        done
    else
        pass "No PVCs stuck in Pending"
    fi

    if [[ "$PVC_LOST" -gt 0 ]]; then
        fail "$PVC_LOST PVC(s) in Lost state"
    fi
else
    info "No PersistentVolumeClaims found"
fi

#===== 4. Unbound PVCs =====
section "Unbound PVC Analysis"

UNBOUND_PVCS=$(kubectl get pvc -A -o custom-columns='NAMESPACE:.metadata.namespace,NAME:.metadata.name,STATUS:.status.phase,STORAGECLASS:.spec.storageClassName' --no-headers 2>/dev/null | grep -v "Bound" || true)
if [[ -n "$UNBOUND_PVCS" ]]; then
    fail "Unbound PVCs found:"
    while IFS= read -r line; do
        NS=$(echo "$line" | awk '{print $1}')
        PVC_NAME=$(echo "$line" | awk '{print $2}')
        STATUS=$(echo "$line" | awk '{print $3}')
        SC=$(echo "$line" | awk '{print $4}')

        echo -e "    ${YELLOW}$NS/$PVC_NAME (status: $STATUS, storageClass: $SC)${NC}"

        # Check if storage class exists
        if [[ -n "$SC" ]] && [[ "$SC" != "<none>" ]]; then
            if ! kubectl get storageclass "$SC" &>/dev/null 2>&1; then
                echo -e "      ${RED}Storage class '$SC' does not exist!${NC}"
            fi
        fi
    done <<< "$UNBOUND_PVCS"
else
    pass "All PVCs are bound"
fi

#===== 5. Node Disk Usage =====
section "Node Disk Usage"

while IFS= read -r node; do
    info "Node: $node"

    # Get allocatable storage info from node
    ALLOC_STORAGE=$(kubectl get node "$node" -o jsonpath='{.status.allocatable.ephemeral-storage}' 2>/dev/null || true)
    if [[ -n "$ALLOC_STORAGE" ]]; then
        info "  Allocatable ephemeral storage: $ALLOC_STORAGE"
    fi

    # Check node conditions for disk pressure
    DISK_PRESSURE=$(kubectl get node "$node" -o jsonpath='{.status.conditions[?(@.type=="DiskPressure")].status}' 2>/dev/null || true)
    if [[ "$DISK_PRESSURE" == "True" ]]; then
        fail "  Node $node has DiskPressure condition!"
    else
        pass "  Node $node: no DiskPressure"
    fi
done < <(kubectl get nodes -o jsonpath='{.items[*].metadata.name}' | tr ' ' '\n')

#===== 6. PVC Capacity Check =====
section "PVC Capacity"

# Check if metrics are available for PVC usage
HAS_KUBELET_METRICS=false
FIRST_NODE=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
if [[ -n "$FIRST_NODE" ]]; then
    if kubectl get --raw "/api/v1/nodes/$FIRST_NODE/proxy/stats/summary" &>/dev/null 2>&1; then
        HAS_KUBELET_METRICS=true
    fi
fi

if [[ "$HAS_KUBELET_METRICS" == "true" ]]; then
    info "Checking PVC usage via kubelet stats (this may take a moment)..."
    while IFS= read -r node; do
        STATS=$(kubectl get --raw "/api/v1/nodes/$node/proxy/stats/summary" 2>/dev/null || true)
        if [[ -n "$STATS" ]] && command -v jq &>/dev/null; then
            echo "$STATS" | jq -r '.pods[]? | select(.volume != null) | .volume[]? | select(.pvcRef != null) | "\(.pvcRef.namespace)/\(.pvcRef.name): \(.usedBytes // 0) / \(.capacityBytes // 0)"' 2>/dev/null | while IFS= read -r vol_line; do
                PVC_NAME=$(echo "$vol_line" | cut -d: -f1)
                USED=$(echo "$vol_line" | awk '{print $2}')
                CAPACITY=$(echo "$vol_line" | awk '{print $4}')
                if [[ "$CAPACITY" -gt 0 ]] 2>/dev/null; then
                    USAGE_PCT=$((USED * 100 / CAPACITY))
                    if [[ "$USAGE_PCT" -gt 90 ]]; then
                        fail "PVC $PVC_NAME: ${USAGE_PCT}% full"
                    elif [[ "$USAGE_PCT" -gt 75 ]]; then
                        warn "PVC $PVC_NAME: ${USAGE_PCT}% full"
                    fi
                fi
            done
        fi
    done < <(kubectl get nodes -o jsonpath='{.items[*].metadata.name}' | tr ' ' '\n')
else
    info "Kubelet stats not accessible - showing PVC capacity from claims"
    kubectl get pvc -A -o custom-columns='NAMESPACE:.metadata.namespace,NAME:.metadata.name,STATUS:.status.phase,CAPACITY:.status.capacity.storage,STORAGECLASS:.spec.storageClassName' 2>/dev/null | sed 's/^/    /'
fi

#===== Summary =====
section "Storage Diagnostics Summary"

echo ""
echo -e "  ${GREEN}Passed:  $PASS_COUNT${NC}"
echo -e "  ${YELLOW}Warnings: $WARN_COUNT${NC}"
echo -e "  ${RED}Failed:  $FAIL_COUNT${NC}"
echo ""

if [[ "$FAIL_COUNT" -gt 0 ]]; then
    echo -e "  ${RED}Overall: STORAGE ISSUES DETECTED${NC}"
    echo "  Review failures above and check docs/troubleshooting/storage-issues.md"
    exit 1
elif [[ "$WARN_COUNT" -gt 0 ]]; then
    echo -e "  ${YELLOW}Overall: MOSTLY HEALTHY (with warnings)${NC}"
    exit 0
else
    echo -e "  ${GREEN}Overall: STORAGE HEALTHY${NC}"
    exit 0
fi
