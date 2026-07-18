## environments/commit-dev/main-0-provider.tf
// Configure the GCP Provider

# Default provider for Project A (Public perimeter: Cloud Armor, External LB)
provider "google" {
  project = var.gcp_project_a_id
  region  = var.gcp_region
  zone    = var.gcp_zone
}

# Alias provider for Project B (Internal perimeter: GKE, Internal LB)
provider "google" {
  alias   = "project_b"
  project = var.gcp_project_b_id
  region  = var.gcp_region
  zone    = var.gcp_zone
}

// Validate right Terraform Version
terraform {
  # Specifying a Required Terraform Version # > terraform version # https://developer.hashicorp.com/terraform/tutorials/configuration-language/versions
  required_version = ">= 1.13.0" # https://github.com/hashicorp/terraform

  # Specifying Provider Requirements
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 6.0.0" # https://registry.terraform.io/providers/hashicorp/google/latest
    }

    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.19.0" # https://registry.terraform.io/providers/gavinbunney/kubectl/latest
    }

    helm = {
      source  = "hashicorp/helm"
      version = ">= 3.1.1" # https://registry.terraform.io/providers/hashicorp/helm/latest
    }

    kubernetes = {
      source  = "hashicorp/kubernetes" # https://registry.terraform.io/providers/hashicorp/kubernetes/latest
      version = ">= 2.30.0" 
    }
  }

  # Stores the Terraform state files in a Google Cloud Storage (GCS) bucket.
  # The GCS bucket must be created manually before running `terraform init`.
  # GCS natively supports state locking out of the box.
  backend "gcs" {
    bucket = "commit-hw-terraforme" # Replace with your actual GCS bucket name
    prefix = "commit-dev/terraform.tfstate"
  }
}