################################################################################
# ArgoCD Bootstrap Module
# Installs ArgoCD and configures initial App of Apps
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
# ArgoCD Namespace
################################################################################

resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"

    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      "app.kubernetes.io/part-of"    = "argocd"
    }
  }
}

################################################################################
# ArgoCD Helm Release
################################################################################

resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.argocd_version
  namespace  = kubernetes_namespace.argocd.metadata[0].name

  wait    = true
  timeout = 600

  values = [
    yamlencode({
      global = {
        domain = var.argocd_domain
      }

      configs = {
        params = {
          "server.insecure" = var.argocd_insecure
        }

        cm = {
          "resource.exclusions" = yamlencode([
            {
              apiGroups = ["cilium.io"]
              kinds     = ["CiliumIdentity"]
              clusters  = ["*"]
            }
          ])
        }
      }

      server = {
        extraArgs = var.argocd_insecure ? ["--insecure"] : []

        service = {
          type = "ClusterIP"
        }

        resources = {
          requests = {
            cpu    = "100m"
            memory = "128Mi"
          }
          limits = {
            cpu    = "500m"
            memory = "512Mi"
          }
        }
      }

      controller = {
        resources = {
          requests = {
            cpu    = "250m"
            memory = "256Mi"
          }
          limits = {
            cpu    = "1000m"
            memory = "1Gi"
          }
        }
      }

      repoServer = {
        resources = {
          requests = {
            cpu    = "100m"
            memory = "128Mi"
          }
          limits = {
            cpu    = "500m"
            memory = "512Mi"
          }
        }
      }

      applicationSet = {
        enabled = true
      }

      notifications = {
        enabled = var.enable_notifications
      }
    })
  ]

  depends_on = [kubernetes_namespace.argocd]
}

################################################################################
# AppProject for Infrastructure Components
################################################################################

resource "kubernetes_manifest" "infrastructure_project" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "AppProject"
    metadata = {
      name      = "infrastructure"
      namespace = "argocd"
    }
    spec = {
      description = "Infrastructure components (cert-manager, external-secrets, etc.)"

      sourceRepos = [var.git_repo_url, "*"]

      destinations = [
        {
          namespace = "*"
          server    = "https://kubernetes.default.svc"
        }
      ]

      clusterResourceWhitelist = [
        {
          group = "*"
          kind  = "*"
        }
      ]

      namespaceResourceWhitelist = [
        {
          group = "*"
          kind  = "*"
        }
      ]
    }
  }

  depends_on = [helm_release.argocd]
}

################################################################################
# AppProject for Applications
################################################################################

resource "kubernetes_manifest" "applications_project" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "AppProject"
    metadata = {
      name      = "applications"
      namespace = "argocd"
    }
    spec = {
      description = "Application workloads (LiveKit server, etc.)"

      sourceRepos = [
        var.git_repo_url,
        "https://helm.livekit.io",
        "*"
      ]

      destinations = [
        {
          namespace = "livekit"
          server    = "https://kubernetes.default.svc"
        }
      ]

      clusterResourceWhitelist = [
        {
          group = ""
          kind  = "Namespace"
        }
      ]

      namespaceResourceWhitelist = [
        {
          group = "*"
          kind  = "*"
        }
      ]
    }
  }

  depends_on = [helm_release.argocd]
}

################################################################################
# App of Apps Bootstrap Application
################################################################################

resource "kubernetes_manifest" "app_of_apps" {
  count = var.bootstrap_app_of_apps ? 1 : 0

  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "app-of-apps-${var.environment}"
      namespace = "argocd"
      labels = {
        "app.kubernetes.io/part-of" = "argocd"
        "environment"               = var.environment
      }
      finalizers = ["resources-finalizer.argocd.argoproj.io"]
    }
    spec = {
      project = "default"
      source = {
        repoURL        = var.git_repo_url
        targetRevision = var.git_target_revision
        path           = "k8s/argocd/applications/overlays/${var.environment}"
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = "argocd"
      }
      syncPolicy = {
        automated = {
          prune      = true
          selfHeal   = true
          allowEmpty = false
        }
        syncOptions = [
          "CreateNamespace=true",
          "PrunePropagationPolicy=foreground",
          "PruneLast=true"
        ]
        retry = {
          limit = 5
          backoff = {
            duration    = "5s"
            factor      = 2
            maxDuration = "3m"
          }
        }
      }
    }
  }

  depends_on = [helm_release.argocd]
}
