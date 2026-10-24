variable "project_id" {
  description = "GCP Project ID hosting the Cloud Run v2 job and optional Cloud Scheduler trigger."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.project_id))
    error_message = "project_id must be a valid GCP project ID."
  }
}

variable "region" {
  description = "GCP region for the Cloud Run v2 job and Cloud Scheduler job (Always Free eligible us-central1)."
  type        = string
  default     = "us-central1"

  validation {
    condition     = var.region == "us-central1"
    error_message = "region must be 'us-central1' per ADR-001."
  }
}

variable "job_name" {
  description = "Cloud Run v2 job name (e.g., p11-trading-signals-job)."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,48}[a-z0-9]$", var.job_name))
    error_message = "job_name must be 3-50 lowercase alphanumeric characters or hyphens."
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

variable "image" {
  description = "Full Artifact Registry container image URI with immutable SHA or release tag."
  type        = string

  validation {
    condition     = length(trimspace(var.image)) > 0
    error_message = "image must be a non-empty container image URI."
  }
}

variable "command" {
  description = "Optional container entrypoint command override."
  type        = list(string)
  default     = null
}

variable "args" {
  description = "Optional container entrypoint arguments override."
  type        = list(string)
  default     = null
}

variable "cpu" {
  description = "vCPU limit per job task container ('1' or '2')."
  type        = string
  default     = "1"

  validation {
    condition     = contains(["1", "2"], var.cpu)
    error_message = "cpu must be '1' or '2' to remain within Cloud Run Always Free guardrails."
  }
}

variable "memory" {
  description = "Memory limit per job task container ('256Mi', '512Mi', '1Gi', or '2Gi')."
  type        = string
  default     = "512Mi"

  validation {
    condition     = contains(["256Mi", "512Mi", "1Gi", "2Gi"], var.memory)
    error_message = "memory must be one of '256Mi', '512Mi', '1Gi', or '2Gi'."
  }
}

variable "max_retries" {
  description = "Maximum task retry attempts on failure (capped at 1 to prevent runaway retry loops per ADR-003)."
  type        = number
  default     = 1

  validation {
    condition     = var.max_retries >= 0 && var.max_retries <= 1 && floor(var.max_retries) == var.max_retries
    error_message = "max_retries must be 0 or 1 to prevent retry storms from exhausting the Cloud Run Free Tier."
  }
}

variable "timeout_seconds" {
  description = "Maximum task execution timeout in seconds (10 to 900 seconds)."
  type        = number
  default     = 600

  validation {
    condition     = var.timeout_seconds >= 10 && var.timeout_seconds <= 900
    error_message = "timeout_seconds must be between 10 and 900 seconds."
  }
}

variable "task_count" {
  description = "Number of parallel tasks per job execution (strictly 1 for budget protection)."
  type        = number
  default     = 1

  validation {
    condition     = var.task_count == 1
    error_message = "task_count must be 1 to prevent parallel task fan-out charges."
  }
}

variable "schedule_cron" {
  description = "Optional cron expression for Cloud Scheduler trigger (null disables Scheduler creation)."
  type        = string
  default     = null
}

variable "schedule_timezone" {
  description = "IANA timezone for the optional Cloud Scheduler cron trigger."
  type        = string
  default     = "UTC"
}

variable "schedule_paused" {
  description = "Whether the optional Cloud Scheduler trigger should be created in a paused state."
  type        = bool
  default     = false
}

variable "env_vars" {
  description = "Plaintext non-sensitive environment variables injected into the job container."
  type        = map(string)
  default     = {}
}

variable "secret_env_vars" {
  description = "Map of environment variable names to Secret Manager secret references ({ secret_id, version })."
  type = map(object({
    secret_id = string
    version   = optional(string, "latest")
  }))
  default = {}
}

variable "cicd_deployer_sa_email" {
  description = "Optional email of sa-cicd-deployer to grant roles/iam.serviceAccountUser on the runtime SA."
  type        = string
  default     = ""
}

variable "storage_bucket_roles" {
  description = "Map of binding keys to GCS bucket IAM grants ({ bucket, role }) for the job runtime SA."
  type = map(object({
    bucket = string
    role   = string
  }))
  default = {}
}

variable "bigquery_dataset_roles" {
  description = "Map of binding keys to BigQuery dataset IAM grants ({ dataset_id, role }) for the job runtime SA."
  type = map(object({
    dataset_id = string
    role       = string
  }))
  default = {}
}

variable "pubsub_topic_roles" {
  description = "Map of binding keys to Pub/Sub topic IAM grants ({ topic, role }) for the job runtime SA."
  type = map(object({
    topic = string
    role  = string
  }))
  default = {}
}

variable "pubsub_subscription_roles" {
  description = "Map of binding keys to Pub/Sub subscription IAM grants ({ subscription, role }) for the job runtime SA."
  type = map(object({
    subscription = string
    role         = string
  }))
  default = {}
}

variable "labels" {
  description = "Additional resource labels merged onto the Cloud Run v2 job."
  type        = map(string)
  default     = {}
}
