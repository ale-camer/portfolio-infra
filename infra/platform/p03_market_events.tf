locals {
  p03_image_uri         = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.portfolio_apps.repository_id}/p03-market-events:${var.p03_image_tag}"
  p03_topic_name        = "p03-market-events-raw"
  p03_subscription_name = "p03-market-events-raw-sub"
}

module "p03_market_events" {
  source = "../modules/cloud-run-service"

  project_id             = var.project_id
  region                 = var.region
  service_name           = "p03-market-events"
  repo_name              = local.workload_db_secret_bindings.p03.repo_name
  image                  = local.p03_image_uri
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
    local.workload_db_secret_bindings.p03.env_vars,
    {
      ENVIRONMENT            = var.environment
      GCP_PROJECT_ID         = var.project_id
      GCP_REGION             = var.region
      STREAMING_BACKEND      = "pubsub"
      PUBSUB_TOPIC_ID        = local.p03_topic_name
      PUBSUB_SUBSCRIPTION_ID = local.p03_subscription_name
      PUBSUB_DLQ_TOPIC_ID    = "${local.p03_topic_name}-dlq"
      LOG_LEVEL              = "INFO"
    },
  )

  secret_env_vars = merge(
    local.workload_db_secret_bindings.p03.secret_env_vars,
    {
      MARKET_API_KEYS = {
        secret_id = google_secret_manager_secret.catalog["portfolio-market-api-keys"].secret_id
        version   = "latest"
      }
    },
  )

  labels = {
    tier      = "event-streaming-api"
    messaging = "pubsub"
  }

  depends_on = [
    google_project_service.platform_apis["run.googleapis.com"],
  ]
}

module "p03_market_events_pubsub" {
  source = "../modules/pubsub"

  project_id                 = var.project_id
  topic_name                 = local.p03_topic_name
  subscription_name          = local.p03_subscription_name
  repo_name                  = local.workload_db_secret_bindings.p03.repo_name
  message_retention_duration = "86400s"
  ack_deadline_seconds       = 30
  max_delivery_attempts      = 5
  enable_dlq                 = true
  minimum_backoff            = "10s"
  maximum_backoff            = "300s"

  publisher_sa_emails  = [module.p03_market_events.service_account_email]
  subscriber_sa_emails = [module.p03_market_events.service_account_email]

  labels = {
    tier = "event-bus"
  }

  depends_on = [
    google_project_service.platform_apis["pubsub.googleapis.com"],
  ]
}
