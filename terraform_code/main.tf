
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }


   backend "gcs" {
     bucket = "test-372004-terraform-state"
     prefix = "terraform/gke-cluster"
   }
}

# PROVIDER CONFIGURATION


provider "google" {
  project = var.project_id
  region  = var.region
  credentials = file("C:/Users/ASUS/Downloads/gcp-test-372004-9cf4a9428536.json")
}

# NETWORK: VPC + SUBNETS + NAT


resource "google_compute_network" "vpc" {
  name                    = var.network_name
  auto_create_subnetworks = false
}

# Public subnet (for bastion or ingress)
resource "google_compute_subnetwork" "public" {
  name          = "${var.network_name}-public"
  ip_cidr_range = "10.0.1.0/24"
  region        = var.region
  network       = google_compute_network.vpc.id
}

# Private subnet (for GKE nodes)
resource "google_compute_subnetwork" "private" {
  name                     = "${var.network_name}-private"
  ip_cidr_range            = "10.0.2.0/24"
  region                   = var.region
  network                  = google_compute_network.vpc.id
  private_ip_google_access = true
}

resource "google_compute_router" "router" {
  name    = "${var.network_name}-router"
  network = google_compute_network.vpc.id
  region  = var.region
}

resource "google_compute_router_nat" "nat" {
  name                               = "${var.network_name}-nat"
  router                             = google_compute_router.router.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}

# IAM: SERVICE ACCOUNT FOR GKE NODES


resource "google_service_account" "gke_node_sa" {
  account_id   = var.gke_service_account
  display_name = "GKE Node Service Account"
}

# Assign required roles to the node service account
resource "google_project_iam_member" "gke_sa_roles" {
  for_each = toset([
    "roles/container.nodeServiceAccount",
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/storage.objectViewer"
  ])
  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.gke_node_sa.email}"
}




# GKE CLUSTER CONFIGURATION

resource "google_container_cluster" "primary" {
  name     = var.cluster_name
  location = var.region

  network    = google_compute_network.vpc.id
  subnetwork = google_compute_subnetwork.private.id

  remove_default_node_pool = true
  initial_node_count       = 1

  ip_allocation_policy {}

  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = "172.16.0.0/28"
  }

  release_channel {
    channel = "REGULAR"
  }

  vertical_pod_autoscaling {
    enabled = true
  }

  depends_on = [google_project_iam_member.gke_sa_roles]
}

resource "google_container_node_pool" "primary_nodes" {
  name       = "node-pool"
  location   = var.region
  cluster    = google_container_cluster.primary.name
  node_count = 2

  node_config {
    preemptible  = false
    machine_type = "e2-medium"
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
    service_account = google_service_account.gke_node_sa.email
    tags            = ["gke-node"]
    metadata = {
      disable-legacy-endpoints = "true"
    }
  }

  management {
    auto_upgrade = true
    auto_repair  = true
  }
}

# GCR (Google Container Registry)


# GCR is essentially a GCS bucket under the hood
resource "google_storage_bucket" "gcr_bucket" {
  name          = "${var.project_id}-artifacts"
  location      = var.region
  storage_class = "STANDARD"
  uniform_bucket_level_access = true
}

resource "google_storage_bucket_iam_member" "gcr_access" {
  bucket = google_storage_bucket.gcr_bucket.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.gke_node_sa.email}"
}

# OUTPUTS


output "vpc_name" {
  value = google_compute_network.vpc.name
}

output "gke_cluster_name" {
  value = google_container_cluster.primary.name
}

output "gke_endpoint" {
  value = google_container_cluster.primary.endpoint
}

output "gcr_bucket_name" {
  value = google_storage_bucket.gcr_bucket.name
}
