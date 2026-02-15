#!/bin/bash
# =============================================================================
# Update GitOps Manifest Script
# Updates the image tag in a GitOps environment overlay
# =============================================================================
#
# Usage:
#   ./update-gitops-manifest.sh <environment> <image> <tag>
#
# Examples:
#   ./update-gitops-manifest.sh dev myregistry/app abc123
#   ./update-gitops-manifest.sh staging myregistry/app v1.0.0
#   ./update-gitops-manifest.sh prod myregistry/app v1.0.0
#
# Environment Variables:
#   GITOPS_REPO    - GitOps repository URL
#   GITOPS_BRANCH  - Target branch (default: main)
#   GITOPS_USER    - Git username for push
#   GITOPS_TOKEN   - Git token for push
# =============================================================================

set -euo pipefail

# Arguments
ENVIRONMENT="${1:-}"
IMAGE_NAME="${2:-}"
IMAGE_TAG="${3:-}"

# Configuration
GITOPS_REPO="${GITOPS_REPO:-http://gitlab.homelab.local:30080/homelab/gitops.git}"
GITOPS_BRANCH="${GITOPS_BRANCH:-main}"
GITOPS_USER="${GITOPS_USER:-root}"
GITOPS_TOKEN="${GITOPS_TOKEN:-}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()  { echo -e "${BLUE}[INFO]${NC} $1"; }
log_ok()    { echo -e "${GREEN}[OK]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Validate inputs
if [[ -z "$ENVIRONMENT" || -z "$IMAGE_NAME" || -z "$IMAGE_TAG" ]]; then
    echo "Usage: $0 <environment> <image-name> <image-tag>"
    echo ""
    echo "Arguments:"
    echo "  environment  - Target environment (dev, staging, prod)"
    echo "  image-name   - Full image name (e.g., registry.gitlab.homelab.local:30080/homelab/demo-app)"
    echo "  image-tag    - Image tag (e.g., abc123, v1.0.0)"
    echo ""
    echo "Environment Variables:"
    echo "  GITOPS_REPO    - GitOps repository URL"
    echo "  GITOPS_TOKEN   - Git token for authentication"
    exit 1
fi

if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
    log_error "Environment must be one of: dev, staging, prod"
    exit 1
fi

if [[ -z "$GITOPS_TOKEN" ]]; then
    log_error "GITOPS_TOKEN environment variable is required"
    exit 1
fi

log_info "Updating ${ENVIRONMENT} environment"
log_info "Image: ${IMAGE_NAME}:${IMAGE_TAG}"

# Check for kustomize
if ! command -v kustomize &>/dev/null; then
    log_error "kustomize is required but not installed"
    echo "Install: curl -s https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh | bash"
    exit 1
fi

# Clone GitOps repository
WORK_DIR=$(mktemp -d)
trap "rm -rf ${WORK_DIR}" EXIT

log_info "Cloning GitOps repository..."
REPO_URL="${GITOPS_REPO//http:\/\//http://${GITOPS_USER}:${GITOPS_TOKEN}@}"
git clone --depth 1 --branch "${GITOPS_BRANCH}" "${REPO_URL}" "${WORK_DIR}/gitops" 2>/dev/null

# Update image tag
cd "${WORK_DIR}/gitops/environments/${ENVIRONMENT}/demo-app"

log_info "Updating kustomization.yaml..."
kustomize edit set image "${IMAGE_NAME}:${IMAGE_TAG}"

# Verify the build works
log_info "Verifying kustomize build..."
kustomize build . > /dev/null

# Commit and push
cd "${WORK_DIR}/gitops"
git config user.email "automation@homelab.local"
git config user.name "GitOps Automation"

git add "environments/${ENVIRONMENT}/"

if git diff --cached --quiet; then
    log_info "No changes detected - image tag already set"
    exit 0
fi

COMMIT_MSG="Update ${ENVIRONMENT} image to ${IMAGE_TAG} [skip ci]"
git commit -m "${COMMIT_MSG}"

log_info "Pushing to remote..."
git push origin "${GITOPS_BRANCH}"

log_ok "GitOps manifest updated successfully!"
log_info "ArgoCD will sync the change automatically"
echo ""
echo "Verify with: argocd app get demo-app-${ENVIRONMENT}"
