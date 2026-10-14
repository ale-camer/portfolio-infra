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
