## environments/commit-dev/main-11-psc-attachment.tf

###### ###### ###### ###### ###### ###### ###### ###### ######
### Private Service Connect (PSC) - Attachment ###
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

# Fetch the Kubernetes Service data to extract the system UID of Traefik
data "kubernetes_service" "traefik" {
  metadata {
    name      = "traefik-reverse-proxy"
    namespace = "traefik-reverse-proxy"
  }
}

locals {
  traefik_service_uid     = replace(data.kubernetes_service.traefik.metadata[0].uid, "-", "")
  traefik_forwarding_rule = "a${substr(local.traefik_service_uid, 0, 31)}"
  traefik_service_ilb_ip  = try(data.kubernetes_service.traefik.status[0].load_balancer[0].ingress[0].ip, null)
  psc_nat_subnet_name     = "${var.env_name_short}-psc-nat-subnet"
  psc_nat_subnet_key      = "${var.gcp_region}/${local.psc_nat_subnet_name}"
}

# Find the automatically created forwarding rule for the Traefik Internal
# Passthrough Network Load Balancer.
data "google_compute_forwarding_rule" "traefik_ilb" {
  provider = google.project_b
  project  = var.gcp_project_b_id
  region   = var.gcp_region
  name     = local.traefik_forwarding_rule
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
  nat_subnets = [module.vpc_b.subnets[local.psc_nat_subnet_key].self_link]

  lifecycle {
    precondition {
      condition     = data.google_compute_forwarding_rule.traefik_ilb.load_balancing_scheme == "INTERNAL"
      error_message = "The Traefik forwarding rule must be an internal load balancer forwarding rule."
    }

    precondition {
      condition     = data.google_compute_forwarding_rule.traefik_ilb.ip_protocol == "TCP"
      error_message = "The Traefik forwarding rule must use TCP for PSC service attachment."
    }

    precondition {
      condition     = try(data.google_compute_forwarding_rule.traefik_ilb.allow_global_access, false) == true
      error_message = "The Traefik forwarding rule must have allow_global_access enabled before it can back a global external Application Load Balancer through a PSC NEG."
    }

    precondition {
      condition     = local.traefik_service_ilb_ip == null || data.google_compute_forwarding_rule.traefik_ilb.ip_address == local.traefik_service_ilb_ip
      error_message = "The Traefik forwarding rule IP must match the Kubernetes Service load balancer IP."
    }
  }
}

################################################################################
# Outputs: Export URI for use on Project A
################################################################################

output "psc_service_attachment_uri" {
  value       = google_compute_service_attachment.traefik_psc_attachment.id
  description = "The URI of the Service Attachment to be used by the Endpoint in Project A."
}
