################################################################################
# Cloud Memorystore for Redis
# Used by LiveKit for distributed mode (multi-node routing)
################################################################################

resource "google_redis_instance" "redis" {
  name           = "${var.instance_name}-${var.environment}"
  project        = var.project_id
  region         = var.region
  tier           = var.tier
  memory_size_gb = var.memory_size_gb
  redis_version  = var.redis_version

  # Network configuration
  authorized_network = var.vpc_network
  connect_mode       = "PRIVATE_SERVICE_ACCESS"

  # Authentication
  auth_enabled = var.auth_enabled

  # Transit encryption
  transit_encryption_mode = var.transit_encryption_mode

  # Maintenance window
  maintenance_policy {
    weekly_maintenance_window {
      day = var.maintenance_window_day == 1 ? "MONDAY" : var.maintenance_window_day == 2 ? "TUESDAY" : var.maintenance_window_day == 3 ? "WEDNESDAY" : var.maintenance_window_day == 4 ? "THURSDAY" : var.maintenance_window_day == 5 ? "FRIDAY" : var.maintenance_window_day == 6 ? "SATURDAY" : "SUNDAY"
      start_time {
        hours   = var.maintenance_window_hour
        minutes = 0
        seconds = 0
        nanos   = 0
      }
    }
  }

  # Labels
  labels = {
    environment = var.environment
    managed_by  = "terraform"
    application = "livekit"
  }

  # Persistence configuration (for STANDARD_HA tier)
  dynamic "persistence_config" {
    for_each = var.tier == "STANDARD_HA" ? [1] : []
    content {
      persistence_mode    = "RDB"
      rdb_snapshot_period = "TWELVE_HOURS"
    }
  }

  lifecycle {
    prevent_destroy = false
  }
}
