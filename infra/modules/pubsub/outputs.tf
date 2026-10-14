output "topic_name" {
  description = "Name of the primary Pub/Sub topic."
  value       = google_pubsub_topic.topic.name
}

output "topic_id" {
  description = "Fully-qualified Terraform resource ID of the primary Pub/Sub topic."
  value       = google_pubsub_topic.topic.id
}

output "subscription_name" {
  description = "Name of the primary Pub/Sub pull subscription."
  value       = google_pubsub_subscription.subscription.name
}

output "subscription_id" {
  description = "Fully-qualified Terraform resource ID of the primary Pub/Sub pull subscription."
  value       = google_pubsub_subscription.subscription.id
}

output "dlq_topic_name" {
  description = "Name of the companion Dead-Letter Queue (DLQ) topic (null when enable_dlq is false)."
  value       = var.enable_dlq ? google_pubsub_topic.dlq[0].name : null
}

output "dlq_topic_id" {
  description = "Fully-qualified Terraform resource ID of the companion DLQ topic (null when enable_dlq is false)."
  value       = var.enable_dlq ? google_pubsub_topic.dlq[0].id : null
}

output "dlq_subscription_name" {
  description = "Name of the companion DLQ pull subscription (null when enable_dlq is false)."
  value       = var.enable_dlq ? google_pubsub_subscription.dlq[0].name : null
}
