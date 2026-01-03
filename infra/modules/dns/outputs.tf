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

output "turn_dns_record_fqdn" {
  description = "FQDN of the TURN domain DNS record"
  value       = aws_route53_record.turn.fqdn
}
