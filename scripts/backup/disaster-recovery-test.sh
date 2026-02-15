#!/usr/bin/env bash
# =============================================================================
# Disaster Recovery Test Script
# =============================================================================
# Tests the full backup and restore cycle using Velero:
#   1. Creates a test namespace with a sample application
#   2. Waits for pods to be ready
#   3. Creates a Velero backup of the test namespace
#   4. Deletes the test namespace
#   5. Restores from the backup
#   6. Verifies the application is running again
#   7. Cleans up test resources
#
# Usage:
#   ./disaster-recovery-test.sh
# =============================================================================

set -euo pipefail

#===== Configuration =====
TEST_NAMESPACE="dr-test"
BACKUP_NAME="dr-test-$(date +%Y%m%d-%H%M%S)"
VELERO_NAMESPACE="velero"
TIMEOUT=300  # 5 minutes
PASSED=true

echo "============================================"
echo "  Disaster Recovery Test"
echo "  $(date)"
echo "============================================"
echo ""

#===== Helper Functions =====
cleanup() {
    echo ""
    echo "Cleaning up test resources..."
    kubectl delete namespace "$TEST_NAMESPACE" --ignore-not-found=true --wait=false 2>/dev/null || true
    kubectl delete backup "$BACKUP_NAME" -n "$VELERO_NAMESPACE" --ignore-not-found=true 2>/dev/null || true
    kubectl delete restore "restore-${BACKUP_NAME}" -n "$VELERO_NAMESPACE" --ignore-not-found=true 2>/dev/null || true
    echo "  Cleanup complete"
}

fail_test() {
    echo ""
    echo "** TEST FAILED: $1"
    PASSED=false
    cleanup
    echo ""
    echo "============================================"
    echo "  RESULT: FAIL"
    echo "============================================"
    exit 1
}

#===== Pre-flight Checks =====
echo "Step 0/7: Pre-flight checks..."

# Check Velero is running
if ! kubectl get namespace "$VELERO_NAMESPACE" &>/dev/null; then
    fail_test "Velero namespace not found. Is Velero installed?"
fi

VELERO_READY=$(kubectl get pods -n "$VELERO_NAMESPACE" -l app.kubernetes.io/name=velero \
    -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "NotFound")
if [[ "$VELERO_READY" != "Running" ]]; then
    fail_test "Velero pod is not running (status: $VELERO_READY)"
fi

# Check BSL is available
BSL_PHASE=$(kubectl get backupstoragelocation -n "$VELERO_NAMESPACE" \
    -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "NotFound")
if [[ "$BSL_PHASE" != "Available" ]]; then
    fail_test "Backup storage location is not available (status: $BSL_PHASE)"
fi

echo "  Velero is running and storage is available"
echo ""

#===== Step 1: Create Test Namespace and Application =====
echo "Step 1/7: Creating test namespace and application..."

kubectl create namespace "$TEST_NAMESPACE"

kubectl apply -n "$TEST_NAMESPACE" -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: dr-test-nginx
  labels:
    app: dr-test-nginx
spec:
  replicas: 2
  selector:
    matchLabels:
      app: dr-test-nginx
  template:
    metadata:
      labels:
        app: dr-test-nginx
    spec:
      containers:
        - name: nginx
          image: nginx:1.25-alpine
          ports:
            - containerPort: 80
          resources:
            requests:
              cpu: 10m
              memory: 16Mi
            limits:
              cpu: 50m
              memory: 64Mi
---
apiVersion: v1
kind: Service
metadata:
  name: dr-test-nginx
spec:
  selector:
    app: dr-test-nginx
  ports:
    - port: 80
      targetPort: 80
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: dr-test-config
data:
  test-key: "disaster-recovery-test-value"
  timestamp: "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
EOF

echo "  Test namespace and resources created"
echo ""

#===== Step 2: Wait for Pods to be Ready =====
echo "Step 2/7: Waiting for pods to be ready..."

WAITED=0
while [[ $WAITED -lt $TIMEOUT ]]; do
    READY_PODS=$(kubectl get pods -n "$TEST_NAMESPACE" -l app=dr-test-nginx \
        -o jsonpath='{.items[*].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "")

    if [[ "$READY_PODS" == "True True" ]]; then
        echo "  All pods are ready"
        break
    fi

    echo "  Waiting for pods... ($WAITED/${TIMEOUT}s)"
    sleep 5
    WAITED=$((WAITED + 5))
done

if [[ $WAITED -ge $TIMEOUT ]]; then
    fail_test "Pods did not become ready within ${TIMEOUT}s"
fi
echo ""

#===== Step 3: Create Velero Backup =====
echo "Step 3/7: Creating Velero backup..."

kubectl apply -f - <<EOF
apiVersion: velero.io/v1
kind: Backup
metadata:
  name: ${BACKUP_NAME}
  namespace: ${VELERO_NAMESPACE}
spec:
  includedNamespaces:
    - ${TEST_NAMESPACE}
  ttl: 1h0m0s
  defaultVolumesToFsBackup: false
EOF

echo "  Backup '$BACKUP_NAME' created"

# Wait for backup to complete
WAITED=0
while [[ $WAITED -lt $TIMEOUT ]]; do
    BACKUP_PHASE=$(kubectl get backup "$BACKUP_NAME" -n "$VELERO_NAMESPACE" \
        -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown")

    if [[ "$BACKUP_PHASE" == "Completed" ]]; then
        echo "  Backup completed successfully"
        break
    elif [[ "$BACKUP_PHASE" == "Failed" || "$BACKUP_PHASE" == "PartiallyFailed" ]]; then
        fail_test "Backup failed with status: $BACKUP_PHASE"
    fi

    echo "  Backup status: $BACKUP_PHASE ($WAITED/${TIMEOUT}s)"
    sleep 5
    WAITED=$((WAITED + 5))
done

if [[ $WAITED -ge $TIMEOUT ]]; then
    fail_test "Backup did not complete within ${TIMEOUT}s"
fi
echo ""

#===== Step 4: Delete Test Namespace =====
echo "Step 4/7: Deleting test namespace..."

kubectl delete namespace "$TEST_NAMESPACE" --wait=true --timeout=60s

# Verify namespace is gone
WAITED=0
while [[ $WAITED -lt 60 ]]; do
    if ! kubectl get namespace "$TEST_NAMESPACE" &>/dev/null; then
        echo "  Namespace deleted"
        break
    fi
    sleep 2
    WAITED=$((WAITED + 2))
done

if kubectl get namespace "$TEST_NAMESPACE" &>/dev/null; then
    fail_test "Namespace was not fully deleted"
fi
echo ""

#===== Step 5: Restore from Backup =====
echo "Step 5/7: Restoring from backup..."

kubectl apply -f - <<EOF
apiVersion: velero.io/v1
kind: Restore
metadata:
  name: restore-${BACKUP_NAME}
  namespace: ${VELERO_NAMESPACE}
spec:
  backupName: ${BACKUP_NAME}
  includedNamespaces:
    - ${TEST_NAMESPACE}
  restorePVs: true
EOF

echo "  Restore 'restore-${BACKUP_NAME}' created"

# Wait for restore to complete
WAITED=0
while [[ $WAITED -lt $TIMEOUT ]]; do
    RESTORE_PHASE=$(kubectl get restore "restore-${BACKUP_NAME}" -n "$VELERO_NAMESPACE" \
        -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown")

    if [[ "$RESTORE_PHASE" == "Completed" ]]; then
        echo "  Restore completed successfully"
        break
    elif [[ "$RESTORE_PHASE" == "Failed" || "$RESTORE_PHASE" == "PartiallyFailed" ]]; then
        fail_test "Restore failed with status: $RESTORE_PHASE"
    fi

    echo "  Restore status: $RESTORE_PHASE ($WAITED/${TIMEOUT}s)"
    sleep 5
    WAITED=$((WAITED + 5))
done

if [[ $WAITED -ge $TIMEOUT ]]; then
    fail_test "Restore did not complete within ${TIMEOUT}s"
fi
echo ""

#===== Step 6: Wait for Restored Pods =====
echo "Step 6/7: Waiting for restored pods to be ready..."

# Wait for namespace to appear
WAITED=0
while [[ $WAITED -lt 30 ]]; do
    if kubectl get namespace "$TEST_NAMESPACE" &>/dev/null; then
        break
    fi
    sleep 2
    WAITED=$((WAITED + 2))
done

# Wait for pods
WAITED=0
while [[ $WAITED -lt $TIMEOUT ]]; do
    READY_PODS=$(kubectl get pods -n "$TEST_NAMESPACE" -l app=dr-test-nginx \
        -o jsonpath='{.items[*].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "")

    if [[ "$READY_PODS" == "True True" ]]; then
        echo "  All restored pods are ready"
        break
    fi

    echo "  Waiting for restored pods... ($WAITED/${TIMEOUT}s)"
    sleep 5
    WAITED=$((WAITED + 5))
done

if [[ $WAITED -ge $TIMEOUT ]]; then
    fail_test "Restored pods did not become ready within ${TIMEOUT}s"
fi
echo ""

#===== Step 7: Verify Restored Resources =====
echo "Step 7/7: Verifying restored resources..."

# Check deployment
DEPLOYMENT_EXISTS=$(kubectl get deployment dr-test-nginx -n "$TEST_NAMESPACE" -o name 2>/dev/null || echo "")
if [[ -z "$DEPLOYMENT_EXISTS" ]]; then
    fail_test "Deployment was not restored"
fi
echo "  Deployment: restored"

# Check service
SERVICE_EXISTS=$(kubectl get service dr-test-nginx -n "$TEST_NAMESPACE" -o name 2>/dev/null || echo "")
if [[ -z "$SERVICE_EXISTS" ]]; then
    fail_test "Service was not restored"
fi
echo "  Service: restored"

# Check configmap
CONFIGMAP_VALUE=$(kubectl get configmap dr-test-config -n "$TEST_NAMESPACE" \
    -o jsonpath='{.data.test-key}' 2>/dev/null || echo "")
if [[ "$CONFIGMAP_VALUE" != "disaster-recovery-test-value" ]]; then
    fail_test "ConfigMap data was not restored correctly (got: '$CONFIGMAP_VALUE')"
fi
echo "  ConfigMap: restored with correct data"

# Check pod count
POD_COUNT=$(kubectl get pods -n "$TEST_NAMESPACE" -l app=dr-test-nginx --no-headers 2>/dev/null | wc -l | tr -d ' ')
if [[ "$POD_COUNT" -ne 2 ]]; then
    fail_test "Expected 2 pods, got $POD_COUNT"
fi
echo "  Pods: $POD_COUNT/2 running"

echo ""

#===== Cleanup =====
cleanup

#===== Result =====
echo ""
if [[ "$PASSED" == "true" ]]; then
    echo "============================================"
    echo "  RESULT: PASS"
    echo "============================================"
    echo ""
    echo "  All disaster recovery tests passed!"
    echo "  Velero backup and restore is working correctly."
    echo ""
else
    echo "============================================"
    echo "  RESULT: FAIL"
    echo "============================================"
    echo ""
    echo "  Some tests failed. Review the output above."
    echo ""
    exit 1
fi
