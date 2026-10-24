variable "project_id" {
  description = "GCP Project ID hosting the Financial Markets Intelligence Platform (e.g., portfolio-platform-000000)."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.project_id))
    error_message = "project_id must be a valid GCP project ID (6-30 lowercase letters, digits, or hyphens)."
  }
}

variable "region" {
  description = "Primary GCP region for all portfolio resources (Always Free eligible US region)."
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

variable "billing_account_id" {
  description = "GCP Billing Account ID (format: XXXXXX-XXXXXX-XXXXXX) used to attach the $10/month budget."
  type        = string

  validation {
    condition     = can(regex("^[0-9A-F]{6}-[0-9A-F]{6}-[0-9A-F]{6}$", upper(var.billing_account_id)))
    error_message = "billing_account_id must match the 18-character hex GCP Billing Account format XXXXXX-XXXXXX-XXXXXX."
  }
}

variable "alert_email" {
  description = "Email address that receives Cloud Billing Budget and Cloud Monitoring alert notifications."
  type        = string

  validation {
    condition     = can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", var.alert_email))
    error_message = "alert_email must be a valid email address."
  }
}

variable "github_owner" {
  description = "GitHub organization or user owning the P-01..P-12 repositories for Workload Identity Federation."
  type        = string
  default     = "ale-camer"

  validation {
    condition     = can(regex("^[A-Za-z0-9-]+$", var.github_owner))
    error_message = "github_owner must be a valid GitHub username or organization slug."
  }
}

variable "monthly_budget_usd" {
  description = "Hard monthly GCP spend budget in USD (must be between 1 and 10 USD)."
  type        = number
  default     = 10

  validation {
    condition     = var.monthly_budget_usd >= 1 && var.monthly_budget_usd <= 10 && floor(var.monthly_budget_usd) == var.monthly_budget_usd
    error_message = "monthly_budget_usd must be a whole integer between 1 and 10 USD to enforce the < $10/month platform ceiling."
  }
}

variable "p01_image_tag" {
  description = "Container image tag or immutable commit SHA deployed for the P-01 daily ETL Cloud Run Job."
  type        = string
  default     = "latest"

  validation {
    condition     = length(trimspace(var.p01_image_tag)) > 0
    error_message = "p01_image_tag must be a non-empty tag or commit SHA."
  }
}

variable "p02_image_tag" {
  description = "Container image tag or immutable commit SHA deployed for the P-02 crypto lakehouse ETL Cloud Run Job."
  type        = string
  default     = "latest"

  validation {
    condition     = length(trimspace(var.p02_image_tag)) > 0
    error_message = "p02_image_tag must be a non-empty tag or commit SHA."
  }
}

variable "p03_image_tag" {
  description = "Container image tag or immutable commit SHA deployed for the P-03 market events Cloud Run Service."
  type        = string
  default     = "latest"

  validation {
    condition     = length(trimspace(var.p03_image_tag)) > 0
    error_message = "p03_image_tag must be a non-empty tag or commit SHA."
  }
}

variable "p05_image_tag" {
  description = "Container image tag or immutable commit SHA deployed for the P-05 intelligence hub API and dbt Cloud Run Job."
  type        = string
  default     = "latest"

  validation {
    condition     = length(trimspace(var.p05_image_tag)) > 0
    error_message = "p05_image_tag must be a non-empty tag or commit SHA."
  }
}

variable "p06_image_tag" {
  description = "Container image tag or immutable commit SHA deployed for the P-06 anomaly inference API and training/drift Cloud Run Job."
  type        = string
  default     = "latest"

  validation {
    condition     = length(trimspace(var.p06_image_tag)) > 0
    error_message = "p06_image_tag must be a non-empty tag or commit SHA."
  }
}

variable "p07_image_tag" {
  description = "Container image tag or immutable commit SHA deployed for the P-07 SEC documents hybrid RAG Cloud Run Service."
  type        = string
  default     = "latest"

  validation {
    condition     = length(trimspace(var.p07_image_tag)) > 0
    error_message = "p07_image_tag must be a non-empty tag or commit SHA."
  }
}

variable "p08_image_tag" {
  description = "Container image tag or immutable commit SHA deployed for the P-08 E2E AI signal API and NLP worker Cloud Run Job."
  type        = string
  default     = "latest"

  validation {
    condition     = length(trimspace(var.p08_image_tag)) > 0
    error_message = "p08_image_tag must be a non-empty tag or commit SHA."
  }
}

variable "p09_image_tag" {
  description = "Container image tag or immutable commit SHA deployed for the P-09 tool-using financial research agent Cloud Run Service."
  type        = string
  default     = "latest"

  validation {
    condition     = length(trimspace(var.p09_image_tag)) > 0
    error_message = "p09_image_tag must be a non-empty tag or commit SHA."
  }
}

variable "p10_image_tag" {
  description = "Container image tag or immutable commit SHA deployed for the P-10 autonomous ReAct paper-trading agent Cloud Run Service."
  type        = string
  default     = "latest"

  validation {
    condition     = length(trimspace(var.p10_image_tag)) > 0
    error_message = "p10_image_tag must be a non-empty tag or commit SHA."
  }
}

variable "p11_image_tag" {
  description = "Container image tag or immutable commit SHA deployed for the P-11 multi-agent LangGraph market intelligence Cloud Run Service."
  type        = string
  default     = "latest"

  validation {
    condition     = length(trimspace(var.p11_image_tag)) > 0
    error_message = "p11_image_tag must be a non-empty tag or commit SHA."
  }
}

variable "enable_uptime_checks" {
  description = "Whether to provision 15-minute (900s) Cloud Monitoring HTTPS /health uptime checks across deployed Cloud Run Services. Set to false during extended hibernation to avoid periodic cold-start invocations."
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "Retention period in days for the Cloud Logging _Default bucket (1 to 30 days; default 7 days to stay strictly within the 50 GiB/month Free Tier)."
  type        = number
  default     = 7

  validation {
    condition     = var.log_retention_days >= 1 && var.log_retention_days <= 30 && floor(var.log_retention_days) == var.log_retention_days
    error_message = "log_retention_days must be a whole integer between 1 and 30 days."
  }
}









