################################################################################
# cert-manager Module Variables
################################################################################

variable "cert_manager_version" {
  description = "Version of cert-manager Helm chart"
  type        = string
  default     = "v1.14.4"
}

variable "create_namespace" {
  description = "Whether to create the cert-manager namespace"
  type        = bool
  default     = true
}

variable "create_cluster_issuer" {
  description = "Whether to create ClusterIssuer for Let's Encrypt"
  type        = bool
  default     = true
}

variable "create_staging_issuer" {
  description = "Whether to create staging ClusterIssuer (for testing)"
  type        = bool
  default     = false
}

variable "use_staging_issuer" {
  description = "Whether to use staging issuer for certificates (for testing)"
  type        = bool
  default     = false
}

variable "acme_email" {
  description = "Email address for Let's Encrypt account"
  type        = string
}

variable "enable_prometheus_metrics" {
  description = "Whether to enable Prometheus metrics"
  type        = bool
  default     = true
}

variable "resources" {
  description = "Resource requests and limits for cert-manager"
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
# TURN Certificate Configuration
################################################################################

variable "create_turn_certificate" {
  description = "Whether to create Certificate for TURN domain"
  type        = bool
  default     = true
}

variable "turn_domain" {
  description = "TURN server domain for TLS certificate"
  type        = string
  default     = ""
}

variable "turn_certificate_secret_name" {
  description = "Name of the Kubernetes secret for TURN TLS certificate"
  type        = string
  default     = "turn-tls-secret"
}

variable "livekit_namespace" {
  description = "Kubernetes namespace where LiveKit is deployed"
  type        = string
  default     = "livekit"
}
