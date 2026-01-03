################################################################################
# Kubernetes Ingress Module for LiveKit
# Creates Ingress, BackendConfig for GKE HTTP(S) Load Balancer
################################################################################

terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }
}

################################################################################
# BackendConfig for WebSocket Support
# Required for long-lived WebSocket connections
################################################################################

resource "kubernetes_manifest" "backend_config" {
  manifest = {
    apiVersion = "cloud.google.com/v1"
    kind       = "BackendConfig"
    metadata = {
      name      = "livekit-backend-config"
      namespace = var.namespace
    }
    spec = {
      timeoutSec = var.websocket_timeout_sec
      connectionDraining = {
        drainingTimeoutSec = var.draining_timeout_sec
      }
      healthCheck = {
        type        = "HTTP"
        port        = var.health_check_port
        requestPath = var.health_check_path
      }
    }
  }
}

################################################################################
# Ingress Resource
# Uses GCE Ingress class with GKE Managed Certificate
################################################################################

resource "kubernetes_ingress_v1" "livekit" {
  metadata {
    name      = "livekit-ingress"
    namespace = var.namespace

    annotations = {
      "kubernetes.io/ingress.class"                 = "gce"
      "kubernetes.io/ingress.global-static-ip-name" = var.static_ip_name
      "networking.gke.io/managed-certificates"      = var.managed_certificate_name
      "networking.gke.io/v1beta1.FrontendConfig"    = kubernetes_manifest.frontend_config.manifest.metadata.name
    }
  }

  spec {
    default_backend {
      service {
        name = var.service_name
        port {
          number = var.service_port
        }
      }
    }

    rule {
      host = var.domain
      http {
        path {
          path      = "/*"
          path_type = "ImplementationSpecific"
          backend {
            service {
              name = var.service_name
              port {
                number = var.service_port
              }
            }
          }
        }
      }
    }
  }

  depends_on = [
    kubernetes_manifest.backend_config,
    kubernetes_manifest.frontend_config
  ]
}

################################################################################
# FrontendConfig for HTTPS Redirect
################################################################################

resource "kubernetes_manifest" "frontend_config" {
  manifest = {
    apiVersion = "networking.gke.io/v1beta1"
    kind       = "FrontendConfig"
    metadata = {
      name      = "livekit-frontend-config"
      namespace = var.namespace
    }
    spec = {
      redirectToHttps = {
        enabled = var.enable_https_redirect
      }
    }
  }
}

################################################################################
# GKE Managed Certificate
################################################################################

resource "kubernetes_manifest" "managed_certificate" {
  count = var.create_managed_certificate ? 1 : 0

  manifest = {
    apiVersion = "networking.gke.io/v1"
    kind       = "ManagedCertificate"
    metadata = {
      name      = var.managed_certificate_name
      namespace = var.namespace
    }
    spec = {
      domains = [var.domain]
    }
  }
}
