locals {
  # Consolidated 6-secret catalog (ADR-004 & docs/inventory.md Section 3).
  # Only secret shell containers are managed in Terraform; payload versions are
  # injected out-of-band via `gcloud secrets versions add <secret_id> --data-file=-`.
  portfolio_secrets = {
    portfolio-llm-api-key = {
      secret_domain = "llm-inference"
      consumers     = "p01-p03-p08"
    }
    portfolio-postgres-url = {
      secret_domain = "relational-db"
      consumers     = "p01-p03-p05-p06-p07-p09"
    }
    portfolio-market-api-keys = {
      secret_domain = "market-data"
      consumers     = "p01-p02-p03"
    }
    portfolio-news-social-keys = {
      secret_domain = "news-sentiment"
      consumers     = "p01-p07"
    }
    portfolio-nosql-cache-urls = {
      secret_domain = "nosql-cache"
      consumers     = "p01-p07"
    }
    portfolio-app-signing-keys = {
      secret_domain = "app-auth-alerts"
      consumers     = "p06-p11"
    }
  }
}

resource "google_secret_manager_secret" "catalog" {
  # checkov:skip=CKV_GCP_114:Cloud KMS customer-managed encryption keys (CMEK) incur monthly key-version fees; Google-managed AES-256 encryption at rest in us-central1 keeps all 6 secrets inside the $0.00/month Free Tier.
  for_each = local.portfolio_secrets

  project   = var.project_id
  secret_id = each.key

  labels = merge(local.common_labels, {
    secret_domain = each.value.secret_domain
    consumers     = each.value.consumers
  })

  replication {
    user_managed {
      replicas {
        location = var.region
      }
    }
  }

  depends_on = [
    google_project_service.platform_apis["secretmanager.googleapis.com"],
  ]
}
