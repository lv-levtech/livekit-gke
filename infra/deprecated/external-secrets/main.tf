################################################################################
# External Secrets Operator Module
# Syncs secrets from GCP Secret Manager to Kubernetes Secrets
################################################################################

terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }
}

################################################################################
# External Secrets Operator Namespace
################################################################################

resource "kubernetes_namespace" "external_secrets" {
  count = var.create_namespace ? 1 : 0

  metadata {
    name = "external-secrets"

    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
}

################################################################################
# External Secrets Operator Helm Release
################################################################################

resource "helm_release" "external_secrets" {
  name       = "external-secrets"
  repository = "https://charts.external-secrets.io"
  chart      = "external-secrets"
  version    = var.eso_version
  namespace  = var.create_namespace ? kubernetes_namespace.external_secrets[0].metadata[0].name : "external-secrets"

  set {
    name  = "installCRDs"
    value = "true"
  }

  # Service account for Workload Identity
  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = var.service_account_name
  }

  set {
    name  = "serviceAccount.annotations.iam\\.gke\\.io/gcp-service-account"
    value = var.gcp_service_account_email
  }

  # Resource limits
  set {
    name  = "resources.requests.cpu"
    value = var.resources.requests.cpu
  }

  set {
    name  = "resources.requests.memory"
    value = var.resources.requests.memory
  }

  set {
    name  = "resources.limits.cpu"
    value = var.resources.limits.cpu
  }

  set {
    name  = "resources.limits.memory"
    value = var.resources.limits.memory
  }

  depends_on = [kubernetes_namespace.external_secrets]
}

################################################################################
# ClusterSecretStore for GCP Secret Manager
################################################################################

resource "kubernetes_manifest" "cluster_secret_store" {
  count = var.create_cluster_secret_store ? 1 : 0

  manifest = {
    apiVersion = "external-secrets.io/v1beta1"
    kind       = "ClusterSecretStore"
    metadata = {
      name = "gcp-secret-manager"
    }
    spec = {
      provider = {
        gcpsm = {
          projectID = var.project_id
        }
      }
    }
  }

  depends_on = [helm_release.external_secrets]
}

################################################################################
# ExternalSecret for LiveKit API Keys
################################################################################

resource "kubernetes_manifest" "livekit_api_keys" {
  count = var.create_livekit_secrets ? 1 : 0

  manifest = {
    apiVersion = "external-secrets.io/v1beta1"
    kind       = "ExternalSecret"
    metadata = {
      name      = "livekit-server-keys"
      namespace = var.livekit_namespace
    }
    spec = {
      refreshInterval = var.refresh_interval
      secretStoreRef = {
        name = "gcp-secret-manager"
        kind = "ClusterSecretStore"
      }
      target = {
        name = "livekit-server-keys"
        template = {
          type = "Opaque"
          data = {
            "keys.yaml" = <<-EOT
              {{ .api_key }}: {{ .api_secret }}
            EOT
          }
        }
      }
      data = [
        {
          secretKey = "api_key"
          remoteRef = {
            key = var.api_key_secret_name
          }
        },
        {
          secretKey = "api_secret"
          remoteRef = {
            key = var.api_secret_secret_name
          }
        }
      ]
    }
  }

  depends_on = [kubernetes_manifest.cluster_secret_store]
}
