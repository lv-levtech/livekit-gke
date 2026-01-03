output "api_key_secret_id" {
  description = "Secret ID for LiveKit API Key"
  value       = google_secret_manager_secret.api_key.secret_id
}

output "api_key_secret_name" {
  description = "Full resource name for LiveKit API Key secret"
  value       = google_secret_manager_secret.api_key.name
}

output "api_secret_secret_id" {
  description = "Secret ID for LiveKit API Secret"
  value       = google_secret_manager_secret.api_secret.secret_id
}

output "api_secret_secret_name" {
  description = "Full resource name for LiveKit API Secret"
  value       = google_secret_manager_secret.api_secret.name
}

# For External Secrets Operator
output "external_secrets_config" {
  description = "Configuration for External Secrets Operator"
  value = {
    api_key_ref    = "projects/${var.project_id}/secrets/${google_secret_manager_secret.api_key.secret_id}/versions/latest"
    api_secret_ref = "projects/${var.project_id}/secrets/${google_secret_manager_secret.api_secret.secret_id}/versions/latest"
  }
}
