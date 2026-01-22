#!/bin/bash
# configure-firewall.sh
# Configure UFW firewall on all Kubernetes cluster nodes
# Run this from your workstation (with SSH access to all nodes)
# Based on Article 3: Network Planning

set -e

NODES="240 241 242 243 244"

echo "====================================="
echo "Configuring Firewall on All Nodes"
echo "====================================="
echo ""

for NODE_IP in $NODES; do
  echo "Configuring firewall on 192.168.1.$NODE_IP..."

  ssh ubuntu@192.168.1.$NODE_IP <<'ENDSSH'
    # Install UFW
    sudo apt install -y ufw

    # Set defaults
    sudo ufw --force reset
    sudo ufw default deny incoming
    sudo ufw default allow outgoing

    # Allow SSH
    sudo ufw allow 22/tcp

    # Allow from cluster nodes
    sudo ufw allow from 192.168.1.240
    sudo ufw allow from 192.168.1.241
    sudo ufw allow from 192.168.1.242
    sudo ufw allow from 192.168.1.243
    sudo ufw allow from 192.168.1.244

    # Enable firewall
    sudo ufw --force enable

    # Show status
    sudo ufw status
ENDSSH

  echo "✓ Firewall configured on 192.168.1.$NODE_IP"
  echo ""
done

echo "====================================="
echo "✓ All firewalls configured successfully!"
echo "====================================="
