################################################################################
# Kubernetes Ingress Module Variables
################################################################################

variable "namespace" {
  description = "Kubernetes namespace for Ingress resources"
  type        = string
  default     = "livekit"
}

variable "domain" {
  description = "Domain name for LiveKit service"
  type        = string
}

variable "static_ip_name" {
  description = "Name of the GCP global static IP"
  type        = string
}

variable "managed_certificate_name" {
  description = "Name of the GKE Managed Certificate"
  type        = string
}

variable "create_managed_certificate" {
  description = "Whether to create ManagedCertificate resource in Kubernetes"
  type        = bool
  default     = true
}

variable "service_name" {
  description = "Name of the LiveKit Kubernetes service"
  type        = string
  default     = "livekit-livekit-server"
}

variable "service_port" {
  description = "Port of the LiveKit service"
  type        = number
  default     = 7880
}

################################################################################
# BackendConfig Settings
################################################################################

variable "websocket_timeout_sec" {
  description = "Timeout for WebSocket connections (seconds). LiveKit needs long-lived connections."
  type        = number
  default     = 36000  # 10 hours
}

variable "draining_timeout_sec" {
  description = "Connection draining timeout (seconds)"
  type        = number
  default     = 300
}

variable "health_check_port" {
  description = "Port for health checks"
  type        = number
  default     = 7880
}

variable "health_check_path" {
  description = "Path for health checks"
  type        = string
  default     = "/"
}

################################################################################
# FrontendConfig Settings
################################################################################

variable "enable_https_redirect" {
  description = "Whether to redirect HTTP to HTTPS"
  type        = bool
  default     = true
}
