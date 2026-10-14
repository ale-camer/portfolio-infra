# Issue 2: Define Target GCP Architecture and Component Decisions in `docs/architecture.md`

**Branch**: `feature/issue-2-target-architecture`
**Status**: Done
**PR**: opened by `make finish-issue` → `develop` (Closes #2)
**Milestone**: M1 - Audit

## Objective
Define the end-to-end target Google Cloud Platform (GCP) architecture (`< $10/month`) for deploying and operating `P-01` through `P-11` from `portfolio-infra` (`P-12`), documenting the system topology, Terraform module and state design, Workload Identity Federation (OIDC) security model, per-layer compute/data/storage/secret mapping, and Architectural Decision Records (ADRs) in `docs/architecture.md`.

## Acceptance Criteria
- [x] `docs/architecture.md` created with an end-to-end Mermaid architecture diagram and topology overview (`us-central1`, `env=prod`, resource labeling, and `< $10/month` budget guardrails)
- [x] `docs/architecture.md` documents the two-stage Terraform state architecture (`infra/bootstrap` -> `infra/platform`), reusable module contracts (`cloud-run-service`, `cloud-run-job`, `deploy-service-account`), and keyless GitHub Actions OIDC / Workload Identity Federation flow
- [x] `docs/architecture.md` defines the concrete GCP & external free-tier service mapping for every workload pattern across `P-01` to `P-11` (Cloud Run Services vs. Cloud Run Jobs + Cloud Scheduler, Pub/Sub vs. local Kafka, BigQuery/GCS, Neon `pgvector`, MongoDB Atlas M0, Upstash Redis, and 6-secret deduplication in Secret Manager)
- [x] `docs/architecture.md` includes formal Architectural Decision Records (ADRs) justifying key cost, security, and operational trade-offs
- [x] `make check` passes

## Implementation Tasks

### 1. Preparation & Branching
```bash
make start-issue ID=2 NAME=target-architecture
```

### 2. Document Platform Topology, Terraform State, and WIF Security Model
- **File**: `docs/architecture.md`
- **Change**: Create `docs/architecture.md` with the platform overview, end-to-end Mermaid topology diagram, single-region (`us-central1`) and single-environment (`prod`) conventions, two-stage Terraform state design (`infra/bootstrap/` local state -> versioned GCS backend for `infra/platform/`), reusable Terraform module interfaces, and keyless GitHub Actions -> GCP Workload Identity Federation (OIDC) authentication flow with per-repository least-privilege Service Accounts.

### 3. Document Compute, Data, Messaging, Secret, and Observability Mapping (`P-01` to `P-11`)
- **File**: `docs/architecture.md`
- **Change**: Append detailed architecture sections mapping each portfolio workload (`P-01` through `P-11`) to its target cloud runtime (Cloud Run Services `min_instances=0`, Cloud Run Jobs + Cloud Scheduler replacing always-on Airflow), data/storage layer (GCS lifecycle rules, BigQuery partitioned marts, Neon serverless Postgres + `pgvector`, MongoDB Atlas M0, Upstash Redis), messaging strategy (Cloud Pub/Sub free tier vs. local Compose Kafka demo), 6-secret consolidation in Secret Manager, and Cloud Monitoring/Logging + `$10/month` `google_billing_budget` alerts.

### 4. Document Architectural Decision Records (ADRs) & Migration Blueprints
- **File**: `docs/architecture.md`
- **Change**: Append formal ADRs covering: (ADR-001) Single Region `us-central1` & Single `prod` Environment; (ADR-002) Two-Stage Terraform State Bootstrap; (ADR-003) Keyless GitHub OIDC via Workload Identity Federation; (ADR-004) Scale-to-Zero Cloud Run Services & Jobs over GKE/Cloud Composer; (ADR-005) External Serverless Free-Tier Databases over Cloud SQL & Memorystore (remediating `P-08` AWS Terraform and high-cost managed DBs); and (ADR-006) Secret Consolidation within Secret Manager Free Tier.

### 5. Verification & Quality Gates
```bash
make check
```

### 6. Git & Issue Finish
```bash
make finish-issue ID=2 MSG="docs(arch): define target GCP architecture and ADRs"
```

### 7. Milestone Finish (Closes M1 - Audit)
```bash
make finish-milestone MILESTONE=M1
```

## Decisions
- **Replace repo-level cloud divergences with a unified GCP serverless blueprint**: `P-08` currently defines AWS Terraform (`RDS`, `ElastiCache`, `ECS`) while `P-02`, `P-05`, and `P-10` define isolated GCP snippets. Centralizing all 11 projects onto GCP Cloud Run + GCS/BigQuery + free-tier serverless DBs in `docs/architecture.md` eliminates ~$120+/month of duplicate or always-on infrastructure before M2 Terraform implementation begins.
- **Standardize reusable Terraform module contracts in M1 before coding M2**: Defining the exact inputs/outputs for `cloud-run-service`, `cloud-run-job`, and `deploy-service-account` in `docs/architecture.md` ensures M2 (`Issues #3–#8`) builds strictly what `P-01`–`P-11` require based on `docs/inventory.md`.
