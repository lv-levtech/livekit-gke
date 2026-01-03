################################################################################
# Kubernetes Ingress Module Outputs
################################################################################

output "ingress_name" {
  description = "Name of the Ingress resource"
  value       = kubernetes_ingress_v1.livekit.metadata[0].name
}

output "backend_config_name" {
  description = "Name of the BackendConfig"
  value       = kubernetes_manifest.backend_config.manifest.metadata.name
}

output "frontend_config_name" {
  description = "Name of the FrontendConfig"
  value       = kubernetes_manifest.frontend_config.manifest.metadata.name
}

output "managed_certificate_name" {
  description = "Name of the ManagedCertificate"
  value       = var.create_managed_certificate ? kubernetes_manifest.managed_certificate[0].manifest.metadata.name : var.managed_certificate_name
}
