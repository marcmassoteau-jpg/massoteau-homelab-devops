#!/bin/bash
#
# GitLab Deployment Helper Script
# Automates GitLab deployment on Kubernetes using Helm
#
# Usage:
#   ./deploy-gitlab.sh [install|upgrade|uninstall|status]
#
# Prerequisites:
#   - Kubernetes cluster running
#   - kubectl configured
#   - Helm 3 installed
#   - local-path-provisioner storage class
#   - Traefik ingress controller

set -euo pipefail

# Configuration
NAMESPACE="gitlab"
RELEASE_NAME="gitlab"
CHART_REPO="https://charts.gitlab.io/"
CHART_NAME="gitlab/gitlab"
CHART_VERSION="7.7.0"
MANIFEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VALUES_FILE="$MANIFEST_DIR/gitlab-values.yaml"
TIMEOUT="15m"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."

    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl not found. Please install kubectl."
        exit 1
    fi

    # Check Helm
    if ! command -v helm &> /dev/null; then
        log_error "Helm not found. Please install Helm 3."
        exit 1
    fi

    # Check cluster connectivity
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Cannot connect to Kubernetes cluster."
        exit 1
    fi

    # Check storage class
    if ! kubectl get storageclass local-path &> /dev/null; then
        log_warn "local-path storage class not found. GitLab requires persistent storage."
    fi

    log_info "Prerequisites check passed."
}

# Install GitLab
install_gitlab() {
    log_info "Installing GitLab..."

    # Create namespace
    log_info "Creating namespace: $NAMESPACE"
    kubectl apply -f "$MANIFEST_DIR/gitlab-namespace.yaml"

    # Add GitLab Helm repository
    log_info "Adding GitLab Helm repository..."
    helm repo add gitlab $CHART_REPO
    helm repo update

    # Install GitLab
    log_info "Deploying GitLab (this may take 10-15 minutes)..."
    helm install $RELEASE_NAME $CHART_NAME \
        --namespace $NAMESPACE \
        --version "$CHART_VERSION" \
        --values "$VALUES_FILE" \
        --timeout $TIMEOUT \
        --wait

    log_info "GitLab installed successfully!"
    show_access_info
}

# Upgrade GitLab
upgrade_gitlab() {
    log_info "Upgrading GitLab..."

    # Update Helm repository
    helm repo update

    # Upgrade GitLab
    log_info "Upgrading GitLab deployment..."
    helm upgrade $RELEASE_NAME $CHART_NAME \
        --namespace $NAMESPACE \
        --version "$CHART_VERSION" \
        --values "$VALUES_FILE" \
        --timeout $TIMEOUT \
        --wait

    log_info "GitLab upgraded successfully!"
    show_access_info
}

# Uninstall GitLab
uninstall_gitlab() {
    log_warn "This will remove GitLab but preserve PVCs (data)."
    read -p "Are you sure you want to uninstall GitLab? (yes/no): " confirm

    if [ "$confirm" != "yes" ]; then
        log_info "Uninstall cancelled."
        exit 0
    fi

    log_info "Uninstalling GitLab..."
    helm uninstall $RELEASE_NAME --namespace $NAMESPACE

    log_info "GitLab uninstalled. PVCs preserved."
    log_info "To completely remove data, run: kubectl delete pvc -n $NAMESPACE --all"
}

# Show GitLab status
show_status() {
    log_info "GitLab Status:"
    echo ""

    # Helm release status
    log_info "Helm Release:"
    helm list -n $NAMESPACE

    echo ""
    log_info "Pods:"
    kubectl get pods -n $NAMESPACE

    echo ""
    log_info "Services:"
    kubectl get svc -n $NAMESPACE

    echo ""
    log_info "PVCs:"
    kubectl get pvc -n $NAMESPACE

    echo ""
    log_info "Ingress:"
    kubectl get ingress -n $NAMESPACE
    kubectl get ingressroute -n $NAMESPACE 2>/dev/null || true

    echo ""
    show_access_info
}

# Show access information
show_access_info() {
    log_info "GitLab Access Information:"
    echo ""

    # Get initial root password
    if kubectl get secret gitlab-gitlab-initial-root-password -n $NAMESPACE &> /dev/null; then
        PASSWORD=$(kubectl get secret gitlab-gitlab-initial-root-password -n $NAMESPACE -o jsonpath="{.data.password}" | base64 --decode)

        echo "URL: http://gitlab.homelab.local:30080"
        echo "Username: root"
        echo "Password: $PASSWORD"
        echo ""
        log_warn "Save this password! It's only shown once."
        log_info "Change the root password after first login."
    else
        log_warn "Initial root password secret not found yet. Wait for GitLab to finish deploying."
    fi

    echo ""
    log_info "Container Registry: http://registry.gitlab.homelab.local:30080"
    log_info "MinIO Console: http://minio.gitlab.homelab.local:30080"
}

# Main script
main() {
    local action="${1:-}"

    case "$action" in
        install)
            check_prerequisites
            install_gitlab
            ;;
        upgrade)
            check_prerequisites
            upgrade_gitlab
            ;;
        uninstall)
            uninstall_gitlab
            ;;
        status)
            show_status
            ;;
        *)
            echo "Usage: $0 [install|upgrade|uninstall|status]"
            echo ""
            echo "Commands:"
            echo "  install    - Install GitLab for the first time"
            echo "  upgrade    - Upgrade existing GitLab installation"
            echo "  uninstall  - Remove GitLab (preserves data)"
            echo "  status     - Show GitLab deployment status"
            exit 1
            ;;
    esac
}

main "$@"
