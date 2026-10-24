output "service_name" {
  description = "Name of the provisioned Cloud Run v2 service."
  value       = google_cloud_run_v2_service.service.name
}

output "service_id" {
  description = "Fully-qualified Terraform resource ID of the Cloud Run v2 service."
  value       = google_cloud_run_v2_service.service.id
}

output "service_uri" {
  description = "Public HTTPS URI assigned to the Cloud Run v2 service."
  value       = google_cloud_run_v2_service.service.uri
}

output "service_account_email" {
  description = "Email of the dedicated least-privilege runtime service account for this Cloud Run service."
  value       = google_service_account.runtime.email
}
