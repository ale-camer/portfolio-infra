locals {
  common_labels = {
    project      = "portfolio"
    env          = var.environment
    repo         = "portfolio-infra"
    github_owner = lower(var.github_owner)
    managed_by   = "terraform"
  }

  platform_apis = toset([
    "artifactregistry.googleapis.com",
    "bigquery.googleapis.com",
    "billingbudgets.googleapis.com",
    "cloudbilling.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "cloudscheduler.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "pubsub.googleapis.com",
    "run.googleapis.com",
    "secretmanager.googleapis.com",
    "storage.googleapis.com",
    "sts.googleapis.com",
  ])
}

resource "google_project_service" "platform_apis" {
  for_each = local.platform_apis

  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}
