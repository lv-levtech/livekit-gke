################################################################################
# GCP Cloud DNS - TURN Subdomain
# Manages the turn.*.levtech.org zone delegated from Route53
################################################################################

resource "google_dns_managed_zone" "turn" {
  project     = var.project_id
  name        = "turn-${var.environment}"
  dns_name    = "${var.turn_domain}."
  description = "TURN subdomain zone for ${var.environment} - delegated from Route53"
  visibility  = "public"

  dnssec_config {
    state = "off"
  }
}

################################################################################
# A Record for TURN Domain
################################################################################

resource "google_dns_record_set" "turn_a" {
  project      = var.project_id
  name         = google_dns_managed_zone.turn.dns_name
  type         = "A"
  ttl          = var.dns_ttl
  managed_zone = google_dns_managed_zone.turn.name
  rrdatas      = [google_compute_address.turn_ip.address]
}
