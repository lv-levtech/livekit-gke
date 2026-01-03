#!/bin/bash
# =============================================================================
# LiveKit Status Check Script
# =============================================================================
# Usage: ./status.sh <environment>
# =============================================================================

set -euo pipefail

NAMESPACE="livekit"
RELEASE_NAME="livekit"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_section() {
    echo -e "\n${YELLOW}=== $1 ===${NC}\n"
}

if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <environment>"
    exit 1
fi

ENV=$1

log_info "Checking LiveKit status for ${ENV} environment..."

log_section "Helm Release"
helm list -n ${NAMESPACE}

log_section "Pods"
kubectl get pods -n ${NAMESPACE} -o wide

log_section "Services"
kubectl get svc -n ${NAMESPACE}

log_section "Ingress"
kubectl get ingress -n ${NAMESPACE}

log_section "BackendConfig"
kubectl get backendconfig -n ${NAMESPACE} 2>/dev/null || echo "No BackendConfig found"

log_section "ManagedCertificate"
kubectl get managedcertificates -n ${NAMESPACE} 2>/dev/null || echo "No ManagedCertificate found"

log_section "Pod Logs (last 20 lines)"
POD=$(kubectl get pods -n ${NAMESPACE} -l app.kubernetes.io/name=livekit-server -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [[ -n "$POD" ]]; then
    kubectl logs ${POD} -n ${NAMESPACE} --tail=20
else
    echo "No pods found"
fi

log_section "Events"
kubectl get events -n ${NAMESPACE} --sort-by='.lastTimestamp' | tail -10
