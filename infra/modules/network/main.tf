################################################################################
# VPC Network
################################################################################
resource "google_compute_network" "vpc" {
  name                    = "${var.vpc_name}-${var.environment}"
  project                 = var.project_id
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
}

################################################################################
# Subnet
################################################################################
resource "google_compute_subnetwork" "subnet" {
  name          = "${var.vpc_name}-subnet-${var.environment}"
  project       = var.project_id
  region        = var.region
  network       = google_compute_network.vpc.id
  ip_cidr_range = var.subnet_cidr

  # Secondary ranges for GKE
  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = var.pods_cidr
  }

  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = var.services_cidr
  }

  private_ip_google_access = true
}

################################################################################
# Cloud Router (for Cloud NAT)
################################################################################
resource "google_compute_router" "router" {
  count   = var.enable_cloud_nat ? 1 : 0
  name    = "${var.vpc_name}-router-${var.environment}"
  project = var.project_id
  region  = var.region
  network = google_compute_network.vpc.id
}

################################################################################
# Cloud NAT
################################################################################
resource "google_compute_router_nat" "nat" {
  count                              = var.enable_cloud_nat ? 1 : 0
  name                               = "${var.vpc_name}-nat-${var.environment}"
  project                            = var.project_id
  router                             = google_compute_router.router[0].name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

################################################################################
# Firewall Rules for LiveKit
################################################################################

# Allow WebSocket API (7880)
resource "google_compute_firewall" "livekit_websocket" {
  name    = "livekit-allow-websocket-${var.environment}"
  project = var.project_id
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["7880"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["livekit-server"]

  description = "Allow LiveKit WebSocket API traffic"
}

# Allow WebRTC over TCP (7881)
resource "google_compute_firewall" "livekit_webrtc_tcp" {
  name    = "livekit-allow-webrtc-tcp-${var.environment}"
  project = var.project_id
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["7881"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["livekit-server"]

  description = "Allow LiveKit WebRTC over TCP traffic"
}

# Allow WebRTC media UDP (50000-60000)
resource "google_compute_firewall" "livekit_webrtc_udp" {
  name    = "livekit-allow-webrtc-udp-${var.environment}"
  project = var.project_id
  network = google_compute_network.vpc.name

  allow {
    protocol = "udp"
    ports    = ["50000-60000"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["livekit-server"]

  description = "Allow LiveKit WebRTC media UDP traffic"
}

# Allow TURN/TLS (5349)
resource "google_compute_firewall" "livekit_turn_tls" {
  name    = "livekit-allow-turn-tls-${var.environment}"
  project = var.project_id
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["5349", "3478"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["livekit-server"]

  description = "Allow LiveKit TURN/TLS traffic"
}

# Allow TURN/UDP + STUN (3478)
resource "google_compute_firewall" "livekit_turn_udp" {
  name    = "livekit-allow-turn-udp-${var.environment}"
  project = var.project_id
  network = google_compute_network.vpc.name

  allow {
    protocol = "udp"
    ports    = ["3478"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["livekit-server"]

  description = "Allow LiveKit TURN/UDP and STUN traffic"
}

# Allow Prometheus metrics (6789) - internal only
resource "google_compute_firewall" "livekit_prometheus" {
  name    = "livekit-allow-prometheus-${var.environment}"
  project = var.project_id
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["6789"]
  }

  source_ranges = [var.subnet_cidr]
  target_tags   = ["livekit-server"]

  description = "Allow Prometheus metrics scraping (internal)"
}

# Allow HTTP for TLS certificate issuance (80)
resource "google_compute_firewall" "livekit_http" {
  name    = "livekit-allow-http-${var.environment}"
  project = var.project_id
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["livekit-server"]

  description = "Allow HTTP for TLS certificate issuance"
}

# Allow HTTPS (443)
resource "google_compute_firewall" "livekit_https" {
  name    = "livekit-allow-https-${var.environment}"
  project = var.project_id
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["443"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["livekit-server"]

  description = "Allow HTTPS traffic"
}

# Allow internal communication
resource "google_compute_firewall" "internal" {
  name    = "livekit-allow-internal-${var.environment}"
  project = var.project_id
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "icmp"
  }

  source_ranges = [var.subnet_cidr, var.pods_cidr, var.services_cidr]

  description = "Allow internal communication within VPC"
}

################################################################################
# Private Service Connection (for Memorystore)
################################################################################
resource "google_compute_global_address" "private_ip_range" {
  name          = "livekit-private-ip-${var.environment}"
  project       = var.project_id
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.vpc.id
}

resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = google_compute_network.vpc.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_range.name]
}
