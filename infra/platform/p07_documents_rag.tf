locals {
  p07_docs_rag_image_uri = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.portfolio_apps.repository_id}/p07-docs-rag:${var.p07_image_tag}"
}

module "p07_docs_rag" {
  source = "../modules/cloud-run-service"

  project_id             = var.project_id
  region                 = var.region
  service_name           = "p07-docs-rag"
  repo_name              = local.workload_db_secret_bindings.p07.repo_name
  image                  = local.p07_docs_rag_image_uri
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
    local.workload_db_secret_bindings.p07.env_vars,
    {
      ENVIRONMENT            = var.environment
      GCP_PROJECT_ID         = var.project_id
      GCP_REGION             = var.region
      PGVECTOR_DIMENSIONS    = "1536"
      RAG_TOP_K              = "5"
      LLM_MAX_TOKENS_PER_REQ = "1024"
      DATA_LAKE_BUCKET       = google_storage_bucket.data_lake.name
      DATA_LAKE_PREFIX       = "p07/sec_filings"
      LOG_LEVEL              = "INFO"
    },
  )

  secret_env_vars = merge(
    local.workload_db_secret_bindings.p07.secret_env_vars,
    {
      LLM_API_KEY = {
        secret_id = google_secret_manager_secret.catalog["portfolio-llm-api-key"].secret_id
        version   = "latest"
      }
    },
  )

  storage_bucket_roles = {
    data_lake_filings = {
      bucket = google_storage_bucket.data_lake.name
      role   = "roles/storage.objectUser"
    }
  }

  labels = {
    tier   = "rag-api"
    engine = "pgvector-hybrid-rag"
  }

  depends_on = [
    google_project_service.platform_apis["run.googleapis.com"],
  ]
}
