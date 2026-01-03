################################################################################
# cert-manager Module Outputs
################################################################################

output "namespace" {
  description = "The namespace where cert-manager is installed"
  value       = var.create_namespace ? kubernetes_namespace.cert_manager[0].metadata[0].name : "cert-manager"
}

output "cluster_issuer_name" {
  description = "Name of the production ClusterIssuer"
  value       = var.create_cluster_issuer ? "letsencrypt-prod" : null
}

output "staging_cluster_issuer_name" {
  description = "Name of the staging ClusterIssuer"
  value       = var.create_cluster_issuer && var.create_staging_issuer ? "letsencrypt-staging" : null
}

output "turn_certificate_secret_name" {
  description = "Name of the Kubernetes secret containing TURN TLS certificate"
  value       = var.create_turn_certificate ? var.turn_certificate_secret_name : null
}

output "helm_release_name" {
  description = "Name of the Helm release"
  value       = helm_release.cert_manager.name
}

output "helm_release_version" {
  description = "Version of the Helm chart"
  value       = helm_release.cert_manager.version
}
