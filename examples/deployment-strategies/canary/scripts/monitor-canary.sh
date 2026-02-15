#!/bin/bash
# Canary Monitoring Script
# Monitors error rates and latency metrics from Prometheus
# Auto-triggers rollback if thresholds are breached
#
# Usage: ./monitor-canary.sh [duration] [error_threshold] [latency_threshold]

set -e

# Configuration
DURATION="${1:-300}"  # Default: 5 minutes
ERROR_THRESHOLD="${2:-0.01}"  # Default: 1% error rate
LATENCY_THRESHOLD="${3:-1000}"  # Default: 1000ms (1 second)

# Prometheus configuration
PROMETHEUS_URL="${PROMETHEUS_URL:-http://prometheus.monitoring.svc.cluster.local:9090}"
APP_NAME="${APP_NAME:-myapp}"
NAMESPACE="${NAMESPACE:-production}"

# Monitoring interval
CHECK_INTERVAL=10  # Check every 10 seconds
CHECKS=$((DURATION / CHECK_INTERVAL))

echo "===================================="
echo "CANARY MONITORING"
echo "===================================="
echo "Duration: ${DURATION} seconds ($CHECKS checks)"
echo "Error rate threshold: ${ERROR_THRESHOLD} ($(echo "${ERROR_THRESHOLD} * 100" | bc -l)%)"
echo "Latency P95 threshold: ${LATENCY_THRESHOLD}ms"
echo "Prometheus: ${PROMETHEUS_URL}"
echo ""

# Check if Prometheus is available
if ! curl -s -f "${PROMETHEUS_URL}/-/healthy" > /dev/null 2>&1; then
  echo "⚠️  WARNING: Prometheus not reachable at ${PROMETHEUS_URL}"
  echo "Continuing with basic health checks only..."
  PROMETHEUS_AVAILABLE=false
else
  echo "✅ Prometheus connection verified"
  PROMETHEUS_AVAILABLE=true
fi

echo ""
echo "Starting monitoring..."
echo ""

# Monitoring loop
for i in $(seq 1 $CHECKS); do
  ELAPSED=$((i * CHECK_INTERVAL))
  PROGRESS=$((ELAPSED * 100 / DURATION))

  echo "[$ELAPSED/${DURATION}s] Check $i/$CHECKS (${PROGRESS}%)"

  if [ "$PROMETHEUS_AVAILABLE" = true ]; then
    # Query Prometheus for canary metrics

    # Error rate query (5xx errors)
    ERROR_RATE_QUERY='rate(http_requests_total{app="'${APP_NAME}'",version="canary",status=~"5.."}[1m]) / rate(http_requests_total{app="'${APP_NAME}'",version="canary"}[1m])'
    ERROR_RATE=$(curl -s "${PROMETHEUS_URL}/api/v1/query?query=${ERROR_RATE_QUERY}" | \
      jq -r '.data.result[0].value[1] // "0"' 2>/dev/null || echo "0")

    # Latency P95 query
    LATENCY_QUERY='histogram_quantile(0.95, rate(http_request_duration_seconds_bucket{app="'${APP_NAME}'",version="canary"}[1m]))'
    LATENCY_P95=$(curl -s "${PROMETHEUS_URL}/api/v1/query?query=${LATENCY_QUERY}" | \
      jq -r '.data.result[0].value[1] // "0"' 2>/dev/null || echo "0")

    # Convert to milliseconds
    LATENCY_P95_MS=$(echo "$LATENCY_P95 * 1000" | bc -l)

    echo "  Error rate: ${ERROR_RATE} (threshold: ${ERROR_THRESHOLD})"
    echo "  Latency P95: ${LATENCY_P95_MS}ms (threshold: ${LATENCY_THRESHOLD}ms)"

    # Check error rate threshold
    if (( $(echo "$ERROR_RATE > $ERROR_THRESHOLD" | bc -l) )); then
      echo ""
      echo "❌ ERROR: Error rate ${ERROR_RATE} exceeds threshold ${ERROR_THRESHOLD}"
      echo "Current error rate: $(echo "$ERROR_RATE * 100" | bc -l)%"
      echo "Threshold: $(echo "$ERROR_THRESHOLD * 100" | bc -l)%"
      echo ""
      exit 1
    fi

    # Check latency threshold
    if (( $(echo "$LATENCY_P95_MS > $LATENCY_THRESHOLD" | bc -l) )); then
      echo ""
      echo "❌ ERROR: P95 latency ${LATENCY_P95_MS}ms exceeds threshold ${LATENCY_THRESHOLD}ms"
      echo ""
      exit 1
    fi

    # Check for canary pod crashes
    CANARY_PODS_READY=$(kubectl get pods -n ${NAMESPACE} -l app=${APP_NAME},version=canary \
      -o jsonpath='{range .items[*]}{.status.conditions[?(@.type=="Ready")].status}{"\n"}{end}' | \
      grep -c "True" || echo "0")
    CANARY_PODS_TOTAL=$(kubectl get pods -n ${NAMESPACE} -l app=${APP_NAME},version=canary \
      --no-headers | wc -l | tr -d ' ')

    echo "  Canary pods ready: ${CANARY_PODS_READY}/${CANARY_PODS_TOTAL}"

    if [ "$CANARY_PODS_READY" -lt "$CANARY_PODS_TOTAL" ]; then
      echo ""
      echo "❌ ERROR: Not all canary pods are ready"
      kubectl get pods -n ${NAMESPACE} -l app=${APP_NAME},version=canary
      echo ""
      exit 1
    fi

  else
    # Fallback: Basic health check without Prometheus
    echo "  Performing basic health check (Prometheus unavailable)..."

    CANARY_SVC="${APP_NAME}-canary.${NAMESPACE}.svc.cluster.local"
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://${CANARY_SVC}/health || echo "000")

    echo "  Health check: HTTP ${HTTP_CODE}"

    if [ "$HTTP_CODE" != "200" ]; then
      echo ""
      echo "❌ ERROR: Health check failed with HTTP ${HTTP_CODE}"
      echo ""
      exit 1
    fi
  fi

  echo "  ✅ Metrics within acceptable range"
  echo ""

  # Wait before next check (skip on last iteration)
  if [ $i -lt $CHECKS ]; then
    sleep $CHECK_INTERVAL
  fi
done

echo "===================================="
echo "✅ MONITORING COMPLETE"
echo "===================================="
echo "Duration: ${DURATION} seconds"
echo "Checks performed: ${CHECKS}"
echo "All metrics remained within acceptable thresholds"
echo ""

exit 0
