terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }

  # Stage 2 remote state stored in the versioned GCS bucket provisioned by infra/bootstrap.
  # Initialize with: terraform -chdir=infra/platform init -backend-config="bucket=<project_id>-tfstate"
  backend "gcs" {
    prefix = "platform/prod"
  }
}

provider "google" {
  project               = var.project_id
  region                = var.region
  billing_project       = var.project_id
  user_project_override = true
}
