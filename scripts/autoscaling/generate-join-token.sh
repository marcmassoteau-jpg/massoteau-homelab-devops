#!/bin/bash
# =============================================================================
# Generate Kubernetes Join Token
# Creates a new kubeadm join token on the master node
#
# Usage:
#   ./generate-join-token.sh
#   ./generate-join-token.sh --ttl 2h
#
# Output:
#   Prints the full kubeadm join command
# =============================================================================
set -euo pipefail

MASTER_IP="${MASTER_IP:-192.168.1.240}"
SSH_USER="${SSH_USER:-ubuntu}"
TTL="${1:-24h}"

# Handle --ttl flag
if [[ "${TTL}" == "--ttl" ]]; then
    TTL="${2:-24h}"
fi

echo "Generating kubeadm join token (TTL: ${TTL})..."
echo "Master node: ${SSH_USER}@${MASTER_IP}"
echo ""

# Generate token on the master node
JOIN_COMMAND=$(ssh -o StrictHostKeyChecking=no "${SSH_USER}@${MASTER_IP}" \
    "sudo kubeadm token create --print-join-command --ttl ${TTL}")

echo "Join command:"
echo "  ${JOIN_COMMAND}"
echo ""
echo "Token will expire in ${TTL}"
echo ""
echo "Usage with provisioner:"
echo "  TOKEN=\$(echo '${JOIN_COMMAND}' | awk '{print \$5}')"
echo "  ./proxmox-node-provisioner.sh --name k8s-autoscale-01 --ip 192.168.1.245 --join-token \${TOKEN}"
