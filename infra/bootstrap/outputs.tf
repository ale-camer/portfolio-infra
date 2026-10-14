output "tfstate_bucket_name" {
  description = "Name of the versioned GCS bucket storing remote Terraform state for infra/platform."
  value       = google_storage_bucket.tfstate.name
}

output "tfstate_bucket_url" {
  description = "gs:// URI of the versioned GCS Terraform state bucket."
  value       = google_storage_bucket.tfstate.url
}

output "backend_config_snippet" {
  description = "Ready-to-use GCS backend configuration snippet for infra/platform/versions.tf."
  value       = <<-EOT
    backend "gcs" {
      bucket = "${google_storage_bucket.tfstate.name}"
      prefix = "platform/${var.environment}"
    }
  EOT
}
