#!/bin/bash
# =============================================================================
# Proxmox Node Provisioner
# Provisions a new Kubernetes worker node via Proxmox API
# Waits for boot, then runs kubeadm join
#
# Usage:
#   ./proxmox-node-provisioner.sh --name k8s-autoscale-01 --ip 192.168.1.245 --join-token <token>
#   ./proxmox-node-provisioner.sh --remove --name k8s-autoscale-01
#
# Prerequisites:
#   - curl, jq installed
#   - Proxmox API access (set PROXMOX_API_URL, PROXMOX_API_TOKEN env vars)
#   - kubectl configured with cluster access
#   - SSH access to new nodes
# =============================================================================
set -euo pipefail

#=============================================================================
# CONFIGURATION
#=============================================================================

PROXMOX_API_URL="${PROXMOX_API_URL:-https://192.168.1.222:8006/api2/json}"
PROXMOX_NODE="${PROXMOX_NODE:-pve}"
PROXMOX_API_TOKEN="${PROXMOX_API_TOKEN:-}"
VM_TEMPLATE_ID="${VM_TEMPLATE_ID:-9000}"
NODE_CPUS="${NODE_CPUS:-4}"
NODE_MEMORY="${NODE_MEMORY:-16384}"
GATEWAY="${GATEWAY:-192.168.1.1}"
NAMESERVER="${NAMESERVER:-192.168.1.1}"
SSH_USER="${SSH_USER:-ubuntu}"
BOOT_WAIT="${BOOT_WAIT:-90}"

#=============================================================================
# USAGE
#=============================================================================

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Provision or remove a Kubernetes autoscale worker node via Proxmox API."
    echo ""
    echo "Options:"
    echo "  --name NAME          Node name (required)"
    echo "  --ip IP              Node IP address (required for provisioning)"
    echo "  --join-token TOKEN   kubeadm join token (required for provisioning)"
    echo "  --remove             Remove node instead of provisioning"
    echo "  --dry-run            Show what would be done without executing"
    echo "  -h, --help           Show this help message"
    echo ""
    echo "Environment variables:"
    echo "  PROXMOX_API_URL      Proxmox API endpoint (default: https://192.168.1.222:8006/api2/json)"
    echo "  PROXMOX_API_TOKEN    Proxmox API token (required)"
    echo "  PROXMOX_NODE         Proxmox node name (default: pve)"
    echo "  VM_TEMPLATE_ID       VM template ID (default: 9000)"
    echo "  NODE_CPUS            CPU cores (default: 4)"
    echo "  NODE_MEMORY          Memory in MB (default: 16384)"
    echo ""
    echo "Examples:"
    echo "  # Provision a new node"
    echo "  $0 --name k8s-autoscale-01 --ip 192.168.1.245 --join-token abcdef.1234567890abcdef"
    echo ""
    echo "  # Remove a node"
    echo "  $0 --remove --name k8s-autoscale-01"
    exit 1
}

#=============================================================================
# ARGUMENT PARSING
#=============================================================================

NODE_NAME=""
NODE_IP=""
JOIN_TOKEN=""
REMOVE=false
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --name)      NODE_NAME="$2"; shift 2 ;;
        --ip)        NODE_IP="$2"; shift 2 ;;
        --join-token) JOIN_TOKEN="$2"; shift 2 ;;
        --remove)    REMOVE=true; shift ;;
        --dry-run)   DRY_RUN=true; shift ;;
        -h|--help)   usage ;;
        *)           echo "Unknown option: $1"; usage ;;
    esac
done

if [[ -z "${NODE_NAME}" ]]; then
    echo "ERROR: --name is required"
    usage
fi

#=============================================================================
# HELPER FUNCTIONS
#=============================================================================

log() { echo "[$(date -u '+%Y-%m-%d %H:%M:%S UTC')] $*"; }

proxmox_api() {
    local method="$1"
    local endpoint="$2"
    shift 2
    curl -sk -X "${method}" \
        -H "Authorization: PVEAPIToken=${PROXMOX_API_TOKEN}" \
        "${PROXMOX_API_URL}${endpoint}" \
        "$@"
}

wait_for_ssh() {
    local ip="$1"
    local max_wait="${2:-120}"
    log "Waiting for SSH on ${ip} (timeout: ${max_wait}s)..."
    local elapsed=0
    while [[ ${elapsed} -lt ${max_wait} ]]; do
        if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no "${SSH_USER}@${ip}" "echo ok" 2>/dev/null; then
            log "SSH is available on ${ip}"
            return 0
        fi
        sleep 10
        elapsed=$((elapsed + 10))
        log "  Waiting... (${elapsed}s)"
    done
    log "ERROR: SSH timeout on ${ip}"
    return 1
}

#=============================================================================
# REMOVE NODE
#=============================================================================

if [[ "${REMOVE}" == "true" ]]; then
    log "=== Removing node: ${NODE_NAME} ==="

    # Drain and delete from Kubernetes
    log "Cordoning node ${NODE_NAME}..."
    if [[ "${DRY_RUN}" == "true" ]]; then
        log "[DRY RUN] kubectl cordon ${NODE_NAME}"
        log "[DRY RUN] kubectl drain ${NODE_NAME} --ignore-daemonsets --delete-emptydir-data --force"
        log "[DRY RUN] kubectl delete node ${NODE_NAME}"
    else
        kubectl cordon "${NODE_NAME}" 2>/dev/null || true
        log "Draining node ${NODE_NAME}..."
        kubectl drain "${NODE_NAME}" --ignore-daemonsets --delete-emptydir-data --force --timeout=120s 2>/dev/null || true
        log "Deleting node ${NODE_NAME} from cluster..."
        kubectl delete node "${NODE_NAME}" 2>/dev/null || true
    fi

    # Find and destroy VM on Proxmox
    log "Looking up VM ID for ${NODE_NAME} on Proxmox..."
    VM_LIST=$(proxmox_api GET "/nodes/${PROXMOX_NODE}/qemu" 2>/dev/null || echo '{"data":[]}')
    VM_ID=$(echo "${VM_LIST}" | jq -r ".data[] | select(.name==\"${NODE_NAME}\") | .vmid" 2>/dev/null || echo "")

    if [[ -n "${VM_ID}" ]]; then
        if [[ "${DRY_RUN}" == "true" ]]; then
            log "[DRY RUN] Stop and destroy VM ${VM_ID} (${NODE_NAME})"
        else
            log "Stopping VM ${VM_ID}..."
            proxmox_api POST "/nodes/${PROXMOX_NODE}/qemu/${VM_ID}/status/stop" >/dev/null 2>&1 || true
            sleep 10
            log "Destroying VM ${VM_ID}..."
            proxmox_api DELETE "/nodes/${PROXMOX_NODE}/qemu/${VM_ID}" >/dev/null 2>&1 || true
        fi
        log "VM ${VM_ID} (${NODE_NAME}) removed"
    else
        log "No VM found with name ${NODE_NAME} on Proxmox"
    fi

    log "=== Node removal complete ==="
    exit 0
fi

#=============================================================================
# PROVISION NODE
#=============================================================================

if [[ -z "${NODE_IP}" ]]; then
    echo "ERROR: --ip is required for provisioning"
    usage
fi

if [[ -z "${PROXMOX_API_TOKEN}" ]]; then
    echo "ERROR: PROXMOX_API_TOKEN environment variable is required"
    exit 1
fi

log "=== Provisioning node: ${NODE_NAME} (${NODE_IP}) ==="
log "Template ID: ${VM_TEMPLATE_ID}"
log "CPUs: ${NODE_CPUS}, Memory: ${NODE_MEMORY}MB"

if [[ "${DRY_RUN}" == "true" ]]; then
    log "[DRY RUN] Would clone VM template ${VM_TEMPLATE_ID} as ${NODE_NAME}"
    log "[DRY RUN] Would configure IP ${NODE_IP}, gateway ${GATEWAY}"
    log "[DRY RUN] Would start VM and wait for boot"
    log "[DRY RUN] Would run kubeadm join"
    exit 0
fi

# Clone the template
log "Cloning VM template ${VM_TEMPLATE_ID}..."
CLONE_RESULT=$(proxmox_api POST "/nodes/${PROXMOX_NODE}/qemu/${VM_TEMPLATE_ID}/clone" \
    -d "newid=0" \
    -d "name=${NODE_NAME}" \
    -d "full=1")

# Get the new VM ID from the task
TASK_ID=$(echo "${CLONE_RESULT}" | jq -r '.data' 2>/dev/null || echo "")
log "Clone task started: ${TASK_ID}"

# Wait for clone to complete
log "Waiting for clone operation to complete..."
sleep 30

# Find the new VM by name
VM_ID=$(proxmox_api GET "/nodes/${PROXMOX_NODE}/qemu" | \
    jq -r ".data[] | select(.name==\"${NODE_NAME}\") | .vmid")

if [[ -z "${VM_ID}" ]]; then
    log "ERROR: Could not find cloned VM ${NODE_NAME}"
    exit 1
fi

log "New VM ID: ${VM_ID}"

# Configure the VM
log "Configuring VM resources and network..."
proxmox_api PUT "/nodes/${PROXMOX_NODE}/qemu/${VM_ID}/config" \
    -d "cores=${NODE_CPUS}" \
    -d "memory=${NODE_MEMORY}" \
    -d "ipconfig0=ip=${NODE_IP}/24,gw=${GATEWAY}" \
    -d "nameserver=${NAMESERVER}" >/dev/null

# Start the VM
log "Starting VM ${VM_ID}..."
proxmox_api POST "/nodes/${PROXMOX_NODE}/qemu/${VM_ID}/status/start" >/dev/null

# Wait for the VM to boot
log "Waiting ${BOOT_WAIT}s for VM to boot..."
sleep "${BOOT_WAIT}"

# Wait for SSH
wait_for_ssh "${NODE_IP}" 120

# Join the Kubernetes cluster
if [[ -n "${JOIN_TOKEN}" ]]; then
    log "Generating kubeadm join command..."
    MASTER_IP="192.168.1.240"
    CA_HASH=$(ssh -o StrictHostKeyChecking=no "${SSH_USER}@${MASTER_IP}" \
        "openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | openssl rsa -pubin -outform der 2>/dev/null | openssl dgst -sha256 -hex | sed 's/^.* //'")

    JOIN_CMD="kubeadm join ${MASTER_IP}:6443 --token ${JOIN_TOKEN} --discovery-token-ca-cert-hash sha256:${CA_HASH}"

    log "Running kubeadm join on ${NODE_NAME}..."
    ssh -o StrictHostKeyChecking=no "${SSH_USER}@${NODE_IP}" "sudo ${JOIN_CMD}"
fi

# Wait for node to appear in kubectl
log "Waiting for node to join the cluster..."
for i in $(seq 1 30); do
    if kubectl get node "${NODE_NAME}" &>/dev/null; then
        log "Node ${NODE_NAME} has joined the cluster!"
        kubectl get node "${NODE_NAME}"
        break
    fi
    sleep 10
done

log "=== Node provisioning complete ==="
log "Node: ${NODE_NAME}"
log "IP: ${NODE_IP}"
log "VM ID: ${VM_ID}"
