variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, stg, prd)"
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

variable "secret_accessors" {
  description = "List of IAM members who can access secrets"
  type        = list(string)
  default     = []
}
