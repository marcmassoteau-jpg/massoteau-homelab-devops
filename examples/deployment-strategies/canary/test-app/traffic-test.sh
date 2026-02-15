#!/bin/bash
# Traffic distribution test script
# Tests canary deployment traffic distribution

set -e

NAMESPACE="canary-test"
REQUESTS=${1:-100}
INTERVAL=${2:-0.1}

echo "==================================="
echo "Canary Traffic Distribution Test"
echo "==================================="
echo "Namespace: $NAMESPACE"
echo "Requests: $REQUESTS"
echo "Interval: ${INTERVAL}s"
echo ""

# Check if services exist
if ! kubectl get svc -n $NAMESPACE myapp-stable &>/dev/null; then
    echo "Error: myapp-stable service not found"
    exit 1
fi

if ! kubectl get svc -n $NAMESPACE myapp-canary &>/dev/null; then
    echo "Error: myapp-canary service not found"
    exit 1
fi

# Get service IPs
STABLE_IP=$(kubectl get svc myapp-stable -n $NAMESPACE -o jsonpath='{.spec.clusterIP}')
CANARY_IP=$(kubectl get svc myapp-canary -n $NAMESPACE -o jsonpath='{.spec.clusterIP}')

echo "Stable Service IP: $STABLE_IP"
echo "Canary Service IP: $CANARY_IP"
echo ""

# Function to send traffic with specific distribution
send_traffic() {
    local stable_weight=$1
    local canary_weight=$2
    local total_weight=$((stable_weight + canary_weight))

    local stable_count=0
    local canary_count=0
    local errors=0

    echo "Sending $REQUESTS requests with ${stable_weight}:${canary_weight} distribution..."

    for i in $(seq 1 $REQUESTS); do
        # Determine which service to hit based on weights
        local rand=$((RANDOM % total_weight))

        if [ $rand -lt $stable_weight ]; then
            # Send to stable
            if kubectl run -n $NAMESPACE curl-test-$i --image=curlimages/curl:latest --rm -i --restart=Never --quiet -- \
                curl -s -m 2 http://$STABLE_IP/ 2>/dev/null | grep -q "v1.0.0-stable"; then
                ((stable_count++))
            else
                ((errors++))
            fi
        else
            # Send to canary
            if kubectl run -n $NAMESPACE curl-test-$i --image=curlimages/curl:latest --rm -i --restart=Never --quiet -- \
                curl -s -m 2 http://$CANARY_IP/ 2>/dev/null | grep -q "v2.0.0-canary"; then
                ((canary_count++))
            else
                ((errors++))
            fi
        fi

        sleep $INTERVAL

        # Progress indicator
        if [ $((i % 10)) -eq 0 ]; then
            echo -n "."
        fi
    done

    echo ""
    echo ""
    echo "Results:"
    echo "--------"
    echo "Stable responses: $stable_count ($(echo "scale=2; $stable_count * 100 / $REQUESTS" | bc)%)"
    echo "Canary responses: $canary_count ($(echo "scale=2; $canary_count * 100 / $REQUESTS" | bc)%)"
    echo "Errors: $errors"
    echo ""
}

# Export function for use
export -f send_traffic
export NAMESPACE STABLE_IP CANARY_IP REQUESTS INTERVAL

# If weights are provided as arguments 3 and 4, send traffic with those weights
if [ $# -ge 4 ]; then
    STABLE_WEIGHT=$3
    CANARY_WEIGHT=$4
    send_traffic $STABLE_WEIGHT $CANARY_WEIGHT
else
    echo "Usage: $0 <requests> <interval> <stable_weight> <canary_weight>"
    echo "Example: $0 100 0.1 90 10  # 90% stable, 10% canary"
fi
