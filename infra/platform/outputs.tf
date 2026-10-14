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


