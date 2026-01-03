################################################################################
# Outputs
################################################################################

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

output "redis_auth_string" {
  description = "Redis AUTH string for LiveKit configuration"
  value       = module.memorystore.redis_auth_string
  sensitive   = true
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

################################################################################
# ArgoCD Outputs
################################################################################

output "argocd_namespace" {
  description = "ArgoCD namespace"
  value       = module.argocd.argocd_namespace
}

output "argocd_get_password_command" {
  description = "Command to get ArgoCD admin password"
  value       = module.argocd.get_admin_password_command
}

output "argocd_port_forward_command" {
  description = "Command to port-forward ArgoCD UI"
  value       = module.argocd.port_forward_command
}
