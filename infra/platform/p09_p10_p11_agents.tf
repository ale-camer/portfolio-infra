locals {
  p09_research_agent_image_uri  = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.portfolio_apps.repository_id}/p09-research-agent:${var.p09_image_tag}"
  p10_trading_analyst_image_uri = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.portfolio_apps.repository_id}/p10-trading-analyst:${var.p10_image_tag}"
  p11_multi_agent_image_uri     = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.portfolio_apps.repository_id}/p11-multi-agent:${var.p11_image_tag}"

  agent_llm_budget_guardrails = {
    ENVIRONMENT            = var.environment
    GCP_PROJECT_ID         = var.project_id
    GCP_REGION             = var.region
    LLM_MODEL              = "gpt-4o-mini"
    LLM_SMOKE_MODE         = "fake"
    LLM_MAX_TOKENS_PER_REQ = "1024"
    AGENT_MAX_ITERATIONS   = "5"
    DAILY_TOKEN_BUDGET     = "50000"
    MONTHLY_LLM_BUDGET_USD = "2.00"
    LOG_LEVEL              = "INFO"
  }

  agent_shared_secrets = {
    LLM_API_KEY = {
      secret_id = google_secret_manager_secret.catalog["portfolio-llm-api-key"].secret_id
      version   = "latest"
    }
    MARKET_API_KEYS = {
      secret_id = google_secret_manager_secret.catalog["portfolio-market-api-keys"].secret_id
      version   = "latest"
    }
  }
}

module "p09_research_agent" {
  source = "../modules/cloud-run-service"

  project_id             = var.project_id
  region                 = var.region
  service_name           = "p09-research-agent"
  repo_name              = local.workload_db_secret_bindings.p09.repo_name
  image                  = local.p09_research_agent_image_uri
  port                   = 8000
  cpu                    = "1"
  memory                 = "512Mi"
  min_instance_count     = 0
  max_instance_count     = 2
  concurrency            = 40
  timeout_seconds        = 60
  allow_public_invoker   = true
  health_check_path      = "/health"
  cicd_deployer_sa_email = google_service_account.cicd_deployer.email

  env_vars = merge(
    local.workload_db_secret_bindings.p09.env_vars,
    local.agent_llm_budget_guardrails,
    {
      DATA_LAKE_BUCKET = google_storage_bucket.data_lake.name
      DATA_LAKE_PREFIX = "p09/research_reports"
    },
  )

  secret_env_vars = merge(
    local.workload_db_secret_bindings.p09.secret_env_vars,
    local.agent_shared_secrets,
  )

  storage_bucket_roles = {
    data_lake_reports = {
      bucket = google_storage_bucket.data_lake.name
      role   = "roles/storage.objectUser"
    }
  }

  labels = {
    tier   = "ai-agent-api"
    engine = "tool-using-research-agent"
  }

  depends_on = [
    google_project_service.platform_apis["run.googleapis.com"],
  ]
}

module "p10_trading_analyst" {
  source = "../modules/cloud-run-service"

  project_id             = var.project_id
  region                 = var.region
  service_name           = "p10-trading-analyst"
  repo_name              = local.workload_db_secret_bindings.p10.repo_name
  image                  = local.p10_trading_analyst_image_uri
  port                   = 8080
  cpu                    = "1"
  memory                 = "512Mi"
  min_instance_count     = 0
  max_instance_count     = 1
  concurrency            = 20
  timeout_seconds        = 60
  allow_public_invoker   = true
  health_check_path      = "/health"
  cicd_deployer_sa_email = google_service_account.cicd_deployer.email

  env_vars = merge(
    local.workload_db_secret_bindings.p10.env_vars,
    local.agent_llm_budget_guardrails,
    {
      PGVECTOR_ENABLED    = "true"
      PGVECTOR_DIMENSIONS = "1536"
      TRADING_MODE        = "paper"
      RESEARCH_AGENT_URL  = module.p09_research_agent.service_uri
      ARTIFACTS_BUCKET    = google_storage_bucket.artifacts.name
      ARTIFACTS_PREFIX    = "p10/backtest_traces"
    },
  )

  secret_env_vars = merge(
    local.workload_db_secret_bindings.p10.secret_env_vars,
    local.agent_shared_secrets,
  )

  storage_bucket_roles = {
    artifacts_traces = {
      bucket = google_storage_bucket.artifacts.name
      role   = "roles/storage.objectUser"
    }
  }

  labels = {
    tier   = "ai-agent-api"
    engine = "react-paper-trading-agent"
  }

  depends_on = [
    google_project_service.platform_apis["run.googleapis.com"],
  ]
}

module "p11_multi_agent" {
  source = "../modules/cloud-run-service"

  project_id             = var.project_id
  region                 = var.region
  service_name           = "p11-multi-agent"
  repo_name              = "multi-agent-market-intelligence"
  image                  = local.p11_multi_agent_image_uri
  port                   = 8000
  cpu                    = "1"
  memory                 = "512Mi"
  min_instance_count     = 0
  max_instance_count     = 1
  concurrency            = 20
  timeout_seconds        = 60
  allow_public_invoker   = true
  health_check_path      = "/health"
  cicd_deployer_sa_email = google_service_account.cicd_deployer.email

  env_vars = merge(
    local.agent_llm_budget_guardrails,
    {
      RESEARCH_AGENT_URL = module.p09_research_agent.service_uri
      TRADING_AGENT_URL  = module.p10_trading_analyst.service_uri
      MARKET_INTEL_URL   = module.p08_market_intel.service_uri
      DOCS_RAG_URL       = module.p07_docs_rag.service_uri
    },
  )

  secret_env_vars = merge(
    local.agent_shared_secrets,
    {
      APP_SIGNING_KEY = {
        secret_id = google_secret_manager_secret.catalog["portfolio-app-signing-keys"].secret_id
        version   = "latest"
      }
    },
  )

  labels = {
    tier   = "ai-agent-capstone"
    engine = "langgraph-multi-agent"
  }

  depends_on = [
    google_project_service.platform_apis["run.googleapis.com"],
  ]
}
