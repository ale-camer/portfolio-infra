# Issue 12: Provision Cloud Run Job + Scheduler and Rollout Specification for P-01

**Branch**: `feature/issue-12-rollout-p01-daily-pipeline`
**Status**: Done
**PR**: opened by `make finish-issue` → `develop` (Closes #12)
**Milestone**: M4 - Rollout

## Objective
Provision the serverless batch infrastructure for **P-01 (`financial-markets-pipeline`)** in `infra/platform/p01_daily_pipeline.tf` using the reusable `infra/modules/cloud-run-job` module — configuring `p01-daily-etl` (`1 vCPU`, `512Mi`, `max_retries = 1`, `timeout_seconds = 600`), a weekday post-market Cloud Scheduler trigger (`0 22 * * 1-5` UTC), least-privilege GCS data-lake and Secret Manager bindings (`portfolio-postgres-url`, `portfolio-nosql-cache-urls`, `portfolio-market-api-keys`), and the keyless GitHub Actions CD rollout specification.

## Acceptance Criteria
- [x] `infra/platform/variables.tf` defines `p01_image_tag` (defaulting to `"latest"` or immutable release SHA override) for `p01-daily-etl`
- [x] `infra/platform/p01_daily_pipeline.tf` instantiates `module "p01_daily_etl"` (`source = "../modules/cloud-run-job"`) with `job_name = "p01-daily-etl"`, `schedule_cron = "0 22 * * 1-5"`, `schedule_timezone = "UTC"`, `cpu = "1"`, `memory = "512Mi"`, `max_retries = 1`, `timeout_seconds = 600`, `storage_bucket_roles` granting `roles/storage.objectUser` on `<project_id>-data-lake`, and `secret_env_vars` bound to `portfolio-postgres-url`, `portfolio-nosql-cache-urls`, and `portfolio-market-api-keys`
- [x] `infra/platform/outputs.tf` exports `p01_daily_etl_job_name`, `p01_daily_etl_sa_email`, and `p01_daily_etl_scheduler_name`
- [x] Rollout specification for `P-01` (`financial-markets-pipeline`) is documented in `docs/issue_12_rollout_p01_daily_pipeline.md` (Section `P-01 Rollout & CI/CD Specification`) covering Artifact Registry build/push, WIF OIDC authentication, `gcloud run jobs update`, and smoke execution
- [x] `make check` passes (`fmt-check`, `validate`, `tflint`, `shellcheck`, and `checkov` with zero failed checks)

## Implementation Tasks

### 1. Preparation & Branching
```bash
make start-issue ID=12 NAME=rollout-p01-daily-pipeline
```

### 2. Provision `p01-daily-etl` Cloud Run Job, Cloud Scheduler & IAM Bindings (`infra/platform/variables.tf`, `infra/platform/p01_daily_pipeline.tf` & `infra/platform/outputs.tf`)
- **File**: `infra/platform/variables.tf`, `infra/platform/p01_daily_pipeline.tf`, `infra/platform/outputs.tf`
- **Change**: Add `p01_image_tag` variable to `infra/platform/variables.tf`. Create `infra/platform/p01_daily_pipeline.tf` invoking `../modules/cloud-run-job` for `p01-daily-etl` with weekday schedule `0 22 * * 1-5` (`UTC`), merging `local.workload_db_secret_bindings.p01` (`DATABASE_URL`, `REDIS_URL`, `PGSSLMODE=require`, `DB_SCHEMA=p01_market_etl`) with `MARKET_API_KEYS` (`portfolio-market-api-keys`) and `DATA_LAKE_BUCKET` (`google_storage_bucket.data_lake.name`), plus `roles/storage.objectUser` on the data-lake bucket and `cicd_deployer_sa_email = google_service_account.cicd_deployer.email`. Export job name, runtime SA email, and scheduler trigger name in `infra/platform/outputs.tf`.

### 3. Document P-01 Container & Keyless GitHub Actions Rollout Specification (`docs/issue_12_rollout_p01_daily_pipeline.md`)
- **File**: `docs/issue_12_rollout_p01_daily_pipeline.md`
- **Change**: Add the concrete P-01 rollout specification detailing entrypoint CLI invocation, WIF OIDC authentication via `sa-cicd-deployer`, Docker image push to `us-central1-docker.pkg.dev/<project_id>/portfolio-apps/p01-daily-etl:<sha>`, and manual/CI verification via `gcloud run jobs execute p01-daily-etl --region=us-central1 --wait`.

### 4. Verification & Quality Gates
```bash
make check
```

### 5. Git & Issue Finish
```bash
make finish-issue ID=12 MSG="feat(p01): provision p01-daily-etl Cloud Run Job, Scheduler and rollout spec"
```

## Decisions
- **Replace P-01 Apache Airflow container with Cloud Run Job + Cloud Scheduler (`ADR-004`)**: Running `p01-daily-etl` once per weekday at `22:00 UTC` (after US market close) consumes ~3–5 minutes/day (`< 4,000 vCPU-seconds/month`), staying 100% within the Cloud Run Jobs Free Tier (`180,000 vCPU-seconds/month`) and Cloud Scheduler Free Tier (`3 free jobs/month`) at **$0.00/month** vs. ~$300+/month for Cloud Composer.
- **Reuse `local.workload_db_secret_bindings.p01` from Issue 11**: Ensures `p01-daily-etl` inherits standardized Neon `pgbouncer` pool limits (`DB_POOL_SIZE=2`, `DB_MAX_OVERFLOW=3`, `PGSSLMODE=require`) and consolidated Secret Manager references (`portfolio-postgres-url`, `portfolio-nosql-cache-urls`) without duplication.

---

## P-01 Rollout & CI/CD Specification (`financial-markets-pipeline`)

### 1. Runtime & Container Contract
- **Workload Name**: `p01-daily-etl` (`google_cloud_run_v2_job`)
- **Artifact Registry Image**: `us-central1-docker.pkg.dev/<project_id>/portfolio-apps/p01-daily-etl:<git-sha>`
- **Compute Limits**: `1 vCPU`, `512Mi` RAM, `task_count = 1`, `max_retries = 1`, `timeout_seconds = 600` (`10m`)
- **Cron Schedule**: `0 22 * * 1-5` (`UTC`, Monday–Friday post US market close via `sched-p01-daily-etl`)
- **Runtime Identity**: `sa-job-p01-daily-etl@<project_id>.iam.gserviceaccount.com`
- **Scoped IAM & Secrets**:
  - `roles/storage.objectUser` on `gs://<project_id>-data-lake` (`DATA_LAKE_PREFIX=p01/raw`)
  - `roles/secretmanager.secretAccessor` on `portfolio-postgres-url` (`DATABASE_URL`), `portfolio-nosql-cache-urls` (`REDIS_URL`), and `portfolio-market-api-keys` (`MARKET_API_KEYS`)

### 2. Keyless GitHub Actions CD Rollout (`ale-camer/financial-markets-pipeline`)
1. Authenticate with GitHub OIDC via `google-github-actions/auth@v2` assuming `sa-cicd-deployer@<project_id>.iam.gserviceaccount.com`.
2. Build and push the multi-stage production image tagged with `${{ github.sha }}` to `us-central1-docker.pkg.dev/<project_id>/portfolio-apps/p01-daily-etl:${{ github.sha }}`.
3. Update the Cloud Run v2 Job image revision and trigger an on-demand smoke execution:
   ```bash
   gcloud run jobs update p01-daily-etl \
     --project="${GCP_PROJECT_ID}" \
     --region="us-central1" \
     --image="us-central1-docker.pkg.dev/${GCP_PROJECT_ID}/portfolio-apps/p01-daily-etl:${GITHUB_SHA}"

   gcloud run jobs execute p01-daily-etl \
     --project="${GCP_PROJECT_ID}" \
     --region="us-central1" \
     --wait
   ```

