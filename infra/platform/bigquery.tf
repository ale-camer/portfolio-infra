locals {
  bigquery_datasets = {
    crypto_market_data = {
      description                   = "P-02 (crypto-lakehouse-etl) raw and curated OHLCV market data tables."
      workload                      = "p02-crypto-lakehouse-etl"
      default_partition_expiry_days = 90
    }
    raw_prod = {
      description                   = "P-05 (fintech-data-warehouse) raw ingested fintech operational tables."
      workload                      = "p05-fintech-data-warehouse"
      default_partition_expiry_days = 90
    }
    staging_prod = {
      description                   = "P-05 (fintech-data-warehouse) dbt staging views and intermediate tables."
      workload                      = "p05-fintech-data-warehouse"
      default_partition_expiry_days = 60
    }
    marts_prod = {
      description                   = "P-05 (fintech-data-warehouse) dbt dimensional marts and BI reporting tables."
      workload                      = "p05-fintech-data-warehouse"
      default_partition_expiry_days = 180
    }
  }
}

resource "google_bigquery_dataset" "datasets" {
  # checkov:skip=CKV_GCP_15:Dataset-level IAM bindings are managed via least-privilege workload service accounts and project-level bindings rather than broad primitive roles.
  # checkov:skip=CKV_GCP_81:Cloud KMS customer-managed encryption keys (CMEK) incur monthly key-version fees; Google-managed encryption at rest is free under the < $10/month budget.
  for_each = local.bigquery_datasets

  project                         = var.project_id
  dataset_id                      = each.key
  friendly_name                   = each.key
  description                     = each.value.description
  location                        = var.region
  delete_contents_on_destroy      = false
  default_partition_expiration_ms = each.value.default_partition_expiry_days * 86400000

  labels = merge(local.common_labels, {
    workload = each.value.workload
  })

  depends_on = [
    google_project_service.platform_apis["bigquery.googleapis.com"],
  ]
}
