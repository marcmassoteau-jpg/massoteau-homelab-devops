#!/bin/bash
# =============================================================================
# Blue-Green Traffic Switch Script (GitOps)
# Switches traffic between blue and green deployments via Git commits
# =============================================================================
#
# Usage:
#   ./switch-blue-green.sh [blue|green]
#
# This script updates the Kubernetes manifests in Git to switch traffic
# between blue and green deployments. ArgoCD then syncs the changes.
# =============================================================================

set -euo pipefail

# Configuration
GITOPS_DIR="${GITOPS_DIR:-$(dirname "$0")/..}"
BLUE_GREEN_DIR="${GITOPS_DIR}/base/blue-green"
TARGET="${1:-}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()  { echo -e "${BLUE}[INFO]${NC} $1"; }
log_ok()    { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Validate target
if [[ -z "$TARGET" ]]; then
    echo "Usage: $0 [blue|green]"
    echo ""
    echo "Switches production traffic to the specified deployment."
    echo "Changes are made via Git commits - ArgoCD syncs automatically."
    exit 1
fi

if [[ "$TARGET" != "blue" && "$TARGET" != "green" ]]; then
    log_error "Target must be 'blue' or 'green'"
    exit 1
fi

INACTIVE=$([[ "$TARGET" == "blue" ]] && echo "green" || echo "blue")

log_info "Switching traffic to ${TARGET} deployment"
log_info "Current active will become: ${INACTIVE}"

# Update deployment labels via sed
# Set target deployment role to 'active'
log_info "Updating ${TARGET} deployment to active..."
sed -i.bak "s/role: inactive/role: active/" "${BLUE_GREEN_DIR}/deployment-${TARGET}.yaml" 2>/dev/null || \
sed -i '' "s/role: inactive/role: active/" "${BLUE_GREEN_DIR}/deployment-${TARGET}.yaml"

# Set other deployment role to 'inactive'
log_info "Updating ${INACTIVE} deployment to inactive..."
sed -i.bak "s/role: active/role: inactive/" "${BLUE_GREEN_DIR}/deployment-${INACTIVE}.yaml" 2>/dev/null || \
sed -i '' "s/role: active/role: inactive/" "${BLUE_GREEN_DIR}/deployment-${INACTIVE}.yaml"

# Clean up backup files
rm -f "${BLUE_GREEN_DIR}/"*.bak

# Commit and push
log_info "Committing changes..."
cd "${GITOPS_DIR}"
git add base/blue-green/
git commit -m "Switch traffic to ${TARGET} deployment [skip ci]"

log_info "Pushing to remote..."
git push origin main

log_ok "Traffic switch committed to Git"
log_info "ArgoCD will sync the change automatically (within 3 minutes)"
log_info "Or force sync: argocd app sync demo-app-blue-green"

echo ""
echo "Post-switch verification:"
echo "  argocd app get demo-app-blue-green"
echo "  kubectl get pods -n demo-blue-green"
echo "  kubectl get endpoints demo-app-production -n demo-blue-green"
