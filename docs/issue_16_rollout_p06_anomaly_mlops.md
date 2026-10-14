# Issue 16: Provision Serverless Batch/API Infrastructure and Rollout Specification for P-06

**Branch**: `feature/issue-16-rollout-p06-anomaly-mlops`
**Status**: Done
**PR**: opened by `make finish-issue` → `develop` (Closes #16)
**Milestone**: M4 - Rollout

## Objective
Provision the scale-to-zero MLOps anomaly inference API and on-demand model training/drift-detection batch job for **P-06 (`asset-anomaly-detection`)** in `infra/platform/p06_anomaly_mlops.tf` using `infra/modules/cloud-run-service` (`p06-anomaly-api`, `1 vCPU`, `1Gi`, `min=0`, `max=1`) and `infra/modules/cloud-run-job` (`p06-train-detect`, `1 vCPU`, `1Gi`, `timeout_seconds = 600`, on-demand execution to preserve the 3-job Cloud Scheduler Free Tier quota) — binding GCS model/Evidently artifact storage (`<project_id>-artifacts` and `<project_id>-data-lake`), Neon PostgreSQL (`p06_anomaly`), and Secret Manager (`portfolio-postgres-url`, `portfolio-market-api-keys`), alongside the keyless GitHub Actions CD rollout specification.

## Acceptance Criteria
- [x] `infra/platform/variables.tf` defines `p06_image_tag` (defaulting to `"latest"` or immutable release SHA override) for `p06-anomaly-api` and `p06-train-detect`
- [x] `infra/platform/p06_anomaly_mlops.tf` instantiates `module "p06_anomaly_api"` (`source = "../modules/cloud-run-service"`) with `service_name = "p06-anomaly-api"`, `repo_name = "asset-anomaly-detection"`, `cpu = "1"`, `memory = "1Gi"`, `min_instance_count = 0`, `max_instance_count = 1`, `port = 8000`, `storage_bucket_roles` (`roles/storage.objectViewer` on `<project_id>-artifacts` and `<project_id>-data-lake`), and `secret_env_vars` bound to `portfolio-postgres-url` and `portfolio-market-api-keys`
- [x] `infra/platform/p06_anomaly_mlops.tf` instantiates `module "p06_train_detect"` (`source = "../modules/cloud-run-job"`) with `job_name = "p06-train-detect"`, `repo_name = "asset-anomaly-detection"`, `cpu = "1"`, `memory = "1Gi"`, `timeout_seconds = 600`, `max_retries = 1`, `schedule_cron = ""` (on-demand / CI-triggered to stay within the 3-job Cloud Scheduler Free Tier), and `storage_bucket_roles` (`roles/storage.objectUser` on `<project_id>-artifacts` and `<project_id>-data-lake`)
- [x] `infra/platform/outputs.tf` exports `p06_anomaly_api_service_name`, `p06_anomaly_api_service_url`, `p06_anomaly_api_sa_email`, `p06_train_detect_job_name`, and `p06_train_detect_sa_email`
- [x] Rollout specification for `P-06` (`asset-anomaly-detection`) is documented in `docs/issue_16_rollout_p06_anomaly_mlops.md` (Section `P-06 Rollout & CI/CD Specification`) covering MLflow/Evidently GCS artifact storage, WIF OIDC authentication, `gcloud run deploy p06-anomaly-api`, `gcloud run jobs update p06-train-detect`, and smoke verification
- [x] `make check` passes (`fmt-check`, `validate`, `tflint`, `shellcheck`, and `checkov` with zero failed checks)

## Implementation Tasks

### 1. Preparation & Branching
```bash
make start-issue ID=16 NAME=rollout-p06-anomaly-mlops
```

### 2. Provision `p06-anomaly-api` Cloud Run Service, `p06-train-detect` Cloud Run Job & GCS/DB/Secret Bindings (`infra/platform/variables.tf`, `infra/platform/p06_anomaly_mlops.tf` & `infra/platform/outputs.tf`)
- **File**: `infra/platform/variables.tf`, `infra/platform/p06_anomaly_mlops.tf`, `infra/platform/outputs.tf`
- **Change**: Add `p06_image_tag` variable to `infra/platform/variables.tf`. Create `infra/platform/p06_anomaly_mlops.tf` provisioning `module "p06_anomaly_api"` (`../modules/cloud-run-service`, `1 vCPU`, `1Gi`, `min=0`, `max=1`, port `8000`) and `module "p06_train_detect"` (`../modules/cloud-run-job`, `1 vCPU`, `1Gi`, `timeout_seconds = 600`, `schedule_cron = ""`), binding `local.workload_db_secret_bindings.p06`, `portfolio-market-api-keys`, `<project_id>-artifacts` (`ARTIFACTS_PREFIX = "p06/models"`), and `<project_id>-data-lake` (`DATA_LAKE_PREFIX = "p06/features"`). Export P-06 service and job outputs in `infra/platform/outputs.tf`.

### 3. Document P-06 MLOps Artifact Registry/GCS Contract & Keyless GitHub Actions Rollout Specification (`docs/issue_16_rollout_p06_anomaly_mlops.md`)
- **File**: `docs/issue_16_rollout_p06_anomaly_mlops.md`
- **Change**: Add the concrete P-06 rollout specification detailing serverless MLflow/Evidently artifact persistence in `gs://<project_id>-artifacts/p06/`, least-privilege read-only model loading in `p06-anomaly-api` vs. read-write artifact publication in `p06-train-detect`, and keyless GitHub Actions CD deployment.

### 4. Verification & Quality Gates
```bash
make check
```

### 5. Git & Issue Finish
```bash
make finish-issue ID=16 MSG="feat(p06): provision p06-anomaly-api service, p06-train-detect job and rollout spec"
```

## Decisions
- **Replace always-on MLflow server with GCS-backed artifact registry + Neon metadata (`ADR-003` & `ADR-004`)**: Storing Isolation Forest / Autoencoder model artifacts and Evidently HTML/JSON drift reports under `gs://<project_id>-artifacts/p06/` and run metadata in Neon PostgreSQL (`p06_anomaly`) eliminates dedicated MLflow VM/SQL hosting costs (**$0.00/month**).
- **Trigger `p06-train-detect` on-demand (`schedule_cron = ""`) via GitHub Actions / CLI**: Preserves the 3 free Cloud Scheduler jobs (`sched-p01-daily-etl`, `sched-p02-crypto-etl`, `sched-p05-dbt-build`) so Cloud Scheduler never exceeds `$0.00/month`.

---

## P-06 Rollout & CI/CD Specification (`asset-anomaly-detection`)

### 1. Runtime & Container Contract
| Component | Resource Type | Image URI | Compute & Scaling | Execution Mode | Runtime Service Account |
|---|---|---|---|---|---|
| **Anomaly Inference API** (`p06-anomaly-api`) | `google_cloud_run_v2_service` | `us-central1-docker.pkg.dev/<project_id>/portfolio-apps/p06-anomaly-api:<git-sha>` | `1 vCPU`, `1Gi`, `min=0`, `max=1`, port `8000` | Public HTTPS (`GET /health`, `POST /predict`) | `sa-run-p06-anomaly-api@<project_id>.iam.gserviceaccount.com` |
| **Trainer & Drift Detector** (`p06-train-detect`) | `google_cloud_run_v2_job` | `us-central1-docker.pkg.dev/<project_id>/portfolio-apps/p06-train-detect:<git-sha>` | `1 vCPU`, `1Gi`, `task_count=1`, `timeout=600s` | On-demand (`gcloud run jobs execute`) | `sa-job-p06-train-detect@<project_id>.iam.gserviceaccount.com` |

### 2. Scoped IAM & Secret Bindings
- **`sa-run-p06-anomaly-api`**:
  - `roles/storage.objectViewer` on `gs://<project_id>-artifacts` (`p06/models`, `p06/evidently`) and `gs://<project_id>-data-lake` (`p06/features`)
  - `roles/secretmanager.secretAccessor` on `portfolio-postgres-url` (`DATABASE_URL`, schema `p06_anomaly`) and `portfolio-market-api-keys` (`MARKET_API_KEYS`)
- **`sa-job-p06-train-detect`**:
  - `roles/storage.objectUser` on `gs://<project_id>-artifacts` and `gs://<project_id>-data-lake`
  - `roles/secretmanager.secretAccessor` on `portfolio-postgres-url` and `portfolio-market-api-keys`

### 3. Keyless GitHub Actions CD Rollout (`ale-camer/asset-anomaly-detection`)
1. Authenticate with GitHub OIDC via `google-github-actions/auth@v2` assuming `sa-cicd-deployer@<project_id>.iam.gserviceaccount.com`.
2. Build and push `p06-anomaly-api:${{ github.sha }}` and `p06-train-detect:${{ github.sha }}` to Artifact Registry.
3. Deploy the inference API revision, update the batch job image, and verify `/health`:
   ```bash
   gcloud run deploy p06-anomaly-api \
     --project="${GCP_PROJECT_ID}" \
     --region="us-central1" \
     --image="us-central1-docker.pkg.dev/${GCP_PROJECT_ID}/portfolio-apps/p06-anomaly-api:${GITHUB_SHA}"

   gcloud run jobs update p06-train-detect \
     --project="${GCP_PROJECT_ID}" \
     --region="us-central1" \
     --image="us-central1-docker.pkg.dev/${GCP_PROJECT_ID}/portfolio-apps/p06-train-detect:${GITHUB_SHA}"

   SERVICE_URL="$(gcloud run services describe p06-anomaly-api --project="${GCP_PROJECT_ID}" --region="us-central1" --format='value(status.url)')"
   curl --fail --silent --show-error --max-time 20 "${SERVICE_URL}/health"
   ```

