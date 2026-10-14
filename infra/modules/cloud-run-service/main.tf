locals {
  runtime_sa_account_id = trim(substr("sa-run-${var.service_name}", 0, 30), "-")

  service_labels = merge(
    {
      project    = "portfolio"
      env        = "prod"
      repo       = lower(replace(var.repo_name, "_", "-"))
      workload   = var.service_name
      managed_by = "terraform"
    },
    var.labels,
  )

  referenced_secret_ids = toset([
    for s in values(var.secret_env_vars) : s.secret_id
  ])
}

resource "google_service_account" "runtime" {
  project      = var.project_id
  account_id   = local.runtime_sa_account_id
  display_name = "Cloud Run Service Runtime SA (${var.service_name})"
  description  = "Least-privilege runtime identity for Cloud Run service ${var.service_name} (${var.repo_name})."
}

# Grant the runtime SA access ONLY to the Secret Manager secrets referenced in secret_env_vars.
resource "google_secret_manager_secret_iam_member" "secret_accessor" {
  for_each = local.referenced_secret_ids

  project   = var.project_id
  secret_id = each.value
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.runtime.email}"
}

# Grant the runtime SA scoped access to GCS buckets when requested by the workload.
resource "google_storage_bucket_iam_member" "bucket_access" {
  for_each = var.storage_bucket_roles

  bucket = each.value.bucket
  role   = each.value.role
  member = "serviceAccount:${google_service_account.runtime.email}"
}

# Grant the runtime SA scoped access to BigQuery datasets when requested by the workload.
resource "google_bigquery_dataset_iam_member" "dataset_access" {
  for_each = var.bigquery_dataset_roles

  project    = var.project_id
  dataset_id = each.value.dataset_id
  role       = each.value.role
  member     = "serviceAccount:${google_service_account.runtime.email}"
}

# Allow sa-cicd-deployer to actAs this workload's runtime service account during GitHub Actions rollouts.
resource "google_service_account_iam_member" "cicd_act_as_runtime" {
  count = length(trimspace(var.cicd_deployer_sa_email)) > 0 ? 1 : 0

  service_account_id = google_service_account.runtime.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${var.cicd_deployer_sa_email}"
}

resource "google_cloud_run_v2_service" "service" {
  project             = var.project_id
  name                = var.service_name
  location            = var.region
  ingress             = "INGRESS_TRAFFIC_ALL"
  deletion_protection = false
  labels              = local.service_labels

  template {
    service_account                  = google_service_account.runtime.email
    max_instance_request_concurrency = var.concurrency
    timeout                          = "${var.timeout_seconds}s"

    scaling {
      min_instance_count = var.min_instance_count
      max_instance_count = var.max_instance_count
    }

    containers {
      image = var.image

      ports {
        container_port = var.port
      }

      resources {
        limits = {
          cpu    = var.cpu
          memory = var.memory
        }
        cpu_idle          = true
        startup_cpu_boost = true
      }

      dynamic "env" {
        for_each = var.env_vars
        content {
          name  = env.key
          value = env.value
        }
      }

      dynamic "env" {
        for_each = var.secret_env_vars
        content {
          name = env.key
          value_source {
            secret_key_ref {
              secret  = env.value.secret_id
              version = env.value.version
            }
          }
        }
      }

      startup_probe {
        initial_delay_seconds = 0
        timeout_seconds       = 5
        period_seconds        = 10
        failure_threshold     = 3
        http_get {
          path = var.health_check_path
          port = var.port
        }
      }

      liveness_probe {
        initial_delay_seconds = 15
        timeout_seconds       = 5
        period_seconds        = 30
        failure_threshold     = 3
        http_get {
          path = var.health_check_path
          port = var.port
        }
      }
    }
  }

  depends_on = [
    google_secret_manager_secret_iam_member.secret_accessor,
  ]
}

resource "google_cloud_run_v2_service_iam_member" "public_invoker" {
  # checkov:skip=CKV_GCP_102:Public portfolio showcase APIs and UIs intentionally allow unauthenticated HTTPS invocation when var.allow_public_invoker is true (ADR-003).
  count = var.allow_public_invoker ? 1 : 0

  project  = var.project_id
  location = google_cloud_run_v2_service.service.location
  name     = google_cloud_run_v2_service.service.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}
