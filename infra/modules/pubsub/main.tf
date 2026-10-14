locals {
  common_labels = merge(
    {
      project    = "portfolio"
      env        = "prod"
      repo       = lower(replace(var.repo_name, "_", "-"))
      workload   = var.topic_name
      managed_by = "terraform"
    },
    var.labels,
  )

  dlq_topic_name        = "${var.topic_name}-dlq"
  dlq_subscription_name = "${var.subscription_name}-dlq-sub"
}

resource "google_pubsub_topic" "topic" {
  # checkov:skip=CKV_GCP_83:Cloud KMS customer-managed encryption keys (CMEK) incur monthly key-version fees; Google-managed AES-256 encryption at rest keeps Pub/Sub within the 10 GB/month Free Tier ($0.00/mo).
  project                    = var.project_id
  name                       = var.topic_name
  message_retention_duration = var.message_retention_duration
  labels                     = local.common_labels
}

resource "google_pubsub_topic" "dlq" {
  # checkov:skip=CKV_GCP_83:Cloud KMS customer-managed encryption keys (CMEK) incur monthly key-version fees; Google-managed AES-256 encryption at rest keeps Pub/Sub within the 10 GB/month Free Tier ($0.00/mo).
  count = var.enable_dlq ? 1 : 0

  project                    = var.project_id
  name                       = local.dlq_topic_name
  message_retention_duration = "604800s"
  labels                     = merge(local.common_labels, { tier = "dlq" })
}

resource "google_pubsub_subscription" "dlq" {
  count = var.enable_dlq ? 1 : 0

  project                    = var.project_id
  name                       = local.dlq_subscription_name
  topic                      = google_pubsub_topic.dlq[0].id
  ack_deadline_seconds       = 60
  message_retention_duration = "604800s"
  retain_acked_messages      = false
  labels                     = merge(local.common_labels, { tier = "dlq" })

  expiration_policy {
    ttl = ""
  }
}

resource "google_pubsub_subscription" "subscription" {
  project                    = var.project_id
  name                       = var.subscription_name
  topic                      = google_pubsub_topic.topic.id
  ack_deadline_seconds       = var.ack_deadline_seconds
  message_retention_duration = var.message_retention_duration
  retain_acked_messages      = false
  labels                     = local.common_labels

  retry_policy {
    minimum_backoff = var.minimum_backoff
    maximum_backoff = var.maximum_backoff
  }

  dynamic "dead_letter_policy" {
    for_each = var.enable_dlq ? [1] : []
    content {
      dead_letter_topic     = google_pubsub_topic.dlq[0].id
      max_delivery_attempts = var.max_delivery_attempts
    }
  }

  expiration_policy {
    ttl = ""
  }
}

resource "google_pubsub_topic_iam_member" "publishers" {
  for_each = var.publisher_sa_emails

  project = var.project_id
  topic   = google_pubsub_topic.topic.name
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${each.value}"
}

resource "google_pubsub_subscription_iam_member" "subscribers" {
  for_each = var.subscriber_sa_emails

  project      = var.project_id
  subscription = google_pubsub_subscription.subscription.name
  role         = "roles/pubsub.subscriber"
  member       = "serviceAccount:${each.value}"
}
