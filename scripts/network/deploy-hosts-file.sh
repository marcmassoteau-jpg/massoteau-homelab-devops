#!/bin/bash
# deploy-hosts-file.sh
# Deploy /etc/hosts configuration to all cluster nodes
# Run this from your workstation (with SSH access to all nodes)
# Based on Article 3: Network Planning

set -e

NODES="240 241 242 243 244"

echo "====================================="
echo "Deploying /etc/hosts to All Nodes"
echo "====================================="
echo ""

# Create the hosts file content
HOSTS_CONTENT=$(cat <<'EOF'
127.0.0.1 localhost
127.0.1.1 HOSTNAME_PLACEHOLDER

# The following lines are desirable for IPv6 capable hosts
::1 ip6-localhost ip6-loopback
fe00::0 ip6-localnet
ff00::0 ip6-mcastprefix
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
ff02::3 ip6-allhosts

# Kubernetes Cluster Nodes
192.168.1.240 k8s-master
192.168.1.241 k8s-worker-01
192.168.1.242 k8s-worker-02
192.168.1.243 k8s-worker-03
192.168.1.244 k8s-worker-04
EOF
)

# Deploy to each node
for NODE_IP in $NODES; do
  echo "Deploying /etc/hosts to 192.168.1.$NODE_IP..."

  # Get hostname for this node
  HOSTNAME=$(ssh ubuntu@192.168.1.$NODE_IP "hostname")

  # Replace placeholder with actual hostname
  FINAL_HOSTS_CONTENT=$(echo "$HOSTS_CONTENT" | sed "s/HOSTNAME_PLACEHOLDER/$HOSTNAME/")

  # Deploy to cloud-init template (for persistence)
  ssh ubuntu@192.168.1.$NODE_IP "echo '$FINAL_HOSTS_CONTENT' | sudo tee /etc/cloud/templates/hosts.debian.tmpl > /dev/null"

  # Deploy to /etc/hosts (immediate effect)
  ssh ubuntu@192.168.1.$NODE_IP "echo '$FINAL_HOSTS_CONTENT' | sudo tee /etc/hosts > /dev/null"

  echo "✓ /etc/hosts deployed to 192.168.1.$NODE_IP ($HOSTNAME)"
  echo ""
done

echo "====================================="
echo "✓ /etc/hosts deployed to all nodes!"
echo "====================================="
echo ""
echo "Verify with:"
echo "  for IP in 240 241 242 243 244; do"
echo "    ssh ubuntu@192.168.1.\$IP 'cat /etc/hosts | grep k8s'"
echo "  done"
