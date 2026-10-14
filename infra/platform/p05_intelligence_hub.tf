locals {
  p05_hub_api_image_uri   = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.portfolio_apps.repository_id}/p05-hub-api:${var.p05_image_tag}"
  p05_dbt_build_image_uri = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.portfolio_apps.repository_id}/p05-dbt-build:${var.p05_image_tag}"
}

module "p05_hub_api" {
  source = "../modules/cloud-run-service"

  project_id             = var.project_id
  region                 = var.region
  service_name           = "p05-hub-api"
  repo_name              = local.workload_db_secret_bindings.p05.repo_name
  image                  = local.p05_hub_api_image_uri
  port                   = 8000
  cpu                    = "1"
  memory                 = "512Mi"
  min_instance_count     = 0
  max_instance_count     = 1
  concurrency            = 80
  timeout_seconds        = 60
  allow_public_invoker   = true
  health_check_path      = "/health"
  cicd_deployer_sa_email = google_service_account.cicd_deployer.email

  env_vars = merge(
    local.workload_db_secret_bindings.p05.env_vars,
    {
      ENVIRONMENT         = var.environment
      GCP_PROJECT_ID      = var.project_id
      GCP_REGION          = var.region
      BQ_RAW_DATASET      = google_bigquery_dataset.datasets["raw_prod"].dataset_id
      BQ_STAGING_DATASET  = google_bigquery_dataset.datasets["staging_prod"].dataset_id
      BQ_MARTS_DATASET    = google_bigquery_dataset.datasets["marts_prod"].dataset_id
      DATA_LAKE_BUCKET    = google_storage_bucket.data_lake.name
      DATA_LAKE_PREFIX    = "p05/hub"
      PUBSUB_EVENTS_TOPIC = module.p03_market_events_pubsub.topic_name
      LOG_LEVEL           = "INFO"
    },
  )

  secret_env_vars = merge(
    local.workload_db_secret_bindings.p05.secret_env_vars,
    {
      MARKET_API_KEYS = {
        secret_id = google_secret_manager_secret.catalog["portfolio-market-api-keys"].secret_id
        version   = "latest"
      }
    },
  )

  storage_bucket_roles = {
    data_lake_user = {
      bucket = google_storage_bucket.data_lake.name
      role   = "roles/storage.objectUser"
    }
  }

  bigquery_dataset_roles = {
    raw_prod_editor = {
      dataset_id = google_bigquery_dataset.datasets["raw_prod"].dataset_id
      role       = "roles/bigquery.dataEditor"
    }
    staging_prod_viewer = {
      dataset_id = google_bigquery_dataset.datasets["staging_prod"].dataset_id
      role       = "roles/bigquery.dataViewer"
    }
    marts_prod_viewer = {
      dataset_id = google_bigquery_dataset.datasets["marts_prod"].dataset_id
      role       = "roles/bigquery.dataViewer"
    }
  }

  labels = {
    tier   = "analytics-hub-api"
    engine = "fastapi-bigquery"
  }

  depends_on = [
    google_project_service.platform_apis["run.googleapis.com"],
    google_project_service.platform_apis["bigquery.googleapis.com"],
  ]
}

module "p05_dbt_build" {
  source = "../modules/cloud-run-job"

  project_id             = var.project_id
  region                 = var.region
  job_name               = "p05-dbt-build"
  repo_name              = local.workload_db_secret_bindings.p05.repo_name
  image                  = local.p05_dbt_build_image_uri
  cpu                    = "1"
  memory                 = "512Mi"
  max_retries            = 1
  timeout_seconds        = 600
  task_count             = 1
  schedule_cron          = "0 2 * * *"
  schedule_timezone      = "UTC"
  schedule_paused        = false
  cicd_deployer_sa_email = google_service_account.cicd_deployer.email

  env_vars = {
    ENVIRONMENT        = var.environment
    GCP_PROJECT_ID     = var.project_id
    GCP_REGION         = var.region
    DBT_TARGET         = "prod"
    BQ_RAW_DATASET     = google_bigquery_dataset.datasets["raw_prod"].dataset_id
    BQ_STAGING_DATASET = google_bigquery_dataset.datasets["staging_prod"].dataset_id
    BQ_MARTS_DATASET   = google_bigquery_dataset.datasets["marts_prod"].dataset_id
    LOG_LEVEL          = "INFO"
  }

  bigquery_dataset_roles = {
    raw_prod_editor = {
      dataset_id = google_bigquery_dataset.datasets["raw_prod"].dataset_id
      role       = "roles/bigquery.dataEditor"
    }
    staging_prod_editor = {
      dataset_id = google_bigquery_dataset.datasets["staging_prod"].dataset_id
      role       = "roles/bigquery.dataEditor"
    }
    marts_prod_editor = {
      dataset_id = google_bigquery_dataset.datasets["marts_prod"].dataset_id
      role       = "roles/bigquery.dataEditor"
    }
  }

  labels = {
    tier   = "warehouse-dbt"
    engine = "dbt-bigquery"
  }

  depends_on = [
    google_project_service.platform_apis["run.googleapis.com"],
    google_project_service.platform_apis["cloudscheduler.googleapis.com"],
    google_project_service.platform_apis["bigquery.googleapis.com"],
  ]
}
