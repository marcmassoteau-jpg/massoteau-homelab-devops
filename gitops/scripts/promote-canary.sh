#!/bin/bash
# =============================================================================
# Canary Promotion Script (GitOps)
# Updates canary traffic weights via Git commits
# =============================================================================
#
# Usage:
#   ./promote-canary.sh <weight>
#
# Examples:
#   ./promote-canary.sh 10    # 10% canary traffic
#   ./promote-canary.sh 25    # 25% canary traffic
#   ./promote-canary.sh 50    # 50% canary traffic
#   ./promote-canary.sh 100   # Full promotion (100% canary)
#   ./promote-canary.sh 0     # Rollback (0% canary)
#
# This script updates the IngressRoute weights in Git.
# ArgoCD then syncs the changes to the cluster.
# =============================================================================

set -euo pipefail

# Configuration
GITOPS_DIR="${GITOPS_DIR:-$(dirname "$0")/..}"
CANARY_DIR="${GITOPS_DIR}/base/canary"
INGRESS_FILE="${CANARY_DIR}/ingress-canary.yaml"
CANARY_WEIGHT="${1:-}"

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

# Validate input
if [[ -z "$CANARY_WEIGHT" ]]; then
    echo "Usage: $0 <canary-weight-percentage>"
    echo ""
    echo "Examples:"
    echo "  $0 10   - Route 10% traffic to canary"
    echo "  $0 25   - Route 25% traffic to canary"
    echo "  $0 50   - Route 50% traffic to canary"
    echo "  $0 100  - Full promotion (100% to canary)"
    echo "  $0 0    - Rollback (0% to canary)"
    exit 1
fi

if ! [[ "$CANARY_WEIGHT" =~ ^[0-9]+$ ]] || [[ "$CANARY_WEIGHT" -gt 100 ]]; then
    log_error "Weight must be a number between 0 and 100"
    exit 1
fi

STABLE_WEIGHT=$((100 - CANARY_WEIGHT))

log_info "Updating canary traffic split"
log_info "  Stable: ${STABLE_WEIGHT}%"
log_info "  Canary: ${CANARY_WEIGHT}%"

# Update the IngressRoute with new weights
cat > "${INGRESS_FILE}" << EOF
---
# Traefik IngressRoute with weighted services for canary traffic splitting
# Current split: ${STABLE_WEIGHT}% stable / ${CANARY_WEIGHT}% canary
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: demo-app-canary
  labels:
    app: demo-app
    deployment-strategy: canary
spec:
  entryPoints:
    - web
  routes:
    - match: Host(\`demo-app.homelab.local\`)
      kind: Rule
      services:
        - name: demo-app-stable
          port: 80
          weight: ${STABLE_WEIGHT}
        - name: demo-app-canary
          port: 80
          weight: ${CANARY_WEIGHT}
EOF

log_ok "IngressRoute updated: ${STABLE_WEIGHT}/${CANARY_WEIGHT}"

# Determine commit message based on weight
if [[ "$CANARY_WEIGHT" -eq 0 ]]; then
    COMMIT_MSG="Rollback canary: 100% stable traffic [skip ci]"
elif [[ "$CANARY_WEIGHT" -eq 100 ]]; then
    COMMIT_MSG="Full canary promotion: 100% canary traffic [skip ci]"
else
    COMMIT_MSG="Canary promotion: ${CANARY_WEIGHT}% canary traffic [skip ci]"
fi

# Commit and push
log_info "Committing changes..."
cd "${GITOPS_DIR}"
git add base/canary/ingress-canary.yaml
git commit -m "$COMMIT_MSG"

log_info "Pushing to remote..."
git push origin main

log_ok "Traffic weights committed to Git"
log_info "ArgoCD will sync the change automatically (within 3 minutes)"
log_info "Or force sync: argocd app sync demo-app-canary"

echo ""
echo "Post-update verification:"
echo "  argocd app get demo-app-canary"
echo "  kubectl get ingressroute demo-app-canary -n demo-canary -o yaml"
echo ""

if [[ "$CANARY_WEIGHT" -gt 0 && "$CANARY_WEIGHT" -lt 100 ]]; then
    echo "Suggested next steps:"
    echo "  1. Monitor canary metrics for 5-10 minutes"
    echo "  2. Check error rates and latency"
    if [[ "$CANARY_WEIGHT" -le 10 ]]; then
        echo "  3. If healthy, promote to 25%: $0 25"
    elif [[ "$CANARY_WEIGHT" -le 25 ]]; then
        echo "  3. If healthy, promote to 50%: $0 50"
    elif [[ "$CANARY_WEIGHT" -le 50 ]]; then
        echo "  3. If healthy, full promotion: $0 100"
    fi
    echo "  4. If issues, rollback: $0 0"
fi
