## environments/commit-dev/main-20-github-actions-wif.tf

################################################################################
### GitHub Actions Workload Identity Federation (WIF) ###
################################################################################

/*
# Workload Identity Federation configuration for GitHub Actions
# Data flow: GitHub Actions → OIDC Token → GCP WIF → IAM Role
# Done in Project "B"
*/

resource "google_iam_workload_identity_pool" "github_pool" {
  provider                  = google
  project                   = var.gcp_project_b_id
  workload_identity_pool_id = "github-actions-pool"
  display_name              = "GitHub Actions Pool"
  description               = "Identity pool for GitHub Actions automation pipelines"
}

resource "google_iam_workload_identity_pool_provider" "github_provider" {
  provider                           = google
  project                            = var.gcp_project_b_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.github_pool.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-provider"
  display_name                       = "GitHub Provider"
  description                        = "OIDC identity provider for GitHub Actions workflows"

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.actor"      = "assertion.actor"
    "attribute.repository" = "assertion.repository"
    "attribute.owner"      = "assertion.repository_owner"
  }

  # This explicit condition ensures only your GitHub organization/user can attempt authentication
  attribute_condition = "assertion.repository_owner == 'kipialive'"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

# ---------------------------------------------------------------
# IAM Binding to allow GitHub Actions to assume the Service Account
# Access path: WIF Provider → IAM Policy → GKE Deployment Service Account
# ---------------------------------------------------------------

resource "google_service_account_iam_member" "wif_sa_binding" {
  service_account_id = "projects/${var.gcp_project_b_id}/serviceAccounts/tf-gke-commit-dev-gke--tvos@${var.gcp_project_b_id}.iam.gserviceaccount.com"
  role               = "roles/iam.workloadIdentityUser"

  # Only allows pushes from your specific GitHub repository to assume this role
  member = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github_pool.name}/attribute.repository/kipialive/commit-hw"
}

# ---------------------------------------------------------------
# GKE Access Permission for the Deployment Service Account
# Access path: Service Account → IAM Project Policy → GKE Admin Rights
# ---------------------------------------------------------------

resource "google_project_iam_member" "sa_gke_admin" {
  project = var.gcp_project_b_id
  role    = "roles/container.admin"
  member  = "serviceAccount:tf-gke-commit-dev-gke--tvos@${var.gcp_project_b_id}.iam.gserviceaccount.com"
}