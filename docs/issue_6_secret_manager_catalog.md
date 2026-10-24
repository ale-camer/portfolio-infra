# Issue 6: Provision Secret Manager Shell Containers for Portfolio API Keys and DB URLs

**Branch**: `feature/issue-6-secret-manager-catalog`
**Status**: Done
**PR**: opened by `make finish-issue` → `develop` (Closes #6)
**Milestone**: M2 - Foundations

## Objective
Provision the 6 deduplicated, platform-level `google_secret_manager_secret` shell containers in `infra/platform/secrets.tf` (`portfolio-llm-api-key`, `portfolio-postgres-url`, `portfolio-market-api-keys`, `portfolio-news-social-keys`, `portfolio-nosql-cache-urls`, and `portfolio-app-signing-keys`) with regional user-managed replication in `us-central1` and zero secret payload versions in Terraform state, keeping total active secret versions at exactly 6 within the GCP Secret Manager Always Free tier (`$0.00/month`).

## Acceptance Criteria
- [x] `infra/platform/secrets.tf` defines the 6 consolidated `google_secret_manager_secret` resources (`portfolio-llm-api-key`, `portfolio-postgres-url`, `portfolio-market-api-keys`, `portfolio-news-social-keys`, `portfolio-nosql-cache-urls`, `portfolio-app-signing-keys`) using `user_managed` replication in `var.region` (`us-central1`)
- [x] Zero `google_secret_manager_secret_version` resources or plaintext secret values exist in Terraform files (`scripts/smoke_check.sh` enforces this boundary)
- [x] Each secret includes portfolio labels (`local.common_labels` + `secret_domain`) and depends on `google_project_service.platform_apis["secretmanager.googleapis.com"]`
- [x] `infra/platform/outputs.tf` exports `secret_manager_secret_ids` and `secret_manager_secret_names` maps for downstream workload IAM binding and Cloud Run secret injection
- [x] `make check` passes (`fmt-check`, `validate`, `tflint`, `shellcheck`, and `checkov` with zero failed checks)

## Implementation Tasks

### 1. Preparation & Branching
```bash
make start-issue ID=6 NAME=secret-manager-catalog
```

### 2. Provision Consolidated Secret Manager Shell Catalog (`infra/platform/secrets.tf`)
- **File**: `infra/platform/secrets.tf`
- **Change**: Define `local.portfolio_secrets` mapping the 6 deduplicated secret containers (`portfolio-llm-api-key`, `portfolio-postgres-url`, `portfolio-market-api-keys`, `portfolio-news-social-keys`, `portfolio-nosql-cache-urls`, `portfolio-app-signing-keys`) to their domain and consumer metadata per `docs/inventory.md` Section 3 and `ADR-004`. Provision `google_secret_manager_secret.catalog` (`for_each = local.portfolio_secrets`) with `replication { user_managed { replicas { location = var.region } } }` and documented Checkov skip justification for Google-managed encryption (`CKV_GCP_114` if applicable).

### 3. Export Secret Manager Identifiers (`infra/platform/outputs.tf`)
- **File**: `infra/platform/outputs.tf`
- **Change**: Export `secret_manager_secret_ids` (`secret_id` map) and `secret_manager_secret_names` (fully-qualified `projects/<project>/secrets/<id>` resource names) for consumption by Cloud Run services/jobs and per-workload IAM bindings.

### 4. Verification & Quality Gates
```bash
make check
```

### 5. Git & Issue Finish
```bash
make finish-issue ID=6 MSG="feat(platform): provision consolidated Secret Manager shell catalog"
```

## Decisions
- **Provision only `google_secret_manager_secret` shells in Terraform (no `google_secret_manager_secret_version`)**: Terraform state is stored in GCS; keeping secret payload injection strictly out-of-band (`gcloud secrets versions add <secret_id> --data-file=-`) prevents plaintext credentials from ever entering `.tfstate` or git history (`ADR-004`).
- **Use regional `user_managed` replication in `us-central1`**: Pinning secret replication to `us-central1` rather than multi-region `auto` guarantees that 1 secret payload = 1 active replica version, keeping all 6 secrets inside the 6-version GCP Secret Manager Free Tier (`$0.00/month`).
