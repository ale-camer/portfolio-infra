# Issue 11: Configure External Free-Tier Database Connectivity (Neon `pgvector` and MongoDB Atlas M0)

**Branch**: `feature/issue-11-external-free-tier-dbs`
**Status**: Done
**PR**: opened by `make finish-issue` → `develop` (Closes #11)
**Milestone**: M4 - Rollout

## Objective
Configure the standardized Terraform connectivity contract (`infra/platform/external_databases.tf` and `infra/platform/outputs.tf`) and operational specification (`docs/external_databases.md`) for external serverless free-tier data stores — **Neon Serverless PostgreSQL 16 + `pgvector`**, **MongoDB Atlas M0 (`512 MB`)**, and **Upstash Serverless Redis** — binding them to the consolidated Secret Manager shells (`portfolio-postgres-url` and `portfolio-nosql-cache-urls`) with strict TLS enforcement and scale-to-zero connection pooling guardrails (`$0.00/month` per `ADR-005` and `ADR-006`).

## Acceptance Criteria
- [x] `infra/platform/external_databases.tf` defines the canonical connectivity catalog (`neon_postgres`, `mongodb_atlas_m0`, `upstash_redis`), logical database/schema allocation per portfolio workload (`P-01`..`P-10`), non-sensitive runtime TLS/pool environment defaults (`PGSSLMODE=require`, `DB_POOL_SIZE=2`, `DB_MAX_OVERFLOW=3`, `MONGODB_MAX_POOL_SIZE=10`), and reusable `secret_env_vars` maps bound to `google_secret_manager_secret.catalog["portfolio-postgres-url"]` and `google_secret_manager_secret.catalog["portfolio-nosql-cache-urls"]`
- [x] `infra/platform/outputs.tf` exports `external_database_topology` and `workload_db_secret_bindings` so workload modules (`Issues #12–#19`) consume standardized Secret Manager references and connection-pool settings without duplicating secret IDs
- [x] `docs/external_databases.md` documents the Neon `pgvector` database/schema bootstrap (`CREATE EXTENSION IF NOT EXISTS vector;`), MongoDB Atlas M0 `us-central1` cluster/network configuration, Upstash Redis TLS setup, and out-of-band `gcloud secrets versions add` commands (zero credentials in Terraform state)
- [x] `make check` passes (`fmt-check`, `validate`, `tflint`, `shellcheck`, and `checkov` with zero failed checks)

## Implementation Tasks

### 1. Preparation & Branching
```bash
make start-issue ID=11 NAME=external-free-tier-dbs
```

### 2. Implement External Database Connectivity Catalog & Secret Bindings (`infra/platform/external_databases.tf` & `infra/platform/outputs.tf`)
- **File**: `infra/platform/external_databases.tf`, `infra/platform/outputs.tf`
- **Change**: Define `local.external_database_topology` and `local.workload_db_secret_bindings` mapping each stateful repository (`P-01`, `P-03`, `P-04`, `P-05`, `P-06`, `P-07`, `P-08`, `P-09`, `P-10`) to its consolidated Secret Manager shell (`portfolio-postgres-url` and/or `portfolio-nosql-cache-urls`), logical database/collection names, and scale-to-zero connection pool environment variables (`PGSSLMODE = "require"`, `DB_POOL_SIZE = "2"`, `DB_MAX_OVERFLOW = "3"`, `MONGODB_MAX_POOL_SIZE = "10"`). Export `external_database_topology` and `workload_db_secret_bindings` in `infra/platform/outputs.tf`.

### 3. Document External Free-Tier Database Provisioning, `pgvector` Bootstrap & Secret Injection (`docs/external_databases.md`)
- **File**: `docs/external_databases.md`
- **Change**: Document the architecture and operational setup for Neon Serverless PostgreSQL 16 (`-pooler` PgBouncer endpoint, logical schema isolation, `pgvector` extension initialization for RAG/embeddings), MongoDB Atlas M0 in `us-central1` (`mongodb+srv://` TLS URI, collection/index setup, Cloud Run outbound IP allowlisting with TLS client auth), Upstash Serverless Redis (`rediss://` TLS URI), and out-of-band `gcloud secrets versions add` commands keeping Secret Manager at `<= 6` active versions (`$0.00/month`).

### 4. Verification & Quality Gates
```bash
make check
```

### 5. Git & Issue Finish
```bash
make finish-issue ID=11 MSG="feat(platform): configure external free-tier database connectivity and secret bindings"
```

## Decisions
- **Use Neon pooled `-pooler` endpoints with small per-container SQLAlchemy pools (`DB_POOL_SIZE=2`, `DB_MAX_OVERFLOW=3`)**: Scale-to-zero Cloud Run instances spin up and down dynamically; routing through Neon's built-in PgBouncer pooler with `sslmode=require` prevents connection exhaustion on the Neon Free Tier while supporting `pgvector` queries (`P-03`, `P-07`, `P-08`).
- **Keep database URIs strictly out-of-band in `portfolio-postgres-url` and `portfolio-nosql-cache-urls` (`ADR-005`, `ADR-006`)**: Terraform manages only the Secret Manager shell references and non-sensitive pool/TLS environment variables, guaranteeing zero connection strings or passwords ever enter `.tfstate`.
