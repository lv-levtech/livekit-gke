################################################################################
# External Secrets Operator Module Variables
################################################################################

variable "eso_version" {
  description = "Version of External Secrets Operator Helm chart"
  type        = string
  default     = "0.9.13"
}

variable "create_namespace" {
  description = "Whether to create the external-secrets namespace"
  type        = bool
  default     = true
}

variable "service_account_name" {
  description = "Name of the Kubernetes service account for ESO"
  type        = string
  default     = "external-secrets"
}

variable "gcp_service_account_email" {
  description = "GCP service account email for Workload Identity"
  type        = string
}

variable "project_id" {
  description = "GCP project ID for Secret Manager"
  type        = string
}

variable "resources" {
  description = "Resource requests and limits for ESO"
  type = object({
    requests = object({
      cpu    = string
      memory = string
    })
    limits = object({
      cpu    = string
      memory = string
    })
  })
  default = {
    requests = {
      cpu    = "50m"
      memory = "64Mi"
    }
    limits = {
      cpu    = "200m"
      memory = "256Mi"
    }
  }
}

################################################################################
# ClusterSecretStore Configuration
################################################################################

variable "create_cluster_secret_store" {
  description = "Whether to create ClusterSecretStore for GCP Secret Manager"
  type        = bool
  default     = true
}

################################################################################
# LiveKit Secrets Configuration
################################################################################

variable "create_livekit_secrets" {
  description = "Whether to create ExternalSecret for LiveKit API keys"
  type        = bool
  default     = true
}

variable "livekit_namespace" {
  description = "Kubernetes namespace where LiveKit is deployed"
  type        = string
  default     = "livekit"
}

variable "api_key_secret_name" {
  description = "Name of the secret in GCP Secret Manager for API key"
  type        = string
}

variable "api_secret_secret_name" {
  description = "Name of the secret in GCP Secret Manager for API secret"
  type        = string
}

variable "refresh_interval" {
  description = "How often to sync secrets from Secret Manager"
  type        = string
  default     = "1h"
}
