#!/usr/bin/env bash
# =============================================================================
# Cluster Health Diagnostic Script
# =============================================================================
# Performs a comprehensive health check of the Kubernetes cluster including
# node status, pod health, resource utilization, and component status.
#
# Usage:
#   ./diagnose-cluster.sh
#   ./diagnose-cluster.sh -h
#
# Requirements:
#   - kubectl configured with cluster access
#   - metrics-server installed (for resource utilization)
# =============================================================================

set -euo pipefail

#===== Colors =====
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

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
    echo "Performs a comprehensive health check of the Kubernetes cluster."
    echo ""
    echo "Options:"
    echo "  -h    Show this help message"
    echo ""
    echo "Checks performed:"
    echo "  - Node status and readiness"
    echo "  - Kubelet health on each node"
    echo "  - Pod status across all namespaces"
    echo "  - Resource utilization (nodes and pods)"
    echo "  - Recent warning and error events"
    echo "  - Control plane component status"
    echo "  - etcd health"
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
echo "  Kubernetes Cluster Health Check"
echo "  $(date)"
echo "============================================"

#===== 1. Node Status =====
section "Node Status"

NODE_OUTPUT=$(kubectl get nodes -o wide 2>&1)
echo "$NODE_OUTPUT"
echo ""

# Check each node
while IFS= read -r line; do
    NODE_NAME=$(echo "$line" | awk '{print $1}')
    NODE_STATUS=$(echo "$line" | awk '{print $2}')
    if [[ "$NODE_STATUS" == "Ready" ]]; then
        pass "Node $NODE_NAME is Ready"
    elif [[ "$NODE_STATUS" == "NotReady" ]]; then
        fail "Node $NODE_NAME is NotReady"
    else
        warn "Node $NODE_NAME status: $NODE_STATUS"
    fi
done < <(kubectl get nodes --no-headers 2>/dev/null)

#===== 2. Kubelet Health =====
section "Kubelet Health"

while IFS= read -r node; do
    KUBELET_STATUS=$(kubectl get node "$node" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
    KUBELET_MSG=$(kubectl get node "$node" -o jsonpath='{.status.conditions[?(@.type=="Ready")].message}' 2>/dev/null)
    if [[ "$KUBELET_STATUS" == "True" ]]; then
        pass "Kubelet on $node: $KUBELET_MSG"
    else
        fail "Kubelet on $node: $KUBELET_MSG"
    fi

    # Check for pressure conditions
    for condition in MemoryPressure DiskPressure PIDPressure; do
        COND_STATUS=$(kubectl get node "$node" -o jsonpath="{.status.conditions[?(@.type==\"$condition\")].status}" 2>/dev/null)
        if [[ "$COND_STATUS" == "True" ]]; then
            fail "$node has $condition"
        fi
    done
done < <(kubectl get nodes -o jsonpath='{.items[*].metadata.name}' | tr ' ' '\n')

#===== 3. Pod Status =====
section "Pod Status (All Namespaces)"

TOTAL_PODS=$(kubectl get pods -A --no-headers 2>/dev/null | wc -l | tr -d ' ')
RUNNING_PODS=$(kubectl get pods -A --no-headers --field-selector=status.phase=Running 2>/dev/null | wc -l | tr -d ' ')
PENDING_PODS=$(kubectl get pods -A --no-headers --field-selector=status.phase=Pending 2>/dev/null | wc -l | tr -d ' ')
FAILED_PODS=$(kubectl get pods -A --no-headers --field-selector=status.phase=Failed 2>/dev/null | wc -l | tr -d ' ')

info "Total pods: $TOTAL_PODS"
info "Running: $RUNNING_PODS"

if [[ "$PENDING_PODS" -gt 0 ]]; then
    warn "Pending pods: $PENDING_PODS"
    kubectl get pods -A --no-headers --field-selector=status.phase=Pending 2>/dev/null | while IFS= read -r line; do
        echo -e "    ${YELLOW}$line${NC}"
    done
else
    pass "No pending pods"
fi

if [[ "$FAILED_PODS" -gt 0 ]]; then
    fail "Failed pods: $FAILED_PODS"
    kubectl get pods -A --no-headers --field-selector=status.phase=Failed 2>/dev/null | while IFS= read -r line; do
        echo -e "    ${RED}$line${NC}"
    done
else
    pass "No failed pods"
fi

# Check for pods in CrashLoopBackOff or other bad states
CRASH_PODS=$(kubectl get pods -A --no-headers 2>/dev/null | grep -E "CrashLoopBackOff|Error|ImagePullBackOff|ErrImagePull" || true)
if [[ -n "$CRASH_PODS" ]]; then
    fail "Pods in error states:"
    echo "$CRASH_PODS" | while IFS= read -r line; do
        echo -e "    ${RED}$line${NC}"
    done
else
    pass "No pods in CrashLoopBackOff or error states"
fi

#===== 4. Resource Utilization =====
section "Resource Utilization"

if kubectl top nodes &>/dev/null; then
    echo "Node Resource Usage:"
    kubectl top nodes 2>/dev/null
    echo ""

    # Check for nodes with high utilization
    while IFS= read -r line; do
        NODE_NAME=$(echo "$line" | awk '{print $1}')
        CPU_PCT=$(echo "$line" | awk '{print $3}' | tr -d '%')
        MEM_PCT=$(echo "$line" | awk '{print $5}' | tr -d '%')

        if [[ -n "$CPU_PCT" ]] && [[ "$CPU_PCT" -gt 90 ]]; then
            fail "Node $NODE_NAME CPU usage: ${CPU_PCT}%"
        elif [[ -n "$CPU_PCT" ]] && [[ "$CPU_PCT" -gt 75 ]]; then
            warn "Node $NODE_NAME CPU usage: ${CPU_PCT}%"
        fi

        if [[ -n "$MEM_PCT" ]] && [[ "$MEM_PCT" -gt 90 ]]; then
            fail "Node $NODE_NAME memory usage: ${MEM_PCT}%"
        elif [[ -n "$MEM_PCT" ]] && [[ "$MEM_PCT" -gt 75 ]]; then
            warn "Node $NODE_NAME memory usage: ${MEM_PCT}%"
        fi
    done < <(kubectl top nodes --no-headers 2>/dev/null)

    echo "Top 10 Pods by CPU:"
    kubectl top pods -A --sort-by=cpu --no-headers 2>/dev/null | head -10 || true
    echo ""

    echo "Top 10 Pods by Memory:"
    kubectl top pods -A --sort-by=memory --no-headers 2>/dev/null | head -10 || true
else
    warn "metrics-server not available - cannot show resource utilization"
fi

#===== 5. Recent Events =====
section "Recent Events (Warnings & Errors)"

WARN_EVENTS=$(kubectl get events -A --field-selector type=Warning --sort-by='.lastTimestamp' 2>/dev/null | tail -20)
if [[ -n "$WARN_EVENTS" && "$WARN_EVENTS" != "No resources found" ]]; then
    warn "Recent warning events found:"
    echo "$WARN_EVENTS"
else
    pass "No recent warning events"
fi

#===== 6. Control Plane Components =====
section "Control Plane Components"

for component in kube-apiserver kube-controller-manager kube-scheduler; do
    POD_STATUS=$(kubectl get pods -n kube-system -l "component=$component" --no-headers 2>/dev/null | awk '{print $3}')
    if [[ "$POD_STATUS" == "Running" ]]; then
        pass "$component is Running"
    elif [[ -z "$POD_STATUS" ]]; then
        warn "$component pod not found (may use different labels)"
    else
        fail "$component status: $POD_STATUS"
    fi
done

# Check CoreDNS
COREDNS_READY=$(kubectl get pods -n kube-system -l k8s-app=kube-dns --no-headers 2>/dev/null | grep -c "Running" || true)
COREDNS_TOTAL=$(kubectl get pods -n kube-system -l k8s-app=kube-dns --no-headers 2>/dev/null | wc -l | tr -d ' ')
if [[ "$COREDNS_READY" -eq "$COREDNS_TOTAL" ]] && [[ "$COREDNS_TOTAL" -gt 0 ]]; then
    pass "CoreDNS: $COREDNS_READY/$COREDNS_TOTAL pods running"
else
    fail "CoreDNS: $COREDNS_READY/$COREDNS_TOTAL pods running"
fi

#===== 7. etcd Health =====
section "etcd Health"

ETCD_POD=$(kubectl get pods -n kube-system -l component=etcd --no-headers 2>/dev/null | awk '{print $1}' | head -1)
if [[ -n "$ETCD_POD" ]]; then
    ETCD_STATUS=$(kubectl get pod -n kube-system "$ETCD_POD" -o jsonpath='{.status.phase}' 2>/dev/null)
    if [[ "$ETCD_STATUS" == "Running" ]]; then
        pass "etcd pod is Running"
    else
        fail "etcd pod status: $ETCD_STATUS"
    fi

    # Try etcd endpoint health
    if kubectl exec -n kube-system "$ETCD_POD" -- etcdctl endpoint health \
        --cacert=/etc/kubernetes/pki/etcd/ca.crt \
        --cert=/etc/kubernetes/pki/etcd/server.crt \
        --key=/etc/kubernetes/pki/etcd/server.key 2>/dev/null; then
        pass "etcd endpoint health check passed"
    else
        warn "Could not verify etcd endpoint health (may need different cert paths)"
    fi
else
    warn "etcd pod not found in kube-system (may be running as external service)"
fi

#===== Summary =====
section "Health Check Summary"

echo ""
echo -e "  ${GREEN}Passed:  $PASS_COUNT${NC}"
echo -e "  ${YELLOW}Warnings: $WARN_COUNT${NC}"
echo -e "  ${RED}Failed:  $FAIL_COUNT${NC}"
echo ""

if [[ "$FAIL_COUNT" -gt 0 ]]; then
    echo -e "  ${RED}Overall: ISSUES DETECTED${NC}"
    echo "  Review the failures above and take corrective action."
    exit 1
elif [[ "$WARN_COUNT" -gt 0 ]]; then
    echo -e "  ${YELLOW}Overall: HEALTHY (with warnings)${NC}"
    echo "  Review warnings above for potential issues."
    exit 0
else
    echo -e "  ${GREEN}Overall: HEALTHY${NC}"
    exit 0
fi
