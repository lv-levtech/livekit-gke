output "livekit_service_account_email" {
  description = "Email of the LiveKit service account"
  value       = google_service_account.livekit.email
}

output "livekit_service_account_name" {
  description = "Name of the LiveKit service account"
  value       = google_service_account.livekit.name
}

output "cicd_service_account_email" {
  description = "Email of the CI/CD service account"
  value       = google_service_account.cicd.email
}

output "cicd_service_account_name" {
  description = "Name of the CI/CD service account"
  value       = google_service_account.cicd.name
}

output "workload_identity_annotation" {
  description = "Annotation to add to Kubernetes service account for Workload Identity"
  value       = "iam.gke.io/gcp-service-account=${google_service_account.livekit.email}"
}

output "certmanager_service_account_email" {
  description = "Email of the cert-manager service account"
  value       = google_service_account.certmanager.email
}

output "certmanager_workload_identity_annotation" {
  description = "Annotation to add to cert-manager service account for Workload Identity"
  value       = "iam.gke.io/gcp-service-account=${google_service_account.certmanager.email}"
}
