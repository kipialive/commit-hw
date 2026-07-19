## environments/commit-dev/main-11-psc-attachment.tf

###### ###### ###### ###### ###### ###### ###### ###### ######
### Private Service Connect (PSC) ###
###### ###### ###### ###### ###### ###### ###### ###### ######

/*
# This manifest orchestrates the cross-perimeter connectivity by publishing the 
# internal GKE Traefik load balancer via a Private Service Connect (PSC) Service Attachment.
# It automatically maps the Traefik ILB target forwarding rule to the dedicated PSC NAT 
# subnet within VPC B, enabling secure internal data flow from Project A to Project B.
*/

################################################################################
# Project B: Private Service Connect (PSC) Service Attachment for Traefik
################################################################################

# Find the automatically created Forwarding Rule for the Traefik ILB.
# GKE names forwarding rules using the format: "a" + md5 hash of the K8s Service UID without hyphens.
data "google_compute_forwarding_rule" "traefik_ilb" {
  provider = google.project_b
  project  = var.gcp_project_b_id
  region   = var.gcp_region
  name     = "a${replace(data.kubernetes_service.traefik.metadata[0].uid, "-", "")}"

  # Delay evaluation until the Kubernetes service data is fully retrieved
  depends_on = [
    data.kubernetes_service.traefik
  ]
}

# Fetch the Kubernetes Service data to extract the system UID of Traefik
data "kubernetes_service" "traefik" {
  metadata {
    name      = "traefik-reverse-proxy"
    namespace = "traefik-reverse-proxy"
  }
}

# Publish the Internal Load Balancer across perimeters via Service Attachment
resource "google_compute_service_attachment" "traefik_psc_attachment" {
  provider              = google.project_b
  project               = var.gcp_project_b_id
  name                  = "${var.env_name_short}-traefik-psc-attachment"
  region                = var.gcp_region
  description           = "PSC Service Attachment for Traefik Ingress ILB in Project B"
  
  # Settings for automatically accepting connections from Project A
  connection_preference = "ACCEPT_AUTOMATIC"

  # Explicitly specify if PROXY protocol header is wrapped around the connection
  enable_proxy_protocol = false

  # Link the Service Attachment directly to the Traefik ILB Forwarding Rule
  target_service = data.google_compute_forwarding_rule.traefik_ilb.self_link

  # Reference the dedicated PSC NAT subnet created by the vpc_b module.
  # In the terraform-google-modules/network/google module, the subnets_self_links 
  # output returns an array where the PSC NAT subnet is the second element (index [1]).
  nat_subnets = [module.vpc_b.subnets_self_links[1]]
}

################################################################################
# Outputs: Export URI for use on Project A
################################################################################

output "psc_service_attachment_uri" {
  value       = google_compute_service_attachment.traefik_psc_attachment.id
  description = "The URI of the Service Attachment to be used by the Endpoint in Project A."
}