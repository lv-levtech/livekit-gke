variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, stg, prd)"
  type        = string
}

variable "kubernetes_namespace" {
  description = "Kubernetes namespace for LiveKit"
  type        = string
  default     = "livekit"
}

variable "kubernetes_service_account" {
  description = "Kubernetes service account name"
  type        = string
  default     = "livekit-server"
}

variable "enable_secret_manager_access" {
  description = "Enable Secret Manager access for the service account"
  type        = bool
  default     = true
}
