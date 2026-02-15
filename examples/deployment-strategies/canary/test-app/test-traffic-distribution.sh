#!/bin/bash
# Simulate traffic distribution for canary testing
# Since we don't have weighted routing, we'll manually distribute requests

NAMESPACE="canary-test"
TOTAL_REQUESTS=$1
CANARY_PERCENT=$2

if [ -z "$TOTAL_REQUESTS" ] || [ -z "$CANARY_PERCENT" ]; then
    echo "Usage: $0 <total_requests> <canary_percent>"
    echo "Example: $0 100 10  # Send 100 requests, 10% to canary"
    exit 1
fi

STABLE_PERCENT=$((100 - CANARY_PERCENT))
CANARY_REQUESTS=$((TOTAL_REQUESTS * CANARY_PERCENT / 100))
STABLE_REQUESTS=$((TOTAL_REQUESTS - CANARY_REQUESTS))

echo "Traffic Distribution Test"
echo "========================="
echo "Total Requests: $TOTAL_REQUESTS"
echo "Stable: ${STABLE_PERCENT}% ($STABLE_REQUESTS requests)"
echo "Canary: ${CANARY_PERCENT}% ($CANARY_REQUESTS requests)"
echo ""

STABLE_SUCCESS=0
CANARY_SUCCESS=0
STABLE_ERRORS=0
CANARY_ERRORS=0

echo "Sending traffic to stable service..."
for i in $(seq 1 $STABLE_REQUESTS); do
    if kubectl run curl-test-s$i --image=curlimages/curl:latest --rm -i --restart=Never -n $NAMESPACE --quiet -- \
        curl -s -m 2 http://myapp-stable/ 2>/dev/null | grep -q "v1.0.0-stable"; then
        ((STABLE_SUCCESS++))
    else
        ((STABLE_ERRORS++))
    fi
    [ $((i % 10)) -eq 0 ] && echo -n "."
done
echo ""

echo "Sending traffic to canary service..."
for i in $(seq 1 $CANARY_REQUESTS); do
    if kubectl run curl-test-c$i --image=curlimages/curl:latest --rm -i --restart=Never -n $NAMESPACE --quiet -- \
        curl -s -m 2 http://myapp-canary/ 2>/dev/null | grep -q "v2.0.0-canary"; then
        ((CANARY_SUCCESS++))
    else
        ((CANARY_ERRORS++))
    fi
    [ $((i % 10)) -eq 0 ] && echo -n "."
done
echo ""
echo ""

echo "Results:"
echo "--------"
echo "Stable: $STABLE_SUCCESS successes, $STABLE_ERRORS errors"
echo "Canary: $CANARY_SUCCESS successes, $CANARY_ERRORS errors"
echo ""

ACTUAL_STABLE_PERCENT=$(echo "scale=1; $STABLE_SUCCESS * 100 / ($STABLE_SUCCESS + $CANARY_SUCCESS)" | bc)
ACTUAL_CANARY_PERCENT=$(echo "scale=1; $CANARY_SUCCESS * 100 / ($STABLE_SUCCESS + $CANARY_SUCCESS)" | bc)

echo "Actual Distribution:"
echo "Stable: ${ACTUAL_STABLE_PERCENT}%"
echo "Canary: ${ACTUAL_CANARY_PERCENT}%"
