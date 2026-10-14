# Issue 13: Provision Cloud Run Job + BigQuery/GCS Bindings and Rollout Specification for P-02

**Branch**: `feature/issue-13-rollout-p02-crypto-analytics`
**Status**: Done
**PR**: opened by `make finish-issue` → `develop` (Closes #13)
**Milestone**: M4 - Rollout

## Objective
Provision the serverless Polars lakehouse ETL infrastructure for **P-02 (`crypto-analytics-platform`)** in `infra/platform/p02_crypto_analytics.tf` using the reusable `infra/modules/cloud-run-job` module — configuring `p02-crypto-etl` (`1 vCPU`, `1Gi` RAM for in-memory Polars transformations, `max_retries = 1`, `timeout_seconds = 600`), a daily Cloud Scheduler trigger (`0 1 * * *` UTC), least-privilege BigQuery (`crypto_market_data`), GCS (`<project_id>-data-lake`), and Secret Manager (`portfolio-market-api-keys`) IAM bindings, and the keyless GitHub Actions CD rollout specification.

## Acceptance Criteria
- [x] `infra/platform/variables.tf` defines `p02_image_tag` (defaulting to `"latest"` or immutable release SHA override) for `p02-crypto-etl`
- [x] `infra/platform/p02_crypto_analytics.tf` instantiates `module "p02_crypto_etl"` (`source = "../modules/cloud-run-job"`) with `job_name = "p02-crypto-etl"`, `repo_name = "crypto-analytics-platform"`, `schedule_cron = "0 1 * * *"`, `schedule_timezone = "UTC"`, `cpu = "1"`, `memory = "1Gi"`, `max_retries = 1`, `timeout_seconds = 600`, `storage_bucket_roles` (`roles/storage.objectUser` on `<project_id>-data-lake`), `bigquery_dataset_roles` (`roles/bigquery.dataEditor` on `crypto_market_data`), and `secret_env_vars` bound to `portfolio-market-api-keys`
- [x] `infra/platform/outputs.tf` exports `p02_crypto_etl_job_name`, `p02_crypto_etl_sa_email`, and `p02_crypto_etl_scheduler_name`
- [x] Rollout specification for `P-02` (`crypto-analytics-platform`) is documented in `docs/issue_13_rollout_p02_crypto_analytics.md` (Section `P-02 Rollout & CI/CD Specification`) covering Artifact Registry build/push, WIF OIDC authentication, `gcloud run jobs update`, and smoke verification
- [x] `make check` passes (`fmt-check`, `validate`, `tflint`, `shellcheck`, and `checkov` with zero failed checks)

## Implementation Tasks

### 1. Preparation & Branching
```bash
make start-issue ID=13 NAME=rollout-p02-crypto-analytics
```

### 2. Provision `p02-crypto-etl` Cloud Run Job, Scheduler & BigQuery/GCS/Secret Bindings (`infra/platform/variables.tf`, `infra/platform/p02_crypto_analytics.tf` & `infra/platform/outputs.tf`)
- **File**: `infra/platform/variables.tf`, `infra/platform/p02_crypto_analytics.tf`, `infra/platform/outputs.tf`
- **Change**: Add `p02_image_tag` variable to `infra/platform/variables.tf`. Create `infra/platform/p02_crypto_analytics.tf` invoking `../modules/cloud-run-job` for `p02-crypto-etl` (`1 vCPU`, `1Gi` RAM, schedule `0 1 * * *` UTC), injecting `BQ_DATASET` (`crypto_market_data`), `DATA_LAKE_BUCKET` (`google_storage_bucket.data_lake.name`), `DATA_LAKE_PREFIX = "p02/lakehouse"`, and `MARKET_API_KEYS` (`portfolio-market-api-keys`), plus `roles/storage.objectUser` on `<project_id>-data-lake`, `roles/bigquery.dataEditor` on `crypto_market_data` (plus project-level `roles/bigquery.jobUser`), and `cicd_deployer_sa_email = google_service_account.cicd_deployer.email`. Export `p02_crypto_etl_job_name`, `p02_crypto_etl_sa_email`, and `p02_crypto_etl_scheduler_name` in `infra/platform/outputs.tf`.

### 3. Document P-02 Container & Keyless GitHub Actions Rollout Specification (`docs/issue_13_rollout_p02_crypto_analytics.md`)
- **File**: `docs/issue_13_rollout_p02_crypto_analytics.md`
- **Change**: Add the concrete P-02 rollout specification detailing Polars Parquet staging on `gs://<project_id>-data-lake/p02/lakehouse/`, BigQuery table loads into `crypto_market_data`, WIF OIDC authentication via `sa-cicd-deployer`, Docker image push to `us-central1-docker.pkg.dev/<project_id>/portfolio-apps/p02-crypto-etl:<sha>`, and smoke execution via `gcloud run jobs execute p02-crypto-etl --region=us-central1 --wait`.

### 4. Verification & Quality Gates
```bash
make check
```

### 5. Git & Issue Finish
```bash
make finish-issue ID=13 MSG="feat(p02): provision p02-crypto-etl Cloud Run Job, BigQuery/GCS bindings and rollout spec"
```

## Decisions
- **Allocate `1Gi` RAM for `p02-crypto-etl` (`ADR-004`)**: Polars columnar Parquet transformations and Arrow buffer serialization into BigQuery (`crypto_market_data`) require higher peak memory than standard REST ingestion; `1 vCPU` + `1Gi` with a daily `0 1 * * *` UTC schedule consumes `< 18,000 GiB-seconds/month`, remaining 100% inside the Cloud Run Jobs Always Free tier (`360,000 GiB-seconds/month`, `$0.00/mo`).
- **Scope BigQuery write permissions strictly to the `crypto_market_data` dataset**: `infra/modules/cloud-run-job` binds `roles/bigquery.dataEditor` on `google_bigquery_dataset.datasets["crypto_market_data"]` and `roles/bigquery.jobUser` on the project so `sa-job-p02-crypto-etl` cannot modify `P-05` datasets (`raw_prod`, `staging_prod`, `marts_prod`).

---

## P-02 Rollout & CI/CD Specification (`crypto-analytics-platform`)

### 1. Runtime & Container Contract
- **Workload Name**: `p02-crypto-etl` (`google_cloud_run_v2_job`)
- **Artifact Registry Image**: `us-central1-docker.pkg.dev/<project_id>/portfolio-apps/p02-crypto-etl:<git-sha>`
- **Compute Limits**: `1 vCPU`, `1Gi` RAM (`POLARS_MAX_THREADS=1`), `task_count = 1`, `max_retries = 1`, `timeout_seconds = 600` (`10m`)
- **Cron Schedule**: `0 1 * * *` (`UTC`, daily at `01:00 UTC` via `sched-p02-crypto-etl`)
- **Runtime Identity**: `sa-job-p02-crypto-etl@<project_id>.iam.gserviceaccount.com`
- **Scoped IAM & Secrets**:
  - `roles/storage.objectUser` on `gs://<project_id>-data-lake` (`DATA_LAKE_PREFIX=p02/lakehouse`)
  - `roles/bigquery.dataEditor` on BigQuery dataset `crypto_market_data` + project-level `roles/bigquery.jobUser`
  - `roles/secretmanager.secretAccessor` on `portfolio-market-api-keys` (`MARKET_API_KEYS`)

### 2. Keyless GitHub Actions CD Rollout (`ale-camer/crypto-analytics-platform`)
1. Authenticate with GitHub OIDC via `google-github-actions/auth@v2` assuming `sa-cicd-deployer@<project_id>.iam.gserviceaccount.com`.
2. Build and push the production Polars ETL image tagged with `${{ github.sha }}` to `us-central1-docker.pkg.dev/<project_id>/portfolio-apps/p02-crypto-etl:${{ github.sha }}`.
3. Update the Cloud Run v2 Job image revision and trigger an on-demand smoke execution:
   ```bash
   gcloud run jobs update p02-crypto-etl \
     --project="${GCP_PROJECT_ID}" \
     --region="us-central1" \
     --image="us-central1-docker.pkg.dev/${GCP_PROJECT_ID}/portfolio-apps/p02-crypto-etl:${GITHUB_SHA}"

   gcloud run jobs execute p02-crypto-etl \
     --project="${GCP_PROJECT_ID}" \
     --region="us-central1" \
     --wait
   ```

