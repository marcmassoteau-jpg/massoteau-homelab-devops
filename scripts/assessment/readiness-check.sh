#!/usr/bin/env bash
# =============================================================================
# Production Readiness Check Script
# =============================================================================
# Performs a comprehensive readiness assessment across 8 categories:
#   - Security: RBAC, network policies, pod security, secrets management
#   - Availability: Multi-node, replicas, anti-affinity
#   - Monitoring: Prometheus, Grafana, AlertManager, ServiceMonitors
#   - Backup: Velero, backup schedules, etcd backup
#   - Networking: CNI, DNS, ingress controller, load balancer
#   - Storage: Storage classes, PV provisioning, backup storage
#   - CI/CD: GitLab, Jenkins, pipelines
#   - GitOps: ArgoCD, applications synced, self-healing
#
# Usage:
#   ./readiness-check.sh
#   ./readiness-check.sh --verbose
#   ./readiness-check.sh --help
# =============================================================================

set -uo pipefail

#===== Color Configuration =====
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

#===== Configuration =====
VERBOSE=false

#===== Counters =====
TOTAL_CHECKS=0
PASSED_CHECKS=0
WARNED_CHECKS=0
FAILED_CHECKS=0

# Per-category counters
declare -A CAT_TOTAL
declare -A CAT_PASSED
declare -A CAT_WARNED
declare -A CAT_FAILED
CATEGORIES=("SECURITY" "AVAILABILITY" "MONITORING" "BACKUP" "NETWORKING" "STORAGE" "CI/CD" "GITOPS")
for cat in "${CATEGORIES[@]}"; do
    CAT_TOTAL[$cat]=0
    CAT_PASSED[$cat]=0
    CAT_WARNED[$cat]=0
    CAT_FAILED[$cat]=0
done

CURRENT_CATEGORY=""

#===== Helper Functions =====
usage() {
    echo "Usage: $0 [--verbose] [--help]"
    echo ""
    echo "Performs a comprehensive production readiness assessment."
    echo "Requires kubectl access to the cluster."
    echo ""
    echo "Options:"
    echo "  --verbose   Show detailed output for each check"
    echo "  --help      Show this help message"
    exit 0
}

set_category() {
    CURRENT_CATEGORY="$1"
}

pass() {
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
    CAT_TOTAL[$CURRENT_CATEGORY]=$(( ${CAT_TOTAL[$CURRENT_CATEGORY]} + 1 ))
    CAT_PASSED[$CURRENT_CATEGORY]=$(( ${CAT_PASSED[$CURRENT_CATEGORY]} + 1 ))
    echo -e "  ${GREEN}[PASS]${NC} $1"
}

warn() {
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    WARNED_CHECKS=$((WARNED_CHECKS + 1))
    CAT_TOTAL[$CURRENT_CATEGORY]=$(( ${CAT_TOTAL[$CURRENT_CATEGORY]} + 1 ))
    CAT_WARNED[$CURRENT_CATEGORY]=$(( ${CAT_WARNED[$CURRENT_CATEGORY]} + 1 ))
    echo -e "  ${YELLOW}[WARN]${NC} $1"
}

fail() {
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
    CAT_TOTAL[$CURRENT_CATEGORY]=$(( ${CAT_TOTAL[$CURRENT_CATEGORY]} + 1 ))
    CAT_FAILED[$CURRENT_CATEGORY]=$(( ${CAT_FAILED[$CURRENT_CATEGORY]} + 1 ))
    echo -e "  ${RED}[FAIL]${NC} $1"
}

info() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "  ${CYAN}[INFO]${NC} $1"
    fi
}

section() {
    echo ""
    echo -e "${BOLD}=== $1 ===${NC}"
    echo ""
}

# Check if a namespace has running pods matching a label
check_running() {
    local ns="$1"
    local label="$2"
    local count
    count=$(kubectl get pods -n "$ns" -l "$label" --no-headers 2>/dev/null \
        | grep -c "Running" || true)
    echo "${count:-0}"
}

# Check if a namespace exists
ns_exists() {
    kubectl get namespace "$1" &>/dev/null 2>&1
}

#===== Parse Arguments =====
while [[ $# -gt 0 ]]; do
    case "$1" in
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        --help|-h)
            usage
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
done

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
echo "  Production Readiness Assessment"
echo "  $(date)"
echo "============================================"

# =========================================================================
# SECURITY
# =========================================================================
section "1. SECURITY"
set_category "SECURITY"

# 1.1 RBAC configured
CUSTOM_ROLES=$(kubectl get clusterroles --no-headers 2>/dev/null \
    | grep -v -E '^system:|^admin$|^edit$|^view$|^cluster-admin$' \
    | wc -l | tr -d ' ')
if [[ "$CUSTOM_ROLES" -gt 0 ]]; then
    pass "RBAC: Custom ClusterRoles configured ($CUSTOM_ROLES)"
else
    warn "RBAC: No custom ClusterRoles (only defaults)"
fi

# 1.2 Network policies exist
NETPOL_COUNT=$(kubectl get networkpolicies -A --no-headers 2>/dev/null | wc -l | tr -d ' ')
if [[ "$NETPOL_COUNT" -gt 0 ]]; then
    pass "Network Policies: $NETPOL_COUNT policies configured"
else
    fail "Network Policies: None configured"
fi

# 1.3 Pod security standards
PSA_NS=$(kubectl get namespaces -o json 2>/dev/null \
    | python3 -c "
import json, sys
data = json.load(sys.stdin)
count = sum(1 for ns in data.get('items', [])
    if 'pod-security.kubernetes.io/enforce' in ns.get('metadata', {}).get('labels', {}))
print(count)
" 2>/dev/null || echo "0")
if [[ "$PSA_NS" -gt 0 ]]; then
    pass "Pod Security Standards: Enforced on $PSA_NS namespace(s)"
else
    warn "Pod Security Standards: No enforcement labels found"
fi

# 1.4 Secrets not exposed as env vars (check for volume mounts)
SECRETS_VOL=$(kubectl get pods -A -o json 2>/dev/null \
    | python3 -c "
import json, sys
data = json.load(sys.stdin)
count = sum(1 for item in data.get('items', [])
    for v in item['spec'].get('volumes', []) if v.get('secret'))
print(count)
" 2>/dev/null || echo "0")
if [[ "$SECRETS_VOL" -gt 0 ]]; then
    pass "Secrets Management: $SECRETS_VOL secrets mounted as volumes"
else
    warn "Secrets Management: No secrets mounted as volumes detected"
fi

# 1.5 Service account tokens
SA_NO_AUTOMOUNT=$(kubectl get serviceaccounts -A -o json 2>/dev/null \
    | python3 -c "
import json, sys
data = json.load(sys.stdin)
count = sum(1 for sa in data.get('items', [])
    if sa.get('automountServiceAccountToken') is False)
print(count)
" 2>/dev/null || echo "0")
if [[ "$SA_NO_AUTOMOUNT" -gt 0 ]]; then
    pass "Service Accounts: $SA_NO_AUTOMOUNT SA(s) with automount disabled"
else
    warn "Service Accounts: No SAs have automount disabled"
fi

# =========================================================================
# AVAILABILITY
# =========================================================================
section "2. AVAILABILITY"
set_category "AVAILABILITY"

# 2.1 Multi-node cluster
NODE_COUNT=$(kubectl get nodes --no-headers 2>/dev/null | wc -l | tr -d ' ')
if [[ "$NODE_COUNT" -ge 3 ]]; then
    pass "Multi-node: $NODE_COUNT nodes in cluster"
elif [[ "$NODE_COUNT" -ge 2 ]]; then
    warn "Multi-node: Only $NODE_COUNT nodes (3+ recommended)"
else
    fail "Single node cluster - no redundancy"
fi

# 2.2 All nodes ready
NOT_READY=$(kubectl get nodes --no-headers 2>/dev/null | grep -v " Ready" | wc -l | tr -d ' ')
if [[ "$NOT_READY" -eq 0 ]]; then
    pass "Node Health: All $NODE_COUNT nodes are Ready"
else
    fail "Node Health: $NOT_READY node(s) not Ready"
fi

# 2.3 Critical services have replicas >1
CRITICAL_SINGLE_REPLICA=0
for DEP in $(kubectl get deployments -A --no-headers 2>/dev/null \
    | awk '$3 ~ /^1\// {print $1"/"$2}'); do
    NS=$(echo "$DEP" | cut -d/ -f1)
    NAME=$(echo "$DEP" | cut -d/ -f2)
    # Skip system namespaces where single replica may be expected
    if [[ "$NS" != "kube-system" ]]; then
        CRITICAL_SINGLE_REPLICA=$((CRITICAL_SINGLE_REPLICA + 1))
        info "Single replica: $NS/$NAME"
    fi
done
if [[ "$CRITICAL_SINGLE_REPLICA" -eq 0 ]]; then
    pass "Replicas: All deployments have >1 replica"
elif [[ "$CRITICAL_SINGLE_REPLICA" -lt 5 ]]; then
    warn "Replicas: $CRITICAL_SINGLE_REPLICA deployment(s) with single replica"
else
    warn "Replicas: $CRITICAL_SINGLE_REPLICA deployment(s) with single replica"
fi

# 2.4 Pod disruption budgets
PDB_COUNT=$(kubectl get pdb -A --no-headers 2>/dev/null | wc -l | tr -d ' ')
if [[ "$PDB_COUNT" -gt 0 ]]; then
    pass "PodDisruptionBudgets: $PDB_COUNT configured"
else
    warn "PodDisruptionBudgets: None configured"
fi

# 2.5 Anti-affinity rules
ANTI_AFFINITY=$(kubectl get pods -A -o json 2>/dev/null \
    | python3 -c "
import json, sys
data = json.load(sys.stdin)
count = sum(1 for item in data.get('items', [])
    if item['spec'].get('affinity', {}).get('podAntiAffinity'))
print(count)
" 2>/dev/null || echo "0")
if [[ "$ANTI_AFFINITY" -gt 0 ]]; then
    pass "Anti-affinity: $ANTI_AFFINITY pod(s) with anti-affinity rules"
else
    warn "Anti-affinity: No pod anti-affinity rules found"
fi

# =========================================================================
# MONITORING
# =========================================================================
section "3. MONITORING"
set_category "MONITORING"

# 3.1 Prometheus running
PROM_NS="monitoring"
PROM_RUNNING=$(check_running "$PROM_NS" "app.kubernetes.io/name=prometheus" 2>/dev/null || echo "0")
if [[ "$PROM_RUNNING" -gt 0 ]]; then
    pass "Prometheus: Running ($PROM_RUNNING pod(s))"
else
    # Try alternative labels
    PROM_RUNNING=$(check_running "$PROM_NS" "app=prometheus" 2>/dev/null || echo "0")
    if [[ "$PROM_RUNNING" -gt 0 ]]; then
        pass "Prometheus: Running ($PROM_RUNNING pod(s))"
    else
        fail "Prometheus: Not detected in $PROM_NS namespace"
    fi
fi

# 3.2 Grafana running
GRAFANA_RUNNING=$(check_running "$PROM_NS" "app.kubernetes.io/name=grafana" 2>/dev/null || echo "0")
if [[ "$GRAFANA_RUNNING" -gt 0 ]]; then
    pass "Grafana: Running ($GRAFANA_RUNNING pod(s))"
else
    fail "Grafana: Not detected in $PROM_NS namespace"
fi

# 3.3 AlertManager running
AM_RUNNING=$(check_running "$PROM_NS" "app.kubernetes.io/name=alertmanager" 2>/dev/null || echo "0")
if [[ "$AM_RUNNING" -gt 0 ]]; then
    pass "AlertManager: Running ($AM_RUNNING pod(s))"
else
    warn "AlertManager: Not detected in $PROM_NS namespace"
fi

# 3.4 ServiceMonitors configured
SM_COUNT=$(kubectl get servicemonitors -A --no-headers 2>/dev/null | wc -l | tr -d ' ')
if [[ "$SM_COUNT" -gt 0 ]]; then
    pass "ServiceMonitors: $SM_COUNT configured"
else
    warn "ServiceMonitors: None found (CRD may not exist)"
fi

# 3.5 Metrics server available
if kubectl top nodes &>/dev/null 2>&1; then
    pass "Metrics Server: Available"
else
    warn "Metrics Server: Not available"
fi

# =========================================================================
# BACKUP
# =========================================================================
section "4. BACKUP"
set_category "BACKUP"

# 4.1 Velero running
VELERO_NS="velero"
if ns_exists "$VELERO_NS"; then
    VELERO_RUNNING=$(check_running "$VELERO_NS" "app.kubernetes.io/name=velero" 2>/dev/null || echo "0")
    if [[ "$VELERO_RUNNING" -gt 0 ]]; then
        pass "Velero: Running ($VELERO_RUNNING pod(s))"
    else
        fail "Velero: Namespace exists but no running pods"
    fi
else
    fail "Velero: Not installed"
fi

# 4.2 Backup schedules
SCHEDULE_COUNT=$(kubectl get schedules.velero.io -n "$VELERO_NS" --no-headers 2>/dev/null | wc -l | tr -d ' ')
if [[ "$SCHEDULE_COUNT" -gt 0 ]]; then
    pass "Backup Schedules: $SCHEDULE_COUNT configured"
else
    warn "Backup Schedules: None configured"
fi

# 4.3 Recent successful backup
RECENT_BACKUP=$(kubectl get backups.velero.io -n "$VELERO_NS" --no-headers 2>/dev/null \
    | grep "Completed" | wc -l | tr -d ' ')
if [[ "$RECENT_BACKUP" -gt 0 ]]; then
    pass "Recent Backups: $RECENT_BACKUP successful backup(s) found"
else
    warn "Recent Backups: No completed backups found"
fi

# 4.4 Backup storage location available
BSL_STATUS=$(kubectl get backupstoragelocation -n "$VELERO_NS" \
    -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "NotFound")
if [[ "$BSL_STATUS" == "Available" ]]; then
    pass "Backup Storage: Location is available"
else
    fail "Backup Storage: Location status is $BSL_STATUS"
fi

# 4.5 etcd backup script
if [[ -f "$(dirname "$0")/../backup/etcd-backup.sh" ]]; then
    pass "etcd Backup: Backup script exists"
else
    warn "etcd Backup: No backup script found at scripts/backup/etcd-backup.sh"
fi

# =========================================================================
# NETWORKING
# =========================================================================
section "5. NETWORKING"
set_category "NETWORKING"

# 5.1 CNI healthy
CNI_PODS=$(kubectl get pods -n kube-system --no-headers 2>/dev/null \
    | grep -E "calico|flannel|weave|cilium|canal" | grep "Running" | wc -l | tr -d ' ')
if [[ "$CNI_PODS" -gt 0 ]]; then
    pass "CNI Plugin: $CNI_PODS CNI pod(s) running"
else
    warn "CNI Plugin: Could not detect running CNI pods"
fi

# 5.2 CoreDNS running
DNS_RUNNING=$(check_running "kube-system" "k8s-app=kube-dns" 2>/dev/null || echo "0")
if [[ "$DNS_RUNNING" -gt 0 ]]; then
    pass "CoreDNS: Running ($DNS_RUNNING pod(s))"
else
    fail "CoreDNS: Not running"
fi

# 5.3 DNS resolution working
DNS_TEST=$(kubectl run dns-test --image=busybox:1.36 --rm --restart=Never \
    --command -- nslookup kubernetes.default.svc.cluster.local 2>/dev/null || echo "failed")
if echo "$DNS_TEST" | grep -q "Address" 2>/dev/null; then
    pass "DNS Resolution: kubernetes.default resolves correctly"
else
    warn "DNS Resolution: Could not verify (test pod may have failed)"
fi

# 5.4 Ingress controller running
INGRESS_PODS=$(kubectl get pods -A --no-headers 2>/dev/null \
    | grep -iE "traefik|nginx-ingress|ingress-nginx|haproxy" | grep "Running" | wc -l | tr -d ' ')
if [[ "$INGRESS_PODS" -gt 0 ]]; then
    pass "Ingress Controller: $INGRESS_PODS pod(s) running"
else
    warn "Ingress Controller: No ingress controller detected"
fi

# 5.5 Load balancer or external access
LB_SERVICES=$(kubectl get services -A --no-headers 2>/dev/null | grep "LoadBalancer" | wc -l | tr -d ' ')
NP_SERVICES=$(kubectl get services -A --no-headers 2>/dev/null | grep "NodePort" | wc -l | tr -d ' ')
if [[ "$LB_SERVICES" -gt 0 ]]; then
    pass "External Access: $LB_SERVICES LoadBalancer service(s)"
elif [[ "$NP_SERVICES" -gt 0 ]]; then
    warn "External Access: $NP_SERVICES NodePort service(s) (no LoadBalancer)"
else
    warn "External Access: No LoadBalancer or NodePort services"
fi

# =========================================================================
# STORAGE
# =========================================================================
section "6. STORAGE"
set_category "STORAGE"

# 6.1 Storage classes defined
SC_COUNT=$(kubectl get storageclasses --no-headers 2>/dev/null | wc -l | tr -d ' ')
if [[ "$SC_COUNT" -gt 0 ]]; then
    pass "Storage Classes: $SC_COUNT defined"
    info "$(kubectl get storageclasses -o custom-columns='NAME:.metadata.name,PROVISIONER:.provisioner' --no-headers 2>/dev/null)"
else
    fail "Storage Classes: None defined"
fi

# 6.2 Default storage class
DEFAULT_SC=$(kubectl get storageclasses -o json 2>/dev/null \
    | python3 -c "
import json, sys
data = json.load(sys.stdin)
for sc in data.get('items', []):
    annotations = sc.get('metadata', {}).get('annotations', {})
    if annotations.get('storageclass.kubernetes.io/is-default-class') == 'true':
        print(sc['metadata']['name'])
        break
" 2>/dev/null || echo "")
if [[ -n "$DEFAULT_SC" ]]; then
    pass "Default Storage Class: $DEFAULT_SC"
else
    warn "Default Storage Class: None set"
fi

# 6.3 Persistent volumes bound
PV_TOTAL=$(kubectl get pv --no-headers 2>/dev/null | wc -l | tr -d ' ')
PV_BOUND=$(kubectl get pv --no-headers 2>/dev/null | grep "Bound" | wc -l | tr -d ' ')
if [[ "$PV_TOTAL" -gt 0 ]]; then
    if [[ "$PV_BOUND" -eq "$PV_TOTAL" ]]; then
        pass "Persistent Volumes: All $PV_TOTAL PVs are Bound"
    else
        warn "Persistent Volumes: $PV_BOUND/$PV_TOTAL PVs are Bound"
    fi
else
    warn "Persistent Volumes: None provisioned"
fi

# 6.4 PVC without binding
PVC_PENDING=$(kubectl get pvc -A --no-headers 2>/dev/null | grep "Pending" | wc -l | tr -d ' ')
if [[ "$PVC_PENDING" -eq 0 ]]; then
    pass "PVC Status: No pending PVCs"
else
    fail "PVC Status: $PVC_PENDING PVC(s) stuck in Pending"
fi

# =========================================================================
# CI/CD
# =========================================================================
section "7. CI/CD"
set_category "CI/CD"

# 7.1 GitLab running
GITLAB_NS="gitlab"
if ns_exists "$GITLAB_NS"; then
    GITLAB_PODS=$(kubectl get pods -n "$GITLAB_NS" --no-headers 2>/dev/null \
        | grep "Running" | wc -l | tr -d ' ')
    if [[ "$GITLAB_PODS" -gt 0 ]]; then
        pass "GitLab: Running ($GITLAB_PODS pod(s) in $GITLAB_NS)"
    else
        warn "GitLab: Namespace exists but pods not all running"
    fi
else
    warn "GitLab: Not installed"
fi

# 7.2 Jenkins running
JENKINS_NS="jenkins"
if ns_exists "$JENKINS_NS"; then
    JENKINS_PODS=$(kubectl get pods -n "$JENKINS_NS" --no-headers 2>/dev/null \
        | grep "Running" | wc -l | tr -d ' ')
    if [[ "$JENKINS_PODS" -gt 0 ]]; then
        pass "Jenkins: Running ($JENKINS_PODS pod(s) in $JENKINS_NS)"
    else
        warn "Jenkins: Namespace exists but pods not all running"
    fi
else
    warn "Jenkins: Not installed"
fi

# 7.3 GitLab Runner or Jenkins agents
RUNNER_PODS=$(kubectl get pods -A --no-headers 2>/dev/null \
    | grep -iE "runner|agent" | grep "Running" | wc -l | tr -d ' ')
if [[ "$RUNNER_PODS" -gt 0 ]]; then
    pass "CI Agents: $RUNNER_PODS runner/agent pod(s) running"
else
    warn "CI Agents: No CI runner or agent pods detected"
fi

# 7.4 CI/CD pipelines configured (check for GitLab CI or Jenkinsfile)
WEBHOOK_COUNT=$(kubectl get ingresses -A -o json 2>/dev/null \
    | python3 -c "
import json, sys
data = json.load(sys.stdin)
count = sum(1 for item in data.get('items', [])
    for rule in item.get('spec', {}).get('rules', [])
    if 'gitlab' in rule.get('host', '').lower() or 'jenkins' in rule.get('host', '').lower())
print(count)
" 2>/dev/null || echo "0")
if [[ "$WEBHOOK_COUNT" -gt 0 ]]; then
    pass "CI/CD Ingress: $WEBHOOK_COUNT CI/CD ingress rule(s) configured"
else
    warn "CI/CD Ingress: No CI/CD ingress rules detected"
fi

# =========================================================================
# GITOPS
# =========================================================================
section "8. GITOPS"
set_category "GITOPS"

# 8.1 ArgoCD running
ARGOCD_NS="argocd"
if ns_exists "$ARGOCD_NS"; then
    ARGOCD_PODS=$(kubectl get pods -n "$ARGOCD_NS" --no-headers 2>/dev/null \
        | grep "Running" | wc -l | tr -d ' ')
    if [[ "$ARGOCD_PODS" -gt 0 ]]; then
        pass "ArgoCD: Running ($ARGOCD_PODS pod(s))"
    else
        fail "ArgoCD: Namespace exists but no running pods"
    fi
else
    fail "ArgoCD: Not installed"
fi

# 8.2 ArgoCD applications
APP_COUNT=$(kubectl get applications.argoproj.io -n "$ARGOCD_NS" --no-headers 2>/dev/null | wc -l | tr -d ' ')
if [[ "$APP_COUNT" -gt 0 ]]; then
    pass "ArgoCD Applications: $APP_COUNT configured"
else
    warn "ArgoCD Applications: None configured"
fi

# 8.3 Applications synced
if [[ "$APP_COUNT" -gt 0 ]]; then
    SYNCED=$(kubectl get applications.argoproj.io -n "$ARGOCD_NS" --no-headers 2>/dev/null \
        | grep "Synced" | wc -l | tr -d ' ')
    if [[ "$SYNCED" -eq "$APP_COUNT" ]]; then
        pass "ArgoCD Sync: All $APP_COUNT application(s) synced"
    else
        warn "ArgoCD Sync: $SYNCED/$APP_COUNT application(s) synced"
    fi
fi

# 8.4 Self-healing enabled
if [[ "$APP_COUNT" -gt 0 ]]; then
    SELF_HEAL=$(kubectl get applications.argoproj.io -n "$ARGOCD_NS" -o json 2>/dev/null \
        | python3 -c "
import json, sys
data = json.load(sys.stdin)
count = sum(1 for app in data.get('items', [])
    if app.get('spec', {}).get('syncPolicy', {}).get('automated', {}).get('selfHeal', False))
print(count)
" 2>/dev/null || echo "0")
    if [[ "$SELF_HEAL" -gt 0 ]]; then
        pass "Self-Healing: Enabled on $SELF_HEAL application(s)"
    else
        warn "Self-Healing: Not enabled on any applications"
    fi
fi

# 8.5 Auto-prune enabled
if [[ "$APP_COUNT" -gt 0 ]]; then
    AUTO_PRUNE=$(kubectl get applications.argoproj.io -n "$ARGOCD_NS" -o json 2>/dev/null \
        | python3 -c "
import json, sys
data = json.load(sys.stdin)
count = sum(1 for app in data.get('items', [])
    if app.get('spec', {}).get('syncPolicy', {}).get('automated', {}).get('prune', False))
print(count)
" 2>/dev/null || echo "0")
    if [[ "$AUTO_PRUNE" -gt 0 ]]; then
        pass "Auto-Prune: Enabled on $AUTO_PRUNE application(s)"
    else
        warn "Auto-Prune: Not enabled on any applications"
    fi
fi

# =========================================================================
# SUMMARY
# =========================================================================
echo ""
echo ""
echo "============================================"
echo "  Production Readiness Summary"
echo "============================================"
echo ""

# Per-category breakdown
for cat in "${CATEGORIES[@]}"; do
    TOTAL=${CAT_TOTAL[$cat]}
    P=${CAT_PASSED[$cat]}
    W=${CAT_WARNED[$cat]}
    F=${CAT_FAILED[$cat]}

    if [[ "$TOTAL" -eq 0 ]]; then
        continue
    fi

    CAT_PCT=$(( (P * 100) / TOTAL ))

    if [[ "$F" -gt 0 ]]; then
        COLOR="$RED"
    elif [[ "$W" -gt 0 ]]; then
        COLOR="$YELLOW"
    else
        COLOR="$GREEN"
    fi

    printf "  %-14s %b%3d%%%b  (%d/%d passed" "$cat" "$COLOR" "$CAT_PCT" "$NC" "$P" "$TOTAL"
    if [[ "$W" -gt 0 ]]; then
        printf ", %d warned" "$W"
    fi
    if [[ "$F" -gt 0 ]]; then
        printf ", %d failed" "$F"
    fi
    printf ")\n"
done

echo ""
echo "  -------------------------------------------"

# Overall score
if [[ "$TOTAL_CHECKS" -gt 0 ]]; then
    OVERALL_PCT=$(( (PASSED_CHECKS * 100) / TOTAL_CHECKS ))
else
    OVERALL_PCT=0
fi

if [[ "$OVERALL_PCT" -ge 90 ]]; then
    GRADE_COLOR="$GREEN"
    GRADE="EXCELLENT"
elif [[ "$OVERALL_PCT" -ge 70 ]]; then
    GRADE_COLOR="$YELLOW"
    GRADE="GOOD"
elif [[ "$OVERALL_PCT" -ge 50 ]]; then
    GRADE_COLOR="$YELLOW"
    GRADE="FAIR"
else
    GRADE_COLOR="$RED"
    GRADE="NEEDS WORK"
fi

echo ""
echo -e "  ${BOLD}Production Readiness: ${GRADE_COLOR}${OVERALL_PCT}%${NC} (${PASSED_CHECKS}/${TOTAL_CHECKS} checks passed)"
echo -e "  ${BOLD}Grade: ${GRADE_COLOR}${GRADE}${NC}"
echo ""
echo -e "  ${GREEN}PASSED${NC}: $PASSED_CHECKS  |  ${YELLOW}WARNED${NC}: $WARNED_CHECKS  |  ${RED}FAILED${NC}: $FAILED_CHECKS"
echo ""
echo "============================================"
echo ""

# Exit code based on results
if [[ "$FAILED_CHECKS" -gt 0 ]]; then
    exit 1
fi
