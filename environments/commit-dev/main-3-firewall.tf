## environments/commit-dev/main-3-firewall.tf

/*
# Firewall Configuration Note:
# This manifest establishes the core security boundaries for both perimeters.
# It configures explicit ingress rules for GCP Load Balancer health checks 
# into VPC A and VPC B, while opening full internal TCP/UDP/ICMP communication 
# within VPC B to ensure seamless GKE node-to-node and pod-to-pod networking.
*/

################################################################################
# Project A: Firewall Rules (Public Perimeter)
################################################################################

# Allow Google Cloud Ingress Load Balancer Health Checks into VPC A
resource "google_compute_firewall" "vpc_a_allow_health_checks" {
  name        = "${var.env_name_short}-vpc-a-allow-health-checks"
  project     = var.gcp_project_a_id
  network     = "${var.env_name_short}-vpc-a"
  description = "Allow incoming Google Cloud Load Balancing health checks into VPC A"

  direction     = "INGRESS"
  priority      = 1000
  source_ranges = ["35.191.0.0/16", "130.211.0.0/22"]

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }
}

################################################################################
# Project B: Firewall Rules (Internal Perimeter & GKE)
################################################################################

# Allow Google Cloud Internal Load Balancer Health Checks into VPC B GKE Nodes
resource "google_compute_firewall" "vpc_b_allow_health_checks" {
  provider    = google.project_b
  name        = "${var.env_name_short}-vpc-b-allow-health-checks"
  project     = var.gcp_project_b_id
  network     = "${var.env_name_short}-vpc-b"
  description = "Allow incoming Google Cloud Load Balancing health checks into VPC B GKE nodes"

  direction     = "INGRESS"
  priority      = 1000
  source_ranges = ["35.191.0.0/16", "130.211.0.0/22"]
  target_tags   = ["${var.env_name_short}-gke-node"]

  allow {
    protocol = "tcp"
  }
}

# Allow full internal communication within VPC B for GKE Pods, Services, and Nodes
resource "google_compute_firewall" "vpc_b_allow_internal" {
  provider    = google.project_b
  name        = "${var.env_name_short}-vpc-b-allow-internal"
  project     = var.gcp_project_b_id
  network     = "${var.env_name_short}-vpc-b"
  description = "Allow internal traffic between GKE nodes, pods, and services within VPC B"

  direction = "INGRESS"
  priority  = 1010
  source_ranges = [
    var.vpc_b_subnet_cidr,
    var.gke_pod_cidr_range,
    var.gke_service_cidr_range,
    var.vpc_b_psc_nat_cidr
  ]

  allow {
    protocol = "tcp"
  }
  allow {
    protocol = "udp"
  }
  allow {
    protocol = "icmp"
  }
}