locals {
  sibling_repositories = toset([
    "polymarket-arbitrage-bot",
    "crypto-lakehouse-etl",
    "fin-doc-intelligence",
    "limit-order-book-sim",
    "fintech-data-warehouse",
    "quant-risk-engine",
    "market-sentiment-NER",
    "sec-rag-agent",
    "credit-risk-mlops",
    "options-pricing-cpp",
    "trading-signals-Kafka",
  ])
}

resource "google_service_account" "cicd_deployer" {
  project      = var.project_id
  account_id   = "sa-cicd-deployer"
  display_name = "Portfolio CI/CD Application Deployer (P-01..P-11)"
  description  = "Keyless WIF target service account for sibling repository Docker pushes and Cloud Run deployments."

  depends_on = [
    google_project_service.platform_apis["iam.googleapis.com"],
  ]
}

resource "google_service_account" "infra_terraform" {
  project      = var.project_id
  account_id   = "sa-infra-terraform"
  display_name = "Portfolio Infrastructure Terraform Runner (P-12)"
  description  = "Keyless WIF target service account for portfolio-infra Terraform CI validation and planning."

  depends_on = [
    google_project_service.platform_apis["iam.googleapis.com"],
  ]
}

# Allow sa-cicd-deployer to push container images only to the portfolio-apps Artifact Registry repository.
resource "google_artifact_registry_repository_iam_member" "cicd_deployer_writer" {
  project    = var.project_id
  location   = google_artifact_registry_repository.portfolio_apps.location
  repository = google_artifact_registry_repository.portfolio_apps.name
  role       = "roles/artifactregistry.writer"
  member     = "serviceAccount:${google_service_account.cicd_deployer.email}"
}

# Allow sa-cicd-deployer to deploy Cloud Run services and jobs across the portfolio project.
resource "google_project_iam_member" "cicd_deployer_run_developer" {
  project = var.project_id
  role    = "roles/run.developer"
  member  = "serviceAccount:${google_service_account.cicd_deployer.email}"
}

# Allow sa-infra-terraform predefined read-only asset & IAM inspection for CI drift checks (avoids basic roles/viewer per CKV_GCP_117).
resource "google_project_iam_member" "infra_terraform_asset_viewer" {
  project = var.project_id
  role    = "roles/cloudasset.viewer"
  member  = "serviceAccount:${google_service_account.infra_terraform.email}"
}

resource "google_project_iam_member" "infra_terraform_security_reviewer" {
  project = var.project_id
  role    = "roles/iam.securityReviewer"
  member  = "serviceAccount:${google_service_account.infra_terraform.email}"
}

# Bind each sibling repository (P-01..P-11) to sa-cicd-deployer via Workload Identity Federation.
resource "google_service_account_iam_member" "sibling_repos_wif_user" {
  for_each = local.sibling_repositories

  service_account_id = google_service_account.cicd_deployer.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${var.github_owner}/${each.value}"
}

# Bind portfolio-infra (P-12) to sa-infra-terraform via Workload Identity Federation.
resource "google_service_account_iam_member" "portfolio_infra_wif_user" {
  service_account_id = google_service_account.infra_terraform.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${var.github_owner}/portfolio-infra"
}
