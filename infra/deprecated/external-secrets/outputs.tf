################################################################################
# External Secrets Operator Module Outputs
################################################################################

output "namespace" {
  description = "The namespace where External Secrets Operator is installed"
  value       = var.create_namespace ? kubernetes_namespace.external_secrets[0].metadata[0].name : "external-secrets"
}

output "helm_release_name" {
  description = "Name of the Helm release"
  value       = helm_release.external_secrets.name
}

output "helm_release_version" {
  description = "Version of the Helm chart"
  value       = helm_release.external_secrets.version
}

output "cluster_secret_store_name" {
  description = "Name of the ClusterSecretStore"
  value       = var.create_cluster_secret_store ? "gcp-secret-manager" : null
}

output "livekit_secret_name" {
  description = "Name of the Kubernetes secret for LiveKit API keys"
  value       = var.create_livekit_secrets ? "livekit-server-keys" : null
}
