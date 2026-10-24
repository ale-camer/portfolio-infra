locals {
  tfstate_bucket_name = "${var.project_id}-tfstate"

  common_labels = {
    project    = "portfolio"
    env        = var.environment
    repo       = "portfolio-infra"
    managed_by = "terraform"
  }

  bootstrap_apis = toset([
    "iam.googleapis.com",
    "storage.googleapis.com",
  ])
}

resource "google_project_service" "bootstrap_apis" {
  for_each = local.bootstrap_apis

  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

resource "google_storage_bucket" "tfstate" {
  # checkov:skip=CKV_GCP_62: Self-logging or secondary access-log bucket on the Terraform state bucket adds unnecessary storage objects against the 5 GB GCS Free Tier; Cloud Audit Logs already capture bucket access.
  name                        = local.tfstate_bucket_name
  project                     = var.project_id
  location                    = var.region
  storage_class               = "STANDARD"
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = false

  versioning {
    enabled = true
  }

  lifecycle_rule {
    action {
      type = "Delete"
    }
    condition {
      num_newer_versions         = 5
      days_since_noncurrent_time = 30
      with_state                 = "ARCHIVED"
    }
  }

  lifecycle_rule {
    action {
      type = "AbortIncompleteMultipartUpload"
    }
    condition {
      age = 7
    }
  }

  labels = local.common_labels

  depends_on = [
    google_project_service.bootstrap_apis,
  ]
}
