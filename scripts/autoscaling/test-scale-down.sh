#!/bin/bash
# =============================================================================
# Test Scale-Down
# Reduces stress deployment replicas and monitors node scale-down behavior
#
# Usage:
#   ./test-scale-down.sh
#   ./test-scale-down.sh --wait
# =============================================================================
set -euo pipefail

#=============================================================================
# CONFIGURATION
#=============================================================================

NAMESPACE="default"
DEPLOYMENT_NAME="autoscaler-stress-test"
AUTOSCALER_NS="autoscaling"

#=============================================================================
# USAGE
#=============================================================================

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Test cluster autoscaler scale-down by reducing replicas."
    echo ""
    echo "Options:"
    echo "  --wait      Watch node status until scale-down occurs"
    echo "  --status    Show current autoscaler status only"
    echo "  -h, --help  Show this help message"
    exit 0
}

#=============================================================================
# ARGUMENT PARSING
#=============================================================================

WAIT=false
STATUS_ONLY=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --wait)    WAIT=true; shift ;;
        --status)  STATUS_ONLY=true; shift ;;
        -h|--help) usage ;;
        *)         echo "Unknown option: $1"; usage ;;
    esac
done

#=============================================================================
# STATUS CHECK
#=============================================================================

echo "=== Cluster Autoscaler Scale-Down Test ==="
echo "Time: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo ""

echo "Current nodes:"
kubectl get nodes -o wide
echo ""

echo "Node utilization:"
kubectl top nodes 2>/dev/null || echo "  metrics not yet available"
echo ""

echo "Autoscale nodes:"
kubectl get nodes --no-headers -o custom-columns=NAME:.metadata.name | grep "k8s-autoscale" || echo "  No autoscale nodes found"
echo ""

# Check for scale-down candidates
echo "Scale-down candidates (annotated nodes):"
kubectl get nodes -o json | jq -r '.items[] |
    select(.metadata.annotations["cluster-autoscaler/scale-down-candidate"] != null) |
    "\(.metadata.name): candidate since \(.metadata.annotations["cluster-autoscaler/scale-down-candidate"])"' 2>/dev/null || echo "  None"
echo ""

if [[ "${STATUS_ONLY}" == "true" ]]; then
    exit 0
fi

#=============================================================================
# REDUCE REPLICAS
#=============================================================================

# Check if stress deployment exists
if kubectl get deployment "${DEPLOYMENT_NAME}" -n "${NAMESPACE}" &>/dev/null; then
    CURRENT_REPLICAS=$(kubectl get deployment "${DEPLOYMENT_NAME}" -n "${NAMESPACE}" -o jsonpath='{.spec.replicas}')
    echo "Current stress deployment replicas: ${CURRENT_REPLICAS}"

    echo "Scaling stress deployment to 0 replicas..."
    kubectl scale deployment "${DEPLOYMENT_NAME}" -n "${NAMESPACE}" --replicas=0
    echo "Deployment scaled to 0."
else
    echo "No stress deployment found. Checking for other test resources..."
fi

echo ""
echo "Waiting for pods to terminate..."
sleep 15

echo ""
echo "Current pod status:"
kubectl get pods -n "${NAMESPACE}" -l "purpose=autoscaler-test" --no-headers 2>/dev/null || echo "  No test pods remaining"

#=============================================================================
# MONITOR SCALE-DOWN
#=============================================================================

echo ""
echo "The cluster autoscaler scale-down CronJob should:"
echo "  1. Detect underutilized autoscale nodes (every 5 min)"
echo "  2. Mark nodes as scale-down candidates"
echo "  3. Wait for scale-down delay (default: 300s)"
echo "  4. Cordon and drain the node"
echo "  5. Log ready-for-removal event"
echo ""
echo "Monitor:"
echo "  kubectl get jobs -n ${AUTOSCALER_NS} -w"
echo "  kubectl logs -n ${AUTOSCALER_NS} -l app.kubernetes.io/component=scale-down --tail=20"
echo "  kubectl get nodes -w"

if [[ "${WAIT}" == "true" ]]; then
    echo ""
    echo "Watching nodes (Ctrl+C to stop)..."
    kubectl get nodes -w
fi

echo ""
echo "To fully clean up test resources:"
echo "  scripts/autoscaling/test-scale-up.sh --cleanup"
