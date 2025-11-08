
# VARIABLES DEFINITION

variable "project_id" {
  description = "The GCP Project ID to deploy resources into"
  type        = string
  default = "gcp-test-372004"
}

variable "region" {
  description = "Region where resources will be deployed"
  type        = string
  default     = "us-central1"
}

variable "network_name" {
  description = "Name of the VPC network"
  type        = string
  default     = "devops-vpc"
}

variable "cluster_name" {
  description = "Name of the GKE cluster"
  type        = string
  default     = "gke-cluster"
}

variable "gke_service_account" {
  description = "Name of the service account for GKE nodes"
  type        = string
  default     = "gke-node-sa"
}
