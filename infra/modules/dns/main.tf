################################################################################
# DNS Module
# Manages Static IPs, GKE Managed Certificates, and AWS Route 53 DNS records
################################################################################

terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

################################################################################
# Static IP Address for LiveKit (HTTP(S) Load Balancer)
################################################################################

resource "google_compute_global_address" "livekit_ip" {
  name         = "livekit-ip-${var.environment}"
  project      = var.project_id
  address_type = "EXTERNAL"

  description = "Static IP for LiveKit ${var.environment} environment"

  lifecycle {
    prevent_destroy = true
  }
}

################################################################################
# Regional Static IP for TURN Server (Network Load Balancer)
################################################################################

resource "google_compute_address" "turn_ip" {
  name         = "livekit-turn-ip-${var.environment}"
  project      = var.project_id
  region       = var.region
  address_type = "EXTERNAL"

  description = "Static IP for LiveKit TURN server ${var.environment} environment"

  lifecycle {
    prevent_destroy = true
  }
}

################################################################################
# GKE Managed Certificate
# NOTE: This is for the primary domain only. TURN requires a separate cert
#       managed via cert-manager (Let's Encrypt)
################################################################################

resource "google_compute_managed_ssl_certificate" "livekit" {
  count   = var.create_managed_certificate ? 1 : 0
  name    = "livekit-cert-${var.environment}"
  project = var.project_id

  managed {
    domains = [var.domain]
  }
}

################################################################################
# AWS Route 53 DNS Records
################################################################################

# A Record for Main Domain (livekit.*.levtech.org)
resource "aws_route53_record" "main" {
  zone_id = var.route53_zone_id
  name    = var.domain
  type    = "A"
  ttl     = var.dns_ttl

  records = [google_compute_global_address.livekit_ip.address]
}

# NS Delegation for TURN Domain (turn.*.levtech.org)
# Delegates to GCP Cloud DNS for cert-manager DNS-01 challenge
resource "aws_route53_record" "turn_ns" {
  zone_id = var.route53_zone_id
  name    = var.turn_domain
  type    = "NS"
  ttl     = var.dns_ttl

  records = google_dns_managed_zone.turn.name_servers
}
