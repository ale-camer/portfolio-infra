variable "project_id" {
  description = "GCP Project ID hosting the Pub/Sub topic, pull subscription, and optional Dead-Letter Queue (DLQ)."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.project_id))
    error_message = "project_id must be a valid GCP project ID."
  }
}

variable "topic_name" {
  description = "Primary Pub/Sub topic name (e.g., p11-trading-signals)."
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9-_~+.%]{2,254}$", var.topic_name))
    error_message = "topic_name must be a valid GCP Pub/Sub topic identifier (3-255 characters)."
  }
}

variable "repo_name" {
  description = "Source GitHub repository slug (e.g., trading-signals-Kafka) used for resource labeling."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9_-]+$", var.repo_name))
    error_message = "repo_name must be a valid repository slug."
  }
}

variable "subscription_name" {
  description = "Primary pull subscription name (e.g., p11-trading-signals-sub)."
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9-_~+.%]{2,254}$", var.subscription_name))
    error_message = "subscription_name must be a valid GCP Pub/Sub subscription identifier (3-255 characters)."
  }
}

variable "message_retention_duration" {
  description = "Duration to retain unacknowledged messages on the subscription and topic (up to 7 days / 604800s)."
  type        = string
  default     = "86400s"

  validation {
    condition     = contains(["3600s", "21600s", "43200s", "86400s", "172800s", "604800s"], var.message_retention_duration)
    error_message = "message_retention_duration must be one of 3600s (1h), 21600s (6h), 43200s (12h), 86400s (24h), 172800s (48h), or 604800s (7d) to stay within Pub/Sub Free Tier storage limits."
  }
}

variable "ack_deadline_seconds" {
  description = "Maximum time in seconds for a subscriber to acknowledge a message before redelivery."
  type        = number
  default     = 30

  validation {
    condition     = var.ack_deadline_seconds >= 10 && var.ack_deadline_seconds <= 600
    error_message = "ack_deadline_seconds must be between 10 and 600 seconds."
  }
}

variable "max_delivery_attempts" {
  description = "Maximum delivery attempts before forwarding an unacknowledged message to the Dead-Letter Queue (5-20)."
  type        = number
  default     = 5

  validation {
    condition     = var.max_delivery_attempts >= 5 && var.max_delivery_attempts <= 20 && floor(var.max_delivery_attempts) == var.max_delivery_attempts
    error_message = "max_delivery_attempts must be an integer between 5 and 20 (GCP Pub/Sub DLQ constraint)."
  }
}

variable "enable_dlq" {
  description = "Whether to provision a companion Dead-Letter Queue topic (<topic_name>-dlq) and pull subscription (<subscription_name>-dlq-sub)."
  type        = bool
  default     = true
}

variable "minimum_backoff" {
  description = "Minimum exponential backoff duration between redelivery attempts (e.g., 10s)."
  type        = string
  default     = "10s"

  validation {
    condition     = can(regex("^[0-9]+s$", var.minimum_backoff))
    error_message = "minimum_backoff must be formatted in seconds (e.g., '10s')."
  }
}

variable "maximum_backoff" {
  description = "Maximum exponential backoff duration between redelivery attempts (e.g., 300s)."
  type        = string
  default     = "300s"

  validation {
    condition     = can(regex("^[0-9]+s$", var.maximum_backoff))
    error_message = "maximum_backoff must be formatted in seconds (e.g., '300s')."
  }
}

variable "publisher_sa_emails" {
  description = "Set of service account emails granted roles/pubsub.publisher on the primary topic."
  type        = set(string)
  default     = []
}

variable "subscriber_sa_emails" {
  description = "Set of service account emails granted roles/pubsub.subscriber on the primary subscription."
  type        = set(string)
  default     = []
}

variable "labels" {
  description = "Additional resource labels merged onto the Pub/Sub topics and subscriptions."
  type        = map(string)
  default     = {}
}
