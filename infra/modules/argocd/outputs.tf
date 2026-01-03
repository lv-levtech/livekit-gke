################################################################################
# ArgoCD Module Outputs
################################################################################

output "argocd_namespace" {
  description = "ArgoCD namespace"
  value       = kubernetes_namespace.argocd.metadata[0].name
}

output "argocd_server_service" {
  description = "ArgoCD server service name"
  value       = "argocd-server"
}

output "get_admin_password_command" {
  description = "Command to get ArgoCD admin password"
  value       = "kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath=\"{.data.password}\" | base64 -d"
}

output "port_forward_command" {
  description = "Command to port-forward ArgoCD UI"
  value       = "kubectl port-forward svc/argocd-server -n argocd 8080:443"
}
