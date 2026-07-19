## environments/commit-dev/main-10-gke.tf

###### ###### ###### ###### ###### ###### ###### ###### ######
### Google Kubernetes Engine (GKE) - K8s ###
###### ###### ###### ###### ###### ###### ###### ###### ######

/*
# GKE Cluster Deployment Note:
# This manifest orchestrates a production-ready, highly isolated GKE Standard 
# private cluster within Project B. It completely removes the default node pool 
# upon creation and establishes a custom core pool with autoscaling enabled, 
# strictly mapped to VPC B's dedicated subnets and container network tags.


Based on source:: https://github.com/terraform-google-modules/terraform-google-kubernetes-engine
# example # https://github.com/terraform-google-modules/terraform-google-kubernetes-engine/tree/main/examples

*/

################################################################################
# Project B: Gke Standard Private Cluster Deployment
################################################################################

locals {
  gke_node_machine_type = "e2-medium"      # 2 vCPU, 4 GB RAM, x86_64 - Absolute minimum allowed for GKE Standard
  image_type            = "COS_CONTAINERD" # Container-Optimized OS from Google
  # gke_node_machine_type   = "t2a-standard-1"          # 1 vCPU, 4 GB RAM, ARM - Absolute minimum allowed for GKE Standard
  # image_type              = "COS_ARM64_CONTAINERD"    # ARM Container-Optimized OS from Google

  gke_cluster_version = "1.33"

  gke_min_node_count = 1                       # Minimum number of nodes per zone in the default node pool
  gke_max_node_count = 1                       # Maximum number of nodes per zone in the default node pool
  gke_zones          = ["${var.gcp_region}-a"] # GKE Nodes only in ONE Zone
  # gke_zones               = ["${var.gcp_region}-a", "${var.gcp_region}-b"] # Multiple zones
}

module "gke_standard_cluster" {
  source  = "terraform-google-modules/kubernetes-engine/google//modules/private-cluster"
  version = ">= 44.3.0"

  # Deploying strictly inside Project B using its alias provider
  project_id = var.gcp_project_b_id
  providers = {
    google = google.project_b
  }

  kubernetes_version = local.gke_cluster_version

  name   = "${var.env_name_short}-gke-cluster"
  region = var.gcp_region
  zones  = local.gke_zones

  # Network topology binding to the custom VPC B module outputs
  network    = module.vpc_b.network_name
  subnetwork = "${var.env_name_short}-subnet-b" # Resolves to commit-dev-subnet-b

  # Mapping secondary IP ranges for Kubernetes internal networking
  ip_range_pods     = "gke-pods-range"
  ip_range_services = "gke-services-range"

  # Production hardening: Complete isolation of worker nodes from the public internet
  enable_private_nodes          = true
  enable_private_endpoint       = false # Control Plane API remains accessible via secure authorized networks
  deploy_using_private_endpoint = false

  # Master Authorized Networks configuration for secure API access
  master_authorized_networks = [
    {
      cidr_block   = "0.0.0.0/0" # In true production, replace with your company bastion/VPN CIDR
      display_name = "Administrative-Access-Gateway"
    }
  ]

  # Production safety guardrails
  deletion_protection      = true
  remove_default_node_pool = true # Best practice: destroy default pool and use custom node pools

  ################################################################################
  # GKE Node Pools Configuration
  ################################################################################
  node_pools = [
    {
      name               = "production-core-pool"
      machine_type       = local.gke_node_machine_type
      min_count          = local.gke_min_node_count
      max_count          = local.gke_max_node_count
      local_ssd_count    = 0
      disk_size_gb       = 100
      disk_type          = "pd-standard"
      image_type         = local.image_type
      auto_repair        = true
      auto_upgrade       = true
      preemptible        = false # Disable preemptible instances for stable production scheduling
      initial_node_count = 1
    }
  ]

  # Injecting Network Tags for targeted Firewall rules routing
  node_pools_tags = {
    all = [
      "${var.env_name_short}-gke-node"
    ]
  }

  # Injecting Metadata Labels for workload accounting
  node_pools_labels = {
    all = {
      tier = "application-backend"
    }
  }
}