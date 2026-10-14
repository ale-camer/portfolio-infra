terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }

  # Stage 1 bootstrap uses local state once to create the remote GCS state bucket
  # consumed by Stage 2 (infra/platform).
  backend "local" {}
}

provider "google" {
  project = var.project_id
  region  = var.region
}
