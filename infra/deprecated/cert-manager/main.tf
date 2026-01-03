################################################################################
# cert-manager Module
# Installs cert-manager and creates ClusterIssuer for Let's Encrypt
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
# cert-manager Namespace
################################################################################

resource "kubernetes_namespace" "cert_manager" {
  count = var.create_namespace ? 1 : 0

  metadata {
    name = "cert-manager"

    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
}

################################################################################
# cert-manager Helm Release
################################################################################

resource "helm_release" "cert_manager" {
  name       = "cert-manager"
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  version    = var.cert_manager_version
  namespace  = var.create_namespace ? kubernetes_namespace.cert_manager[0].metadata[0].name : "cert-manager"

  set {
    name  = "installCRDs"
    value = "true"
  }

  set {
    name  = "global.leaderElection.namespace"
    value = "cert-manager"
  }

  # Enable Prometheus metrics
  set {
    name  = "prometheus.enabled"
    value = var.enable_prometheus_metrics
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

  depends_on = [kubernetes_namespace.cert_manager]
}

################################################################################
# ClusterIssuer for Let's Encrypt
################################################################################

resource "kubernetes_manifest" "cluster_issuer_prod" {
  count = var.create_cluster_issuer ? 1 : 0

  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name = "letsencrypt-prod"
    }
    spec = {
      acme = {
        server = "https://acme-v02.api.letsencrypt.org/directory"
        email  = var.acme_email
        privateKeySecretRef = {
          name = "letsencrypt-prod-account-key"
        }
        solvers = [
          {
            http01 = {
              ingress = {
                class = "gce"
              }
            }
          }
        ]
      }
    }
  }

  depends_on = [helm_release.cert_manager]
}

resource "kubernetes_manifest" "cluster_issuer_staging" {
  count = var.create_cluster_issuer && var.create_staging_issuer ? 1 : 0

  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name = "letsencrypt-staging"
    }
    spec = {
      acme = {
        server = "https://acme-staging-v02.api.letsencrypt.org/directory"
        email  = var.acme_email
        privateKeySecretRef = {
          name = "letsencrypt-staging-account-key"
        }
        solvers = [
          {
            http01 = {
              ingress = {
                class = "gce"
              }
            }
          }
        ]
      }
    }
  }

  depends_on = [helm_release.cert_manager]
}

################################################################################
# Certificate for TURN domain
################################################################################

resource "kubernetes_manifest" "turn_certificate" {
  count = var.create_turn_certificate ? 1 : 0

  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "Certificate"
    metadata = {
      name      = "turn-tls-cert"
      namespace = var.livekit_namespace
    }
    spec = {
      secretName = var.turn_certificate_secret_name
      issuerRef = {
        name = var.use_staging_issuer ? "letsencrypt-staging" : "letsencrypt-prod"
        kind = "ClusterIssuer"
      }
      dnsNames = [var.turn_domain]
    }
  }

  depends_on = [
    kubernetes_manifest.cluster_issuer_prod,
    kubernetes_manifest.cluster_issuer_staging
  ]
}
