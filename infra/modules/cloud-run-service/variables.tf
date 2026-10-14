variable "project_id" {
  description = "GCP Project ID hosting the Cloud Run v2 service."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.project_id))
    error_message = "project_id must be a valid GCP project ID."
  }
}

variable "region" {
  description = "GCP region for the Cloud Run v2 service (Always Free eligible us-central1)."
  type        = string
  default     = "us-central1"

  validation {
    condition     = var.region == "us-central1"
    error_message = "region must be 'us-central1' per ADR-001."
  }
}

variable "service_name" {
  description = "Cloud Run v2 service name (e.g., p09-credit-risk-api)."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,48}[a-z0-9]$", var.service_name))
    error_message = "service_name must be 3-50 lowercase alphanumeric characters or hyphens."
  }
}

variable "repo_name" {
  description = "Source GitHub repository slug (e.g., credit-risk-mlops) used for resource labeling."
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

variable "port" {
  description = "Container HTTP listening port exposed to the Cloud Run ingress proxy."
  type        = number
  default     = 8000

  validation {
    condition     = var.port >= 1 && var.port <= 65535
    error_message = "port must be a valid TCP port between 1 and 65535."
  }
}

variable "cpu" {
  description = "vCPU limit per container instance ('1' or '2')."
  type        = string
  default     = "1"

  validation {
    condition     = contains(["1", "2"], var.cpu)
    error_message = "cpu must be '1' or '2' to remain within Cloud Run Always Free guardrails."
  }
}

variable "memory" {
  description = "Memory limit per container instance ('256Mi', '512Mi', '1Gi', or '2Gi')."
  type        = string
  default     = "512Mi"

  validation {
    condition     = contains(["256Mi", "512Mi", "1Gi", "2Gi"], var.memory)
    error_message = "memory must be one of '256Mi', '512Mi', '1Gi', or '2Gi'."
  }
}

variable "min_instance_count" {
  description = "Minimum warm instance count (strictly locked to 0 for scale-to-zero cost control per ADR-003)."
  type        = number
  default     = 0

  validation {
    condition     = var.min_instance_count == 0
    error_message = "min_instance_count must be 0 so all Cloud Run services scale to zero when idle (ADR-003)."
  }
}

variable "max_instance_count" {
  description = "Maximum auto-scaled instance count (hard capped at 2 to prevent runaway spend)."
  type        = number
  default     = 2

  validation {
    condition     = var.max_instance_count >= 1 && var.max_instance_count <= 2
    error_message = "max_instance_count must be between 1 and 2 per ADR-003."
  }
}

variable "concurrency" {
  description = "Maximum concurrent requests per Cloud Run container instance."
  type        = number
  default     = 80

  validation {
    condition     = var.concurrency >= 1 && var.concurrency <= 250
    error_message = "concurrency must be between 1 and 250."
  }
}

variable "timeout_seconds" {
  description = "Maximum request execution timeout in seconds."
  type        = number
  default     = 60

  validation {
    condition     = var.timeout_seconds >= 5 && var.timeout_seconds <= 900
    error_message = "timeout_seconds must be between 5 and 900 seconds."
  }
}

variable "allow_public_invoker" {
  description = "Whether to grant roles/run.invoker to allUsers for public portfolio showcase endpoints."
  type        = bool
  default     = true
}

variable "env_vars" {
  description = "Plaintext non-sensitive environment variables injected into the container."
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

variable "health_check_path" {
  description = "HTTP GET path used by Cloud Run startup and liveness probes."
  type        = string
  default     = "/health"

  validation {
    condition     = startswith(var.health_check_path, "/")
    error_message = "health_check_path must start with '/'."
  }
}

variable "cicd_deployer_sa_email" {
  description = "Optional email of sa-cicd-deployer to grant roles/iam.serviceAccountUser on the runtime SA."
  type        = string
  default     = ""
}

variable "storage_bucket_roles" {
  description = "Map of binding keys to GCS bucket IAM grants ({ bucket, role }) for the runtime SA."
  type = map(object({
    bucket = string
    role   = string
  }))
  default = {}
}

variable "bigquery_dataset_roles" {
  description = "Map of binding keys to BigQuery dataset IAM grants ({ dataset_id, role }) for the runtime SA."
  type = map(object({
    dataset_id = string
    role       = string
  }))
  default = {}
}

variable "labels" {
  description = "Additional resource labels merged onto the Cloud Run v2 service."
  type        = map(string)
  default     = {}
}
