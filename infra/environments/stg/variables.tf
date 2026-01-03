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
  default     = null
}

################################################################################
# Feature Flags for New Modules
################################################################################

variable "enable_cert_manager" {
  description = "Enable cert-manager module for TURN TLS certificates"
  type        = bool
  default     = false
}

variable "enable_ingress_module" {
  description = "Enable Kubernetes Ingress module (Terraform-managed Ingress)"
  type        = bool
  default     = false
}

variable "enable_external_secrets" {
  description = "Enable External Secrets Operator for Secret Manager sync"
  type        = bool
  default     = false
}

variable "acme_email" {
  description = "Email address for Let's Encrypt ACME account"
  type        = string
  default     = ""
}
