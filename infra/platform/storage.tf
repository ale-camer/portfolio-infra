resource "google_storage_bucket" "data_lake" {
  # checkov:skip=CKV_GCP_62:Cloud Audit Logs capture GCS data/admin operations without provisioning a separate access-log bucket that consumes the 5 GB Standard Free Tier.
  # checkov:skip=CKV_GCP_78:Versioning is explicitly enabled in the versioning block below.
  name                        = "${var.project_id}-data-lake"
  project                     = var.project_id
  location                    = var.region
  storage_class               = "STANDARD"
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = false
  labels                      = merge(local.common_labels, { tier = "data-lake" })

  versioning {
    enabled = true
  }

  lifecycle_rule {
    action {
      type = "Delete"
    }
    condition {
      age        = 30
      with_state = "LIVE"
    }
  }

  lifecycle_rule {
    action {
      type = "Delete"
    }
    condition {
      days_since_noncurrent_time = 7
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

  depends_on = [
    google_project_service.platform_apis["storage.googleapis.com"],
  ]
}

resource "google_storage_bucket" "artifacts" {
  # checkov:skip=CKV_GCP_62:Cloud Audit Logs capture GCS data/admin operations without provisioning a separate access-log bucket that consumes the 5 GB Standard Free Tier.
  # checkov:skip=CKV_GCP_78:Versioning is explicitly enabled in the versioning block below.
  name                        = "${var.project_id}-artifacts"
  project                     = var.project_id
  location                    = var.region
  storage_class               = "STANDARD"
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = false
  labels                      = merge(local.common_labels, { tier = "artifacts" })

  versioning {
    enabled = true
  }

  lifecycle_rule {
    action {
      type = "Delete"
    }
    condition {
      age        = 90
      with_state = "LIVE"
    }
  }

  lifecycle_rule {
    action {
      type = "Delete"
    }
    condition {
      days_since_noncurrent_time = 7
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

  depends_on = [
    google_project_service.platform_apis["storage.googleapis.com"],
  ]
}
