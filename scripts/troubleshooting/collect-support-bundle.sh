#!/usr/bin/env bash
# =============================================================================
# Support Bundle Collection Script
# =============================================================================
# Collects comprehensive cluster state information into a tarball for
# debugging and support purposes.
#
# Usage:
#   ./collect-support-bundle.sh [output-dir]
#   ./collect-support-bundle.sh /tmp/bundles
#   ./collect-support-bundle.sh -h
#
# Default output directory: /tmp/k8s-support-bundle
#
# Requirements:
#   - kubectl configured with cluster access
# =============================================================================

set -euo pipefail

#===== Colors =====
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

#===== Functions =====
info() {
    echo -e "  ${CYAN}[INFO]${NC} $1"
}

success() {
    echo -e "  ${GREEN}[OK]${NC} $1"
}

error() {
    echo -e "  ${RED}[ERROR]${NC} $1"
}

warning() {
    echo -e "  ${YELLOW}[WARN]${NC} $1"
}

section() {
    echo ""
    echo "============================================"
    echo "  $1"
    echo "============================================"
}

# Safely collect command output to a file
collect() {
    local description="$1"
    local output_file="$2"
    shift 2

    info "Collecting: $description"
    if "$@" > "$output_file" 2>&1; then
        success "$description -> $(basename "$output_file")"
    else
        warning "Partial or no data for: $description"
    fi
}

show_help() {
    echo "Usage: $(basename "$0") [output-dir] [-h]"
    echo ""
    echo "Collects comprehensive Kubernetes cluster state into a tarball."
    echo ""
    echo "Arguments:"
    echo "  output-dir  Directory for the support bundle (default: /tmp/k8s-support-bundle)"
    echo ""
    echo "Options:"
    echo "  -h          Show this help message"
    echo ""
    echo "Data collected:"
    echo "  - Node information and status"
    echo "  - All pod statuses across namespaces"
    echo "  - Events (cluster-wide)"
    echo "  - Pod logs (last 100 lines per container)"
    echo "  - Service and endpoint information"
    echo "  - ConfigMaps and Secrets (metadata only)"
    echo "  - Helm releases"
    echo "  - Custom Resource Definitions"
    echo "  - Storage (PV/PVC/StorageClass)"
    echo "  - Network policies and ingresses"
    exit 0
}

#===== Parse Arguments =====
if [[ "${1:-}" == "-h" ]] || [[ "${1:-}" == "--help" ]]; then
    show_help
fi

#===== Configuration =====
OUTPUT_BASE="${1:-/tmp/k8s-support-bundle}"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BUNDLE_DIR="${OUTPUT_BASE}/bundle-${TIMESTAMP}"
TARBALL="${OUTPUT_BASE}/k8s-support-bundle-${TIMESTAMP}.tar.gz"

#===== Pre-flight =====
if ! command -v kubectl &>/dev/null; then
    echo -e "${RED}ERROR: kubectl not found in PATH${NC}"
    exit 1
fi

if ! kubectl cluster-info &>/dev/null; then
    echo -e "${RED}ERROR: Cannot connect to Kubernetes cluster${NC}"
    exit 1
fi

echo "============================================"
echo "  Kubernetes Support Bundle Collection"
echo "  $(date)"
echo "============================================"
echo ""
info "Output directory: $BUNDLE_DIR"
info "This may take a few minutes..."

# Create directory structure
mkdir -p "$BUNDLE_DIR"/{cluster,nodes,namespaces,logs,storage,network,helm,crds}

#===== 1. Cluster Information =====
section "Cluster Information"

collect "Cluster info" "$BUNDLE_DIR/cluster/cluster-info.txt" \
    kubectl cluster-info

collect "Cluster version" "$BUNDLE_DIR/cluster/version.txt" \
    kubectl version

collect "API resources" "$BUNDLE_DIR/cluster/api-resources.txt" \
    kubectl api-resources

collect "Component statuses" "$BUNDLE_DIR/cluster/component-status.txt" \
    kubectl get componentstatuses

collect "Namespaces" "$BUNDLE_DIR/cluster/namespaces.txt" \
    kubectl get namespaces -o wide

#===== 2. Node Information =====
section "Node Information"

collect "Node list" "$BUNDLE_DIR/nodes/nodes-wide.txt" \
    kubectl get nodes -o wide

collect "Node details" "$BUNDLE_DIR/nodes/nodes-describe.txt" \
    kubectl describe nodes

# Per-node resource usage
if kubectl top nodes &>/dev/null 2>&1; then
    collect "Node resource usage" "$BUNDLE_DIR/nodes/nodes-top.txt" \
        kubectl top nodes
fi

#===== 3. Per-Namespace Resources =====
section "Namespace Resources"

NAMESPACES=$(kubectl get namespaces -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)

for ns in $NAMESPACES; do
    NS_DIR="$BUNDLE_DIR/namespaces/$ns"
    mkdir -p "$NS_DIR"

    info "Processing namespace: $ns"

    # All resources
    kubectl get all -n "$ns" -o wide > "$NS_DIR/all-resources.txt" 2>&1 || true

    # Pods
    kubectl get pods -n "$ns" -o wide > "$NS_DIR/pods.txt" 2>&1 || true
    kubectl describe pods -n "$ns" > "$NS_DIR/pods-describe.txt" 2>&1 || true

    # Services
    kubectl get svc -n "$ns" -o wide > "$NS_DIR/services.txt" 2>&1 || true

    # Endpoints
    kubectl get endpoints -n "$ns" > "$NS_DIR/endpoints.txt" 2>&1 || true

    # ConfigMaps (names only, no data for security)
    kubectl get configmaps -n "$ns" > "$NS_DIR/configmaps.txt" 2>&1 || true

    # Secrets (names and types only, no data)
    kubectl get secrets -n "$ns" -o custom-columns='NAME:.metadata.name,TYPE:.type,AGE:.metadata.creationTimestamp' \
        > "$NS_DIR/secrets-metadata.txt" 2>&1 || true

    # Deployments
    kubectl get deployments -n "$ns" -o wide > "$NS_DIR/deployments.txt" 2>&1 || true

    # StatefulSets
    kubectl get statefulsets -n "$ns" -o wide > "$NS_DIR/statefulsets.txt" 2>&1 || true

    # DaemonSets
    kubectl get daemonsets -n "$ns" -o wide > "$NS_DIR/daemonsets.txt" 2>&1 || true

    # Jobs
    kubectl get jobs -n "$ns" > "$NS_DIR/jobs.txt" 2>&1 || true

    # Events
    kubectl get events -n "$ns" --sort-by='.lastTimestamp' > "$NS_DIR/events.txt" 2>&1 || true

    # PVCs
    kubectl get pvc -n "$ns" -o wide > "$NS_DIR/pvcs.txt" 2>&1 || true
done

#===== 4. Pod Logs =====
section "Pod Logs (last 100 lines)"

for ns in $NAMESPACES; do
    PODS=$(kubectl get pods -n "$ns" --no-headers -o custom-columns='NAME:.metadata.name' 2>/dev/null || true)
    if [[ -z "$PODS" ]]; then
        continue
    fi

    LOG_DIR="$BUNDLE_DIR/logs/$ns"
    mkdir -p "$LOG_DIR"

    while IFS= read -r pod; do
        [[ -z "$pod" ]] && continue

        CONTAINERS=$(kubectl get pod "$pod" -n "$ns" -o jsonpath='{.spec.containers[*].name}' 2>/dev/null || true)
        for container in $CONTAINERS; do
            LOG_FILE="$LOG_DIR/${pod}_${container}.log"
            kubectl logs "$pod" -n "$ns" -c "$container" --tail=100 > "$LOG_FILE" 2>&1 || true

            # Also get previous logs if container restarted
            RESTARTS=$(kubectl get pod "$pod" -n "$ns" -o jsonpath="{.status.containerStatuses[?(@.name==\"$container\")].restartCount}" 2>/dev/null || echo "0")
            if [[ "$RESTARTS" -gt 0 ]]; then
                kubectl logs "$pod" -n "$ns" -c "$container" --previous --tail=50 \
                    > "$LOG_DIR/${pod}_${container}_previous.log" 2>&1 || true
            fi
        done
    done <<< "$PODS"
    success "Logs collected for namespace: $ns"
done

#===== 5. Storage =====
section "Storage Information"

collect "PersistentVolumes" "$BUNDLE_DIR/storage/pvs.txt" \
    kubectl get pv -o wide

collect "PV details" "$BUNDLE_DIR/storage/pvs-describe.txt" \
    kubectl describe pv

collect "Storage classes" "$BUNDLE_DIR/storage/storageclasses.txt" \
    kubectl get storageclass -o wide

collect "Storage class details" "$BUNDLE_DIR/storage/storageclasses-describe.txt" \
    kubectl describe storageclass

#===== 6. Network =====
section "Network Information"

collect "All services" "$BUNDLE_DIR/network/services-all.txt" \
    kubectl get svc -A -o wide

collect "All ingresses" "$BUNDLE_DIR/network/ingresses.txt" \
    kubectl get ingress -A -o wide

collect "Network policies" "$BUNDLE_DIR/network/networkpolicies.txt" \
    kubectl get networkpolicies -A -o wide

collect "Endpoints (all)" "$BUNDLE_DIR/network/endpoints-all.txt" \
    kubectl get endpoints -A

#===== 7. Helm Releases =====
section "Helm Releases"

if command -v helm &>/dev/null; then
    collect "Helm releases" "$BUNDLE_DIR/helm/releases.txt" \
        helm list -A

    # Get release details for each
    RELEASES=$(helm list -A --no-headers 2>/dev/null | awk '{print $1 ":" $2}' || true)
    for release_info in $RELEASES; do
        RELEASE_NAME=$(echo "$release_info" | cut -d: -f1)
        RELEASE_NS=$(echo "$release_info" | cut -d: -f2)
        helm status "$RELEASE_NAME" -n "$RELEASE_NS" > "$BUNDLE_DIR/helm/release-${RELEASE_NAME}.txt" 2>&1 || true
    done
    success "Helm release information collected"
else
    warning "helm command not found - skipping Helm data"
fi

#===== 8. Custom Resource Definitions =====
section "Custom Resource Definitions"

collect "CRDs" "$BUNDLE_DIR/crds/crds-list.txt" \
    kubectl get crds

# Collect CRD instances for key types
for crd_group in "applications.argoproj.io" "appprojects.argoproj.io"; do
    if kubectl get crd "$crd_group" &>/dev/null 2>&1; then
        CRD_SHORT=$(echo "$crd_group" | cut -d. -f1)
        kubectl get "$CRD_SHORT" -A -o wide > "$BUNDLE_DIR/crds/${CRD_SHORT}.txt" 2>&1 || true
    fi
done

#===== 9. Metadata =====
section "Bundle Metadata"

{
    echo "Support Bundle Metadata"
    echo "======================="
    echo "Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "Cluster: $(kubectl config current-context 2>/dev/null || echo 'unknown')"
    echo "Server: $(kubectl cluster-info 2>/dev/null | head -1 || echo 'unknown')"
    echo "Kubectl Version: $(kubectl version --client --short 2>/dev/null || kubectl version --client 2>/dev/null | head -1)"
    echo "Node Count: $(kubectl get nodes --no-headers 2>/dev/null | wc -l | tr -d ' ')"
    echo "Namespace Count: $(kubectl get namespaces --no-headers 2>/dev/null | wc -l | tr -d ' ')"
    echo "Total Pods: $(kubectl get pods -A --no-headers 2>/dev/null | wc -l | tr -d ' ')"
} > "$BUNDLE_DIR/metadata.txt"

success "Metadata written"

#===== Create Tarball =====
section "Packaging Bundle"

info "Creating tarball..."
tar -czf "$TARBALL" -C "$OUTPUT_BASE" "bundle-${TIMESTAMP}" 2>/dev/null

# Get tarball size
TARBALL_SIZE=$(du -h "$TARBALL" | cut -f1)

# Clean up uncompressed bundle directory
rm -rf "$BUNDLE_DIR"

echo ""
echo "============================================"
echo "  Support Bundle Complete"
echo "============================================"
echo ""
echo -e "  ${GREEN}Tarball: $TARBALL${NC}"
echo -e "  ${GREEN}Size: $TARBALL_SIZE${NC}"
echo ""
echo "  To extract:"
echo "    tar -xzf $TARBALL"
echo ""
echo "  To view contents:"
echo "    tar -tzf $TARBALL"
