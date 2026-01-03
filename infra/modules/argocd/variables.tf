################################################################################
# ArgoCD Module Variables
################################################################################

variable "argocd_version" {
  description = "ArgoCD Helm chart version"
  type        = string
  default     = "5.51.6"
}

variable "environment" {
  description = "Environment name (dev, stg, prd)"
  type        = string
}

variable "argocd_domain" {
  description = "Domain for ArgoCD UI"
  type        = string
  default     = ""
}

variable "argocd_insecure" {
  description = "Run ArgoCD server in insecure mode (no TLS)"
  type        = bool
  default     = true
}

################################################################################
# App of Apps Configuration
################################################################################

variable "bootstrap_app_of_apps" {
  description = "Whether to bootstrap the App of Apps application"
  type        = bool
  default     = true
}

variable "git_repo_url" {
  description = "Git repository URL for ArgoCD applications"
  type        = string
}

variable "git_target_revision" {
  description = "Git branch/tag/commit to use"
  type        = string
  default     = "main"
}

################################################################################
# Optional Features
################################################################################

variable "enable_notifications" {
  description = "Enable ArgoCD notifications"
  type        = bool
  default     = false
}
