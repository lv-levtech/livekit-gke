variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region"
  type        = string
  default     = "asia-northeast1"
}

variable "domain" {
  description = "Primary domain for LiveKit"
  type        = string
}

variable "turn_domain" {
  description = "TURN domain for LiveKit"
  type        = string
}

variable "livekit_api_key" {
  description = "LiveKit API Key"
  type        = string
  sensitive   = true
}

variable "livekit_api_secret" {
  description = "LiveKit API Secret"
  type        = string
  sensitive   = true
}

variable "route53_zone_id" {
  description = "AWS Route 53 Hosted Zone ID for DNS management"
  type        = string
}

################################################################################
# ArgoCD Configuration
################################################################################

variable "git_repo_url" {
  description = "Git repository URL for ArgoCD applications"
  type        = string
}

variable "git_target_revision" {
  description = "Git branch/tag/commit for ArgoCD to use"
  type        = string
  default     = "main"
}

variable "bootstrap_app_of_apps" {
  description = "Whether to bootstrap the App of Apps application"
  type        = bool
  default     = true
}

################################################################################
# DEPRECATED: These variables are no longer used
# The corresponding modules have been moved to ArgoCD management
################################################################################

# variable "enable_cert_manager" - cert-manager is now managed by ArgoCD
# variable "enable_ingress_module" - Ingress is now managed by ArgoCD
# variable "enable_external_secrets" - External Secrets is now managed by ArgoCD
# variable "acme_email" - Defined in k8s/cert-manager/base/cluster-issuer-*.yaml
