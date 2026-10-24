# Issue 17: Provision Cloud Run Service + pgvector Secret Bindings and Rollout Specification for P-07

**Branch**: `feature/issue-17-rollout-p07-documents-rag`
**Status**: Done
**PR**: opened by `make finish-issue` → `develop` (Closes #17)
**Milestone**: M4 - Rollout

## Objective
Provision the scale-to-zero SEC 10-K/10-Q Hybrid RAG API infrastructure for **P-07 (`financial-documents-rag`)** in `infra/platform/p07_documents_rag.tf` using `infra/modules/cloud-run-service` (`p07-docs-rag`, `1 vCPU`, `512Mi`, `min=0`, `max=1`, port `8000`) — wiring Neon Serverless PostgreSQL 16 + `pgvector` (`1536`-dim embeddings, schema `p07_docs_rag`), MongoDB Atlas M0 + Upstash Redis (`portfolio-nosql-cache-urls`), LLM provider keys (`portfolio-llm-api-key`) with hard token/rate guardrails, and GCS SEC filing storage (`<project_id>-data-lake`), alongside the keyless GitHub Actions CD rollout specification.

## Acceptance Criteria
- [x] `infra/platform/variables.tf` defines `p07_image_tag` (defaulting to `"latest"` or immutable release SHA override) for `p07-docs-rag`
- [x] `infra/platform/p07_documents_rag.tf` instantiates `module "p07_docs_rag"` (`source = "../modules/cloud-run-service"`) with `service_name = "p07-docs-rag"`, `repo_name = "financial-documents-rag"`, `cpu = "1"`, `memory = "512Mi"`, `min_instance_count = 0`, `max_instance_count = 1`, `port = 8000`, `storage_bucket_roles` (`roles/storage.objectUser` on `<project_id>-data-lake`), `env_vars` merged with `local.workload_db_secret_bindings.p07.env_vars` + `PGVECTOR_DIMENSIONS = "1536"` + LLM token/cost guardrails, and `secret_env_vars` bound to `portfolio-postgres-url`, `portfolio-nosql-cache-urls`, and `portfolio-llm-api-key`
- [x] `infra/platform/outputs.tf` exports `p07_docs_rag_service_name`, `p07_docs_rag_service_url`, and `p07_docs_rag_sa_email`
- [x] Rollout specification for `P-07` (`financial-documents-rag`) is documented in `docs/issue_17_rollout_p07_documents_rag.md` (Section `P-07 Rollout & CI/CD Specification`) covering Neon `pgvector` HNSW indexing, hybrid BM25 + dense retrieval, WIF OIDC authentication, `gcloud run deploy p07-docs-rag`, and smoke verification
- [x] `make check` passes (`fmt-check`, `validate`, `tflint`, `shellcheck`, and `checkov` with zero failed checks)

## Implementation Tasks

### 1. Preparation & Branching
```bash
make start-issue ID=17 NAME=rollout-p07-documents-rag
```

### 2. Provision `p07-docs-rag` Cloud Run Service, `pgvector`/LLM Secret Bindings & GCS Access (`infra/platform/variables.tf`, `infra/platform/p07_documents_rag.tf` & `infra/platform/outputs.tf`)
- **File**: `infra/platform/variables.tf`, `infra/platform/p07_documents_rag.tf`, `infra/platform/outputs.tf`
- **Change**: Add `p07_image_tag` variable to `infra/platform/variables.tf`. Create `infra/platform/p07_documents_rag.tf` invoking `../modules/cloud-run-service` for `p07-docs-rag` (`1 vCPU`, `512Mi`, `min=0`, `max=1`, port `8000`), merging `local.workload_db_secret_bindings.p07.env_vars` (`DB_SCHEMA = "p07_docs_rag"`, `PGVECTOR_ENABLED = "true"`, `MONGODB_DB_NAME = "p07_raw_filings"`) with `PGVECTOR_DIMENSIONS = "1536"`, `RAG_TOP_K = "5"`, `LLM_MAX_TOKENS_PER_REQ = "1024"`, and `DATA_LAKE_PREFIX = "p07/sec_filings"`, plus `secret_env_vars` for `DATABASE_URL` (`portfolio-postgres-url`), `NOSQL_CACHE_URLS` (`portfolio-nosql-cache-urls`), and `LLM_API_KEY` (`portfolio-llm-api-key`), and `roles/storage.objectUser` on `<project_id>-data-lake`. Export `p07_docs_rag_service_name`, `p07_docs_rag_service_url`, and `p07_docs_rag_sa_email` in `infra/platform/outputs.tf`.

### 3. Document P-07 Hybrid SEC RAG (`pgvector`) & Keyless GitHub Actions Rollout Specification (`docs/issue_17_rollout_p07_documents_rag.md`)
- **File**: `docs/issue_17_rollout_p07_documents_rag.md`
- **Change**: Add the concrete P-07 rollout specification covering Neon PostgreSQL 16 `pgvector` HNSW index setup (`1536` dimensions), SEC 10-K/10-Q chunk storage in `p07_docs_rag` + raw filings in `gs://<project_id>-data-lake/p07/sec_filings`, LLM budget guardrails, and keyless GitHub Actions CD deployment (`gcloud run deploy p07-docs-rag`).

### 4. Verification & Quality Gates
```bash
make check
```

### 5. Git & Issue Finish
```bash
make finish-issue ID=17 MSG="feat(p07): provision p07-docs-rag Cloud Run service, pgvector secret bindings and rollout spec"
```

## Decisions
- **Host `1536`-dim `pgvector` HNSW index on Neon Serverless PostgreSQL 16 Free Tier (`ADR-004`)**: Eliminates ~$70+/month Vertex AI Vector Search / Cloud SQL costs while supporting hybrid dense (`pgvector` cosine similarity) + sparse (`tsvector` BM25) retrieval in schema `p07_docs_rag` at **$0.00/month**.
- **Enforce `LLM_MAX_TOKENS_PER_REQ = 1024` and `max_instance_count = 1` on `p07-docs-rag`**: Prevents unbounded embedding/completion token consumption while keeping RAG query latency under 2 seconds.

---

## P-07 Rollout & CI/CD Specification (`financial-documents-rag`)

### 1. Runtime & Container Contract
| Attribute | Value |
|---|---|
| **Resource Type** | `google_cloud_run_v2_service` (`module.p07_docs_rag`) |
| **Service Name** | `p07-docs-rag` |
| **Artifact Registry Image** | `us-central1-docker.pkg.dev/<project_id>/portfolio-apps/p07-docs-rag:<git-sha>` |
| **Runtime Service Account** | `sa-run-p07-docs-rag@<project_id>.iam.gserviceaccount.com` |
| **Compute & Scaling** | `1 vCPU`, `512Mi`, `min_instance_count = 0`, `max_instance_count = 1`, `concurrency = 80`, `timeout = 60s` |
| **HTTP Contract** | Port `8000`, `GET /health` startup probe, `POST /ingest`, `POST /query` |

### 2. Hybrid Retrieval & Scoped IAM/Secret Bindings
- **Neon PostgreSQL 16 + `pgvector`**: Schema `p07_docs_rag` (`DATABASE_URL` via `portfolio-postgres-url`) stores SEC 10-K/10-Q chunks with `vector(1536)` HNSW cosine index (`PGVECTOR_DIMENSIONS=1536`, `PGVECTOR_ENABLED=true`, `RAG_TOP_K=5`) paired with PostgreSQL `tsvector` GIN full-text search.
- **NoSQL Document Store & Semantic Cache**: `NOSQL_CACHE_URLS` (`portfolio-nosql-cache-urls`) provides MongoDB Atlas M0 (`p07_raw_filings`) and Upstash Redis (`p07:rag:*`) query caching.
- **LLM Cost Guardrails**: `LLM_API_KEY` (`portfolio-llm-api-key`) capped via `LLM_MAX_TOKENS_PER_REQ=1024` and `max_instance_count=1`.
- **GCS Filing Storage**: `roles/storage.objectUser` on `gs://<project_id>-data-lake` (`DATA_LAKE_PREFIX=p07/sec_filings`).

### 3. Keyless GitHub Actions CD Rollout (`ale-camer/financial-documents-rag`)
1. Authenticate with GitHub OIDC via `google-github-actions/auth@v2` assuming `sa-cicd-deployer@<project_id>.iam.gserviceaccount.com`.
2. Build and push `us-central1-docker.pkg.dev/<project_id>/portfolio-apps/p07-docs-rag:${{ github.sha }}`.
3. Roll out the Cloud Run revision and verify `/health`:
   ```bash
   gcloud run deploy p07-docs-rag \
     --project="${GCP_PROJECT_ID}" \
     --region="us-central1" \
     --image="us-central1-docker.pkg.dev/${GCP_PROJECT_ID}/portfolio-apps/p07-docs-rag:${GITHUB_SHA}"

   SERVICE_URL="$(gcloud run services describe p07-docs-rag --project="${GCP_PROJECT_ID}" --region="us-central1" --format='value(status.url)')"
   curl --fail --silent --show-error --max-time 20 "${SERVICE_URL}/health"
   ```

