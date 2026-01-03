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
  region = "ap-northeast-1"
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
  environment = "prd"
}

################################################################################
# Network Module
################################################################################

module "network" {
  source = "../../modules/network"

  project_id    = var.project_id
  region        = var.region
  environment   = local.environment
  vpc_name      = "livekit-vpc"
  subnet_cidr   = "10.20.0.0/20"
  pods_cidr     = "10.21.0.0/16"
  services_cidr = "10.22.0.0/20"
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

  # Production uses single node (can scale if needed)
  node_machine_type  = "c2-standard-8"
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
  tier           = "STANDARD_HA"  # High Availability for production
  memory_size_gb = 5
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
# cert-manager Module (TURN TLS Certificate)
################################################################################

module "cert_manager" {
  source = "../../modules/cert-manager"
  count  = var.enable_cert_manager ? 1 : 0

  acme_email                   = var.acme_email
  turn_domain                  = var.turn_domain
  turn_certificate_secret_name = "turn-tls-secret"
  livekit_namespace            = "livekit"
  create_staging_issuer        = false  # Production uses real Let's Encrypt

  depends_on = [module.gke]
}

################################################################################
# Kubernetes Ingress Module
################################################################################

module "kubernetes_ingress" {
  source = "../../modules/kubernetes-ingress"
  count  = var.enable_ingress_module ? 1 : 0

  namespace                = "livekit"
  domain                   = var.domain
  static_ip_name           = module.dns.livekit_ip_name
  managed_certificate_name = module.dns.managed_certificate_name
  service_name             = "livekit-livekit-server"

  depends_on = [module.gke, module.dns]
}

################################################################################
# External Secrets Operator Module
################################################################################

module "external_secrets" {
  source = "../../modules/external-secrets"
  count  = var.enable_external_secrets ? 1 : 0

  project_id                = var.project_id
  gcp_service_account_email = module.iam.livekit_service_account_email
  livekit_namespace         = "livekit"
  api_key_secret_name       = module.secret_manager.api_key_secret_id
  api_secret_secret_name    = module.secret_manager.api_secret_secret_id

  depends_on = [module.gke, module.iam, module.secret_manager]
}
