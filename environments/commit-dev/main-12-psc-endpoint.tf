### environments/commit-dev/main-12-psc-endpoint.tf

###### ###### ###### ###### ###### ###### ###### ###### ######
### Private Service Connect (PSC) - Endpoint ###
###### ###### ###### ###### ###### ###### ###### ###### ######

/*
# This manifest establishes the consumer-side connection by deploying a Private 
# Service Connect (PSC) Endpoint within VPC A (Project A). It reserves a static 
# internal IP address and links a local forwarding rule directly to the published 
# Traefik Service Attachment URI exported from Project B.

# This endpoint organizes data flow within our network perimeter: 
# VPC A → PSC Endpoint → PSC Service Attachment → Traefik ILB (VPC B).
*/

################################################################################
# Project A: Private Service Connect (PSC) Endpoint Configuration
################################################################################

# Reserve a static internal IP address within VPC A for the PSC Endpoint
resource "google_compute_address" "traefik_psc_endpoint_ip" {
  project      = var.gcp_project_a_id
  name         = "${var.env_name_short}-traefik-psc-endpoint-ip"
  region       = var.gcp_region
  subnetwork   = module.vpc_a.subnets_self_links[0]
  address_type = "INTERNAL"
  purpose      = "GCE_ENDPOINT"
}

# Create the Forwarding Rule (Endpoint) linking VPC A to Project B's Service Attachment
resource "google_compute_forwarding_rule" "traefik_psc_endpoint" {
  project               = var.gcp_project_a_id
  name                  = "${var.env_name_short}-traefik-psc-endpoint"
  region                = var.gcp_region
  network               = module.vpc_a.network_self_link
  target                = google_compute_service_attachment.traefik_psc_attachment.id
  load_balancing_scheme = ""

  # Bind the reserved static internal IP address
  ip_address            = google_compute_address.traefik_psc_endpoint_ip.id
}

################################################################################
# Outputs
################################################################################

output "psc_endpoint_ip" {
  value       = google_compute_address.traefik_psc_endpoint_ip.address
  description = "The internal IP address allocated for the Traefik PSC Endpoint in VPC A."
}