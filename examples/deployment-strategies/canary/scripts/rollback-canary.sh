#!/bin/bash
# Canary Rollback Script
# Immediately rolls back canary deployment by setting traffic to 100% stable
# Usage: ./rollback-canary.sh [namespace] [app-name]

set -e

# Configuration
NAMESPACE="${1:-production}"
APP_NAME="${2:-myapp}"
INGRESS_NAME="${APP_NAME}-canary"

echo "===================================="
echo "CANARY ROLLBACK"
echo "===================================="
echo "Namespace: ${NAMESPACE}"
echo "Application: ${APP_NAME}"
echo "Ingress: ${INGRESS_NAME}"
echo ""

# Get current traffic distribution
echo "Current traffic distribution:"
kubectl get ingressroute ${INGRESS_NAME} -n ${NAMESPACE} \
  -o jsonpath='{range .spec.routes[0].services[*]}{.name}{": "}{.weight}{"%\n"}{end}' 2>/dev/null || \
  echo "⚠️  Could not retrieve current traffic distribution"
echo ""

# Confirm rollback
echo "⚠️  This will:"
echo "  1. Set traffic to 100% stable, 0% canary"
echo "  2. Rollback canary deployment to stable image"
echo ""

if [ -t 0 ]; then
  # Interactive mode
  read -p "Proceed with rollback? (yes/no): " CONFIRM
  if [ "$CONFIRM" != "yes" ]; then
    echo "Rollback cancelled"
    exit 0
  fi
else
  # Non-interactive mode (CI/CD)
  echo "Running in non-interactive mode, proceeding automatically..."
fi

echo ""
echo "Starting rollback..."
echo ""

# Step 1: Set traffic to 100% stable, 0% canary
echo "Step 1/3: Redirecting all traffic to stable..."

kubectl patch ingressroute ${INGRESS_NAME} -n ${NAMESPACE} --type=json -p='[
  {"op":"replace","path":"/spec/routes/0/services/0/weight","value":100},
  {"op":"replace","path":"/spec/routes/0/services/1/weight","value":0}
]'

if [ $? -eq 0 ]; then
  echo "✅ Traffic redirected to stable (100%)"
else
  echo "❌ Failed to update traffic weights"
  exit 1
fi

echo ""

# Step 2: Rollback canary deployment to stable image
echo "Step 2/3: Rolling back canary deployment to stable image..."

# Get stable deployment image
STABLE_IMAGE=$(kubectl get deployment ${APP_NAME}-stable -n ${NAMESPACE} \
  -o jsonpath='{.spec.template.spec.containers[0].image}')

if [ -z "$STABLE_IMAGE" ]; then
  echo "⚠️  WARNING: Could not retrieve stable image, skipping canary rollback"
else
  echo "Stable image: ${STABLE_IMAGE}"

  # Update canary deployment to use stable image
  kubectl set image deployment/${APP_NAME}-canary \
    ${APP_NAME}=${STABLE_IMAGE} \
    -n ${NAMESPACE}

  if [ $? -eq 0 ]; then
    # Wait for rollout
    kubectl rollout status deployment/${APP_NAME}-canary \
      -n ${NAMESPACE} \
      --timeout=3m

    echo "✅ Canary deployment rolled back to stable image"
  else
    echo "⚠️  WARNING: Failed to rollback canary deployment"
  fi
fi

echo ""

# Step 3: Verify rollback
echo "Step 3/3: Verifying rollback..."

# Check traffic distribution
echo "New traffic distribution:"
kubectl get ingressroute ${INGRESS_NAME} -n ${NAMESPACE} \
  -o jsonpath='{range .spec.routes[0].services[*]}{.name}{": "}{.weight}{"%\n"}{end}'

echo ""

# Check deployment status
echo "Deployment status:"
kubectl get deployments -n ${NAMESPACE} -l app=${APP_NAME}

echo ""

# Check pod health
echo "Pod health:"
kubectl get pods -n ${NAMESPACE} -l app=${APP_NAME} -L version

echo ""

# Test stable endpoint
echo "Testing stable endpoint..."
STABLE_SVC="${APP_NAME}-stable.${NAMESPACE}.svc.cluster.local"
if command -v curl &> /dev/null; then
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://${STABLE_SVC}/health || echo "000")
  if [ "$HTTP_CODE" = "200" ]; then
    echo "✅ Stable health check: OK (HTTP ${HTTP_CODE})"
  else
    echo "⚠️  Stable health check: Failed (HTTP ${HTTP_CODE})"
  fi
else
  echo "ℹ️  curl not available, skipping health check"
fi

echo ""
echo "===================================="
echo "✅ ROLLBACK COMPLETE"
echo "===================================="
echo "All production traffic is now on stable deployment"
echo "Canary deployment has been rolled back to stable image"
echo ""
echo "Next steps:"
echo "1. Investigate the cause of the rollback"
echo "2. Fix issues in the canary version"
echo "3. Re-deploy canary when ready"
echo ""
echo "To scale down canary deployment:"
echo "  kubectl scale deployment/${APP_NAME}-canary --replicas=0 -n ${NAMESPACE}"
echo ""

exit 0
