#!/usr/bin/env bash
# =============================================================================
# Performance Baseline Script
# =============================================================================
# Captures a comprehensive performance baseline for a Kubernetes cluster:
#   - Node resource utilization (CPU, memory)
#   - Pod resource utilization across all namespaces
#   - API server response time
#   - etcd database size and performance metrics
#   - Optionally saves baseline to a JSON file for comparison
#
# Usage:
#   ./performance-baseline.sh
#   ./performance-baseline.sh --save baseline.json
#   ./performance-baseline.sh --help
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
SAVE_FILE=""
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
METRICS_AVAILABLE=true

#===== Helper Functions =====
usage() {
    echo "Usage: $0 [--save <file.json>] [--help]"
    echo ""
    echo "Captures a comprehensive performance baseline for the Kubernetes cluster."
    echo "Requires kubectl access and metrics-server running in the cluster."
    echo ""
    echo "Options:"
    echo "  --save <file>   Save baseline to a JSON file for later comparison"
    echo "  --help          Show this help message"
    exit 0
}

info() {
    echo -e "  ${CYAN}[INFO]${NC} $1"
}

ok() {
    echo -e "  ${GREEN}[OK]${NC} $1"
}

warning() {
    echo -e "  ${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "  ${RED}[ERROR]${NC} $1"
}

section() {
    echo ""
    echo -e "${BOLD}=== $1 ===${NC}"
    echo ""
}

#===== Parse Arguments =====
while [[ $# -gt 0 ]]; do
    case "$1" in
        --save)
            if [[ -z "${2:-}" ]]; then
                echo "Error: --save requires a filename argument"
                exit 1
            fi
            SAVE_FILE="$2"
            shift 2
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
    error "kubectl not found in PATH"
    exit 1
fi

if ! kubectl cluster-info &>/dev/null; then
    error "Cannot connect to Kubernetes cluster"
    exit 1
fi

# Check if metrics-server is available
if ! kubectl top nodes &>/dev/null 2>&1; then
    warning "metrics-server not available - resource utilization data will be limited"
    METRICS_AVAILABLE=false
fi

#===== Banner =====
echo "============================================"
echo "  Performance Baseline Capture"
echo "  $(date)"
echo "============================================"

#===== Initialize JSON output =====
JSON_OUTPUT='{'
JSON_OUTPUT="$JSON_OUTPUT\"timestamp\":\"$TIMESTAMP\","
JSON_OUTPUT="$JSON_OUTPUT\"cluster\":{}"

#===== 1. Node Resource Utilization =====
section "Node Resource Utilization"

if [[ "$METRICS_AVAILABLE" == "true" ]]; then
    echo "  Node metrics:"
    echo "  ---"
    kubectl top nodes 2>/dev/null | while read -r line; do
        echo "  $line"
    done
    echo ""

    # Capture node data for JSON
    NODE_JSON=$(kubectl top nodes --no-headers 2>/dev/null | awk '{
        printf "{\"name\":\"%s\",\"cpu\":\"%s\",\"cpu_pct\":\"%s\",\"memory\":\"%s\",\"memory_pct\":\"%s\"},", $1, $2, $3, $4, $5
    }' | sed 's/,$//')
    JSON_OUTPUT="$JSON_OUTPUT,\"nodes\":[$NODE_JSON]"

    # Check for high utilization
    HIGH_CPU=$(kubectl top nodes --no-headers 2>/dev/null \
        | awk '{gsub(/%/,"",$3); if ($3+0 > 80) print $1" ("$3"%)"}')
    HIGH_MEM=$(kubectl top nodes --no-headers 2>/dev/null \
        | awk '{gsub(/%/,"",$5); if ($5+0 > 80) print $1" ("$5"%)"}')

    if [[ -n "$HIGH_CPU" ]]; then
        warning "High CPU utilization detected:"
        echo "$HIGH_CPU" | while read -r line; do
            echo "    $line"
        done
    else
        ok "All nodes below 80% CPU utilization"
    fi

    if [[ -n "$HIGH_MEM" ]]; then
        warning "High memory utilization detected:"
        echo "$HIGH_MEM" | while read -r line; do
            echo "    $line"
        done
    else
        ok "All nodes below 80% memory utilization"
    fi
else
    warning "Skipping node metrics (metrics-server unavailable)"
    JSON_OUTPUT="$JSON_OUTPUT,\"nodes\":[]"
fi

# Node capacity info
echo ""
info "Node capacity:"
kubectl get nodes -o custom-columns=\
'NAME:.metadata.name,CPU:.status.capacity.cpu,MEMORY:.status.capacity.memory,PODS:.status.capacity.pods' \
    2>/dev/null | while read -r line; do
    echo "  $line"
done

#===== 2. Pod Resource Utilization =====
section "Pod Resource Utilization"

if [[ "$METRICS_AVAILABLE" == "true" ]]; then
    # Top consuming pods by CPU
    info "Top 10 pods by CPU usage:"
    kubectl top pods -A --sort-by=cpu --no-headers 2>/dev/null | head -10 | while read -r line; do
        echo "    $line"
    done
    echo ""

    # Top consuming pods by memory
    info "Top 10 pods by memory usage:"
    kubectl top pods -A --sort-by=memory --no-headers 2>/dev/null | head -10 | while read -r line; do
        echo "    $line"
    done
    echo ""

    # Pods per namespace summary
    info "Resource usage per namespace:"
    NAMESPACES=$(kubectl get namespaces -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)
    NS_JSON=""
    for NS in $NAMESPACES; do
        POD_COUNT=$(kubectl get pods -n "$NS" --no-headers 2>/dev/null | wc -l | tr -d ' ')
        if [[ "$POD_COUNT" -gt 0 ]]; then
            NS_CPU=$(kubectl top pods -n "$NS" --no-headers 2>/dev/null \
                | awk '{gsub(/m/,"",$2); sum+=$2} END {if (NR>0) printf "%dm", sum; else printf "N/A"}')
            NS_CPU=${NS_CPU:-N/A}
            NS_MEM=$(kubectl top pods -n "$NS" --no-headers 2>/dev/null \
                | awk '{gsub(/Mi/,"",$3); sum+=$3} END {if (NR>0) printf "%dMi", sum; else printf "N/A"}')
            NS_MEM=${NS_MEM:-N/A}
            echo "    $NS: $POD_COUNT pods, CPU: $NS_CPU, Memory: $NS_MEM"
            NS_JSON="$NS_JSON{\"namespace\":\"$NS\",\"pods\":$POD_COUNT,\"cpu\":\"$NS_CPU\",\"memory\":\"$NS_MEM\"},"
        fi
    done
    NS_JSON=$(echo "$NS_JSON" | sed 's/,$//')
    JSON_OUTPUT="$JSON_OUTPUT,\"namespaces\":[$NS_JSON]"
else
    warning "Skipping pod metrics (metrics-server unavailable)"
    JSON_OUTPUT="$JSON_OUTPUT,\"namespaces\":[]"
fi

#===== 3. API Server Response Time =====
section "API Server Response Time"

info "Measuring API server response time..."

# Health check endpoint
HEALTH_START=$(python3 -c "import time; print(time.time())")
HEALTH_STATUS=$(kubectl get --raw /healthz 2>/dev/null || echo "error")
HEALTH_END=$(python3 -c "import time; print(time.time())")
HEALTH_TIME=$(python3 -c "print(f'{(${HEALTH_END} - ${HEALTH_START}) * 1000:.1f}')")

if [[ "$HEALTH_STATUS" == "ok" ]]; then
    ok "/healthz responded in ${HEALTH_TIME}ms (status: $HEALTH_STATUS)"
else
    warning "/healthz returned: $HEALTH_STATUS (${HEALTH_TIME}ms)"
fi

# Livez endpoint
LIVEZ_START=$(python3 -c "import time; print(time.time())")
LIVEZ_STATUS=$(kubectl get --raw /livez 2>/dev/null || echo "error")
LIVEZ_END=$(python3 -c "import time; print(time.time())")
LIVEZ_TIME=$(python3 -c "print(f'{(${LIVEZ_END} - ${LIVEZ_START}) * 1000:.1f}')")
ok "/livez responded in ${LIVEZ_TIME}ms"

# Readyz endpoint
READYZ_START=$(python3 -c "import time; print(time.time())")
READYZ_STATUS=$(kubectl get --raw /readyz 2>/dev/null || echo "error")
READYZ_END=$(python3 -c "import time; print(time.time())")
READYZ_TIME=$(python3 -c "print(f'{(${READYZ_END} - ${READYZ_START}) * 1000:.1f}')")
ok "/readyz responded in ${READYZ_TIME}ms"

# List pods benchmark (measure API responsiveness under load)
LIST_START=$(python3 -c "import time; print(time.time())")
kubectl get pods -A --no-headers &>/dev/null
LIST_END=$(python3 -c "import time; print(time.time())")
LIST_TIME=$(python3 -c "print(f'{(${LIST_END} - ${LIST_START}) * 1000:.1f}')")
ok "List all pods responded in ${LIST_TIME}ms"

JSON_OUTPUT="$JSON_OUTPUT,\"api_server\":{\"healthz_ms\":$HEALTH_TIME,\"livez_ms\":$LIVEZ_TIME,\"readyz_ms\":$READYZ_TIME,\"list_pods_ms\":$LIST_TIME}"

# Evaluate API latency
HEALTH_TIME_INT=${HEALTH_TIME%.*}
if [[ "$HEALTH_TIME_INT" -lt 100 ]]; then
    ok "API server latency is within normal range"
elif [[ "$HEALTH_TIME_INT" -lt 500 ]]; then
    warning "API server latency is elevated"
else
    error "API server latency is high (>500ms)"
fi

#===== 4. etcd Database =====
section "etcd Performance"

# Try to get etcd database size via metrics
ETCD_SIZE=""
ETCD_POD=$(kubectl get pods -n kube-system -l component=etcd --no-headers 2>/dev/null \
    | awk 'NR==1{print $1}' || echo "")

if [[ -n "$ETCD_POD" ]]; then
    ok "etcd pod found: $ETCD_POD"

    # Try to get etcd metrics via the pod
    ETCD_DB_SIZE=$(kubectl exec -n kube-system "$ETCD_POD" -- \
        sh -c 'ETCDCTL_API=3 etcdctl --endpoints=https://127.0.0.1:2379 \
        --cacert=/etc/kubernetes/pki/etcd/ca.crt \
        --cert=/etc/kubernetes/pki/etcd/server.crt \
        --key=/etc/kubernetes/pki/etcd/server.key \
        endpoint status --write-out=json' 2>/dev/null || echo "")

    if [[ -n "$ETCD_DB_SIZE" ]]; then
        DB_SIZE_BYTES=$(echo "$ETCD_DB_SIZE" | python3 -c "
import json, sys
data = json.load(sys.stdin)
if isinstance(data, list):
    print(data[0].get('Status', {}).get('dbSize', 0))
else:
    print(data.get('Status', {}).get('dbSize', 0))
" 2>/dev/null || echo "0")

        if [[ "$DB_SIZE_BYTES" -gt 0 ]]; then
            DB_SIZE_MB=$(python3 -c "print(f'{${DB_SIZE_BYTES} / 1024 / 1024:.1f}')")
            ok "etcd database size: ${DB_SIZE_MB}MB"
            JSON_OUTPUT="$JSON_OUTPUT,\"etcd\":{\"db_size_bytes\":$DB_SIZE_BYTES,\"db_size_mb\":$DB_SIZE_MB}"

            # Warn if database is getting large (>500MB)
            DB_SIZE_INT=${DB_SIZE_MB%.*}
            if [[ "$DB_SIZE_INT" -lt 100 ]]; then
                ok "etcd database size is healthy (<100MB)"
            elif [[ "$DB_SIZE_INT" -lt 500 ]]; then
                warning "etcd database size is moderate - consider compaction"
            else
                error "etcd database size is large (>500MB) - compaction recommended"
            fi
        else
            warning "Could not parse etcd database size"
            JSON_OUTPUT="$JSON_OUTPUT,\"etcd\":{}"
        fi

        # Check etcd leader and raft index
        ETCD_LEADER=$(echo "$ETCD_DB_SIZE" | python3 -c "
import json, sys
data = json.load(sys.stdin)
if isinstance(data, list):
    status = data[0].get('Status', {})
else:
    status = data.get('Status', {})
leader = status.get('leader', 0)
raft = status.get('raftIndex', 0)
print(f'Leader: {leader}, Raft index: {raft}')
" 2>/dev/null || echo "Unknown")
        info "etcd $ETCD_LEADER"
    else
        warning "Could not query etcd metrics (may require direct access)"
        JSON_OUTPUT="$JSON_OUTPUT,\"etcd\":{}"
    fi
else
    warning "etcd pod not found in kube-system (may be external)"
    JSON_OUTPUT="$JSON_OUTPUT,\"etcd\":{}"
fi

# Count total Kubernetes objects (etcd load indicator)
echo ""
info "Kubernetes object counts:"
TOTAL_OBJECTS=0
for RESOURCE in pods services deployments configmaps secrets; do
    COUNT=$(kubectl get "$RESOURCE" -A --no-headers 2>/dev/null | wc -l | tr -d ' ')
    echo "    $RESOURCE: $COUNT"
    TOTAL_OBJECTS=$((TOTAL_OBJECTS + COUNT))
done
info "Total tracked objects: $TOTAL_OBJECTS"

#===== 5. Summary =====
section "Baseline Summary"

TOTAL_NODES=$(kubectl get nodes --no-headers 2>/dev/null | wc -l | tr -d ' ')
TOTAL_PODS=$(kubectl get pods -A --no-headers 2>/dev/null | wc -l | tr -d ' ')
TOTAL_NS=$(kubectl get namespaces --no-headers 2>/dev/null | wc -l | tr -d ' ')

echo "  Cluster overview:"
echo "    Nodes:      $TOTAL_NODES"
echo "    Namespaces: $TOTAL_NS"
echo "    Pods:       $TOTAL_PODS"
echo "    Objects:    $TOTAL_OBJECTS"
echo ""
echo "  API Server latency:"
echo "    /healthz:    ${HEALTH_TIME}ms"
echo "    /livez:      ${LIVEZ_TIME}ms"
echo "    /readyz:     ${READYZ_TIME}ms"
echo "    List pods:   ${LIST_TIME}ms"

JSON_OUTPUT="$JSON_OUTPUT,\"summary\":{\"nodes\":$TOTAL_NODES,\"namespaces\":$TOTAL_NS,\"pods\":$TOTAL_PODS,\"objects\":$TOTAL_OBJECTS}"
JSON_OUTPUT="$JSON_OUTPUT}"

#===== Save to File =====
if [[ -n "$SAVE_FILE" ]]; then
    echo ""
    # Pretty-print JSON
    echo "$JSON_OUTPUT" | python3 -m json.tool > "$SAVE_FILE" 2>/dev/null
    if [[ $? -eq 0 ]]; then
        ok "Baseline saved to: $SAVE_FILE"
        info "Compare baselines by diffing JSON files"
    else
        # Fallback: write raw JSON
        echo "$JSON_OUTPUT" > "$SAVE_FILE"
        ok "Baseline saved to: $SAVE_FILE (raw JSON)"
    fi
fi

echo ""
echo "============================================"
echo "  Baseline capture complete"
echo "============================================"
echo ""
