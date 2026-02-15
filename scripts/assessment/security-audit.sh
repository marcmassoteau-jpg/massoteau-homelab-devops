#!/usr/bin/env bash
# =============================================================================
# Security Audit Script
# =============================================================================
# Performs a comprehensive security assessment of a Kubernetes cluster:
#   - RBAC configuration (cluster roles, bindings)
#   - Pod security standards and policies
#   - Privileged containers detection
#   - Network policies per namespace
#   - Secrets mounted as environment variables
#   - Default service account usage
#   - kube-bench CIS benchmark (if available)
#
# Usage:
#   ./security-audit.sh
#   ./security-audit.sh --help
# =============================================================================

set -uo pipefail

#===== Color Configuration =====
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

#===== Counters =====
TOTAL_CHECKS=0
PASSED_CHECKS=0
WARNED_CHECKS=0
FAILED_CHECKS=0

#===== Helper Functions =====
usage() {
    echo "Usage: $0 [--help]"
    echo ""
    echo "Performs a comprehensive security audit of the Kubernetes cluster."
    echo "Requires kubectl access to the cluster."
    echo ""
    echo "Options:"
    echo "  --help    Show this help message"
    exit 0
}

pass() {
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
    echo -e "  ${GREEN}[PASS]${NC} $1"
}

warn() {
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    WARNED_CHECKS=$((WARNED_CHECKS + 1))
    echo -e "  ${YELLOW}[WARN]${NC} $1"
}

fail() {
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
    echo -e "  ${RED}[FAIL]${NC} $1"
}

info() {
    echo -e "  ${CYAN}[INFO]${NC} $1"
}

section() {
    echo ""
    echo -e "${BOLD}=== $1 ===${NC}"
    echo ""
}

#===== Parse Arguments =====
if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    usage
fi

#===== Pre-flight Check =====
if ! command -v kubectl &>/dev/null; then
    echo -e "${RED}Error: kubectl not found in PATH${NC}"
    exit 1
fi

if ! kubectl cluster-info &>/dev/null; then
    echo -e "${RED}Error: Cannot connect to Kubernetes cluster${NC}"
    exit 1
fi

#===== Banner =====
echo "============================================"
echo "  Kubernetes Security Audit"
echo "  $(date)"
echo "============================================"

#===== 1. RBAC Configuration =====
section "RBAC Configuration"

# Check for custom ClusterRoles (beyond defaults)
CUSTOM_CLUSTER_ROLES=$(kubectl get clusterroles --no-headers 2>/dev/null \
    | grep -v -E '^system:|^admin$|^edit$|^view$|^cluster-admin$' \
    | wc -l | tr -d ' ')
if [[ "$CUSTOM_CLUSTER_ROLES" -gt 0 ]]; then
    pass "Custom ClusterRoles defined: $CUSTOM_CLUSTER_ROLES"
else
    warn "No custom ClusterRoles found (using only defaults)"
fi

# Check for ClusterRoleBindings to cluster-admin
CLUSTER_ADMIN_BINDINGS=$(kubectl get clusterrolebindings -o json 2>/dev/null \
    | python3 -c "
import json, sys
data = json.load(sys.stdin)
count = 0
for item in data.get('items', []):
    ref = item.get('roleRef', {})
    if ref.get('name') == 'cluster-admin':
        subjects = item.get('subjects', [])
        for s in subjects:
            if s.get('kind') != 'ServiceAccount' or s.get('namespace') != 'kube-system':
                count += 1
print(count)
" 2>/dev/null || echo "0")
if [[ "$CLUSTER_ADMIN_BINDINGS" -eq 0 ]]; then
    pass "No non-system cluster-admin bindings found"
else
    warn "Found $CLUSTER_ADMIN_BINDINGS non-system cluster-admin bindings"
fi

# Check for RoleBindings in user namespaces
USER_NAMESPACES=$(kubectl get namespaces --no-headers 2>/dev/null \
    | grep -v -E '^kube-|^default ' | awk '{print $1}')
NS_WITH_RBAC=0
NS_WITHOUT_RBAC=0
for NS in $USER_NAMESPACES; do
    RB_COUNT=$(kubectl get rolebindings -n "$NS" --no-headers 2>/dev/null | wc -l | tr -d ' ')
    if [[ "$RB_COUNT" -gt 0 ]]; then
        NS_WITH_RBAC=$((NS_WITH_RBAC + 1))
    else
        NS_WITHOUT_RBAC=$((NS_WITHOUT_RBAC + 1))
    fi
done
if [[ "$NS_WITHOUT_RBAC" -eq 0 && "$NS_WITH_RBAC" -gt 0 ]]; then
    pass "All user namespaces have RoleBindings ($NS_WITH_RBAC namespaces)"
elif [[ "$NS_WITH_RBAC" -gt 0 ]]; then
    warn "$NS_WITHOUT_RBAC user namespaces lack RoleBindings"
else
    fail "No user namespaces have RoleBindings configured"
fi

#===== 2. Pod Security Standards =====
section "Pod Security Standards"

# Check for PodSecurityAdmission labels on namespaces
PSA_ENFORCED=0
PSA_WARNED=0
PSA_NONE=0
ALL_NAMESPACES=$(kubectl get namespaces -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)
for NS in $ALL_NAMESPACES; do
    ENFORCE_LABEL=$(kubectl get namespace "$NS" -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/enforce}' 2>/dev/null || echo "")
    if [[ -n "$ENFORCE_LABEL" ]]; then
        PSA_ENFORCED=$((PSA_ENFORCED + 1))
    else
        WARN_LABEL=$(kubectl get namespace "$NS" -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/warn}' 2>/dev/null || echo "")
        if [[ -n "$WARN_LABEL" ]]; then
            PSA_WARNED=$((PSA_WARNED + 1))
        else
            PSA_NONE=$((PSA_NONE + 1))
        fi
    fi
done
if [[ "$PSA_ENFORCED" -gt 0 ]]; then
    pass "Pod Security Standards enforced on $PSA_ENFORCED namespaces"
else
    warn "No namespaces have Pod Security Standards enforcement labels"
fi
if [[ "$PSA_NONE" -gt 0 ]]; then
    info "$PSA_NONE namespaces without any Pod Security labels"
fi

# Check for deprecated PodSecurityPolicies
PSP_COUNT=$(kubectl get podsecuritypolicies --no-headers 2>/dev/null | wc -l | tr -d ' ')
PSP_COUNT=${PSP_COUNT:-0}
if [[ "$PSP_COUNT" -eq 0 ]]; then
    pass "No deprecated PodSecurityPolicies found"
else
    warn "Found $PSP_COUNT PodSecurityPolicies (deprecated in K8s 1.25+)"
fi

#===== 3. Privileged Containers =====
section "Privileged Containers"

PRIVILEGED_PODS=$(kubectl get pods -A -o json 2>/dev/null \
    | python3 -c "
import json, sys
data = json.load(sys.stdin)
results = []
for item in data.get('items', []):
    ns = item['metadata']['namespace']
    name = item['metadata']['name']
    for c in item['spec'].get('containers', []) + item['spec'].get('initContainers', []):
        sc = c.get('securityContext', {})
        if sc.get('privileged', False):
            results.append(f'{ns}/{name} ({c[\"name\"]})')
for r in results:
    print(r)
" 2>/dev/null || echo "")

PRIV_COUNT=$(echo "$PRIVILEGED_PODS" | grep -c '.' || echo "0")
if [[ "$PRIV_COUNT" -eq 0 ]]; then
    pass "No privileged containers running"
else
    warn "Found $PRIV_COUNT privileged container(s)"
    echo "$PRIVILEGED_PODS" | while read -r line; do
        info "  Privileged: $line"
    done
fi

# Check for containers running as root
ROOT_PODS=$(kubectl get pods -A -o json 2>/dev/null \
    | python3 -c "
import json, sys
data = json.load(sys.stdin)
count = 0
for item in data.get('items', []):
    for c in item['spec'].get('containers', []):
        sc = c.get('securityContext', {})
        if sc.get('runAsUser', 1) == 0 or sc.get('runAsNonRoot') is False:
            count += 1
print(count)
" 2>/dev/null || echo "0")
if [[ "$ROOT_PODS" -eq 0 ]]; then
    pass "No containers explicitly running as root"
else
    warn "Found $ROOT_PODS container(s) configured to run as root"
fi

#===== 4. Network Policies =====
section "Network Policies"

NS_WITH_NETPOL=0
NS_WITHOUT_NETPOL=0
NETPOL_DETAILS=""
for NS in $USER_NAMESPACES; do
    NP_COUNT=$(kubectl get networkpolicies -n "$NS" --no-headers 2>/dev/null | wc -l | tr -d ' ')
    if [[ "$NP_COUNT" -gt 0 ]]; then
        NS_WITH_NETPOL=$((NS_WITH_NETPOL + 1))
    else
        NS_WITHOUT_NETPOL=$((NS_WITHOUT_NETPOL + 1))
        NETPOL_DETAILS="${NETPOL_DETAILS}  - ${NS}\n"
    fi
done

if [[ "$NS_WITHOUT_NETPOL" -eq 0 && "$NS_WITH_NETPOL" -gt 0 ]]; then
    pass "All user namespaces have NetworkPolicies ($NS_WITH_NETPOL namespaces)"
elif [[ "$NS_WITH_NETPOL" -gt 0 ]]; then
    warn "$NS_WITHOUT_NETPOL user namespace(s) lack NetworkPolicies"
    if [[ -n "$NETPOL_DETAILS" ]]; then
        echo -e "    Namespaces without NetworkPolicies:"
        echo -e "$NETPOL_DETAILS" | while read -r line; do
            [[ -n "$line" ]] && echo "    $line"
        done
    fi
else
    fail "No user namespaces have NetworkPolicies"
fi

# Check for default-deny policies
DEFAULT_DENY=$(kubectl get networkpolicies -A -o json 2>/dev/null \
    | python3 -c "
import json, sys
data = json.load(sys.stdin)
count = 0
for item in data.get('items', []):
    spec = item.get('spec', {})
    pod_selector = spec.get('podSelector', {})
    if not pod_selector.get('matchLabels') and not pod_selector.get('matchExpressions'):
        policy_types = spec.get('policyTypes', [])
        if 'Ingress' in policy_types and not spec.get('ingress'):
            count += 1
print(count)
" 2>/dev/null || echo "0")
if [[ "$DEFAULT_DENY" -gt 0 ]]; then
    pass "Default-deny NetworkPolicies found: $DEFAULT_DENY"
else
    warn "No default-deny NetworkPolicies detected"
fi

#===== 5. Secrets Management =====
section "Secrets Management"

# Check for secrets exposed as environment variables
SECRETS_AS_ENV=$(kubectl get pods -A -o json 2>/dev/null \
    | python3 -c "
import json, sys
data = json.load(sys.stdin)
count = 0
for item in data.get('items', []):
    for c in item['spec'].get('containers', []):
        for env in c.get('env', []):
            vf = env.get('valueFrom', {})
            if vf.get('secretKeyRef'):
                count += 1
        for ef in c.get('envFrom', []):
            if ef.get('secretRef'):
                count += 1
print(count)
" 2>/dev/null || echo "0")
if [[ "$SECRETS_AS_ENV" -eq 0 ]]; then
    pass "No secrets exposed as environment variables"
else
    warn "Found $SECRETS_AS_ENV secret reference(s) mounted as environment variables"
    info "Consider using volume mounts for secrets instead"
fi

# Check for secrets mounted as volumes (good practice)
SECRETS_AS_VOL=$(kubectl get pods -A -o json 2>/dev/null \
    | python3 -c "
import json, sys
data = json.load(sys.stdin)
count = 0
for item in data.get('items', []):
    for v in item['spec'].get('volumes', []):
        if v.get('secret'):
            count += 1
        if v.get('projected'):
            for src in v['projected'].get('sources', []):
                if src.get('secret'):
                    count += 1
print(count)
" 2>/dev/null || echo "0")
if [[ "$SECRETS_AS_VOL" -gt 0 ]]; then
    pass "Secrets mounted as volumes: $SECRETS_AS_VOL (good practice)"
fi

#===== 6. Default Service Account Usage =====
section "Default Service Account Usage"

DEFAULT_SA_PODS=$(kubectl get pods -A -o json 2>/dev/null \
    | python3 -c "
import json, sys
data = json.load(sys.stdin)
results = []
for item in data.get('items', []):
    ns = item['metadata']['namespace']
    name = item['metadata']['name']
    sa = item['spec'].get('serviceAccountName', 'default')
    if sa == 'default' and ns not in ('kube-system', 'kube-public', 'kube-node-lease'):
        results.append(f'{ns}/{name}')
for r in results:
    print(r)
" 2>/dev/null || echo "")

DEFAULT_SA_COUNT=$(echo "$DEFAULT_SA_PODS" | grep -c '.' || echo "0")
if [[ "$DEFAULT_SA_COUNT" -eq 0 ]]; then
    pass "No pods in user namespaces using the default service account"
else
    warn "Found $DEFAULT_SA_COUNT pod(s) using the default service account"
    echo "$DEFAULT_SA_PODS" | head -5 | while read -r line; do
        [[ -n "$line" ]] && info "  Default SA: $line"
    done
    if [[ "$DEFAULT_SA_COUNT" -gt 5 ]]; then
        info "  ... and $((DEFAULT_SA_COUNT - 5)) more"
    fi
fi

# Check if default service accounts have automountServiceAccountToken disabled
SA_AUTOMOUNT_ENABLED=0
for NS in $USER_NAMESPACES; do
    AUTOMOUNT=$(kubectl get serviceaccount default -n "$NS" \
        -o jsonpath='{.automountServiceAccountToken}' 2>/dev/null || echo "")
    if [[ "$AUTOMOUNT" != "false" ]]; then
        SA_AUTOMOUNT_ENABLED=$((SA_AUTOMOUNT_ENABLED + 1))
    fi
done
if [[ "$SA_AUTOMOUNT_ENABLED" -eq 0 ]]; then
    pass "Default service accounts have automountServiceAccountToken disabled"
else
    warn "$SA_AUTOMOUNT_ENABLED namespace(s) have default SA with automount enabled"
fi

#===== 7. kube-bench CIS Benchmark =====
section "CIS Benchmark (kube-bench)"

if command -v kube-bench &>/dev/null; then
    pass "kube-bench is available"
    info "Running kube-bench (this may take a moment)..."
    KUBE_BENCH_OUTPUT=$(kube-bench run --targets node 2>/dev/null || echo "kube-bench failed")
    BENCH_PASS=$(echo "$KUBE_BENCH_OUTPUT" | grep -c '\[PASS\]' || echo "0")
    BENCH_FAIL=$(echo "$KUBE_BENCH_OUTPUT" | grep -c '\[FAIL\]' || echo "0")
    BENCH_WARN=$(echo "$KUBE_BENCH_OUTPUT" | grep -c '\[WARN\]' || echo "0")
    info "kube-bench results: $BENCH_PASS PASS, $BENCH_FAIL FAIL, $BENCH_WARN WARN"
    if [[ "$BENCH_FAIL" -eq 0 ]]; then
        pass "kube-bench: No failures detected"
    else
        warn "kube-bench: $BENCH_FAIL failure(s) detected - review output for details"
    fi
else
    info "kube-bench is not installed - skipping CIS benchmark"
    info "Install from: https://github.com/aquasecurity/kube-bench"
fi

# Check if kube-bench can be run as a pod
KUBE_BENCH_JOB=$(kubectl get jobs -n default -l app=kube-bench --no-headers 2>/dev/null | wc -l | tr -d ' ')
if [[ "$KUBE_BENCH_JOB" -gt 0 ]]; then
    info "kube-bench job found in cluster - check results with: kubectl logs job/kube-bench"
fi

#===== Summary =====
echo ""
echo "============================================"
echo "  Security Audit Summary"
echo "============================================"
echo ""
echo -e "  ${GREEN}PASSED${NC}: $PASSED_CHECKS"
echo -e "  ${YELLOW}WARNED${NC}: $WARNED_CHECKS"
echo -e "  ${RED}FAILED${NC}: $FAILED_CHECKS"
echo -e "  ${BOLD}TOTAL${NC}:  $TOTAL_CHECKS"
echo ""

SCORE_PCT=0
if [[ "$TOTAL_CHECKS" -gt 0 ]]; then
    SCORE_PCT=$(( (PASSED_CHECKS * 100) / TOTAL_CHECKS ))
fi

if [[ "$FAILED_CHECKS" -eq 0 && "$WARNED_CHECKS" -eq 0 ]]; then
    echo -e "  ${GREEN}Score: ${SCORE_PCT}% - Excellent security posture${NC}"
elif [[ "$FAILED_CHECKS" -eq 0 ]]; then
    echo -e "  ${YELLOW}Score: ${SCORE_PCT}% - Good with recommendations${NC}"
else
    echo -e "  ${RED}Score: ${SCORE_PCT}% - Action required${NC}"
fi
echo ""
echo "============================================"
echo ""

# Exit with non-zero if any checks failed
if [[ "$FAILED_CHECKS" -gt 0 ]]; then
    exit 1
fi
