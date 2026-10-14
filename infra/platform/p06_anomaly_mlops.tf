locals {
  p06_anomaly_api_image_uri  = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.portfolio_apps.repository_id}/p06-anomaly-api:${var.p06_image_tag}"
  p06_train_detect_image_uri = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.portfolio_apps.repository_id}/p06-train-detect:${var.p06_image_tag}"
}

module "p06_anomaly_api" {
  source = "../modules/cloud-run-service"

  project_id             = var.project_id
  region                 = var.region
  service_name           = "p06-anomaly-api"
  repo_name              = local.workload_db_secret_bindings.p06.repo_name
  image                  = local.p06_anomaly_api_image_uri
  port                   = 8000
  cpu                    = "1"
  memory                 = "1Gi"
  min_instance_count     = 0
  max_instance_count     = 1
  concurrency            = 80
  timeout_seconds        = 60
  allow_public_invoker   = true
  health_check_path      = "/health"
  cicd_deployer_sa_email = google_service_account.cicd_deployer.email

  env_vars = merge(
    local.workload_db_secret_bindings.p06.env_vars,
    {
      ENVIRONMENT      = var.environment
      GCP_PROJECT_ID   = var.project_id
      GCP_REGION       = var.region
      ARTIFACTS_BUCKET = google_storage_bucket.artifacts.name
      ARTIFACTS_PREFIX = "p06/models"
      EVIDENTLY_PREFIX = "p06/evidently"
      DATA_LAKE_BUCKET = google_storage_bucket.data_lake.name
      DATA_LAKE_PREFIX = "p06/features"
      LOG_LEVEL        = "INFO"
    },
  )

  secret_env_vars = merge(
    local.workload_db_secret_bindings.p06.secret_env_vars,
    {
      MARKET_API_KEYS = {
        secret_id = google_secret_manager_secret.catalog["portfolio-market-api-keys"].secret_id
        version   = "latest"
      }
    },
  )

  storage_bucket_roles = {
    artifacts_viewer = {
      bucket = google_storage_bucket.artifacts.name
      role   = "roles/storage.objectViewer"
    }
    data_lake_viewer = {
      bucket = google_storage_bucket.data_lake.name
      role   = "roles/storage.objectViewer"
    }
  }

  labels = {
    tier   = "mlops-inference-api"
    engine = "isolation-forest-autoencoder"
  }

  depends_on = [
    google_project_service.platform_apis["run.googleapis.com"],
  ]
}

module "p06_train_detect" {
  source = "../modules/cloud-run-job"

  project_id             = var.project_id
  region                 = var.region
  job_name               = "p06-train-detect"
  repo_name              = local.workload_db_secret_bindings.p06.repo_name
  image                  = local.p06_train_detect_image_uri
  cpu                    = "1"
  memory                 = "1Gi"
  max_retries            = 1
  timeout_seconds        = 600
  task_count             = 1
  schedule_cron          = ""
  cicd_deployer_sa_email = google_service_account.cicd_deployer.email

  env_vars = merge(
    local.workload_db_secret_bindings.p06.env_vars,
    {
      ENVIRONMENT      = var.environment
      GCP_PROJECT_ID   = var.project_id
      GCP_REGION       = var.region
      ARTIFACTS_BUCKET = google_storage_bucket.artifacts.name
      ARTIFACTS_PREFIX = "p06/models"
      EVIDENTLY_PREFIX = "p06/evidently"
      DATA_LAKE_BUCKET = google_storage_bucket.data_lake.name
      DATA_LAKE_PREFIX = "p06/features"
      LOG_LEVEL        = "INFO"
    },
  )

  secret_env_vars = merge(
    local.workload_db_secret_bindings.p06.secret_env_vars,
    {
      MARKET_API_KEYS = {
        secret_id = google_secret_manager_secret.catalog["portfolio-market-api-keys"].secret_id
        version   = "latest"
      }
    },
  )

  storage_bucket_roles = {
    artifacts_writer = {
      bucket = google_storage_bucket.artifacts.name
      role   = "roles/storage.objectUser"
    }
    data_lake_writer = {
      bucket = google_storage_bucket.data_lake.name
      role   = "roles/storage.objectUser"
    }
  }

  labels = {
    tier   = "mlops-batch-trainer"
    engine = "mlflow-evidently"
  }

  depends_on = [
    google_project_service.platform_apis["run.googleapis.com"],
  ]
}
