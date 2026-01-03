################################################################################
# Secret Manager Secrets for LiveKit
################################################################################

# LiveKit API Key
resource "google_secret_manager_secret" "api_key" {
  secret_id = "livekit-api-key-${var.environment}"
  project   = var.project_id

  labels = {
    environment = var.environment
    managed_by  = "terraform"
    application = "livekit"
  }

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "api_key" {
  secret      = google_secret_manager_secret.api_key.id
  secret_data = var.livekit_api_key
}

# LiveKit API Secret
resource "google_secret_manager_secret" "api_secret" {
  secret_id = "livekit-api-secret-${var.environment}"
  project   = var.project_id

  labels = {
    environment = var.environment
    managed_by  = "terraform"
    application = "livekit"
  }

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "api_secret" {
  secret      = google_secret_manager_secret.api_secret.id
  secret_data = var.livekit_api_secret
}

################################################################################
# IAM Bindings for Secret Access
################################################################################

resource "google_secret_manager_secret_iam_member" "api_key_accessor" {
  count     = length(var.secret_accessors)
  project   = var.project_id
  secret_id = google_secret_manager_secret.api_key.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = var.secret_accessors[count.index]
}

resource "google_secret_manager_secret_iam_member" "api_secret_accessor" {
  count     = length(var.secret_accessors)
  project   = var.project_id
  secret_id = google_secret_manager_secret.api_secret.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = var.secret_accessors[count.index]
}
