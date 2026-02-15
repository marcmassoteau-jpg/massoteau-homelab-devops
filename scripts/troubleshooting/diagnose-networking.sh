#!/usr/bin/env bash
# =============================================================================
# Network Diagnostic Script
# =============================================================================
# Diagnoses common Kubernetes networking issues including CNI status,
# DNS resolution, pod-to-pod connectivity, services, and ingress.
#
# Usage:
#   ./diagnose-networking.sh
#   ./diagnose-networking.sh -h
#
# Requirements:
#   - kubectl configured with cluster access
#   - Calico CNI (checks calico-specific pods)
#   - Traefik ingress controller
# =============================================================================

set -euo pipefail

#===== Colors =====
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

#===== Counters =====
PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0

#===== Temp Resources Tracking =====
CLEANUP_RESOURCES=()

#===== Functions =====
pass() {
    echo -e "  ${GREEN}[PASS]${NC} $1"
    ((PASS_COUNT++)) || true
}

fail() {
    echo -e "  ${RED}[FAIL]${NC} $1"
    ((FAIL_COUNT++)) || true
}

warn() {
    echo -e "  ${YELLOW}[WARN]${NC} $1"
    ((WARN_COUNT++)) || true
}

info() {
    echo -e "  ${CYAN}[INFO]${NC} $1"
}

section() {
    echo ""
    echo "============================================"
    echo "  $1"
    echo "============================================"
}

cleanup() {
    if [[ ${#CLEANUP_RESOURCES[@]} -gt 0 ]]; then
        echo ""
        info "Cleaning up temporary resources..."
        for resource in "${CLEANUP_RESOURCES[@]}"; do
            kubectl delete "$resource" --ignore-not-found=true &>/dev/null || true
        done
        info "Cleanup complete"
    fi
}

trap cleanup EXIT

show_help() {
    echo "Usage: $(basename "$0") [-h]"
    echo ""
    echo "Diagnoses common Kubernetes networking issues."
    echo ""
    echo "Options:"
    echo "  -h    Show this help message"
    echo ""
    echo "Checks performed:"
    echo "  - CNI plugin status (Calico pods)"
    echo "  - CoreDNS resolution (internal and external)"
    echo "  - Pod-to-pod connectivity"
    echo "  - Service endpoints"
    echo "  - Network policies"
    echo "  - Ingress controller (Traefik)"
    exit 0
}

#===== Parse Arguments =====
while getopts "h" opt; do
    case ${opt} in
        h) show_help ;;
        *) show_help ;;
    esac
done

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
echo "  Network Diagnostics"
echo "  $(date)"
echo "============================================"

#===== 1. CNI Plugin Status =====
section "CNI Plugin Status (Calico)"

# Check calico-node pods
CALICO_PODS=$(kubectl get pods -n kube-system -l k8s-app=calico-node --no-headers 2>/dev/null || true)
if [[ -n "$CALICO_PODS" ]]; then
    CALICO_RUNNING=$(echo "$CALICO_PODS" | grep -c "Running" || true)
    CALICO_TOTAL=$(echo "$CALICO_PODS" | wc -l | tr -d ' ')
    if [[ "$CALICO_RUNNING" -eq "$CALICO_TOTAL" ]]; then
        pass "Calico node pods: $CALICO_RUNNING/$CALICO_TOTAL running"
    else
        fail "Calico node pods: $CALICO_RUNNING/$CALICO_TOTAL running"
        echo "$CALICO_PODS" | grep -v "Running" | while IFS= read -r line; do
            echo -e "    ${RED}$line${NC}"
        done
    fi
else
    warn "Calico node pods not found (may use different CNI)"
fi

# Check calico-kube-controllers
CALICO_CTRL=$(kubectl get pods -n kube-system -l k8s-app=calico-kube-controllers --no-headers 2>/dev/null || true)
if [[ -n "$CALICO_CTRL" ]]; then
    if echo "$CALICO_CTRL" | grep -q "Running"; then
        pass "Calico kube-controllers is running"
    else
        fail "Calico kube-controllers is not running"
    fi
fi

# Check IP pools
if kubectl get ippools.crd.projectcalico.org &>/dev/null 2>&1; then
    info "Calico IP pools:"
    kubectl get ippools.crd.projectcalico.org -o wide 2>/dev/null | sed 's/^/    /'
fi

#===== 2. CoreDNS Resolution =====
section "DNS Resolution"

# Check CoreDNS pods
COREDNS_RUNNING=$(kubectl get pods -n kube-system -l k8s-app=kube-dns --no-headers 2>/dev/null | grep -c "Running" || true)
if [[ "$COREDNS_RUNNING" -gt 0 ]]; then
    pass "CoreDNS pods running: $COREDNS_RUNNING"
else
    fail "No CoreDNS pods running"
fi

# Test internal DNS resolution
DNS_TEST_POD="dns-test-$(date +%s)"
info "Creating temporary pod for DNS testing..."

kubectl run "$DNS_TEST_POD" --image=busybox:1.36 --restart=Never \
    --command -- sleep 30 &>/dev/null 2>&1 || true
CLEANUP_RESOURCES+=("pod/$DNS_TEST_POD")

# Wait for pod to be ready
for i in $(seq 1 15); do
    POD_STATUS=$(kubectl get pod "$DNS_TEST_POD" -o jsonpath='{.status.phase}' 2>/dev/null || echo "Pending")
    if [[ "$POD_STATUS" == "Running" ]]; then
        break
    fi
    sleep 2
done

if [[ "$POD_STATUS" == "Running" ]]; then
    # Test kubernetes.default.svc resolution
    if kubectl exec "$DNS_TEST_POD" -- nslookup kubernetes.default.svc.cluster.local &>/dev/null 2>&1; then
        pass "Internal DNS: kubernetes.default.svc.cluster.local resolves"
    else
        fail "Internal DNS: kubernetes.default.svc.cluster.local does not resolve"
    fi

    # Test kube-dns service resolution
    if kubectl exec "$DNS_TEST_POD" -- nslookup kube-dns.kube-system.svc.cluster.local &>/dev/null 2>&1; then
        pass "Internal DNS: kube-dns.kube-system.svc.cluster.local resolves"
    else
        fail "Internal DNS: kube-dns.kube-system.svc.cluster.local does not resolve"
    fi

    # Test external DNS resolution
    if kubectl exec "$DNS_TEST_POD" -- nslookup google.com &>/dev/null 2>&1; then
        pass "External DNS: google.com resolves"
    else
        fail "External DNS: google.com does not resolve"
    fi
else
    warn "DNS test pod did not start (status: $POD_STATUS) - skipping DNS tests"
fi

#===== 3. Pod-to-Pod Connectivity =====
section "Pod-to-Pod Connectivity"

# Get two nodes for cross-node test
NODE_COUNT=$(kubectl get nodes --no-headers 2>/dev/null | wc -l | tr -d ' ')

if [[ "$NODE_COUNT" -ge 2 ]]; then
    NODES=($(kubectl get nodes -o jsonpath='{.items[*].metadata.name}'))
    NODE1="${NODES[0]}"
    NODE2="${NODES[1]}"

    POD_A="nettest-a-$(date +%s)"
    POD_B="nettest-b-$(date +%s)"

    info "Testing cross-node connectivity ($NODE1 -> $NODE2)..."

    kubectl run "$POD_A" --image=busybox:1.36 --restart=Never \
        --overrides="{\"spec\":{\"nodeName\":\"$NODE1\"}}" \
        --command -- sleep 30 &>/dev/null 2>&1 || true
    CLEANUP_RESOURCES+=("pod/$POD_A")

    kubectl run "$POD_B" --image=busybox:1.36 --restart=Never \
        --overrides="{\"spec\":{\"nodeName\":\"$NODE2\"}}" \
        --command -- sleep 30 &>/dev/null 2>&1 || true
    CLEANUP_RESOURCES+=("pod/$POD_B")

    # Wait for pods
    for i in $(seq 1 15); do
        STATUS_A=$(kubectl get pod "$POD_A" -o jsonpath='{.status.phase}' 2>/dev/null || echo "Pending")
        STATUS_B=$(kubectl get pod "$POD_B" -o jsonpath='{.status.phase}' 2>/dev/null || echo "Pending")
        if [[ "$STATUS_A" == "Running" ]] && [[ "$STATUS_B" == "Running" ]]; then
            break
        fi
        sleep 2
    done

    if [[ "$STATUS_A" == "Running" ]] && [[ "$STATUS_B" == "Running" ]]; then
        POD_B_IP=$(kubectl get pod "$POD_B" -o jsonpath='{.status.podIP}' 2>/dev/null)
        if [[ -n "$POD_B_IP" ]]; then
            if kubectl exec "$POD_A" -- ping -c 2 -W 3 "$POD_B_IP" &>/dev/null 2>&1; then
                pass "Cross-node pod connectivity: $NODE1 -> $NODE2 ($POD_B_IP)"
            else
                fail "Cross-node pod connectivity failed: $NODE1 -> $NODE2 ($POD_B_IP)"
            fi
        else
            warn "Could not get IP for test pod B"
        fi
    else
        warn "Connectivity test pods did not start - skipping test"
    fi
else
    info "Single-node cluster detected - skipping cross-node test"
fi

#===== 4. Service Endpoints =====
section "Service Endpoints"

# Check for services without endpoints
SVCS_NO_ENDPOINTS=0
while IFS= read -r svc_line; do
    NS=$(echo "$svc_line" | awk '{print $1}')
    SVC=$(echo "$svc_line" | awk '{print $2}')
    SVC_TYPE=$(echo "$svc_line" | awk '{print $3}')

    # Skip headless and ExternalName services
    if [[ "$SVC_TYPE" == "ExternalName" ]]; then
        continue
    fi

    ENDPOINTS=$(kubectl get endpoints "$SVC" -n "$NS" -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null || true)
    if [[ -z "$ENDPOINTS" ]]; then
        warn "Service $NS/$SVC ($SVC_TYPE) has no endpoints"
        ((SVCS_NO_ENDPOINTS++)) || true
    fi
done < <(kubectl get svc -A --no-headers 2>/dev/null | grep -v "kubernetes")

if [[ "$SVCS_NO_ENDPOINTS" -eq 0 ]]; then
    pass "All services have active endpoints"
else
    warn "$SVCS_NO_ENDPOINTS service(s) without endpoints"
fi

#===== 5. Network Policies =====
section "Network Policies"

NETPOL_COUNT=$(kubectl get networkpolicies -A --no-headers 2>/dev/null | wc -l | tr -d ' ')
if [[ "$NETPOL_COUNT" -gt 0 ]]; then
    info "Network policies found: $NETPOL_COUNT"
    kubectl get networkpolicies -A 2>/dev/null | sed 's/^/    /'
else
    info "No network policies configured"
fi

#===== 6. Ingress Controller =====
section "Ingress Controller (Traefik)"

TRAEFIK_PODS=$(kubectl get pods -A -l app.kubernetes.io/name=traefik --no-headers 2>/dev/null || true)
if [[ -n "$TRAEFIK_PODS" ]]; then
    TRAEFIK_RUNNING=$(echo "$TRAEFIK_PODS" | grep -c "Running" || true)
    TRAEFIK_TOTAL=$(echo "$TRAEFIK_PODS" | wc -l | tr -d ' ')
    if [[ "$TRAEFIK_RUNNING" -eq "$TRAEFIK_TOTAL" ]]; then
        pass "Traefik pods: $TRAEFIK_RUNNING/$TRAEFIK_TOTAL running"
    else
        fail "Traefik pods: $TRAEFIK_RUNNING/$TRAEFIK_TOTAL running"
    fi
else
    # Try alternative label
    TRAEFIK_PODS=$(kubectl get pods -A -l app=traefik --no-headers 2>/dev/null || true)
    if [[ -n "$TRAEFIK_PODS" ]]; then
        pass "Traefik found with app=traefik label"
    else
        warn "Traefik ingress controller pods not found"
    fi
fi

# List ingress resources
INGRESS_COUNT=$(kubectl get ingress -A --no-headers 2>/dev/null | wc -l | tr -d ' ')
if [[ "$INGRESS_COUNT" -gt 0 ]]; then
    info "Ingress resources: $INGRESS_COUNT"
    kubectl get ingress -A 2>/dev/null | sed 's/^/    /'
else
    info "No ingress resources configured"
fi

#===== Summary =====
section "Network Diagnostics Summary"

echo ""
echo -e "  ${GREEN}Passed:  $PASS_COUNT${NC}"
echo -e "  ${YELLOW}Warnings: $WARN_COUNT${NC}"
echo -e "  ${RED}Failed:  $FAIL_COUNT${NC}"
echo ""

if [[ "$FAIL_COUNT" -gt 0 ]]; then
    echo -e "  ${RED}Overall: NETWORK ISSUES DETECTED${NC}"
    echo "  Review the failures above and check docs/troubleshooting/networking-issues.md"
    exit 1
elif [[ "$WARN_COUNT" -gt 0 ]]; then
    echo -e "  ${YELLOW}Overall: MOSTLY HEALTHY (with warnings)${NC}"
    exit 0
else
    echo -e "  ${GREEN}Overall: NETWORK HEALTHY${NC}"
    exit 0
fi
