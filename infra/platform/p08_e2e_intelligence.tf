locals {
  p08_market_intel_image_uri = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.portfolio_apps.repository_id}/p08-market-intel:${var.p08_image_tag}"
  p08_nlp_worker_image_uri   = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.portfolio_apps.repository_id}/p08-nlp-worker:${var.p08_image_tag}"
}

module "p08_market_intel" {
  source = "../modules/cloud-run-service"

  project_id             = var.project_id
  region                 = var.region
  service_name           = "p08-market-intel"
  repo_name              = local.workload_db_secret_bindings.p08.repo_name
  image                  = local.p08_market_intel_image_uri
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
    local.workload_db_secret_bindings.p08.env_vars,
    {
      ENVIRONMENT            = var.environment
      GCP_PROJECT_ID         = var.project_id
      GCP_REGION             = var.region
      PGVECTOR_DIMENSIONS    = "1536"
      REDIS_KEY_PREFIX       = "p08:"
      LLM_MAX_TOKENS_PER_REQ = "1024"
      DATA_LAKE_BUCKET       = google_storage_bucket.data_lake.name
      DATA_LAKE_PREFIX       = "p08/market_intel"
      ARTIFACTS_BUCKET       = google_storage_bucket.artifacts.name
      ARTIFACTS_PREFIX       = "p08/nlp_models"
      LOG_LEVEL              = "INFO"
    },
  )

  secret_env_vars = merge(
    local.workload_db_secret_bindings.p08.secret_env_vars,
    {
      LLM_API_KEY = {
        secret_id = google_secret_manager_secret.catalog["portfolio-llm-api-key"].secret_id
        version   = "latest"
      }
      MARKET_API_KEYS = {
        secret_id = google_secret_manager_secret.catalog["portfolio-market-api-keys"].secret_id
        version   = "latest"
      }
      NEWS_SOCIAL_KEYS = {
        secret_id = google_secret_manager_secret.catalog["portfolio-news-social-keys"].secret_id
        version   = "latest"
      }
    },
  )

  storage_bucket_roles = {
    data_lake_viewer = {
      bucket = google_storage_bucket.data_lake.name
      role   = "roles/storage.objectViewer"
    }
    artifacts_viewer = {
      bucket = google_storage_bucket.artifacts.name
      role   = "roles/storage.objectViewer"
    }
  }

  labels = {
    tier   = "e2e-intel-api"
    engine = "fastapi-pgvector"
  }

  depends_on = [
    google_project_service.platform_apis["run.googleapis.com"],
  ]
}

module "p08_nlp_worker" {
  source = "../modules/cloud-run-job"

  project_id             = var.project_id
  region                 = var.region
  job_name               = "p08-nlp-worker"
  repo_name              = local.workload_db_secret_bindings.p08.repo_name
  image                  = local.p08_nlp_worker_image_uri
  cpu                    = "1"
  memory                 = "1Gi"
  max_retries            = 1
  timeout_seconds        = 600
  task_count             = 1
  schedule_cron          = ""
  cicd_deployer_sa_email = google_service_account.cicd_deployer.email

  env_vars = merge(
    local.workload_db_secret_bindings.p08.env_vars,
    {
      ENVIRONMENT            = var.environment
      GCP_PROJECT_ID         = var.project_id
      GCP_REGION             = var.region
      PGVECTOR_DIMENSIONS    = "1536"
      REDIS_KEY_PREFIX       = "p08:"
      LLM_MAX_TOKENS_PER_REQ = "1024"
      DATA_LAKE_BUCKET       = google_storage_bucket.data_lake.name
      DATA_LAKE_PREFIX       = "p08/market_intel"
      ARTIFACTS_BUCKET       = google_storage_bucket.artifacts.name
      ARTIFACTS_PREFIX       = "p08/nlp_models"
      LOG_LEVEL              = "INFO"
    },
  )

  secret_env_vars = merge(
    local.workload_db_secret_bindings.p08.secret_env_vars,
    {
      LLM_API_KEY = {
        secret_id = google_secret_manager_secret.catalog["portfolio-llm-api-key"].secret_id
        version   = "latest"
      }
      MARKET_API_KEYS = {
        secret_id = google_secret_manager_secret.catalog["portfolio-market-api-keys"].secret_id
        version   = "latest"
      }
      NEWS_SOCIAL_KEYS = {
        secret_id = google_secret_manager_secret.catalog["portfolio-news-social-keys"].secret_id
        version   = "latest"
      }
    },
  )

  storage_bucket_roles = {
    data_lake_writer = {
      bucket = google_storage_bucket.data_lake.name
      role   = "roles/storage.objectUser"
    }
    artifacts_writer = {
      bucket = google_storage_bucket.artifacts.name
      role   = "roles/storage.objectUser"
    }
  }

  labels = {
    tier   = "e2e-nlp-worker"
    engine = "finbert-embeddings"
  }

  depends_on = [
    google_project_service.platform_apis["run.googleapis.com"],
  ]
}
