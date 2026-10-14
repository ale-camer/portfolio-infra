locals {
  p01_image_uri = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.portfolio_apps.repository_id}/p01-daily-etl:${var.p01_image_tag}"
}

module "p01_daily_etl" {
  source = "../modules/cloud-run-job"

  project_id             = var.project_id
  region                 = var.region
  job_name               = "p01-daily-etl"
  repo_name              = local.workload_db_secret_bindings.p01.repo_name
  image                  = local.p01_image_uri
  cpu                    = "1"
  memory                 = "512Mi"
  max_retries            = 1
  timeout_seconds        = 600
  task_count             = 1
  schedule_cron          = "0 22 * * 1-5"
  schedule_timezone      = "UTC"
  schedule_paused        = false
  cicd_deployer_sa_email = google_service_account.cicd_deployer.email

  env_vars = merge(
    local.workload_db_secret_bindings.p01.env_vars,
    {
      ENVIRONMENT      = var.environment
      GCP_PROJECT_ID   = var.project_id
      GCP_REGION       = var.region
      DATA_LAKE_BUCKET = google_storage_bucket.data_lake.name
      DATA_LAKE_PREFIX = "p01/raw"
      LOG_LEVEL        = "INFO"
    },
  )

  secret_env_vars = merge(
    local.workload_db_secret_bindings.p01.secret_env_vars,
    {
      MARKET_API_KEYS = {
        secret_id = google_secret_manager_secret.catalog["portfolio-market-api-keys"].secret_id
        version   = "latest"
      }
    },
  )

  storage_bucket_roles = {
    data_lake_writer = {
      bucket = google_storage_bucket.data_lake.name
      role   = "roles/storage.objectUser"
    }
  }

  labels = {
    tier = "batch-etl"
  }

  depends_on = [
    google_project_service.platform_apis["run.googleapis.com"],
    google_project_service.platform_apis["cloudscheduler.googleapis.com"],
  ]
}
