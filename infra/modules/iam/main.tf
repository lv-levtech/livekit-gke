################################################################################
# GCP Service Account for LiveKit
################################################################################

resource "google_service_account" "livekit" {
  account_id   = "livekit-server-${var.environment}"
  project      = var.project_id
  display_name = "LiveKit Server Service Account (${var.environment})"
  description  = "Service account for LiveKit server in ${var.environment} environment"
}

################################################################################
# Workload Identity Binding
# Allows Kubernetes service account to impersonate GCP service account
################################################################################

resource "google_service_account_iam_binding" "workload_identity" {
  service_account_id = google_service_account.livekit.name
  role               = "roles/iam.workloadIdentityUser"

  members = [
    "serviceAccount:${var.project_id}.svc.id.goog[${var.kubernetes_namespace}/${var.kubernetes_service_account}]",
    "serviceAccount:${var.project_id}.svc.id.goog[external-secrets/external-secrets]"
  ]
}

################################################################################
# IAM Roles for LiveKit Service Account
################################################################################

# Secret Manager access (for API keys)
resource "google_project_iam_member" "secret_accessor" {
  count   = var.enable_secret_manager_access ? 1 : 0
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.livekit.email}"
}

# Monitoring metrics writer (for custom metrics)
resource "google_project_iam_member" "monitoring_writer" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.livekit.email}"
}

# Logging writer
resource "google_project_iam_member" "logging_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.livekit.email}"
}

################################################################################
# CI/CD Service Account (for GitHub Actions)
################################################################################

resource "google_service_account" "cicd" {
  account_id   = "livekit-cicd-${var.environment}"
  project      = var.project_id
  display_name = "LiveKit CI/CD Service Account (${var.environment})"
  description  = "Service account for CI/CD pipeline in ${var.environment} environment"
}

# GKE cluster access
resource "google_project_iam_member" "cicd_gke_admin" {
  project = var.project_id
  role    = "roles/container.admin"
  member  = "serviceAccount:${google_service_account.cicd.email}"
}

# Storage admin (for Terraform state)
resource "google_project_iam_member" "cicd_storage_admin" {
  project = var.project_id
  role    = "roles/storage.admin"
  member  = "serviceAccount:${google_service_account.cicd.email}"
}

# Service account user (to impersonate other SAs)
resource "google_project_iam_member" "cicd_sa_user" {
  project = var.project_id
  role    = "roles/iam.serviceAccountUser"
  member  = "serviceAccount:${google_service_account.cicd.email}"
}

# Compute admin (for managing infrastructure)
resource "google_project_iam_member" "cicd_compute_admin" {
  project = var.project_id
  role    = "roles/compute.admin"
  member  = "serviceAccount:${google_service_account.cicd.email}"
}

# Redis admin (for Memorystore)
resource "google_project_iam_member" "cicd_redis_admin" {
  project = var.project_id
  role    = "roles/redis.admin"
  member  = "serviceAccount:${google_service_account.cicd.email}"
}

# DNS admin
resource "google_project_iam_member" "cicd_dns_admin" {
  project = var.project_id
  role    = "roles/dns.admin"
  member  = "serviceAccount:${google_service_account.cicd.email}"
}

# Secret Manager admin
resource "google_project_iam_member" "cicd_secret_admin" {
  project = var.project_id
  role    = "roles/secretmanager.admin"
  member  = "serviceAccount:${google_service_account.cicd.email}"
}

################################################################################
# cert-manager Service Account
# For DNS-01 ACME challenge with Cloud DNS (Workload Identity)
################################################################################

resource "google_service_account" "certmanager" {
  account_id   = "certmanager-${var.environment}"
  project      = var.project_id
  display_name = "cert-manager Service Account (${var.environment})"
  description  = "Service account for cert-manager DNS-01 challenge in ${var.environment} environment"
}

# Workload Identity binding for cert-manager
resource "google_service_account_iam_binding" "certmanager_workload_identity" {
  service_account_id = google_service_account.certmanager.name
  role               = "roles/iam.workloadIdentityUser"

  members = [
    "serviceAccount:${var.project_id}.svc.id.goog[cert-manager/cert-manager]"
  ]
}

# DNS Admin for cert-manager (required for DNS-01 challenge)
resource "google_project_iam_member" "certmanager_dns_admin" {
  project = var.project_id
  role    = "roles/dns.admin"
  member  = "serviceAccount:${google_service_account.certmanager.email}"
}
