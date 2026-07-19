## environments/commit-dev/main-14-external-lb-armor.tf

###### ###### ###### ###### ###### ###### ###### ###### ######
### External HTTPS Load Balancer -with- Google Cloud Armor ###
###### ###### ###### ###### ###### ###### ###### ###### ######

/*

Based on source:: https://registry.terraform.io/modules/terraform-google-modules/lb-http/google/latest
                  https://github.com/terraform-google-modules/terraform-google-lb-http/tree/v14.2.0
# example # https://github.com/terraform-google-modules/terraform-google-lb-http/tree/v14.2.0/examples

# This manifest orchestrates the public perimeter security and ingress routing within Project A.
# It configures a Google Cloud Armor security policy with custom WAF rules, deploys an External 
# HTTPS Load Balancer, and binds it to a Private Service Connect (PSC) Network Endpoint Group (NEG) 
# pointing directly to the Traefik internal endpoint.
*/

locals {
  list_domain_names = ["api.commit-dev.cloudsmesh.be"]
}

################################################################################
# Project A: Cloud Armor Security Policy (WAF & DDoS Protection)
################################################################################

resource "google_compute_security_policy" "cloud_armor_policy" {
  project     = var.gcp_project_a_id
  name        = "${var.env_name_short}-cloud-armor-waf"
  description = "Cloud Armor security policy for public ingress perimeter protection"

  # Default rule: Allow all traffic, individual filters will override this
  rule {
    action   = "allow"
    priority = "2147483647"
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    description = "Default rule, higher priority numbers mean lower precedence"
  }

  # Custom Rule: Block common web attacks (SQLi, XSS) using preconfigured WAF rules
  rule {
    action   = "deny(403)"
    priority = "1000"
    match {
      expr {
        expression = "evaluatePreconfiguredExpr('sqli-v33-stable') || evaluatePreconfiguredExpr('xss-v33-stable')"
      }
    }
    description = "Mitigate SQL Injection and Cross-Site Scripting threats"
  }
}

################################################################################
# Project A: Private Service Connect Network Endpoint Group (PSC NEG)
################################################################################

# This NEG allows the External Load Balancer to route traffic directly into the PSC Endpoint
# This NEG binds the infrastructure of Project A to the Service Attachment in Project B
resource "google_compute_region_network_endpoint_group" "traefik_psc_neg" {
  project               = var.gcp_project_a_id
  name                  = "${var.env_name_short}-traefik-psc-neg"
  region                = var.gcp_region
  network_endpoint_type = "PRIVATE_SERVICE_CONNECT"
  network               = module.vpc_a.network_self_link

  # Explicitly specify the subnetwork in Project A (required for custom mode VPCs)
  subnetwork = module.vpc_a.subnets["${var.gcp_region}/${var.env_name_short}-subnet-a"].self_link

  # Link the NEG directly to the published Service Attachment URI in Project B
  psc_target_service = google_compute_service_attachment.traefik_psc_attachment.id

  lifecycle {
    replace_triggered_by = [
      google_compute_service_attachment.traefik_psc_attachment,
    ]
  }
}

################################################################################
# Project A: External HTTPS Load Balancer
################################################################################

module "external_lb" {
  source  = "terraform-google-modules/lb-http/google"
  version = ">= 14.2.0"

  depends_on = [
    terraform_data.traefik_ilb_allow_global_access,
  ]

  project = var.gcp_project_a_id
  name    = "${var.env_name_short}-external-lb"

  # Core Network Settings
  firewall_networks = []
  create_address    = true

  # SSL & Frontend Configurations
  ssl                             = true
  managed_ssl_certificate_domains = local.list_domain_names
  create_ssl_certificate          = false
  load_balancing_scheme           = "EXTERNAL_MANAGED"

  # Backend Architecture definition mapping directly to our PSC NEG configuration
  backends = {
    traefik-psc-backend = {
      protocol    = "HTTPS"
      port_name   = "https"
      description = "PSC dynamic backend routing to Traefik internal HTTPS proxy"

      # Bind the Cloud Armor policy to this specific backend routing path
      security_policy = google_compute_security_policy.cloud_armor_policy.self_link

      groups = [
        {
          group = google_compute_region_network_endpoint_group.traefik_psc_neg.id
        }
      ]

      # Mandatory zero-out rules for Private Service Connect network endpoints
      enable_cdn              = false
      custom_request_headers  = []
      custom_response_headers = []
      log_config              = { enable = false }
      iap_config              = { enable = false }
    }
  }
}

################################################################################
# Outputs
################################################################################

output "external_lb_public_ip" {
  value       = module.external_lb.external_ip
  description = "The public external IP address generated by the Google LB module of the Project A Load Balancer."
}
