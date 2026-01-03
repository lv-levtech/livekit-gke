################################################################################
# GKE Cluster
# NOTE: LiveKit requires Standard cluster (not Autopilot) and Public cluster
#       (not Private) due to host networking and WebRTC requirements
#
# Zonal vs Regional:
# - Zonal cluster: Single zone, lower cost, suitable for dev/small deployments
# - Regional cluster: Multi-zone control plane, higher availability for production
################################################################################

locals {
  # Use zone if specified, otherwise use region (regional cluster)
  cluster_location = var.zone != null ? var.zone : var.region
}

resource "google_container_cluster" "cluster" {
  name     = "${var.cluster_name}-${var.environment}"
  project  = var.project_id
  location = local.cluster_location

  # We can't create a cluster with no node pool defined, but we want to only use
  # separately managed node pools. So we create the smallest possible default
  # node pool and immediately delete it.
  remove_default_node_pool = true
  initial_node_count       = 1

  network    = var.vpc_name
  subnetwork = var.subnet_name

  # IP allocation policy for VPC-native cluster
  ip_allocation_policy {
    cluster_secondary_range_name  = var.pods_secondary_range_name
    services_secondary_range_name = var.services_secondary_range_name
  }

  # Release channel
  release_channel {
    channel = var.release_channel
  }

  # Workload Identity
  dynamic "workload_identity_config" {
    for_each = var.enable_workload_identity ? [1] : []
    content {
      workload_pool = "${var.project_id}.svc.id.goog"
    }
  }

  # Addons configuration
  addons_config {
    http_load_balancing {
      disabled = false
    }
    horizontal_pod_autoscaling {
      disabled = false
    }
    gce_persistent_disk_csi_driver_config {
      enabled = true
    }
  }

  # Maintenance window (daily 4-hour window to meet GKE's 32-day requirement)
  maintenance_policy {
    recurring_window {
      start_time = "2024-01-01T17:00:00Z" # 2:00 AM JST
      end_time   = "2024-01-01T21:00:00Z" # 6:00 AM JST
      recurrence = "FREQ=DAILY"
    }
  }

  # Logging and monitoring
  logging_service    = "logging.googleapis.com/kubernetes"
  monitoring_service = "monitoring.googleapis.com/kubernetes"

  # Network policy
  network_policy {
    enabled  = true
    provider = "CALICO"
  }

  # Binary authorization (disabled for simplicity)
  binary_authorization {
    evaluation_mode = "DISABLED"
  }

  # Deletion protection (enable in production)
  deletion_protection = var.environment == "prd" ? true : false

  # Resource labels
  resource_labels = {
    environment = var.environment
    managed_by  = "terraform"
    application = "livekit"
  }

  lifecycle {
    ignore_changes = [
      # Ignore changes to node pool as we manage it separately
      node_pool,
      initial_node_count,
    ]
  }
}

################################################################################
# Node Pool for LiveKit
# NOTE: LiveKit requires host networking, so only 1 pod per node is possible
################################################################################

resource "google_container_node_pool" "livekit_nodes" {
  name     = "livekit-node-pool"
  project  = var.project_id
  location = local.cluster_location
  cluster  = google_container_cluster.cluster.name

  initial_node_count = var.initial_node_count

  # Autoscaling configuration
  autoscaling {
    min_node_count = var.min_node_count
    max_node_count = var.max_node_count
  }

  # Node management
  management {
    auto_repair  = true
    auto_upgrade = true
  }

  # Upgrade settings for graceful upgrades
  upgrade_settings {
    max_surge       = 1
    max_unavailable = 0
    strategy        = "SURGE"
  }

  node_config {
    machine_type = var.node_machine_type
    disk_size_gb = var.disk_size_gb
    disk_type    = var.disk_type

    # Use Container-Optimized OS
    image_type = "COS_CONTAINERD"

    # OAuth scopes
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]

    # Network tags for firewall rules
    tags = var.network_tags

    # Labels
    labels = {
      environment = var.environment
      node_pool   = "livekit"
    }

    # Workload Identity metadata
    dynamic "workload_metadata_config" {
      for_each = var.enable_workload_identity ? [1] : []
      content {
        mode = "GKE_METADATA"
      }
    }

    # Shielded instance config
    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }

    # Metadata
    metadata = {
      disable-legacy-endpoints = "true"
    }
  }

  lifecycle {
    ignore_changes = [
      # Ignore changes that might be set by autoscaling
      initial_node_count,
    ]
  }
}
