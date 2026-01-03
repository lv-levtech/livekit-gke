################################################################################
# DNS Module Outputs
################################################################################

output "livekit_ip_address" {
  description = "The static IP address for LiveKit"
  value       = google_compute_global_address.livekit_ip.address
}

output "livekit_ip_name" {
  description = "The name of the static IP address for LiveKit"
  value       = google_compute_global_address.livekit_ip.name
}

output "turn_ip_address" {
  description = "The static IP address for TURN server"
  value       = google_compute_address.turn_ip.address
}

output "turn_ip_name" {
  description = "The name of the static IP address for TURN server"
  value       = google_compute_address.turn_ip.name
}

output "managed_certificate_name" {
  description = "The name of the managed SSL certificate"
  value       = var.create_managed_certificate ? google_compute_managed_ssl_certificate.livekit[0].name : null
}

output "managed_certificate_id" {
  description = "The ID of the managed SSL certificate"
  value       = var.create_managed_certificate ? google_compute_managed_ssl_certificate.livekit[0].id : null
}

################################################################################
# Route 53 Outputs
################################################################################

output "main_dns_record_fqdn" {
  description = "FQDN of the main domain DNS record"
  value       = aws_route53_record.main.fqdn
}

output "turn_ns_record_fqdn" {
  description = "FQDN of the TURN NS delegation record"
  value       = aws_route53_record.turn_ns.fqdn
}

################################################################################
# Cloud DNS Outputs
################################################################################

output "cloud_dns_zone_name" {
  description = "Cloud DNS zone name for TURN subdomain"
  value       = google_dns_managed_zone.turn.name
}

output "cloud_dns_name_servers" {
  description = "Cloud DNS name servers for TURN subdomain"
  value       = google_dns_managed_zone.turn.name_servers
}

output "turn_dns_record_fqdn" {
  description = "FQDN of the TURN domain A record in Cloud DNS"
  value       = trimsuffix(google_dns_record_set.turn_a.name, ".")
}
