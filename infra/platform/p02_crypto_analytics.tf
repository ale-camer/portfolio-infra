locals {
  p02_image_uri = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.portfolio_apps.repository_id}/p02-crypto-etl:${var.p02_image_tag}"
}

module "p02_crypto_etl" {
  source = "../modules/cloud-run-job"

  project_id             = var.project_id
  region                 = var.region
  job_name               = "p02-crypto-etl"
  repo_name              = "crypto-analytics-platform"
  image                  = local.p02_image_uri
  cpu                    = "1"
  memory                 = "1Gi"
  max_retries            = 1
  timeout_seconds        = 600
  task_count             = 1
  schedule_cron          = "0 1 * * *"
  schedule_timezone      = "UTC"
  schedule_paused        = false
  cicd_deployer_sa_email = google_service_account.cicd_deployer.email

  env_vars = {
    ENVIRONMENT        = var.environment
    GCP_PROJECT_ID     = var.project_id
    GCP_REGION         = var.region
    BQ_DATASET         = google_bigquery_dataset.datasets["crypto_market_data"].dataset_id
    DATA_LAKE_BUCKET   = google_storage_bucket.data_lake.name
    DATA_LAKE_PREFIX   = "p02/lakehouse"
    POLARS_MAX_THREADS = "1"
    LOG_LEVEL          = "INFO"
  }

  secret_env_vars = {
    MARKET_API_KEYS = {
      secret_id = google_secret_manager_secret.catalog["portfolio-market-api-keys"].secret_id
      version   = "latest"
    }
  }

  storage_bucket_roles = {
    data_lake_writer = {
      bucket = google_storage_bucket.data_lake.name
      role   = "roles/storage.objectUser"
    }
  }

  bigquery_dataset_roles = {
    crypto_market_data_editor = {
      dataset_id = google_bigquery_dataset.datasets["crypto_market_data"].dataset_id
      role       = "roles/bigquery.dataEditor"
    }
  }

  labels = {
    tier   = "lakehouse-etl"
    engine = "polars-bigquery"
  }

  depends_on = [
    google_project_service.platform_apis["run.googleapis.com"],
    google_project_service.platform_apis["cloudscheduler.googleapis.com"],
    google_project_service.platform_apis["bigquery.googleapis.com"],
  ]
}
