output "job_name" {
  description = "Name of the provisioned Cloud Run v2 job."
  value       = google_cloud_run_v2_job.job.name
}

output "job_id" {
  description = "Fully-qualified Terraform resource ID of the Cloud Run v2 job."
  value       = google_cloud_run_v2_job.job.id
}

output "service_account_email" {
  description = "Email of the dedicated least-privilege runtime service account for this Cloud Run job."
  value       = google_service_account.runtime.email
}

output "scheduler_job_name" {
  description = "Name of the optional Cloud Scheduler job triggering this Cloud Run job (null when schedule_cron is unset)."
  value       = local.enable_scheduler ? google_cloud_scheduler_job.trigger[0].name : null
}
