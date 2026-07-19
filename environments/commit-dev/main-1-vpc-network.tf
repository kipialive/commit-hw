## environments/commit-dev/main-1-vpc-network.tf
/*
###### ###### ###### ###### ######
### GCP VPC and Network ###
###### ###### ###### ###### ######

Based on source:: https://github.com/terraform-google-modules/terraform-google-network
# example # https://github.com/terraform-google-modules/terraform-google-network/tree/main/examples

*/

################################################################################
# Project A: VPC "A" with Network Infrastructure Module (Public Perimeter)
################################################################################

module "vpc_a" {
  source  = "terraform-google-modules/network/google"
  version = ">= 18.1.2"

  project_id   = var.gcp_project_a_id
  network_name = "${var.env_name_short}-vpc-a"
  routing_mode = "REGIONAL"

  subnets = [
    {
      subnet_name   = "${var.env_name_short}-subnet-a"
      subnet_ip     = var.vpc_a_subnet_cidr
      subnet_region = var.gcp_region
    }
  ]
}

################################################################################
# Project B: VPC "B" with Network Infrastructure Module (Internal Perimeter & GKE)
################################################################################

module "vpc_b" {
  source  = "terraform-google-modules/network/google"
  version = ">= 18.1.2"

  # Crucial: Passing the correct project and its corresponding alias provider
  project_id = var.gcp_project_b_id
  providers = {
    google = google.project_b
  }

  network_name = "${var.env_name_short}-vpc-b"
  routing_mode = "REGIONAL"

  # Defining the primary subnets inside VPC B
  subnets = [
    {
      subnet_name   = "${var.env_name_short}-subnet-b"
      subnet_ip     = var.vpc_b_subnet_cidr
      subnet_region = var.gcp_region
    },
    {
      subnet_name   = "${var.env_name_short}-psc-nat-subnet"
      subnet_ip     = var.vpc_b_psc_nat_cidr
      subnet_region = var.gcp_region
      purpose       = "PRIVATE_SERVICE_CONNECT"
    },
    {
      subnet_name   = "${var.env_name_short}-proxy-only-subnet"
      subnet_ip     = var.vpc_b_proxy_only_cidr
      subnet_region = var.gcp_region
      purpose       = "REGIONAL_MANAGED_PROXY"
      role          = "ACTIVE"
    }
  ]

  # Defining secondary ranges specifically for GKE Pods and Services
  secondary_ranges = {
    "${var.env_name_short}-subnet-b" = [
      {
        range_name    = "gke-pods-range"
        ip_cidr_range = var.gke_pod_cidr_range
      },
      {
        range_name    = "gke-services-range"
        ip_cidr_range = var.gke_service_cidr_range
      }
    ]
  }
}

# ---------------------------------------------------------------
# Cloud Router for VPC B to handle NAT gateway routing
# Data flow: GKE Nodes (VPC B) → Cloud Router → Cloud NAT
# ---------------------------------------------------------------
resource "google_compute_router" "router_b" {
  # Use standard single provider argument for native resources
  provider = google.project_b

  name    = "${var.env_name_short}-vpc-b-router"
  region  = var.gcp_region
  project = var.gcp_project_b_id
  network = module.vpc_b.network_name # Automatically pulls the network name from module output
}

# ---------------------------------------------------------------
# Cloud NAT Gateway to grant private GKE nodes internet access
# Access path: Private Subnet B → Cloud NAT → External Repositories (Quay.io)
# ---------------------------------------------------------------
resource "google_compute_router_nat" "nat_b" {
  # Use standard single provider argument for native resources
  provider = google.project_b

  name                               = "${var.env_name_short}-vpc-b-nat"
  router                             = google_compute_router.router_b.name
  region                             = google_compute_router.router_b.region
  project                            = var.gcp_project_b_id
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}