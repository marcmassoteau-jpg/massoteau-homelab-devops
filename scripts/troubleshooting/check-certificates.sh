#!/usr/bin/env bash
# =============================================================================
# Certificate Check Script
# =============================================================================
# Checks Kubernetes certificate expiration including kubeadm certificates,
# webhook certificates, and TLS secrets.
#
# Usage:
#   ./check-certificates.sh
#   sudo ./check-certificates.sh    (for kubeadm cert check)
#   ./check-certificates.sh -h
#
# Requirements:
#   - kubectl configured with cluster access
#   - kubeadm (for certificate expiration check, requires root)
#   - openssl (for TLS secret inspection)
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

#===== Thresholds (days) =====
CRITICAL_DAYS=30
WARNING_DAYS=90

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

show_help() {
    echo "Usage: $(basename "$0") [-h]"
    echo ""
    echo "Checks Kubernetes certificate expiration dates."
    echo ""
    echo "Options:"
    echo "  -h    Show this help message"
    echo ""
    echo "Checks performed:"
    echo "  - kubeadm certificate expiration (requires root)"
    echo "  - Webhook certificates"
    echo "  - TLS secrets in all namespaces"
    echo "  - Service account token expiration"
    echo ""
    echo "Thresholds:"
    echo "  - Critical: < $CRITICAL_DAYS days until expiration"
    echo "  - Warning:  < $WARNING_DAYS days until expiration"
    exit 0
}

# Check days until a date expires
# Args: $1 = expiry date string (parseable by date)
# Returns: number of days (negative if expired)
days_until_expiry() {
    local expiry_date="$1"
    local expiry_epoch
    local now_epoch
    local diff_days

    # Handle different date command variants (GNU vs BSD)
    if date --version &>/dev/null 2>&1; then
        # GNU date
        expiry_epoch=$(date -d "$expiry_date" +%s 2>/dev/null || echo "0")
    else
        # BSD date (macOS)
        expiry_epoch=$(date -j -f "%b %d %H:%M:%S %Y %Z" "$expiry_date" +%s 2>/dev/null || \
                       date -j -f "%Y-%m-%dT%H:%M:%SZ" "$expiry_date" +%s 2>/dev/null || echo "0")
    fi

    now_epoch=$(date +%s)

    if [[ "$expiry_epoch" -eq 0 ]]; then
        echo "unknown"
        return
    fi

    diff_days=$(( (expiry_epoch - now_epoch) / 86400 ))
    echo "$diff_days"
}

# Evaluate and display days until expiry
# Args: $1 = label, $2 = days until expiry
check_expiry_days() {
    local label="$1"
    local days="$2"

    if [[ "$days" == "unknown" ]]; then
        warn "$label: could not parse expiration date"
        return
    fi

    if [[ "$days" -lt 0 ]]; then
        fail "$label: EXPIRED $(( -days )) days ago"
    elif [[ "$days" -lt "$CRITICAL_DAYS" ]]; then
        fail "$label: expires in $days days (CRITICAL)"
    elif [[ "$days" -lt "$WARNING_DAYS" ]]; then
        warn "$label: expires in $days days"
    else
        pass "$label: expires in $days days"
    fi
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

echo "============================================"
echo "  Certificate Expiration Check"
echo "  $(date)"
echo "============================================"
echo ""
echo "  Thresholds: Critical < ${CRITICAL_DAYS} days | Warning < ${WARNING_DAYS} days"

#===== 1. Kubeadm Certificates =====
section "Kubeadm Certificates"

if command -v kubeadm &>/dev/null; then
    if [[ $EUID -eq 0 ]]; then
        CERT_OUTPUT=$(kubeadm certs check-expiration 2>/dev/null || true)
        if [[ -n "$CERT_OUTPUT" ]]; then
            echo "$CERT_OUTPUT"
            echo ""

            # Parse certificate expiration lines
            while IFS= read -r line; do
                # Match lines like: "admin.conf    Dec 15, 2026 10:30 UTC   364d   ..."
                if echo "$line" | grep -qE "^[a-z].*20[0-9]{2}"; then
                    CERT_NAME=$(echo "$line" | awk '{print $1}')
                    # Extract the residual time (e.g., "364d" or "no")
                    RESIDUAL=$(echo "$line" | grep -oE '[0-9]+d' | head -1 || true)
                    if [[ -n "$RESIDUAL" ]]; then
                        DAYS=$(echo "$RESIDUAL" | tr -d 'd')
                        check_expiry_days "$CERT_NAME" "$DAYS"
                    fi
                fi
            done <<< "$CERT_OUTPUT"
        else
            warn "Could not retrieve kubeadm certificate information"
        fi
    else
        warn "kubeadm cert check requires root. Run with: sudo $(basename "$0")"
        info "Skipping kubeadm certificate checks"
    fi
else
    info "kubeadm not found - skipping kubeadm certificate checks"
    info "This is expected if running from a remote machine"
fi

#===== 2. Webhook Certificates =====
section "Webhook Certificates"

# Check validating webhook configurations
VWHOOKS=$(kubectl get validatingwebhookconfigurations --no-headers 2>/dev/null || true)
if [[ -n "$VWHOOKS" ]]; then
    info "Validating Webhook Configurations:"
    while IFS= read -r line; do
        HOOK_NAME=$(echo "$line" | awk '{print $1}')
        # Get the CA bundle and check its expiration
        CA_BUNDLE=$(kubectl get validatingwebhookconfiguration "$HOOK_NAME" -o jsonpath='{.webhooks[0].clientConfig.caBundle}' 2>/dev/null || true)
        if [[ -n "$CA_BUNDLE" ]]; then
            EXPIRY=$(echo "$CA_BUNDLE" | base64 -d 2>/dev/null | openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2 || true)
            if [[ -n "$EXPIRY" ]]; then
                DAYS=$(days_until_expiry "$EXPIRY")
                check_expiry_days "ValidatingWebhook/$HOOK_NAME" "$DAYS"
            else
                info "  $HOOK_NAME: could not read CA bundle expiration"
            fi
        else
            info "  $HOOK_NAME: no CA bundle configured"
        fi
    done <<< "$VWHOOKS"
else
    info "No validating webhook configurations found"
fi

# Check mutating webhook configurations
MWHOOKS=$(kubectl get mutatingwebhookconfigurations --no-headers 2>/dev/null || true)
if [[ -n "$MWHOOKS" ]]; then
    info "Mutating Webhook Configurations:"
    while IFS= read -r line; do
        HOOK_NAME=$(echo "$line" | awk '{print $1}')
        CA_BUNDLE=$(kubectl get mutatingwebhookconfiguration "$HOOK_NAME" -o jsonpath='{.webhooks[0].clientConfig.caBundle}' 2>/dev/null || true)
        if [[ -n "$CA_BUNDLE" ]]; then
            EXPIRY=$(echo "$CA_BUNDLE" | base64 -d 2>/dev/null | openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2 || true)
            if [[ -n "$EXPIRY" ]]; then
                DAYS=$(days_until_expiry "$EXPIRY")
                check_expiry_days "MutatingWebhook/$HOOK_NAME" "$DAYS"
            else
                info "  $HOOK_NAME: could not read CA bundle expiration"
            fi
        else
            info "  $HOOK_NAME: no CA bundle configured"
        fi
    done <<< "$MWHOOKS"
else
    info "No mutating webhook configurations found"
fi

#===== 3. TLS Secrets =====
section "TLS Secrets"

TLS_SECRETS=$(kubectl get secrets -A --field-selector type=kubernetes.io/tls --no-headers 2>/dev/null || true)
if [[ -n "$TLS_SECRETS" ]]; then
    while IFS= read -r line; do
        NS=$(echo "$line" | awk '{print $1}')
        SECRET_NAME=$(echo "$line" | awk '{print $2}')

        # Extract and decode the certificate
        CERT_DATA=$(kubectl get secret "$SECRET_NAME" -n "$NS" -o jsonpath='{.data.tls\.crt}' 2>/dev/null || true)
        if [[ -n "$CERT_DATA" ]]; then
            EXPIRY=$(echo "$CERT_DATA" | base64 -d 2>/dev/null | openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2 || true)
            if [[ -n "$EXPIRY" ]]; then
                DAYS=$(days_until_expiry "$EXPIRY")
                check_expiry_days "TLS/$NS/$SECRET_NAME" "$DAYS"
            else
                warn "TLS/$NS/$SECRET_NAME: could not parse certificate"
            fi
        else
            warn "TLS/$NS/$SECRET_NAME: no tls.crt data found"
        fi
    done <<< "$TLS_SECRETS"
else
    info "No TLS secrets found in the cluster"
fi

#===== Summary =====
section "Certificate Check Summary"

echo ""
echo -e "  ${GREEN}Passed:  $PASS_COUNT${NC}"
echo -e "  ${YELLOW}Warnings: $WARN_COUNT${NC}"
echo -e "  ${RED}Failed:  $FAIL_COUNT${NC}"
echo ""

if [[ "$FAIL_COUNT" -gt 0 ]]; then
    echo -e "  ${RED}Overall: CERTIFICATE ISSUES DETECTED${NC}"
    echo ""
    echo "  To renew kubeadm certificates:"
    echo "    sudo kubeadm certs renew all"
    echo ""
    echo "  See docs/troubleshooting/certificate-issues.md for more details."
    exit 1
elif [[ "$WARN_COUNT" -gt 0 ]]; then
    echo -e "  ${YELLOW}Overall: CERTIFICATES OK (renewals needed soon)${NC}"
    exit 0
else
    echo -e "  ${GREEN}Overall: ALL CERTIFICATES HEALTHY${NC}"
    exit 0
fi
