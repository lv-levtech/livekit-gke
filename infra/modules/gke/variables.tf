variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region"
  type        = string
  default     = "asia-northeast1"
}

variable "zone" {
  description = "GCP Zone for zonal cluster (e.g., asia-northeast1-a)"
  type        = string
  default     = null  # If null, uses regional cluster
}

variable "environment" {
  description = "Environment name (dev, stg, prd)"
  type        = string
}

variable "cluster_name" {
  description = "Name of the GKE cluster"
  type        = string
  default     = "livekit-cluster"
}

variable "vpc_name" {
  description = "Name of the VPC network"
  type        = string
}

variable "subnet_name" {
  description = "Name of the subnet"
  type        = string
}

variable "pods_secondary_range_name" {
  description = "Name of the secondary range for pods"
  type        = string
  default     = "pods"
}

variable "services_secondary_range_name" {
  description = "Name of the secondary range for services"
  type        = string
  default     = "services"
}

variable "node_machine_type" {
  description = "Machine type for GKE nodes (c2-standard-8 recommended for LiveKit)"
  type        = string
  default     = "c2-standard-8"
}

variable "min_node_count" {
  description = "Minimum number of nodes in the node pool"
  type        = number
  default     = 1
}

variable "max_node_count" {
  description = "Maximum number of nodes in the node pool"
  type        = number
  default     = 10
}

variable "initial_node_count" {
  description = "Initial number of nodes in the node pool"
  type        = number
  default     = 1
}

variable "disk_size_gb" {
  description = "Disk size in GB for each node"
  type        = number
  default     = 100
}

variable "disk_type" {
  description = "Disk type for each node"
  type        = string
  default     = "pd-ssd"
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = null # Use default version
}

variable "release_channel" {
  description = "Release channel for GKE cluster"
  type        = string
  default     = "REGULAR"
}

variable "enable_workload_identity" {
  description = "Enable Workload Identity"
  type        = bool
  default     = true
}

variable "network_tags" {
  description = "Network tags for GKE nodes"
  type        = list(string)
  default     = ["livekit-server"]
}
