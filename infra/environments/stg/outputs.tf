output "gke_cluster_name" {
  description = "GKE cluster name"
  value       = module.gke.cluster_name
}

output "gke_cluster_endpoint" {
  description = "GKE cluster endpoint"
  value       = module.gke.cluster_endpoint
  sensitive   = true
}

output "get_credentials_command" {
  description = "Command to get GKE credentials"
  value       = module.gke.get_credentials_command
}

output "redis_address" {
  description = "Redis address for LiveKit configuration"
  value       = module.memorystore.redis_address
}

output "livekit_static_ip" {
  description = "Static IP for LiveKit"
  value       = module.dns.livekit_ip_address
}

output "turn_static_ip" {
  description = "Static IP for TURN server"
  value       = module.dns.turn_ip_address
}

output "workload_identity_annotation" {
  description = "Annotation for Kubernetes service account"
  value       = module.iam.workload_identity_annotation
}
