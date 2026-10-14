output "enabled_apis" {
  description = "Sorted list of GCP service APIs enabled for the portfolio platform."
  value       = sort(keys(google_project_service.platform_apis))
}

output "budget_resource_name" {
  description = "Resource name of the $10/month Cloud Billing Budget guarding the platform."
  value       = google_billing_budget.monthly_cap.name
}

output "budget_notification_channel_id" {
  description = "Cloud Monitoring email notification channel ID attached to budget and operational alerts."
  value       = google_monitoring_notification_channel.budget_email.id
}

output "artifact_registry_url" {
  description = "Base Docker repository URL in Artifact Registry for pushing and pulling portfolio images."
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.portfolio_apps.repository_id}"
}

output "data_lake_bucket_name" {
  description = "Name of the consolidated GCS Standard bucket for raw/staged data lake payloads (30-day retention)."
  value       = google_storage_bucket.data_lake.name
}

output "data_lake_bucket_url" {
  description = "gs:// URI of the consolidated GCS Standard data lake bucket."
  value       = google_storage_bucket.data_lake.url
}

output "artifacts_bucket_name" {
  description = "Name of the consolidated GCS Standard bucket for ML models, reports, and dbt docs (90-day retention)."
  value       = google_storage_bucket.artifacts.name
}

output "artifacts_bucket_url" {
  description = "gs:// URI of the consolidated GCS Standard artifacts bucket."
  value       = google_storage_bucket.artifacts.url
}

output "bigquery_dataset_ids" {
  description = "Map of BigQuery logical keys to provisioned dataset IDs for P-02 and P-05."
  value       = { for k, ds in google_bigquery_dataset.datasets : k => ds.dataset_id }
}

output "secret_manager_secret_ids" {
  description = "Map of logical secret keys to Secret Manager secret_id values for the 6 consolidated portfolio secrets."
  value       = { for k, s in google_secret_manager_secret.catalog : k => s.secret_id }
}

output "secret_manager_secret_names" {
  description = "Map of logical secret keys to fully-qualified Secret Manager resource names (projects/<project>/secrets/<id>)."
  value       = { for k, s in google_secret_manager_secret.catalog : k => s.name }
}

output "wif_pool_name" {
  description = "Fully-qualified resource name of the GitHub Actions Workload Identity Pool."
  value       = google_iam_workload_identity_pool.github.name
}

output "wif_provider_name" {
  description = "Fully-qualified resource name of the GitHub OIDC Workload Identity Pool Provider for google-github-actions/auth@v2."
  value       = google_iam_workload_identity_pool_provider.github_oidc.name
}

output "cicd_deployer_sa_email" {
  description = "Email of the keyless CI/CD deployer service account (sa-cicd-deployer) used by P-01..P-11."
  value       = google_service_account.cicd_deployer.email
}

output "infra_terraform_sa_email" {
  description = "Email of the keyless Terraform CI service account (sa-infra-terraform) used by portfolio-infra (P-12)."
  value       = google_service_account.infra_terraform.email
}

output "external_database_topology" {
  description = "Canonical connectivity metadata, Secret Manager shell IDs, and scale-to-zero pool settings for Neon PostgreSQL (pgvector), MongoDB Atlas M0, and Upstash Redis."
  value       = local.external_database_topology
}

output "workload_db_secret_bindings" {
  description = "Standardized per-workload database secret_env_vars and connection-pool env_vars map for P-01 through P-10."
  value       = local.workload_db_secret_bindings
}

output "p01_daily_etl_job_name" {
  description = "Provisioned Cloud Run v2 Job name for P-01 (financial-markets-pipeline)."
  value       = module.p01_daily_etl.job_name
}

output "p01_daily_etl_sa_email" {
  description = "Dedicated least-privilege runtime Service Account email for the P-01 daily ETL Cloud Run Job."
  value       = module.p01_daily_etl.service_account_email
}

output "p01_daily_etl_scheduler_name" {
  description = "Cloud Scheduler job name triggering P-01 daily ETL on weekdays after US market close (0 22 * * 1-5 UTC)."
  value       = module.p01_daily_etl.scheduler_job_name
}

output "p02_crypto_etl_job_name" {
  description = "Provisioned Cloud Run v2 Job name for P-02 (crypto-analytics-platform)."
  value       = module.p02_crypto_etl.job_name
}

output "p02_crypto_etl_sa_email" {
  description = "Dedicated least-privilege runtime Service Account email for the P-02 Polars lakehouse ETL Cloud Run Job."
  value       = module.p02_crypto_etl.service_account_email
}

output "p02_crypto_etl_scheduler_name" {
  description = "Cloud Scheduler job name triggering P-02 crypto lakehouse ETL daily at 01:00 UTC (0 1 * * *)."
  value       = module.p02_crypto_etl.scheduler_job_name
}

output "p03_market_events_service_name" {
  description = "Provisioned Cloud Run v2 Service name for P-03 (real-time-market-events)."
  value       = module.p03_market_events.service_name
}

output "p03_market_events_service_url" {
  description = "Public HTTPS URL of the P-03 market events Cloud Run v2 Service."
  value       = module.p03_market_events.service_uri
}

output "p03_market_events_sa_email" {
  description = "Dedicated least-privilege runtime Service Account email for the P-03 Cloud Run Service."
  value       = module.p03_market_events.service_account_email
}

output "p03_pubsub_topic_name" {
  description = "Primary Cloud Pub/Sub topic name replacing Apache Kafka for P-03 market events."
  value       = module.p03_market_events_pubsub.topic_name
}

output "p03_pubsub_subscription_name" {
  description = "Primary Cloud Pub/Sub pull subscription name for P-03 market events."
  value       = module.p03_market_events_pubsub.subscription_name
}







