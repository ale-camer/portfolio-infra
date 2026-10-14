locals {
  runtime_sa_account_id = trim(substr("sa-job-${var.job_name}", 0, 30), "-")

  job_labels = merge(
    {
      project    = "portfolio"
      env        = "prod"
      repo       = lower(replace(var.repo_name, "_", "-"))
      workload   = var.job_name
      managed_by = "terraform"
    },
    var.labels,
  )

  referenced_secret_ids = toset([
    for s in values(var.secret_env_vars) : s.secret_id
  ])

  enable_scheduler = var.schedule_cron != null && length(trimspace(coalesce(var.schedule_cron, ""))) > 0
}

resource "google_service_account" "runtime" {
  project      = var.project_id
  account_id   = local.runtime_sa_account_id
  display_name = "Cloud Run Job Runtime SA (${var.job_name})"
  description  = "Least-privilege runtime identity for Cloud Run job ${var.job_name} (${var.repo_name})."
}

resource "google_secret_manager_secret_iam_member" "secret_accessor" {
  for_each = local.referenced_secret_ids

  project   = var.project_id
  secret_id = each.value
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.runtime.email}"
}

resource "google_storage_bucket_iam_member" "bucket_access" {
  for_each = var.storage_bucket_roles

  bucket = each.value.bucket
  role   = each.value.role
  member = "serviceAccount:${google_service_account.runtime.email}"
}

resource "google_bigquery_dataset_iam_member" "dataset_access" {
  for_each = var.bigquery_dataset_roles

  project    = var.project_id
  dataset_id = each.value.dataset_id
  role       = each.value.role
  member     = "serviceAccount:${google_service_account.runtime.email}"
}

resource "google_project_iam_member" "bigquery_job_user" {
  count = length(var.bigquery_dataset_roles) > 0 ? 1 : 0

  project = var.project_id
  role    = "roles/bigquery.jobUser"
  member  = "serviceAccount:${google_service_account.runtime.email}"
}

resource "google_pubsub_topic_iam_member" "topic_access" {
  for_each = var.pubsub_topic_roles

  project = var.project_id
  topic   = each.value.topic
  role    = each.value.role
  member  = "serviceAccount:${google_service_account.runtime.email}"
}

resource "google_pubsub_subscription_iam_member" "subscription_access" {
  for_each = var.pubsub_subscription_roles

  project      = var.project_id
  subscription = each.value.subscription
  role         = each.value.role
  member       = "serviceAccount:${google_service_account.runtime.email}"
}

resource "google_service_account_iam_member" "cicd_act_as_runtime" {
  count = length(trimspace(var.cicd_deployer_sa_email)) > 0 ? 1 : 0

  service_account_id = google_service_account.runtime.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${var.cicd_deployer_sa_email}"
}

resource "google_cloud_run_v2_job" "job" {
  project             = var.project_id
  name                = var.job_name
  location            = var.region
  deletion_protection = false
  labels              = local.job_labels

  template {
    task_count = var.task_count

    template {
      service_account = google_service_account.runtime.email
      max_retries     = var.max_retries
      timeout         = "${var.timeout_seconds}s"

      containers {
        image   = var.image
        command = var.command
        args    = var.args

        resources {
          limits = {
            cpu    = var.cpu
            memory = var.memory
          }
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
      }
    }
  }

  depends_on = [
    google_secret_manager_secret_iam_member.secret_accessor,
  ]
}

resource "google_cloud_run_v2_job_iam_member" "scheduler_invoker" {
  count = local.enable_scheduler ? 1 : 0

  project  = var.project_id
  location = google_cloud_run_v2_job.job.location
  name     = google_cloud_run_v2_job.job.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.runtime.email}"
}

resource "google_cloud_scheduler_job" "trigger" {
  count = local.enable_scheduler ? 1 : 0

  project          = var.project_id
  region           = var.region
  name             = "sched-${var.job_name}"
  description      = "Scheduled cron trigger (${var.schedule_cron}) for Cloud Run job ${var.job_name}."
  schedule         = var.schedule_cron
  time_zone        = var.schedule_timezone
  attempt_deadline = "320s"
  paused           = var.schedule_paused

  retry_config {
    retry_count = 0
  }

  http_target {
    http_method = "POST"
    uri         = "https://${var.region}-run.googleapis.com/apis/run.googleapis.com/v1/namespaces/${var.project_id}/jobs/${google_cloud_run_v2_job.job.name}:run"

    oauth_token {
      service_account_email = google_service_account.runtime.email
      scope                 = "https://www.googleapis.com/auth/cloud-platform"
    }
  }

  depends_on = [
    google_cloud_run_v2_job_iam_member.scheduler_invoker,
  ]
}
