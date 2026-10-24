variable "project_id" {
  description = "GCP Project ID hosting the Financial Markets Intelligence Platform (e.g., portfolio-platform-000000)."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.project_id))
    error_message = "project_id must be a valid GCP project ID (6-30 lowercase letters, digits, or hyphens)."
  }
}

variable "region" {
  description = "Primary GCP region for the Terraform state bucket (Always Free eligible US region)."
  type        = string
  default     = "us-central1"

  validation {
    condition     = var.region == "us-central1"
    error_message = "region must be 'us-central1' per ADR-001 to stay within GCP Always Free regional quotas."
  }
}

variable "environment" {
  description = "Deployment environment label (single prod environment per ADR-001)."
  type        = string
  default     = "prod"

  validation {
    condition     = var.environment == "prod"
    error_message = "environment must be 'prod' per ADR-001."
  }
}
