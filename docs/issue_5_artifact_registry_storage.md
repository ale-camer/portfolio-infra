# Issue 5: Provision Artifact Registry with Cleanup Policies, Shared GCS Buckets, and BigQuery Datasets

**Branch**: `feature/issue-5-artifact-registry-storage`
**Status**: Done
**PR**: opened by `make finish-issue` → `develop` (Closes #5)
**Milestone**: M2 - Foundations

## Objective
Provision the shared container registry, object storage, and analytical warehouse foundation in `infra/platform/`: a single Docker Artifact Registry (`portfolio-apps`) with automated cleanup policies (retaining the latest 3 tagged images per package and purging untagged images after 7 days), consolidated GCS Standard buckets (`<project_id>-data-lake` and `<project_id>-artifacts`) with UBLA, public access prevention, versioning, and 30–90 day lifecycle rules, and BigQuery datasets for `P-02` (`crypto_market_data`) and `P-05` (`raw_prod`, `staging_prod`, `marts_prod`).

## Acceptance Criteria
- [x] `infra/platform/artifact_registry.tf` provisions `google_artifact_registry_repository.portfolio_apps` (`format = "DOCKER"`, `location = var.region`) with `cleanup_policies` keeping the 3 most recent versions and deleting untagged/older artifacts after 7 days
- [x] `infra/platform/storage.tf` provisions hardened GCS Standard buckets (`<project_id>-data-lake` and `<project_id>-artifacts`) in `us-central1` with `uniform_bucket_level_access = true`, `public_access_prevention = "enforced"`, versioning, lifecycle cleanup rules (30–90 days), and documented Checkov skip justifications
- [x] `infra/platform/bigquery.tf` provisions the 4 BigQuery datasets required by `P-02` (`crypto_market_data`) and `P-05` (`raw_prod`, `staging_prod`, `marts_prod`) in `us-central1` with partition expiration guardrails and portfolio labels
- [x] `infra/platform/outputs.tf` exports the Artifact Registry repository URL, GCS bucket names/URLs, and BigQuery dataset IDs with descriptions
- [x] `make check` passes (`fmt-check`, `validate`, `tflint`, `shellcheck`, and `checkov` with zero failed checks)

## Implementation Tasks

### 1. Preparation & Branching
```bash
make start-issue ID=5 NAME=artifact-registry-storage
```

### 2. Provision Docker Artifact Registry with Cleanup Policies (`infra/platform/artifact_registry.tf`)
- **File**: `infra/platform/artifact_registry.tf`
- **Change**: Create `google_artifact_registry_repository.portfolio_apps` (`repository_id = "portfolio-apps"`, `format = "DOCKER"`, `location = var.region`, `cleanup_policy_dry_run = false`) with two `cleanup_policies`: `delete-untagged-7d` (`tag_state = "UNTAGGED"`, `older_than = "604800s"`) and `keep-recent-3-versions` (`action = "KEEP"`, `most_recent_versions { keep_count = 3 }`), plus `delete-old-tagged-30d` (`tag_state = "ANY"`, `older_than = "2592000s"`). Include documented Checkov justification for using free Google-managed encryption (`CKV_GCP_84`) instead of paid Cloud KMS keys.

### 3. Provision Consolidated GCS Data Lake & Artifacts Buckets (`infra/platform/storage.tf`)
- **File**: `infra/platform/storage.tf`
- **Change**: Create `google_storage_bucket.data_lake` (`${var.project_id}-data-lake`, 30-day raw object lifecycle + 7-day noncurrent cleanup) and `google_storage_bucket.artifacts` (`${var.project_id}-artifacts`, 90-day artifact lifecycle + 7-day noncurrent cleanup) in `us-central1` (`STANDARD`, `uniform_bucket_level_access = true`, `public_access_prevention = "enforced"`, `versioning { enabled = true }`), consolidating storage for `P-01`, `P-02`, `P-05`, `P-06`, `P-08`, `P-09`, and `P-10`.

### 4. Provision BigQuery Analytical Datasets & Export Outputs (`infra/platform/bigquery.tf` & `outputs.tf`)
- **File**: `infra/platform/bigquery.tf`, `infra/platform/outputs.tf`
- **Change**: Create `google_bigquery_dataset.datasets` via `for_each` for `crypto_market_data` (`P-02`), `raw_prod` (`P-05`), `staging_prod` (`P-05`), and `marts_prod` (`P-05`) in `us-central1` with `delete_contents_on_destroy = false` and standard portfolio labels (skipping paid CMEK `CKV_GCP_80` with justification). Update `infra/platform/outputs.tf` to export `artifact_registry_url`, `data_lake_bucket_name`, `artifacts_bucket_name`, and `bigquery_dataset_ids`.

### 5. Verification & Quality Gates
```bash
make check
```

### 6. Git & Issue Finish
```bash
make finish-issue ID=5 MSG="feat(platform): provision Artifact Registry, GCS buckets, and BigQuery datasets"
```

## Decisions
- **Consolidate portfolio object storage into two shared buckets (`data-lake` and `artifacts`)**: Rather than creating 7 separate buckets across `P-01`–`P-10`, two shared buckets in `us-central1` with per-repo prefix conventions (`p01/`, `p02/`, `p05/`, `p06/`, `p08/`, `p09/`, `p10/`) and 30–90 day lifecycle rules keep total storage within the 5 GB GCS Standard Free Tier (~$0.12/mo).
- **Use Google-managed encryption (GMEK) on Artifact Registry and BigQuery (`CKV_GCP_84`, `CKV_GCP_80`)**: Customer-managed encryption keys (CMEK) in Cloud KMS add fixed monthly per-key-version fees across every service; default Google-managed AES-256 encryption provides encryption at rest at `$0.00/month`.
