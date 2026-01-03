################################################################################
# Terraform Configuration
################################################################################

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 5.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
  }
}

################################################################################
# Provider Configuration
################################################################################

provider "google" {
  project = var.project_id
  region  = var.region
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
}

# AWS Provider for Route 53
provider "aws" {
  region  = "ap-northeast-1"
  profile = "lt-system-dev"
}

# Data source to get GKE cluster credentials
data "google_client_config" "default" {}

data "google_container_cluster" "primary" {
  name     = module.gke.cluster_name
  location = module.gke.cluster_location
  project  = var.project_id

  depends_on = [module.gke]
}

# Kubernetes Provider configured with GKE credentials
provider "kubernetes" {
  host                   = "https://${data.google_container_cluster.primary.endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(data.google_container_cluster.primary.master_auth[0].cluster_ca_certificate)
}

# Helm Provider configured with GKE credentials
provider "helm" {
  kubernetes {
    host                   = "https://${data.google_container_cluster.primary.endpoint}"
    token                  = data.google_client_config.default.access_token
    cluster_ca_certificate = base64decode(data.google_container_cluster.primary.master_auth[0].cluster_ca_certificate)
  }
}

################################################################################
# Local Variables
################################################################################

locals {
  environment = "dev"
}

################################################################################
# Network Module
################################################################################

module "network" {
  source = "../../modules/network"

  project_id   = var.project_id
  region       = var.region
  environment  = local.environment
  vpc_name     = "livekit-vpc"
  subnet_cidr  = "10.0.0.0/20"
  pods_cidr    = "10.1.0.0/16"
  services_cidr = "10.2.0.0/20"
}

################################################################################
# GKE Module
################################################################################

module "gke" {
  source = "../../modules/gke"

  project_id                    = var.project_id
  region                        = var.region
  zone                          = "${var.region}-a"  # Zonal cluster for cost savings
  environment                   = local.environment
  cluster_name                  = "livekit-cluster"
  vpc_name                      = module.network.vpc_name
  subnet_name                   = module.network.subnet_name
  pods_secondary_range_name     = module.network.pods_secondary_range_name
  services_secondary_range_name = module.network.services_secondary_range_name

  # Dev environment uses single node
  node_machine_type  = "c2-standard-4"
  min_node_count     = 1
  max_node_count     = 1
  initial_node_count = 1
}

################################################################################
# Memorystore Module
################################################################################

module "memorystore" {
  source = "../../modules/memorystore"

  project_id     = var.project_id
  region         = var.region
  environment    = local.environment
  instance_name  = "livekit-redis"
  tier           = "BASIC"
  memory_size_gb = 1
  vpc_network    = module.network.vpc_self_link

  depends_on = [module.network]
}

################################################################################
# DNS Module (Static IPs + Route 53)
################################################################################

module "dns" {
  source = "../../modules/dns"

  project_id      = var.project_id
  region          = var.region
  environment     = local.environment
  domain          = var.domain
  turn_domain     = var.turn_domain
  route53_zone_id = var.route53_zone_id
}

################################################################################
# IAM Module
################################################################################

module "iam" {
  source = "../../modules/iam"

  project_id                   = var.project_id
  environment                  = local.environment
  kubernetes_namespace         = "livekit"
  kubernetes_service_account   = "livekit-server"
  enable_secret_manager_access = true

  # Workload Identity requires GKE cluster to be created first
  depends_on = [module.gke]
}

################################################################################
# Secret Manager Module
################################################################################

module "secret_manager" {
  source = "../../modules/secret-manager"

  project_id         = var.project_id
  environment        = local.environment
  livekit_api_key    = var.livekit_api_key
  livekit_api_secret = var.livekit_api_secret
  secret_accessors   = ["serviceAccount:${module.iam.livekit_service_account_email}"]
}

################################################################################
# ArgoCD Module
################################################################################

module "argocd" {
  source = "../../modules/argocd"

  environment         = local.environment
  git_repo_url        = var.git_repo_url
  git_target_revision = var.git_target_revision

  # ArgoCD configuration
  argocd_version        = "5.51.6"
  argocd_insecure       = true
  bootstrap_app_of_apps = var.bootstrap_app_of_apps
  enable_notifications  = false

  depends_on = [module.gke]
}

################################################################################
# DEPRECATED: The following modules have been moved to ArgoCD management
# See: k8s/argocd/applications/ for the new ArgoCD Application definitions
################################################################################

# module "cert_manager" - Now managed by ArgoCD (k8s/argocd/applications/base/cert-manager.yaml)
# module "kubernetes_ingress" - Now managed by ArgoCD (k8s/cluster-resources/)
# module "external_secrets" - Now managed by ArgoCD (k8s/argocd/applications/base/external-secrets.yaml)
