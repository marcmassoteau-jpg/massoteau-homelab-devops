#!/bin/bash
# =============================================================================
# Test Scale-Up
# Creates a stress deployment with many replicas to trigger pending pods
# and test the cluster autoscaler scale-up behavior
#
# Usage:
#   ./test-scale-up.sh
#   ./test-scale-up.sh --replicas 30
#   ./test-scale-up.sh --cleanup
# =============================================================================
set -euo pipefail

#=============================================================================
# CONFIGURATION
#=============================================================================

REPLICAS="${REPLICAS:-20}"
NAMESPACE="default"
DEPLOYMENT_NAME="autoscaler-stress-test"
WATCH_TIMEOUT="${WATCH_TIMEOUT:-300}"

#=============================================================================
# USAGE
#=============================================================================

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Test cluster autoscaler scale-up by creating CPU-intensive pods."
    echo ""
    echo "Options:"
    echo "  --replicas N    Number of stress replicas (default: 20)"
    echo "  --cleanup       Remove test resources and exit"
    echo "  --watch         Watch pod scheduling after deployment"
    echo "  -h, --help      Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                     # Deploy 20 stress pods"
    echo "  $0 --replicas 30       # Deploy 30 stress pods"
    echo "  $0 --cleanup           # Remove all test resources"
    exit 0
}

#=============================================================================
# ARGUMENT PARSING
#=============================================================================

CLEANUP=false
WATCH=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --replicas)  REPLICAS="$2"; shift 2 ;;
        --cleanup)   CLEANUP=true; shift ;;
        --watch)     WATCH=true; shift ;;
        -h|--help)   usage ;;
        *)           echo "Unknown option: $1"; usage ;;
    esac
done

#=============================================================================
# CLEANUP
#=============================================================================

if [[ "${CLEANUP}" == "true" ]]; then
    echo "=== Cleaning up scale-up test resources ==="
    kubectl delete deployment "${DEPLOYMENT_NAME}" -n "${NAMESPACE}" 2>/dev/null || true
    kubectl delete hpa "${DEPLOYMENT_NAME}-hpa" -n "${NAMESPACE}" 2>/dev/null || true
    echo "Cleanup complete."
    echo ""
    echo "Current pods:"
    kubectl get pods -n "${NAMESPACE}" --field-selector=status.phase=Pending 2>/dev/null || echo "  No pending pods"
    echo ""
    echo "Current nodes:"
    kubectl get nodes
    exit 0
fi

#=============================================================================
# PRE-CHECK
#=============================================================================

echo "=== Cluster Autoscaler Scale-Up Test ==="
echo "Time: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo ""

echo "Current cluster state:"
echo "  Nodes:"
kubectl get nodes --no-headers | while read -r line; do echo "    ${line}"; done
echo ""
echo "  Node resources:"
kubectl top nodes 2>/dev/null || echo "    metrics not yet available"
echo ""

#=============================================================================
# DEPLOY STRESS TEST
#=============================================================================

echo "Deploying ${REPLICAS} stress-test replicas..."
echo "Each pod requests 500m CPU and 128Mi memory."
echo ""

kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${DEPLOYMENT_NAME}
  namespace: ${NAMESPACE}
  labels:
    app: ${DEPLOYMENT_NAME}
    purpose: autoscaler-test
spec:
  replicas: ${REPLICAS}
  selector:
    matchLabels:
      app: ${DEPLOYMENT_NAME}
  template:
    metadata:
      labels:
        app: ${DEPLOYMENT_NAME}
        purpose: autoscaler-test
    spec:
      containers:
        - name: stress
          image: progrium/stress:latest
          command: ["stress"]
          args: ["--cpu", "1", "--timeout", "3600"]
          resources:
            requests:
              cpu: 500m
              memory: 128Mi
            limits:
              cpu: "1"
              memory: 256Mi
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
              - matchExpressions:
                  - key: node-role.kubernetes.io/control-plane
                    operator: DoesNotExist
EOF

echo ""
echo "Deployment created. Waiting for pods to be scheduled..."
sleep 10

#=============================================================================
# MONITOR
#=============================================================================

echo ""
echo "Pod status:"
kubectl get pods -n "${NAMESPACE}" -l "app=${DEPLOYMENT_NAME}" --no-headers | head -20

PENDING_COUNT=$(kubectl get pods -n "${NAMESPACE}" -l "app=${DEPLOYMENT_NAME}" \
    --field-selector=status.phase=Pending --no-headers 2>/dev/null | wc -l | tr -d ' ')
RUNNING_COUNT=$(kubectl get pods -n "${NAMESPACE}" -l "app=${DEPLOYMENT_NAME}" \
    --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l | tr -d ' ')

echo ""
echo "Summary:"
echo "  Running: ${RUNNING_COUNT}/${REPLICAS}"
echo "  Pending: ${PENDING_COUNT}/${REPLICAS}"

if [[ "${PENDING_COUNT}" -gt 0 ]]; then
    echo ""
    echo "Pending pods detected. The cluster autoscaler should:"
    echo "  1. Detect pending pods in the next CronJob run (every 2 min)"
    echo "  2. Log a scale-up event"
    echo "  3. Trigger VM provisioning via Proxmox API"
    echo ""
    echo "Monitor autoscaler:"
    echo "  kubectl get jobs -n autoscaling -w"
    echo "  kubectl logs -n autoscaling -l app.kubernetes.io/component=scale-up --tail=20"
fi

if [[ "${WATCH}" == "true" ]]; then
    echo ""
    echo "Watching pods (Ctrl+C to stop)..."
    kubectl get pods -n "${NAMESPACE}" -l "app=${DEPLOYMENT_NAME}" -w
fi

echo ""
echo "To clean up: $0 --cleanup"
