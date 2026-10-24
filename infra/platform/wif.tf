resource "google_iam_workload_identity_pool" "github" {
  project                   = var.project_id
  workload_identity_pool_id = "github-actions-pool"
  display_name              = "GitHub Actions WIF Pool"
  description               = "Keyless OIDC Workload Identity Pool for P-01..P-12 GitHub Actions workflows."
  disabled                  = false

  depends_on = [
    google_project_service.platform_apis["iam.googleapis.com"],
    google_project_service.platform_apis["iamcredentials.googleapis.com"],
    google_project_service.platform_apis["sts.googleapis.com"],
  ]
}

resource "google_iam_workload_identity_pool_provider" "github_oidc" {
  # checkov:skip=CKV_GCP_125:attribute_condition strictly restricts OIDC tokens to var.github_owner and per-repo principalSet bindings; Checkov static evaluation cannot resolve Terraform variable interpolation in attribute_condition.
  project                            = var.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-oidc-provider"
  display_name                       = "GitHub Actions OIDC Provider"
  description                        = "OIDC identity provider trusting https://token.actions.githubusercontent.com for ${var.github_owner}."
  disabled                           = false

  attribute_mapping = {
    "google.subject"             = "assertion.sub"
    "attribute.actor"            = "assertion.actor"
    "attribute.repository"       = "assertion.repository"
    "attribute.repository_owner" = "assertion.repository_owner"
    "attribute.ref"              = "assertion.ref"
  }

  attribute_condition = "assertion.repository_owner == '${var.github_owner}'"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}
