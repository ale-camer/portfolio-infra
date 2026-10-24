# Issue 18: Provision Cloud Run Service Infrastructure and Rollout Specification for P-08

**Branch**: `feature/issue-18-rollout-p08-e2e-intelligence`
**Status**: Done
**PR**: opened by `make finish-issue` → `develop` (Closes #18)
**Milestone**: M4 - Rollout

## Objective
Provision the scale-to-zero End-to-End AI Market Intelligence infrastructure for **P-08 (`ai-powered-market-intelligence`)** in `infra/platform/p08_e2e_intelligence.tf` using `infra/modules/cloud-run-service` for the E2E AI Signal API (`p08-market-intel`, `1 vCPU`, `1Gi`, `min=0`, `max=1`, port `8000`) and `infra/modules/cloud-run-job` for the on-demand NLP/embedding batch worker (`p08-nlp-worker`, `1 vCPU`, `1Gi`, `timeout_seconds = 600`, `schedule_cron = ""` to preserve the 3-job Cloud Scheduler Free Tier) — wiring Neon PostgreSQL 16 + `pgvector` (`p08_e2e_intel`), Upstash Redis (`portfolio-nosql-cache-urls`), LLM/market/news secrets (`portfolio-llm-api-key`, `portfolio-market-api-keys`, `portfolio-news-social-keys`), and GCS (`<project_id>-data-lake`, `<project_id>-artifacts`), alongside the keyless GitHub Actions CD rollout specification.

## Acceptance Criteria
- [x] `infra/platform/variables.tf` defines `p08_image_tag` (defaulting to `"latest"` or immutable release SHA override) for `p08-market-intel` and `p08-nlp-worker`
- [x] `infra/platform/p08_e2e_intelligence.tf` instantiates `module "p08_market_intel"` (`source = "../modules/cloud-run-service"`) with `service_name = "p08-market-intel"`, `repo_name = "ai-powered-market-intelligence"`, `cpu = "1"`, `memory = "1Gi"`, `min_instance_count = 0`, `max_instance_count = 1`, `port = 8000`, `storage_bucket_roles` (`roles/storage.objectViewer` on `<project_id>-data-lake` and `<project_id>-artifacts`), and `secret_env_vars` bound to `portfolio-postgres-url`, `portfolio-nosql-cache-urls`, `portfolio-llm-api-key`, `portfolio-market-api-keys`, and `portfolio-news-social-keys`
- [x] `infra/platform/p08_e2e_intelligence.tf` instantiates `module "p08_nlp_worker"` (`source = "../modules/cloud-run-job"`) with `job_name = "p08-nlp-worker"`, `repo_name = "ai-powered-market-intelligence"`, `cpu = "1"`, `memory = "1Gi"`, `timeout_seconds = 600`, `max_retries = 1`, `schedule_cron = ""` (on-demand execution preserving the 3-job Cloud Scheduler Free Tier), and `storage_bucket_roles` (`roles/storage.objectUser` on `<project_id>-data-lake` and `<project_id>-artifacts`)
- [x] `infra/platform/outputs.tf` exports `p08_market_intel_service_name`, `p08_market_intel_service_url`, `p08_market_intel_sa_email`, `p08_nlp_worker_job_name`, and `p08_nlp_worker_sa_email`
- [x] Rollout specification for `P-08` (`ai-powered-market-intelligence`) is documented in `docs/issue_18_rollout_p08_e2e_intelligence.md` (Section `P-08 Rollout & CI/CD Specification`) covering WIF OIDC authentication, `gcloud run deploy p08-market-intel`, `gcloud run jobs update p08-nlp-worker`, and smoke verification
- [x] `make check` passes (`fmt-check`, `validate`, `tflint`, `shellcheck`, and `checkov` with zero failed checks)

## Implementation Tasks

### 1. Preparation & Branching
```bash
make start-issue ID=18 NAME=rollout-p08-e2e-intelligence
```

### 2. Provision `p08-market-intel` Service & `p08-nlp-worker` Job with Scoped IAM & Secrets (`infra/platform/variables.tf`, `infra/platform/p08_e2e_intelligence.tf` & `infra/platform/outputs.tf`)
- **File**: `infra/platform/variables.tf`, `infra/platform/p08_e2e_intelligence.tf`, `infra/platform/outputs.tf`
- **Change**: Add `p08_image_tag` variable to `infra/platform/variables.tf`. Create `infra/platform/p08_e2e_intelligence.tf` invoking `../modules/cloud-run-service` for `p08-market-intel` (`1 vCPU`, `1Gi`, `min=0`, `max=1`, port `8000`) and `../modules/cloud-run-job` for `p08-nlp-worker` (`1 vCPU`, `1Gi`, `timeout_seconds = 600`, `schedule_cron = ""`) with Neon PostgreSQL 16 + `pgvector` (`p08_e2e_intel`), Upstash Redis (`REDIS_URL`), LLM/market/news secrets, and GCS (`data-lake`, `artifacts`) bindings. Export `p08_*` outputs in `infra/platform/outputs.tf`.

### 3. Document P-08 E2E AI Market Intelligence & Keyless GitHub Actions Rollout Specification (`docs/issue_18_rollout_p08_e2e_intelligence.md`)
- **File**: `docs/issue_18_rollout_p08_e2e_intelligence.md`
- **Change**: Add the concrete P-08 rollout specification covering `p08-market-intel` (`Cloud Run Service`) and `p08-nlp-worker` (`Cloud Run Job`), Celery/Airflow replacement via Cloud Run Job + Upstash Redis (`p08:` prefix), LLM budget guardrails (`LLM_MAX_TOKENS_PER_REQ = 1024`), and keyless GitHub Actions CD deployment.

### 4. Verification & Quality Gates
```bash
make check
```

### 5. Git & Issue Finish
```bash
make finish-issue ID=18 MSG="feat(p08): provision p08-market-intel service, p08-nlp-worker job and rollout spec"
```

## Decisions
- **Replace always-on Celery/Airflow workers with `p08-nlp-worker` Cloud Run Job + Upstash Redis (`ADR-003` & `ADR-004`)**: Eliminates idle worker compute while keeping Cloud Scheduler within the 3-job Free Tier (`schedule_cron = ""`, triggered on-demand or via GitHub Actions).
- **Consolidate relational + vector storage in Neon schema `p08_e2e_intel` (`PGVECTOR_ENABLED = true`)**: Avoids dedicated vector DB and Cloud SQL costs (**$0.00/month**).

---

## P-08 Rollout & CI/CD Specification (`ai-powered-market-intelligence`)

### 1. Runtime & Container Contract
| Component | Resource Type | Image URI | Compute & Scaling | Execution Mode | Runtime Service Account |
|---|---|---|---|---|---|
| **E2E AI Signal API** (`p08-market-intel`) | `google_cloud_run_v2_service` | `us-central1-docker.pkg.dev/<project_id>/portfolio-apps/p08-market-intel:<git-sha>` | `1 vCPU`, `1Gi`, `min=0`, `max=1`, port `8000` | Public HTTPS (`GET /health`, REST/WS) | `sa-run-p08-market-intel@<project_id>.iam.gserviceaccount.com` |
| **NLP Signal Worker** (`p08-nlp-worker`) | `google_cloud_run_v2_job` | `us-central1-docker.pkg.dev/<project_id>/portfolio-apps/p08-nlp-worker:<git-sha>` | `1 vCPU`, `1Gi`, `task_count=1`, `timeout=600s` | On-demand (`gcloud run jobs execute`) | `sa-job-p08-nlp-worker@<project_id>.iam.gserviceaccount.com` |

### 2. Scoped IAM, Database & Secret Bindings
- **Neon PostgreSQL 16 + `pgvector` & Upstash Redis**: `DATABASE_URL` (`portfolio-postgres-url`, schema `p08_e2e_intel`, `PGVECTOR_DIMENSIONS=1536`) and `REDIS_URL` (`portfolio-nosql-cache-urls`, prefix `p08:`).
- **LLM & Market/News Secret Bindings**: `LLM_API_KEY` (`portfolio-llm-api-key`, capped via `LLM_MAX_TOKENS_PER_REQ=1024`), `MARKET_API_KEYS` (`portfolio-market-api-keys`), and `NEWS_SOCIAL_KEYS` (`portfolio-news-social-keys`).
- **GCS Bucket Permissions**:
  - `sa-run-p08-market-intel`: `roles/storage.objectViewer` on `gs://<project_id>-data-lake` (`p08/market_intel`) and `gs://<project_id>-artifacts` (`p08/nlp_models`).
  - `sa-job-p08-nlp-worker`: `roles/storage.objectUser` on `gs://<project_id>-data-lake` and `gs://<project_id>-artifacts`.

### 3. Keyless GitHub Actions CD Rollout (`ale-camer/ai-powered-market-intelligence`)
1. Authenticate with GitHub OIDC via `google-github-actions/auth@v2` assuming `sa-cicd-deployer@<project_id>.iam.gserviceaccount.com`.
2. Build and push `p08-market-intel:${{ github.sha }}` and `p08-nlp-worker:${{ github.sha }}` to Artifact Registry.
3. Deploy the API revision, update the NLP batch job image, and verify `/health`:
   ```bash
   gcloud run deploy p08-market-intel \
     --project="${GCP_PROJECT_ID}" \
     --region="us-central1" \
     --image="us-central1-docker.pkg.dev/${GCP_PROJECT_ID}/portfolio-apps/p08-market-intel:${GITHUB_SHA}"

   gcloud run jobs update p08-nlp-worker \
     --project="${GCP_PROJECT_ID}" \
     --region="us-central1" \
     --image="us-central1-docker.pkg.dev/${GCP_PROJECT_ID}/portfolio-apps/p08-nlp-worker:${GITHUB_SHA}"

   SERVICE_URL="$(gcloud run services describe p08-market-intel --project="${GCP_PROJECT_ID}" --region="us-central1" --format='value(status.url)')"
   curl --fail --silent --show-error --max-time 20 "${SERVICE_URL}/health"
   ```

