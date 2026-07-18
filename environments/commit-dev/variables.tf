################################################################################
# GCP Project & Location
################################################################################

variable "gcp_project_a_id" {
  type        = string
  description = "The ID of Project A (Public perimeter containing Cloud Armor and External HTTPS LB)."
  default     = ""
}

variable "gcp_project_b_id" {
  type        = string
  description = "The ID of Project B (Internal perimeter containing GKE cluster and Internal HTTPS LB)."
  default     = ""
}

variable "env_name" {
  description = "Environment name e.g., 'prod-env', 'staging-env', 'dev-env', 'UAT-env' ... etc."
  type        = string
  default     = ""
}

variable "env_name_short" {
  description = "Short version of environment name e.g., 'prod', 'staging', 'dev', 'UAT' ... etc."
  type        = string
  default     = ""
}

variable "git_branch_env_name" {
  description = "Environment name e.g., 'main', 'staging', 'dev', 'UAT', 'preprod' ... etc."
  type        = string
  default     = ""
}

// Region Location
variable "gcp_region" {
  type        = string
  description = "The primary GCP region where the regional infrastructure will be deployed."
  default     = ""
}

// Availability Zone (az)
variable "gcp_zone" {
  type        = string
  description = "The primary GCP zone within the selected region for single-zone resource deployment."
  default     = ""
}

################################################################################
# Network IP CIDR Range
################################################################################

variable "vpc_a_subnet_cidr" {
  type        = string
  description = "The IP CIDR range for the primary subnet in VPC A."
  default     = ""
}

variable "vpc_b_subnet_cidr" {
  type        = string
  description = "The IP CIDR range for the primary GKE node subnet in VPC B."
  default     = ""
}

variable "vpc_b_psc_nat_cidr" {
  type        = string
  description = "The dedicated IP CIDR range required by the Private Service Connect (PSC) NAT subnet in VPC B."
  default     = ""
}

variable "vpc_b_proxy_only_cidr" {
  type        = string
  description = "The dedicated Proxy-Only subnet CIDR range required by the Internal HTTPS Load Balancer in VPC B."
  default     = ""
}

################################################################################
# GKE Cluster Configuration
################################################################################

variable "gke_pod_cidr_range" {
  type        = string
  description = "The secondary IP range name or CIDR block for GKE Pods allocation."
  default     = ""
}

variable "gke_service_cidr_range" {
  type        = string
  description = "The secondary IP range name or CIDR block for GKE Services allocation."
  default     = ""
}