################################################################################
# GCS Backend Configuration
################################################################################

terraform {
  backend "gcs" {
    bucket = "lt-ai-roleplay-dev-terraform-state"
    prefix = "livekit/dev"
  }
}
