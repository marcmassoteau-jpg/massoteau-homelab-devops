#!/usr/bin/env bash
# =============================================================================
# Pod Diagnostic Script
# =============================================================================
# Performs detailed diagnostics on a specific pod including description,
# events, logs, resource usage, and container statuses.
#
# Usage:
#   ./diagnose-pod.sh <pod-name> <namespace>
#   ./diagnose-pod.sh my-app-pod default
#   ./diagnose-pod.sh -h
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

#===== Functions =====
pass() {
    echo -e "  ${GREEN}[PASS]${NC} $1"
}

fail() {
    echo -e "  ${RED}[FAIL]${NC} $1"
}

warn() {
    echo -e "  ${YELLOW}[WARN]${NC} $1"
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
    echo "Usage: $(basename "$0") <pod-name> <namespace>"
    echo ""
    echo "Performs detailed diagnostics on a specific Kubernetes pod."
    echo ""
    echo "Arguments:"
    echo "  pod-name    Name of the pod to diagnose"
    echo "  namespace   Namespace where the pod is running"
    echo ""
    echo "Options:"
    echo "  -h          Show this help message"
    echo ""
    echo "Examples:"
    echo "  $(basename "$0") nginx-7d6b4 default"
    echo "  $(basename "$0") gitlab-webservice-0 gitlab"
    echo ""
    echo "Information gathered:"
    echo "  - Pod description (full kubectl describe)"
    echo "  - Pod events"
    echo "  - Container logs (last 50 lines per container)"
    echo "  - Resource usage (if metrics-server is available)"
    echo "  - Container statuses and restart counts"
    exit 0
}

#===== Parse Arguments =====
if [[ "${1:-}" == "-h" ]] || [[ "${1:-}" == "--help" ]]; then
    show_help
fi

if [[ $# -lt 2 ]]; then
    echo -e "${RED}ERROR: Missing required arguments${NC}"
    echo ""
    echo "Usage: $(basename "$0") <pod-name> <namespace>"
    echo "       $(basename "$0") -h for help"
    exit 1
fi

POD_NAME="$1"
NAMESPACE="$2"

#===== Pre-flight =====
if ! command -v kubectl &>/dev/null; then
    echo -e "${RED}ERROR: kubectl not found in PATH${NC}"
    exit 1
fi

if ! kubectl get pod "$POD_NAME" -n "$NAMESPACE" &>/dev/null; then
    echo -e "${RED}ERROR: Pod '$POD_NAME' not found in namespace '$NAMESPACE'${NC}"
    echo ""
    echo "Available pods in namespace '$NAMESPACE':"
    kubectl get pods -n "$NAMESPACE" --no-headers 2>/dev/null | awk '{print "  " $1}' || echo "  (namespace may not exist)"
    exit 1
fi

echo "============================================"
echo "  Pod Diagnostics: $POD_NAME"
echo "  Namespace: $NAMESPACE"
echo "  $(date)"
echo "============================================"

#===== 1. Pod Overview =====
section "Pod Overview"

POD_PHASE=$(kubectl get pod "$POD_NAME" -n "$NAMESPACE" -o jsonpath='{.status.phase}' 2>/dev/null)
POD_NODE=$(kubectl get pod "$POD_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.nodeName}' 2>/dev/null)
POD_IP=$(kubectl get pod "$POD_NAME" -n "$NAMESPACE" -o jsonpath='{.status.podIP}' 2>/dev/null)
POD_QOS=$(kubectl get pod "$POD_NAME" -n "$NAMESPACE" -o jsonpath='{.status.qosClass}' 2>/dev/null)
POD_SA=$(kubectl get pod "$POD_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.serviceAccountName}' 2>/dev/null)
CREATION=$(kubectl get pod "$POD_NAME" -n "$NAMESPACE" -o jsonpath='{.metadata.creationTimestamp}' 2>/dev/null)

info "Phase: $POD_PHASE"
info "Node: $POD_NODE"
info "Pod IP: $POD_IP"
info "QoS Class: $POD_QOS"
info "Service Account: $POD_SA"
info "Created: $CREATION"

if [[ "$POD_PHASE" == "Running" ]]; then
    pass "Pod is Running"
elif [[ "$POD_PHASE" == "Succeeded" ]]; then
    pass "Pod completed successfully"
elif [[ "$POD_PHASE" == "Pending" ]]; then
    warn "Pod is Pending"
else
    fail "Pod phase: $POD_PHASE"
fi

#===== 2. Container Statuses =====
section "Container Statuses"

CONTAINERS=$(kubectl get pod "$POD_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.containers[*].name}' 2>/dev/null)

for container in $CONTAINERS; do
    echo ""
    info "Container: $container"

    # Get current state
    STATE=$(kubectl get pod "$POD_NAME" -n "$NAMESPACE" -o jsonpath="{.status.containerStatuses[?(@.name==\"$container\")].state}" 2>/dev/null)
    READY=$(kubectl get pod "$POD_NAME" -n "$NAMESPACE" -o jsonpath="{.status.containerStatuses[?(@.name==\"$container\")].ready}" 2>/dev/null)
    RESTART_COUNT=$(kubectl get pod "$POD_NAME" -n "$NAMESPACE" -o jsonpath="{.status.containerStatuses[?(@.name==\"$container\")].restartCount}" 2>/dev/null)
    IMAGE=$(kubectl get pod "$POD_NAME" -n "$NAMESPACE" -o jsonpath="{.spec.containers[?(@.name==\"$container\")].image}" 2>/dev/null)

    info "  Image: $IMAGE"
    info "  Ready: $READY"
    info "  Restart count: $RESTART_COUNT"

    if [[ "$READY" == "true" ]]; then
        pass "  Container $container is ready"
    else
        fail "  Container $container is not ready"
    fi

    if [[ -n "$RESTART_COUNT" ]] && [[ "$RESTART_COUNT" -gt 5 ]]; then
        fail "  Container $container has restarted $RESTART_COUNT times"
    elif [[ -n "$RESTART_COUNT" ]] && [[ "$RESTART_COUNT" -gt 0 ]]; then
        warn "  Container $container has restarted $RESTART_COUNT times"
    fi

    # Get resource requests and limits
    CPU_REQ=$(kubectl get pod "$POD_NAME" -n "$NAMESPACE" -o jsonpath="{.spec.containers[?(@.name==\"$container\")].resources.requests.cpu}" 2>/dev/null || true)
    CPU_LIM=$(kubectl get pod "$POD_NAME" -n "$NAMESPACE" -o jsonpath="{.spec.containers[?(@.name==\"$container\")].resources.limits.cpu}" 2>/dev/null || true)
    MEM_REQ=$(kubectl get pod "$POD_NAME" -n "$NAMESPACE" -o jsonpath="{.spec.containers[?(@.name==\"$container\")].resources.requests.memory}" 2>/dev/null || true)
    MEM_LIM=$(kubectl get pod "$POD_NAME" -n "$NAMESPACE" -o jsonpath="{.spec.containers[?(@.name==\"$container\")].resources.limits.memory}" 2>/dev/null || true)

    info "  Resources:"
    info "    CPU request/limit: ${CPU_REQ:-<none>} / ${CPU_LIM:-<none>}"
    info "    Memory request/limit: ${MEM_REQ:-<none>} / ${MEM_LIM:-<none>}"

    if [[ -z "$CPU_REQ" ]] && [[ -z "$MEM_REQ" ]]; then
        warn "  No resource requests set for container $container"
    fi
done

# Init containers
INIT_CONTAINERS=$(kubectl get pod "$POD_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.initContainers[*].name}' 2>/dev/null || true)
if [[ -n "$INIT_CONTAINERS" ]]; then
    echo ""
    info "Init Containers:"
    for init_container in $INIT_CONTAINERS; do
        INIT_STATE=$(kubectl get pod "$POD_NAME" -n "$NAMESPACE" -o jsonpath="{.status.initContainerStatuses[?(@.name==\"$init_container\")].state}" 2>/dev/null)
        info "  $init_container: $INIT_STATE"
    done
fi

#===== 3. Pod Events =====
section "Pod Events"

EVENTS=$(kubectl get events -n "$NAMESPACE" --field-selector "involvedObject.name=$POD_NAME" --sort-by='.lastTimestamp' 2>/dev/null || true)
if [[ -n "$EVENTS" ]] && [[ "$EVENTS" != "No resources found"* ]]; then
    echo "$EVENTS"
else
    info "No events found for this pod (events may have expired)"
fi

#===== 4. Container Logs =====
section "Container Logs (last 50 lines)"

for container in $CONTAINERS; do
    echo ""
    echo "--- Container: $container ---"

    LOGS=$(kubectl logs "$POD_NAME" -n "$NAMESPACE" -c "$container" --tail=50 2>&1 || true)
    if [[ -n "$LOGS" ]]; then
        echo "$LOGS"
    else
        info "No logs available"
    fi

    # Show previous container logs if there were restarts
    RESTART_COUNT=$(kubectl get pod "$POD_NAME" -n "$NAMESPACE" -o jsonpath="{.status.containerStatuses[?(@.name==\"$container\")].restartCount}" 2>/dev/null || echo "0")
    if [[ "$RESTART_COUNT" -gt 0 ]]; then
        echo ""
        echo "--- Container: $container (previous instance) ---"
        PREV_LOGS=$(kubectl logs "$POD_NAME" -n "$NAMESPACE" -c "$container" --previous --tail=30 2>&1 || true)
        if [[ -n "$PREV_LOGS" ]]; then
            echo "$PREV_LOGS"
        else
            info "No previous logs available"
        fi
    fi
done

#===== 5. Resource Usage =====
section "Resource Usage"

if kubectl top pod "$POD_NAME" -n "$NAMESPACE" &>/dev/null 2>&1; then
    kubectl top pod "$POD_NAME" -n "$NAMESPACE" --containers 2>/dev/null
else
    warn "metrics-server not available - cannot show resource usage"
fi

#===== 6. Full Describe =====
section "Full Pod Description"

kubectl describe pod "$POD_NAME" -n "$NAMESPACE" 2>/dev/null

echo ""
echo "============================================"
echo "  Pod Diagnostics Complete"
echo "============================================"
