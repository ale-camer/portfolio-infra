# Issue 15: Provision Cloud Run Service Infrastructure and Rollout Specification for P-05

**Branch**: `feature/issue-15-rollout-p05-intelligence-hub`
**Status**: Done
**PR**: opened by `make finish-issue` → `develop` (Closes #15)
**Milestone**: M4 - Rollout

## Objective
Provision the scale-to-zero Unified Market Hub API and daily dbt BigQuery pipeline infrastructure for **P-05 (`market-intelligence-hub`)** in `infra/platform/p05_intelligence_hub.tf` using `infra/modules/cloud-run-service` (`p05-hub-api`) and `infra/modules/cloud-run-job` (`p05-dbt-build`) — binding BigQuery warehouse datasets (`raw_prod`, `staging_prod`, `marts_prod`), GCS data lake (`<project_id>-data-lake`), Neon PostgreSQL (`p05_intel_hub`), and Secret Manager (`portfolio-postgres-url`, `portfolio-market-api-keys`), along with the keyless GitHub Actions CD rollout specification.

## Acceptance Criteria
- [x] `infra/platform/variables.tf` defines `p05_image_tag` (defaulting to `"latest"` or immutable release SHA override) for `p05-hub-api` and `p05-dbt-build`
- [x] `infra/platform/p05_intelligence_hub.tf` instantiates `module "p05_hub_api"` (`source = "../modules/cloud-run-service"`) with `service_name = "p05-hub-api"`, `repo_name = "market-intelligence-hub"`, `cpu = "1"`, `memory = "512Mi"`, `min_instance_count = 0`, `max_instance_count = 1`, `port = 8000`, `bigquery_dataset_roles` on `raw_prod`, `staging_prod`, and `marts_prod`, `storage_bucket_roles` on `<project_id>-data-lake`, and `secret_env_vars` bound to `portfolio-postgres-url` and `portfolio-market-api-keys`
- [x] `infra/platform/p05_intelligence_hub.tf` instantiates `module "p05_dbt_build"` (`source = "../modules/cloud-run-job"`) with `job_name = "p05-dbt-build"`, `schedule_cron = "0 2 * * *"`, `schedule_timezone = "UTC"`, `cpu = "1"`, `memory = "512Mi"`, `timeout_seconds = 600`, and `bigquery_dataset_roles` (`roles/bigquery.dataEditor` on `raw_prod`, `staging_prod`, and `marts_prod`)
- [x] `infra/platform/outputs.tf` exports `p05_hub_api_service_name`, `p05_hub_api_service_url`, `p05_hub_api_sa_email`, `p05_dbt_build_job_name`, `p05_dbt_build_sa_email`, and `p05_dbt_build_scheduler_name`
- [x] Rollout specification for `P-05` (`market-intelligence-hub`) is documented in `docs/issue_15_rollout_p05_intelligence_hub.md` (Section `P-05 Rollout & CI/CD Specification`) covering Artifact Registry build/push, WIF OIDC authentication, `gcloud run deploy p05-hub-api`, `gcloud run jobs update p05-dbt-build`, and smoke verification
- [x] `make check` passes (`fmt-check`, `validate`, `tflint`, `shellcheck`, and `checkov` with zero failed checks)

## Implementation Tasks

### 1. Preparation & Branching
```bash
make start-issue ID=15 NAME=rollout-p05-intelligence-hub
```

### 2. Provision `p05-hub-api` Cloud Run Service, `p05-dbt-build` Cloud Run Job & BigQuery/GCS/Secret Bindings (`infra/platform/variables.tf`, `infra/platform/p05_intelligence_hub.tf` & `infra/platform/outputs.tf`)
- **File**: `infra/platform/variables.tf`, `infra/platform/p05_intelligence_hub.tf`, `infra/platform/outputs.tf`
- **Change**: Add `p05_image_tag` variable to `infra/platform/variables.tf`. Create `infra/platform/p05_intelligence_hub.tf` provisioning `module "p05_hub_api"` (`../modules/cloud-run-service`, `1 vCPU`, `512Mi`, `min=0`, `max=1`, port `8000`) and `module "p05_dbt_build"` (`../modules/cloud-run-job`, `1 vCPU`, `512Mi`, cron `0 2 * * *` UTC), wiring `local.workload_db_secret_bindings.p05`, `portfolio-market-api-keys`, `<project_id>-data-lake` (`DATA_LAKE_PREFIX = "p05/hub"`), and BigQuery dataset permissions on `raw_prod`, `staging_prod`, and `marts_prod`. Export P-05 service and job outputs in `infra/platform/outputs.tf`.

### 3. Document P-05 Unified Hub API + dbt Build & Keyless GitHub Actions Rollout Specification (`docs/issue_15_rollout_p05_intelligence_hub.md`)
- **File**: `docs/issue_15_rollout_p05_intelligence_hub.md`
- **Change**: Add the concrete P-05 rollout specification covering the scale-to-zero FastAPI hub (`p05-hub-api`), daily scheduled `dbt build` execution (`p05-dbt-build` at `02:00 UTC`), BigQuery dataset isolation (`raw_prod`, `staging_prod`, `marts_prod`), and keyless GitHub Actions CD deployment.

### 4. Verification & Quality Gates
```bash
make check
```

### 5. Git & Issue Finish
```bash
make finish-issue ID=15 MSG="feat(p05): provision p05-hub-api Cloud Run service, p05-dbt-build job and rollout spec"
```

## Decisions
- **Pair scale-to-zero `p05-hub-api` Service with scheduled `p05-dbt-build` Job (`ADR-003` & `ADR-004`)**: Separating interactive API serving (`min=0`, `max=1`, `512Mi`) from daily `dbt build` warehouse transformations (`0 2 * * *` UTC — the 3rd and final free Cloud Scheduler job under the 3-job/month Always Free quota) keeps both workloads at **$0.00/month** while isolating BigQuery write privileges (`roles/bigquery.dataEditor` on `raw_prod`, `staging_prod`, `marts_prod`).
- **Grant `roles/bigquery.dataViewer` to `p05-hub-api` on `marts_prod` and `staging_prod` (and `roles/bigquery.dataEditor` on `raw_prod`)**: Enforces least privilege between the analytical serving API and the batch `dbt` builder.

---

## P-05 Rollout & CI/CD Specification (`market-intelligence-hub`)

### 1. Runtime & Container Contract
| Component | Resource Type | Image URI | Compute & Scaling | Schedule / Ingress | Runtime Service Account |
|---|---|---|---|---|---|
| **Unified Hub API** (`p05-hub-api`) | `google_cloud_run_v2_service` | `us-central1-docker.pkg.dev/<project_id>/portfolio-apps/p05-hub-api:<git-sha>` | `1 vCPU`, `512Mi`, `min=0`, `max=1`, port `8000` | Public HTTPS (`GET /health`) | `sa-run-p05-hub-api@<project_id>.iam.gserviceaccount.com` |
| **Daily dbt Runner** (`p05-dbt-build`) | `google_cloud_run_v2_job` | `us-central1-docker.pkg.dev/<project_id>/portfolio-apps/p05-dbt-build:<git-sha>` | `1 vCPU`, `512Mi`, `task_count=1`, `timeout=600s` | `0 2 * * *` (`UTC`, `sched-p05-dbt-build`) | `sa-job-p05-dbt-build@<project_id>.iam.gserviceaccount.com` |

### 2. Scoped IAM & Secret Bindings
- **`sa-run-p05-hub-api`**:
  - `roles/bigquery.dataEditor` on `raw_prod`, `roles/bigquery.dataViewer` on `staging_prod` and `marts_prod`, + project-level `roles/bigquery.jobUser`
  - `roles/storage.objectUser` on `gs://<project_id>-data-lake` (`DATA_LAKE_PREFIX=p05/hub`)
  - `roles/secretmanager.secretAccessor` on `portfolio-postgres-url` (`DATABASE_URL`, schema `p05_intel_hub`) and `portfolio-market-api-keys` (`MARKET_API_KEYS`)
- **`sa-job-p05-dbt-build`**:
  - `roles/bigquery.dataEditor` on `raw_prod`, `staging_prod`, and `marts_prod` + project-level `roles/bigquery.jobUser`

### 3. Keyless GitHub Actions CD Rollout (`ale-camer/market-intelligence-hub`)
1. Authenticate with GitHub OIDC via `google-github-actions/auth@v2` assuming `sa-cicd-deployer@<project_id>.iam.gserviceaccount.com`.
2. Build and push both `p05-hub-api:${{ github.sha }}` and `p05-dbt-build:${{ github.sha }}` images to Artifact Registry.
3. Deploy the API revision, update the `dbt` job image, and verify `/health`:
   ```bash
   gcloud run deploy p05-hub-api \
     --project="${GCP_PROJECT_ID}" \
     --region="us-central1" \
     --image="us-central1-docker.pkg.dev/${GCP_PROJECT_ID}/portfolio-apps/p05-hub-api:${GITHUB_SHA}"

   gcloud run jobs update p05-dbt-build \
     --project="${GCP_PROJECT_ID}" \
     --region="us-central1" \
     --image="us-central1-docker.pkg.dev/${GCP_PROJECT_ID}/portfolio-apps/p05-dbt-build:${GITHUB_SHA}"

   SERVICE_URL="$(gcloud run services describe p05-hub-api --project="${GCP_PROJECT_ID}" --region="us-central1" --format='value(status.url)')"
   curl --fail --silent --show-error --max-time 20 "${SERVICE_URL}/health"
   ```

