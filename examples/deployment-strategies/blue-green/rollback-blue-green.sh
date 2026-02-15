#!/bin/bash
# Blue-Green Deployment Rollback Script
# Quickly switch traffic back to the previous environment
# Usage: ./rollback-blue-green.sh [namespace] [app-name]

set -e

# Configuration
NAMESPACE="${1:-production}"
APP_NAME="${2:-myapp}"

echo "===================================="
echo "BLUE-GREEN ROLLBACK"
echo "===================================="
echo "Namespace: ${NAMESPACE}"
echo "Application: ${APP_NAME}"
echo ""

# Detect current active environment
echo "Detecting current active environment..."
CURRENT=$(kubectl get pods -n ${NAMESPACE} \
  -l app=${APP_NAME},role=active \
  -o jsonpath='{.items[0].metadata.labels.version}' 2>/dev/null || echo "")

if [ -z "$CURRENT" ]; then
  echo "❌ Error: No active environment detected"
  echo "Check that pods exist with app=${APP_NAME},role=active labels"
  exit 1
fi

# Determine target environment
if [ "$CURRENT" = "blue" ]; then
  TARGET="green"
elif [ "$CURRENT" = "green" ]; then
  TARGET="blue"
else
  echo "❌ Error: Unknown active environment: $CURRENT"
  exit 1
fi

echo "Current active: ${CURRENT}"
echo "Rollback target: ${TARGET}"
echo ""

# Confirm rollback
read -p "Are you sure you want to rollback from ${CURRENT} to ${TARGET}? (yes/no): " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
  echo "Rollback cancelled"
  exit 0
fi

echo ""
echo "Starting rollback..."

# Step 1: Ensure target environment is running
echo "Step 1/4: Checking target environment status..."
TARGET_REPLICAS=$(kubectl get deployment myapp-${TARGET} -n ${NAMESPACE} \
  -o jsonpath='{.spec.replicas}')

if [ "$TARGET_REPLICAS" -eq 0 ]; then
  echo "⚠️  Target environment is scaled to 0, scaling to 3 replicas..."
  kubectl scale deployment myapp-${TARGET} --replicas=3 -n ${NAMESPACE}
  echo "Waiting for target environment to be ready..."
  kubectl rollout status deployment/myapp-${TARGET} -n ${NAMESPACE} --timeout=3m
fi

echo "✅ Target environment ready"

# Step 2: Switch labels
echo ""
echo "Step 2/4: Switching traffic labels..."

# Set target environment to active
kubectl label pods -l app=${APP_NAME},version=${TARGET} \
  role=active \
  --overwrite \
  -n ${NAMESPACE}

# Set current environment to inactive
kubectl label pods -l app=${APP_NAME},version=${CURRENT} \
  role=inactive \
  --overwrite \
  -n ${NAMESPACE}

echo "✅ Labels updated"

# Step 3: Verify the switch
echo ""
echo "Step 3/4: Verifying rollback..."
sleep 2

NEW_ACTIVE=$(kubectl get pods -n ${NAMESPACE} \
  -l app=${APP_NAME},role=active \
  -o jsonpath='{.items[0].metadata.labels.version}' 2>/dev/null || echo "")

if [ "$NEW_ACTIVE" != "$TARGET" ]; then
  echo "❌ Error: Rollback verification failed"
  echo "Expected: ${TARGET}, Got: ${NEW_ACTIVE}"
  exit 1
fi

echo "✅ Rollback verified"

# Step 4: Display current state
echo ""
echo "Step 4/4: Current deployment state:"
echo ""
kubectl get pods -n ${NAMESPACE} -l app=${APP_NAME} -L role,version
echo ""

# Test production endpoint
echo ""
echo "Testing production endpoint..."
PROD_SERVICE="myapp-production.${NAMESPACE}.svc.cluster.local"
if command -v curl &> /dev/null; then
  RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://${PROD_SERVICE}/health || echo "000")
  if [ "$RESPONSE" = "200" ]; then
    echo "✅ Health check: OK (HTTP ${RESPONSE})"
  else
    echo "⚠️  Health check: Failed (HTTP ${RESPONSE})"
  fi
else
  echo "ℹ️  curl not available, skipping health check"
fi

echo ""
echo "===================================="
echo "✅ ROLLBACK COMPLETE"
echo "===================================="
echo "Production traffic switched from ${CURRENT} to ${TARGET}"
echo "Previous environment (${CURRENT}) is still running for quick revert if needed"
echo ""
echo "Next steps:"
echo "1. Monitor application metrics and logs"
echo "2. Run smoke tests against production"
echo "3. If issues occur, you can switch back to ${CURRENT} by running:"
echo "   kubectl label pods -l app=${APP_NAME},version=${CURRENT} role=active --overwrite -n ${NAMESPACE}"
echo "   kubectl label pods -l app=${APP_NAME},version=${TARGET} role=inactive --overwrite -n ${NAMESPACE}"
echo ""
