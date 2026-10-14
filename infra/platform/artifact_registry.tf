resource "google_artifact_registry_repository" "portfolio_apps" {
  # checkov:skip=CKV_GCP_84:Cloud KMS customer-managed encryption keys (CMEK) incur monthly key-version fees; Google-managed AES-256 encryption at rest is free and compliant with the < $10/month ceiling.
  project                = var.project_id
  location               = var.region
  repository_id          = "portfolio-apps"
  description            = "Centralized Docker container registry for P-01 through P-11 workloads."
  format                 = "DOCKER"
  cleanup_policy_dry_run = false
  labels                 = local.common_labels

  cleanup_policies {
    id     = "delete-untagged-7d"
    action = "DELETE"

    condition {
      tag_state  = "UNTAGGED"
      older_than = "604800s"
    }
  }

  cleanup_policies {
    id     = "delete-old-tagged-30d"
    action = "DELETE"

    condition {
      tag_state  = "TAGGED"
      older_than = "2592000s"
    }
  }

  cleanup_policies {
    id     = "keep-recent-3-versions"
    action = "KEEP"

    most_recent_versions {
      keep_count = 3
    }
  }

  depends_on = [
    google_project_service.platform_apis["artifactregistry.googleapis.com"],
  ]
}
