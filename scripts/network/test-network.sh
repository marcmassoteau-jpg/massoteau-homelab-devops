#!/bin/bash
# test-network.sh
# Comprehensive network verification for Kubernetes cluster
# Run this from one of the cluster nodes (e.g., k8s-master)
# Based on Article 3: Network Planning

echo "=== Kubernetes Cluster Network Verification ==="
echo ""

# Define nodes
NODES=(
  "240:k8s-master"
  "241:k8s-worker-01"
  "242:k8s-worker-02"
  "243:k8s-worker-03"
  "244:k8s-worker-04"
)

# Test 1: Ping all nodes
echo "Test 1: Ping connectivity"
echo "-------------------------"
for NODE in "${NODES[@]}"; do
  IP="${NODE%%:*}"
  NAME="${NODE##*:}"
  if ping -c 1 -W 2 192.168.1.$IP > /dev/null 2>&1; then
    echo "✓ 192.168.1.$IP ($NAME) is reachable"
  else
    echo "✗ 192.168.1.$IP ($NAME) is NOT reachable"
  fi
done
echo ""

# Test 2: SSH connectivity
echo "Test 2: SSH connectivity"
echo "------------------------"
for NODE in "${NODES[@]}"; do
  IP="${NODE%%:*}"
  NAME="${NODE##*:}"
  if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no ubuntu@192.168.1.$IP "echo ok" > /dev/null 2>&1; then
    echo "✓ SSH to 192.168.1.$IP ($NAME) works"
  else
    echo "✗ SSH to 192.168.1.$IP ($NAME) failed"
  fi
done
echo ""

# Test 3: Hostname resolution
echo "Test 3: Hostname resolution"
echo "---------------------------"
for NODE in "${NODES[@]}"; do
  NAME="${NODE##*:}"
  if getent hosts $NAME > /dev/null 2>&1; then
    RESOLVED_IP=$(getent hosts $NAME | awk '{print $1}')
    echo "✓ $NAME resolves to $RESOLVED_IP"
  else
    echo "✗ $NAME does not resolve"
  fi
done
echo ""

# Test 4: Internet connectivity
echo "Test 4: Internet connectivity (from each node)"
echo "-----------------------------------------------"
for NODE in "${NODES[@]}"; do
  IP="${NODE%%:*}"
  NAME="${NODE##*:}"
  if ssh -o ConnectTimeout=5 ubuntu@192.168.1.$IP "curl -s -o /dev/null -w '%{http_code}' --connect-timeout 5 https://www.google.com" | grep -q "200"; then
    echo "✓ $NAME can reach internet"
  else
    echo "✗ $NAME cannot reach internet"
  fi
done
echo ""

# Test 5: DNS resolution (from each node)
echo "Test 5: DNS resolution (from each node)"
echo "----------------------------------------"
for NODE in "${NODES[@]}"; do
  IP="${NODE%%:*}"
  NAME="${NODE##*:}"
  if ssh -o ConnectTimeout=5 ubuntu@192.168.1.$IP "nslookup kubernetes.io > /dev/null 2>&1"; then
    echo "✓ DNS works on $NAME"
  else
    echo "✗ DNS does not work on $NAME"
  fi
done
echo ""

# Test 6: Firewall status
echo "Test 6: Firewall status"
echo "-----------------------"
for NODE in "${NODES[@]}"; do
  IP="${NODE%%:*}"
  NAME="${NODE##*:}"
  STATUS=$(ssh -o ConnectTimeout=5 ubuntu@192.168.1.$IP "sudo ufw status" | grep "Status:" | awk '{print $2}')
  echo "$NAME firewall: $STATUS"
done
echo ""

# Test 7: Time synchronization
echo "Test 7: Time synchronization"
echo "----------------------------"
for NODE in "${NODES[@]}"; do
  IP="${NODE%%:*}"
  NAME="${NODE##*:}"
  TIME=$(ssh -o ConnectTimeout=5 ubuntu@192.168.1.$IP "date +%s")
  LOCAL_TIME=$(date +%s)
  DIFF=$((LOCAL_TIME - TIME))
  if [ ${DIFF#-} -lt 5 ]; then
    echo "✓ $NAME time is synchronized (diff: ${DIFF}s)"
  else
    echo "⚠ $NAME time differs by ${DIFF}s"
  fi
done
echo ""

echo "=== Network verification complete ==="
