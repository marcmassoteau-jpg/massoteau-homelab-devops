#!/usr/bin/env bash
#
# Kubernetes Cluster Provisioning Script
#
# This script orchestrates the complete cluster provisioning workflow:
# 1. Terraform creates VMs on Proxmox
# 2. Waits for VMs to boot and cloud-init to complete
# 3. Ansible configures the VMs and deploys Kubernetes
# 4. Verifies cluster health
#
# Author: Marc Massoteau
# Repository: https://github.com/marcmassoteau-jpg/massoteau-homelab-devops
#
# Usage:
#   ./scripts/automation/provision-cluster.sh [--destroy]
#
# Options:
#   --destroy    Destroy the cluster instead of creating it
#   --help       Show this help message

set -euo pipefail

# ============================================
# Configuration
# ============================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
TERRAFORM_DIR="${PROJECT_ROOT}/terraform/proxmox-vms"
ANSIBLE_DIR="${PROJECT_ROOT}/ansible"
LOG_FILE="${PROJECT_ROOT}/cluster-provision.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ============================================
# Functions
# ============================================

log() {
    local message="$1"
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} ${message}" | tee -a "${LOG_FILE}"
}

log_success() {
    local message="$1"
    echo -e "${GREEN}[✓]${NC} ${message}" | tee -a "${LOG_FILE}"
}

log_warning() {
    local message="$1"
    echo -e "${YELLOW}[!]${NC} ${message}" | tee -a "${LOG_FILE}"
}

log_error() {
    local message="$1"
    echo -e "${RED}[✗]${NC} ${message}" | tee -a "${LOG_FILE}"
}

show_help() {
    cat << EOF
Kubernetes Cluster Provisioning Script

This script automates the complete cluster provisioning workflow using
Terraform (infrastructure) and Ansible (configuration).

Usage:
    $(basename "$0") [OPTIONS]

Options:
    --destroy     Destroy the cluster (terraform destroy)
    --help        Show this help message

Examples:
    # Provision a new cluster
    $(basename "$0")

    # Destroy the cluster
    $(basename "$0") --destroy

Steps Performed:
    1. Terraform: Create VMs on Proxmox
    2. Wait: VMs boot and cloud-init completes (~60s)
    3. Ansible: Network configuration
    4. Ansible: Security hardening
    5. Ansible: Kubernetes prerequisites
    6. Ansible: Kubernetes cluster deployment
    7. Verify: Cluster health check

Requirements:
    - Terraform 1.5+ installed
    - Ansible 2.14+ installed
    - terraform/proxmox-vms/terraform.tfvars configured
    - ansible/inventory/hosts.ini configured
    - SSH access to Proxmox
    - Proxmox API token configured

EOF
    exit 0
}

check_prerequisites() {
    log "Checking prerequisites..."

    # Check Terraform
    if ! command -v terraform &> /dev/null; then
        log_error "Terraform not found. Install from https://www.terraform.io/downloads"
        exit 1
    fi
    log_success "Terraform found: $(terraform version -json | jq -r '.terraform_version')"

    # Check Ansible
    if ! command -v ansible &> /dev/null; then
        log_error "Ansible not found. Install with: pip install ansible"
        exit 1
    fi
    log_success "Ansible found: $(ansible --version | head -n1 | awk '{print $2}')"

    # Check jq (for JSON parsing)
    if ! command -v jq &> /dev/null; then
        log_warning "jq not found. Install for better output parsing: brew install jq"
    fi

    # Check Terraform directory
    if [ ! -d "${TERRAFORM_DIR}" ]; then
        log_error "Terraform directory not found: ${TERRAFORM_DIR}"
        exit 1
    fi

    # Check terraform.tfvars
    if [ ! -f "${TERRAFORM_DIR}/terraform.tfvars" ]; then
        log_error "terraform.tfvars not found. Copy from terraform.tfvars.example and configure"
        exit 1
    fi

    # Check Ansible directory
    if [ ! -d "${ANSIBLE_DIR}" ]; then
        log_error "Ansible directory not found: ${ANSIBLE_DIR}"
        exit 1
    fi

    log_success "All prerequisites satisfied"
}

terraform_deploy() {
    log "Initializing Terraform..."
    cd "${TERRAFORM_DIR}"

    terraform init -upgrade > /dev/null 2>&1
    log_success "Terraform initialized"

    log "Planning infrastructure deployment..."
    terraform plan -out=tfplan

    log "Applying Terraform configuration..."
    terraform apply tfplan

    log_success "VMs created successfully"

    # Extract node IPs for later use
    log "Extracting node information..."
    MASTER_IP=$(terraform output -raw master_node_ip)
    WORKER_IPS=$(terraform output -json worker_node_ips | jq -r '.[]')

    log_success "Master IP: ${MASTER_IP}"
    log_success "Worker IPs: $(echo ${WORKER_IPS} | tr '\n' ' ')"

    cd "${PROJECT_ROOT}"
}

wait_for_vms() {
    log "Waiting for VMs to boot and cloud-init to complete..."
    log_warning "This typically takes 60-90 seconds..."

    local wait_time=90
    local interval=10
    local elapsed=0

    while [ $elapsed -lt $wait_time ]; do
        echo -n "."
        sleep $interval
        elapsed=$((elapsed + interval))
    done
    echo ""

    log_success "Wait complete. VMs should be ready."
}

test_connectivity() {
    log "Testing SSH connectivity to nodes..."

    cd "${ANSIBLE_DIR}"

    if ansible all -m ping -o; then
        log_success "All nodes reachable via SSH"
        return 0
    else
        log_error "Some nodes not reachable. Waiting 30 more seconds..."
        sleep 30

        if ansible all -m ping -o; then
            log_success "All nodes now reachable"
            return 0
        else
            log_error "Connectivity test failed. Check SSH configuration and network."
            return 1
        fi
    fi

    cd "${PROJECT_ROOT}"
}

ansible_configure() {
    log "Running Ansible playbooks to configure cluster..."

    cd "${ANSIBLE_DIR}"

    local playbooks=(
        "playbooks/01-network-setup.yml"
        "playbooks/02-security-hardening.yml"
        "playbooks/03-kubernetes-prereqs.yml"
        "playbooks/04-install-kubernetes.yml"
    )

    for playbook in "${playbooks[@]}"; do
        log "Running ${playbook}..."
        if ansible-playbook "${playbook}"; then
            log_success "Playbook ${playbook} completed successfully"
        else
            log_error "Playbook ${playbook} failed"
            exit 1
        fi
    done

    cd "${PROJECT_ROOT}"
}

verify_cluster() {
    log "Verifying cluster health..."

    cd "${ANSIBLE_DIR}"

    # Run verification playbook if it exists
    if [ -f "playbooks/99-verify-cluster.yml" ]; then
        log "Running cluster verification playbook..."
        ansible-playbook playbooks/99-verify-cluster.yml
    else
        log_warning "Verification playbook not found, skipping automated verification"
        log "You can verify manually with: kubectl get nodes; kubectl get pods -A"
    fi

    cd "${PROJECT_ROOT}"
}

terraform_destroy() {
    log "Destroying cluster infrastructure..."

    cd "${TERRAFORM_DIR}"

    log_warning "This will destroy all VMs created by Terraform"
    read -p "Are you sure? Type 'yes' to confirm: " confirm

    if [ "$confirm" != "yes" ]; then
        log "Destroy cancelled"
        exit 0
    fi

    terraform destroy

    log_success "Cluster destroyed"

    cd "${PROJECT_ROOT}"
}

show_summary() {
    cat << EOF

╔════════════════════════════════════════════════════════════╗
║  Kubernetes Cluster Provisioning - Complete!              ║
╚════════════════════════════════════════════════════════════╝

Cluster Information:
  Master Node: ${MASTER_IP}
  Worker Nodes: $(echo ${WORKER_IPS} | tr '\n' ',' | sed 's/,$//')

Next Steps:
  1. SSH to master: ssh ubuntu@${MASTER_IP}
  2. Check nodes: kubectl get nodes
  3. Check pods: kubectl get pods -A
  4. Deploy applications: kubectl apply -f your-app.yaml

Useful Commands:
  # Get cluster info
  terraform -chdir=${TERRAFORM_DIR} output

  # Re-run Ansible playbooks
  cd ${ANSIBLE_DIR}
  ansible-playbook playbooks/04-install-kubernetes.yml

  # Destroy cluster
  $(basename "$0") --destroy

Documentation:
  - Article 10: Terraform Foundations
  - Article 11: Ansible Configuration
  - Article 12: Terraform + Ansible Integration

Log file: ${LOG_FILE}

╚════════════════════════════════════════════════════════════╝

EOF
}

# ============================================
# Main Script
# ============================================

main() {
    local mode="provision"

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --destroy)
                mode="destroy"
                shift
                ;;
            --help)
                show_help
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                ;;
        esac
    done

    # Clear log file
    > "${LOG_FILE}"

    log "╔════════════════════════════════════════════════════════════╗"
    log "║  Kubernetes Cluster Provisioning Script                   ║"
    log "╚════════════════════════════════════════════════════════════╝"
    log ""

    if [ "$mode" == "destroy" ]; then
        check_prerequisites
        terraform_destroy
        exit 0
    fi

    # Provision mode
    check_prerequisites
    terraform_deploy
    wait_for_vms
    test_connectivity
    ansible_configure
    verify_cluster
    show_summary

    log_success "Cluster provisioning complete! 🎉"
}

# Run main function
main "$@"
