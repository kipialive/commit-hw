## environments/commit-dev/main-20-github-actions-wif.tf

################################################################################
### GitHub Actions Workload Identity Federation (WIF) ###
################################################################################

/*

Based on source:: https://github.com/terraform-google-modules/terraform-google-github-actions-runners
# example # https://github.com/terraform-google-modules/terraform-google-github-actions-runners/tree/main/examples

# Workload Identity Federation configuration for GitHub Actions
# Data flow: GitHub Actions → OIDC Token → GCP WIF → IAM Role
# Done in Project "B"
*/

locals {
  github_actions_owner                 = "kipialive"
  github_actions_repository            = "kipialive/commit-hw"
  github_actions_deployer_sa_name      = "tf-gke-commit-dev-gke--tvos"
  github_actions_deployer_sa_resource  = "projects/${var.gcp_project_b_id}/serviceAccounts/${local.github_actions_deployer_sa_name}@${var.gcp_project_b_id}.iam.gserviceaccount.com"
  github_actions_deployer_sa_principal = "attribute.repository/${local.github_actions_repository}"
}

module "github_actions_oidc" {
  source  = "terraform-google-modules/github-actions-runners/google//modules/gh-oidc"
  version = "5.1.0"

  providers = {
    google      = google.project_b
    google-beta = google-beta.project_b
  }

  project_id  = var.gcp_project_b_id
  pool_id     = "github-actions-pool"
  provider_id = "github-provider"

  pool_display_name     = "GitHub Actions Pool"
  pool_description      = "Identity pool for GitHub Actions automation pipelines"
  provider_display_name = "GitHub Provider"
  provider_description  = "OIDC identity provider for GitHub Actions workflows"
  attribute_condition   = "assertion.repository_owner == '${local.github_actions_owner}'"

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.actor"      = "assertion.actor"
    "attribute.repository" = "assertion.repository"
    "attribute.owner"      = "assertion.repository_owner"
  }

  sa_mapping = {
    (local.github_actions_deployer_sa_name) = {
      sa_name   = local.github_actions_deployer_sa_resource
      attribute = local.github_actions_deployer_sa_principal
    }
  }
}

# ---------------------------------------------------------------
# GKE Access Permission for the Deployment Service Account
# Access path: Service Account → IAM Project Policy → GKE Admin Rights
# ---------------------------------------------------------------

resource "google_project_iam_member" "sa_gke_admin" {
  project = var.gcp_project_b_id
  role    = "roles/container.admin"
  member  = "serviceAccount:${local.github_actions_deployer_sa_name}@${var.gcp_project_b_id}.iam.gserviceaccount.com"
}
