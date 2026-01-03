################################################################################
# DNS Module Variables
################################################################################

variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region"
  type        = string
  default     = "asia-northeast1"
}

variable "environment" {
  description = "Environment name (dev, stg, prd)"
  type        = string
}

variable "domain" {
  description = "Primary domain for LiveKit (e.g., livekit.example.com)"
  type        = string
}

variable "turn_domain" {
  description = "TURN domain for LiveKit (e.g., turn.example.com)"
  type        = string
}

################################################################################
# GKE Managed Certificate
################################################################################

variable "create_managed_certificate" {
  description = "Create GKE Managed Certificate for the primary domain"
  type        = bool
  default     = true
}

################################################################################
# AWS Route 53 Configuration
################################################################################

variable "route53_zone_id" {
  description = "AWS Route 53 Hosted Zone ID for DNS record management"
  type        = string
}

variable "dns_ttl" {
  description = "TTL for DNS records in seconds"
  type        = number
  default     = 300
}
