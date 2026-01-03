#!/bin/bash
# =============================================================================
# LiveKit Helm Deployment Script
# =============================================================================
# Usage: ./deploy.sh <environment> [action]
# 
# Arguments:
#   environment: dev | stg | prd
#   action: install | upgrade | uninstall | template (default: upgrade)
#
# Examples:
#   ./deploy.sh dev install      # Install to dev environment
#   ./deploy.sh prd upgrade      # Upgrade production deployment
#   ./deploy.sh stg template     # Dry-run: show rendered manifests
# =============================================================================

set -euo pipefail

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VALUES_DIR="${SCRIPT_DIR}/../values"
TERRAFORM_DIR="${SCRIPT_DIR}/../../terraform/environments"
NAMESPACE="livekit"
RELEASE_NAME="livekit"
CHART_REPO="livekit"
CHART_NAME="livekit/livekit-server"
CHART_VERSION=""  # Leave empty for latest

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# -----------------------------------------------------------------------------
# Functions
# -----------------------------------------------------------------------------
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

usage() {
    echo "Usage: $0 <environment> [action]"
    echo ""
    echo "Arguments:"
    echo "  environment: dev | stg | prd"
    echo "  action: install | upgrade | uninstall | template (default: upgrade)"
    echo ""
    echo "Examples:"
    echo "  $0 dev install      # Install to dev environment"
    echo "  $0 prd upgrade      # Upgrade production deployment"
    echo "  $0 stg template     # Dry-run: show rendered manifests"
    exit 1
}

validate_environment() {
    local env=$1
    case $env in
        dev|stg|prd)
            return 0
            ;;
        *)
            log_error "Invalid environment: $env"
            usage
            ;;
    esac
}

validate_action() {
    local action=$1
    case $action in
        install|upgrade|uninstall|template)
            return 0
            ;;
        *)
            log_error "Invalid action: $action"
            usage
            ;;
    esac
}

check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check helm
    if ! command -v helm &> /dev/null; then
        log_error "helm is not installed. Please install helm first."
        exit 1
    fi
    
    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed. Please install kubectl first."
        exit 1
    fi
    
    # Check gcloud
    if ! command -v gcloud &> /dev/null; then
        log_error "gcloud is not installed. Please install Google Cloud SDK first."
        exit 1
    fi
    
    log_info "All prerequisites satisfied."
}

setup_helm_repo() {
    log_info "Setting up LiveKit Helm repository..."
    
    if ! helm repo list | grep -q "^${CHART_REPO}"; then
        helm repo add ${CHART_REPO} https://helm.livekit.io
    fi
    
    helm repo update
    log_info "Helm repository updated."
}

get_terraform_outputs() {
    local env=$1
    local tf_dir="${TERRAFORM_DIR}/${env}"

    if [[ ! -d "$tf_dir" ]]; then
        log_error "Terraform directory not found: $tf_dir"
        exit 1
    fi

    log_info "Fetching Terraform outputs for ${env}..."

    cd "$tf_dir"

    # Get outputs
    REDIS_ADDRESS=$(terraform output -raw redis_address 2>/dev/null || echo "")
    REDIS_AUTH_STRING=$(terraform output -raw redis_auth_string 2>/dev/null || echo "")
    STATIC_IP=$(terraform output -raw livekit_static_ip 2>/dev/null || echo "")
    TURN_STATIC_IP=$(terraform output -raw turn_static_ip 2>/dev/null || echo "")
    WORKLOAD_IDENTITY=$(terraform output -raw workload_identity_annotation 2>/dev/null || echo "")
    GKE_CREDENTIALS_CMD=$(terraform output -raw get_credentials_command 2>/dev/null || echo "")

    cd - > /dev/null

    # Log retrieved values (mask sensitive data)
    log_info "Terraform outputs retrieved:"
    log_info "  - Redis Address: ${REDIS_ADDRESS:-'(not set)'}"
    log_info "  - Redis Password: ${REDIS_AUTH_STRING:+'(set)'}"
    log_info "  - Static IP: ${STATIC_IP:-'(not set)'}"
    log_info "  - TURN IP: ${TURN_STATIC_IP:-'(not set)'}"
    log_info "  - Workload Identity: ${WORKLOAD_IDENTITY:-'(not set)'}"
}

configure_kubectl() {
    local env=$1
    
    log_info "Configuring kubectl for ${env} cluster..."
    
    if [[ -n "$GKE_CREDENTIALS_CMD" ]]; then
        eval "$GKE_CREDENTIALS_CMD"
    else
        log_warn "Could not get GKE credentials command from Terraform."
        log_warn "Please ensure kubectl is configured for the correct cluster."
    fi
}

create_namespace() {
    log_info "Ensuring namespace ${NAMESPACE} exists..."
    kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -
}

create_turn_secret() {
    local env=$1
    local secret_name="livekit-turn-tls-${env}"
    
    log_info "Checking TURN TLS secret..."
    
    if ! kubectl get secret ${secret_name} -n ${NAMESPACE} &> /dev/null; then
        log_warn "TURN TLS secret '${secret_name}' not found."
        log_warn "Please create it manually with your TLS certificate:"
        log_warn "  kubectl create secret tls ${secret_name} \\"
        log_warn "    --cert=path/to/cert.pem \\"
        log_warn "    --key=path/to/key.pem \\"
        log_warn "    -n ${NAMESPACE}"
    else
        log_info "TURN TLS secret exists."
    fi
}

create_api_keys_secret() {
    local env=$1
    
    log_info "Checking LiveKit API keys secret..."
    
    if ! kubectl get secret livekit-server-keys -n ${NAMESPACE} &> /dev/null; then
        log_warn "LiveKit API keys secret not found."
        log_warn "Please create it with your API keys:"
        log_warn "  kubectl create secret generic livekit-server-keys \\"
        log_warn "    --from-literal=LIVEKIT_API_KEY=<your-api-key> \\"
        log_warn "    --from-literal=LIVEKIT_API_SECRET=<your-api-secret> \\"
        log_warn "    -n ${NAMESPACE}"
        log_warn ""
        log_warn "Or use External Secrets Operator to sync from Secret Manager."
    else
        log_info "API keys secret exists."
    fi
}

build_helm_args() {
    local env=$1
    local action=$2

    HELM_ARGS=""

    # Common and environment-specific values
    HELM_ARGS+=" -f ${VALUES_DIR}/common.yaml"
    HELM_ARGS+=" -f ${VALUES_DIR}/${env}.yaml"

    # Override values from Terraform outputs
    if [[ -n "$REDIS_ADDRESS" ]]; then
        HELM_ARGS+=" --set livekit.redis.address=${REDIS_ADDRESS}"
    fi

    if [[ -n "$REDIS_AUTH_STRING" ]]; then
        HELM_ARGS+=" --set livekit.redis.password=${REDIS_AUTH_STRING}"
    fi

    if [[ -n "$WORKLOAD_IDENTITY" ]]; then
        HELM_ARGS+=" --set serviceAccount.annotations.\"iam\\.gke\\.io/gcp-service-account\"=${WORKLOAD_IDENTITY}"
    fi

    # Chart version if specified
    if [[ -n "$CHART_VERSION" ]]; then
        HELM_ARGS+=" --version ${CHART_VERSION}"
    fi

    # Namespace
    HELM_ARGS+=" -n ${NAMESPACE}"
}

helm_install() {
    local env=$1
    
    log_info "Installing LiveKit to ${env}..."
    
    build_helm_args "$env" "install"
    
    # shellcheck disable=SC2086
    helm install ${RELEASE_NAME} ${CHART_NAME} ${HELM_ARGS} --create-namespace
    
    log_info "LiveKit installed successfully."
}

helm_upgrade() {
    local env=$1
    
    log_info "Upgrading LiveKit in ${env}..."
    
    build_helm_args "$env" "upgrade"
    
    # shellcheck disable=SC2086
    helm upgrade ${RELEASE_NAME} ${CHART_NAME} ${HELM_ARGS} --install
    
    log_info "LiveKit upgraded successfully."
}

helm_uninstall() {
    local env=$1
    
    log_info "Uninstalling LiveKit from ${env}..."
    
    helm uninstall ${RELEASE_NAME} -n ${NAMESPACE}
    
    log_info "LiveKit uninstalled successfully."
}

helm_template() {
    local env=$1
    
    log_info "Rendering LiveKit templates for ${env}..."
    
    build_helm_args "$env" "template"
    
    # shellcheck disable=SC2086
    helm template ${RELEASE_NAME} ${CHART_NAME} ${HELM_ARGS}
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
main() {
    # Parse arguments
    if [[ $# -lt 1 ]]; then
        usage
    fi
    
    local env=$1
    local action=${2:-upgrade}
    
    # Validate
    validate_environment "$env"
    validate_action "$action"
    
    # Check prerequisites
    check_prerequisites
    
    # Setup
    setup_helm_repo
    get_terraform_outputs "$env"
    
    # Configure cluster access (skip for template)
    if [[ "$action" != "template" ]]; then
        configure_kubectl "$env"
        create_namespace
        create_turn_secret "$env"
        create_api_keys_secret "$env"
    fi
    
    # Execute action
    case $action in
        install)
            helm_install "$env"
            ;;
        upgrade)
            helm_upgrade "$env"
            ;;
        uninstall)
            helm_uninstall "$env"
            ;;
        template)
            helm_template "$env"
            ;;
    esac
    
    log_info "Done!"
}

main "$@"
