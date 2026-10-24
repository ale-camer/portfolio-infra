# Portfolio Infrastructure & Deployment (`portfolio-infra`)

Centralized Infrastructure as Code (Terraform) and CI/CD blueprints for deploying the **Financial Markets Intelligence Platform** (projects **P-01 to P-11**) on Google Cloud Platform (GCP) under a strict **< $10/month** budget.

---

## 1. Platform Overview & Deployed Workloads (`P-01` to `P-11`)

The 11 sibling repositories in this portfolio form a unified Data Engineering, MLOps, and AI Agents ecosystem deployed on GCP (`us-central1`, `env=prod`) via reusable Terraform modules (`cloud-run-service`, `cloud-run-job`, `pubsub`):

| ID | Repository | Layer | GCP Compute Target | Runtime & Schedule / Scaling | Primary Storage & Messaging |
|:---:|:---|:---|:---|:---|:---|
| **P-01** | `financial-markets-pipeline` | DE | Cloud Run Job (`p01-daily-etl`) | `1 vCPU / 512Mi`, Cron `0 22 * * 1-5` UTC | Neon Postgres + GCS `data-lake/p01` |
| **P-02** | `crypto-analytics-platform` | DE | Cloud Run Job (`p02-crypto-etl`) | `1 vCPU / 1Gi`, Cron `0 1 * * *` UTC | GCS `data-lake/p02` + BigQuery `crypto_analytics` |
| **P-03** | `real-time-market-events` | DE | Cloud Run Service (`p03-market-events`) | `1 vCPU / 512Mi`, `min=0, max=2` | Pub/Sub (`p03-market-events` + DLQ) + Neon + Upstash Redis |
| **P-04** | `financial-news-intelligence-api` | DE / API | Consolidated into **P-08** (`ADR-002`) | Served via `p08-market-intel` & `p08-nlp-worker` | Atlas M0 + Neon Postgres + Upstash Redis |
| **P-05** | `market-intelligence-hub` | DE / API | Cloud Run Service (`p05-hub-api`) + Job (`p05-dbt-build`) | API `min=0, max=2`; dbt Job Cron `0 2 * * *` UTC | BigQuery `market_intelligence` + Neon + Upstash + GCS `artifacts/p05` |
| **P-06** | `asset-anomaly-detection` | MLOps | Cloud Run Service (`p06-anomaly-api`) + Job (`p06-train-detect`) | API `1Gi, min=0, max=2`; On-demand Training/Drift Job | GCS `artifacts/p06` + `data-lake/p06` + Neon Postgres |
| **P-07** | `financial-documents-rag` | AI / L1 | Cloud Run Service (`p07-docs-rag`) | `1 vCPU / 1Gi`, `min=0, max=2` | Neon `pgvector` + Upstash Redis + GCS `data-lake/p07` |
| **P-08** | `ai-powered-market-intelligence` | AI / L2 | Cloud Run Service (`p08-market-intel`) + Job (`p08-nlp-worker`) | API `1Gi, min=0, max=2`; On-demand FinBERT Job (`1Gi`) | Neon `pgvector` + Atlas M0 + Upstash + BigQuery `market_intelligence` |
| **P-09** | `financial-research-agent` | Agents / L2-L3 | Cloud Run Service (`p09-research-agent`) | `1 vCPU / 512Mi`, `min=0, max=2` | Neon Postgres + Atlas M0 + GCS `data-lake/p09` |
| **P-10** | `autonomous-trading-analyst` | Agents / L3 | Cloud Run Service (`p10-trading-analyst`) | `1 vCPU / 512Mi`, `min=0, max=1` (`TRADING_MODE=paper`) | Neon `pgvector` + Upstash Redis + GCS `artifacts/p10` |
| **P-11** | `multi-agent-market-intelligence` | Agents / L4 | Cloud Run Service (`p11-multi-agent`) | `1 vCPU / 512Mi`, `min=0, max=1` (LangGraph orchestrator) | Orchestrates `P-07`, `P-08`, `P-09`, `P-10` over HTTPS |

---

## 2. Target GCP Architecture (< $10/month)

```text
+-------------------------------------------------------------------------+
| GitHub Actions (P-01 .. P-11 + portfolio-infra)                         |
|   | OIDC Token (Workload Identity Federation - Zero JSON Keys)          |
|   v                                                                     |
| GCP Project: portfolio-platform-<suffix> (Region: us-central1, env=prod)|
|  - Billing Budget ($10/mo, alerts at 50% / 80% / 100%)                  |
|  - Artifact Registry (0.5 GB free tier + image cleanup policies)        |
|  - Cloud Run Services (min-instances=0): FastAPI & AI Agent APIs        |
|  - Cloud Run Jobs + Cloud Scheduler: Batch ETL & ML pipelines           |
|  - GCS Standard (5 GB free) + BigQuery (10 GB / 1 TB queries free)      |
|  - Pub/Sub (10 GB/mo free) + Secret Manager                             |
|  - External Free Tiers: Neon/Supabase (Postgres+pgvector), Atlas M0     |
+-------------------------------------------------------------------------+
```

### Key Architectural Decisions
1. **Single Region (`us-central1`) & Single Environment (`prod`)**: GCP free tiers for Cloud Run and GCS Standard apply in US regions. Consolidating everything into `us-central1` and a single `prod` environment avoids cross-region data transfer fees and duplicate staging costs.
2. **Two-Stage Terraform State (`infra/bootstrap/` -> `infra/platform/`)**: Terraform cannot use a remote GCS backend before the bucket exists. `infra/bootstrap/` runs once with local state to create the versioned GCS state bucket, and `infra/platform/` stores all shared state remotely in that bucket.
3. **Keyless GitHub -> GCP Auth (Workload Identity Federation)**: GitHub Actions exchanges short-lived OIDC tokens directly with GCP IAM using one least-privilege Service Account per repository, eliminating leaked JSON key risks.
4. **Scale-to-Zero Compute**: HTTP services run on Cloud Run with `min-instances=0` ($0 when idle), and batch DAGs run as Cloud Run Jobs triggered by Cloud Scheduler instead of expensive managed Airflow (Cloud Composer).

---

## 3. Repository Structure

```text
portfolio-infra/
├── .agents/rules/workflow.md          # Engineering & GCP FinOps governance rules
├── .github/workflows/
│   ├── ci.yml                         # Formatting, validation, linting & Checkov CI
│   └── cd-cloud-run.yml               # Reusable keyless WIF CD workflow for P-01..P-11
├── docs/
│   ├── inventory.md                   # Complete audit inventory across P-01..P-11
│   ├── architecture.md                # Target GCP architecture, ADRs & cost model
│   ├── external_databases.md          # Neon pgvector, Atlas M0 & Upstash Redis runbook
│   ├── teardown.md                    # Hibernation, teardown & <$10/mo verification checklist
│   └── roadmap.md                     # M0-M5 implementation roadmap (Issues 0..21)
├── infra/
│   ├── bootstrap/                     # Stage 1: Versioned GCS state bucket (local state)
│   ├── platform/                      # Stage 2: Shared foundations, WIF, P-01..P-11 & monitoring
│   └── modules/
│       ├── cloud-run-service/         # Scale-to-zero Cloud Run v2 Service + runtime SA
│       ├── cloud-run-job/             # Batch Cloud Run v2 Job + optional Cloud Scheduler
│       └── pubsub/                    # Cloud Pub/Sub topic + DLQ + pull subscription
├── scripts/                           # GitHub bootstrap and repository smoke check scripts
├── .checkov.yaml                      # Checkov IaC & GitHub Actions security scanner config
├── .env.example                       # Non-sensitive environment variable template
├── .tflint.hcl                        # TFLint configuration
├── Makefile                           # Self-documented automation & quality gates
└── terraform.tfvars.example           # Example Terraform variable inputs
```

---

## 4. Two-Stage Provisioning & CI/CD Quickstart

> [!TIP]
> For the comprehensive, step-by-step master guide covering external database setup (Neon, MongoDB Atlas, Upstash), secret injection, missing container builds, and staged Terraform commands, see the **[Master Deployment Guide (`docs/deployment_guide.md`)](docs/deployment_guide.md)**.

### Stage 1 — Bootstrap Remote State Bucket (Run Once)
```bash
terraform -chdir=infra/bootstrap init
terraform -chdir=infra/bootstrap apply -var="project_id=portfolio-platform-000000"
```

### Stage 2 — Provision Shared Platform & Workloads (`P-01` to `P-11`)
```bash
cp terraform.tfvars.example infra/platform/terraform.tfvars
terraform -chdir=infra/platform init \
  -backend-config="bucket=portfolio-platform-000000-tfstate"
terraform -chdir=infra/platform plan
terraform -chdir=infra/platform apply
```

### Stage 3 — Keyless GitHub OIDC Deployment (`cd-cloud-run.yml`)
Sibling repositories (`P-01` to `P-11`) invoke `.github/workflows/cd-cloud-run.yml` using `google-github-actions/auth@v2` over Workload Identity Federation (`sa-cicd-deployer` — zero JSON service account keys) to build/push immutable SHA tags to Artifact Registry (`portfolio-apps`) and roll out Cloud Run Services/Jobs with post-deploy `/health` or `--wait` verification.

---

## 5. FinOps Monthly Cost Breakdown (`~$1.62/month` vs. `$10.00/month` Cap)

| Resource Category | Provisioned Footprint (`us-central1`) | Free Tier Allowance | Est. Monthly Cost |
|:---|:---|:---|:---:|
| **Cloud Run Services (8) & Jobs (5)** | `min_instances = 0`, `cpu_idle = true`, 3 daily batch jobs | 2M reqs, 180k vCPU-s, 360k GiB-s | `$0.00` |
| **Cloud Scheduler (3) & Pub/Sub** | `sched-p01-daily-etl`, `sched-p02-crypto-etl`, `sched-p05-dbt-build` + `p03-market-events` | 3 jobs + 10 GB/mo Pub/Sub free | `$0.00` |
| **Artifact Registry (`portfolio-apps`)** | Cleanup policy keeps last 3 tagged images & purges untagged `> 7d` | 0.5 GB free (`$0.10/GB-mo` overflow) | `~$0.10` |
| **GCS (`tfstate`, `data-lake`, `artifacts`)** | 30-day (`data-lake`) & 90-day (`artifacts`) auto-delete lifecycle | 5 GB Standard Storage free | `~$0.02` |
| **BigQuery (`crypto_analytics`, `market_intelligence`)** | Partitioned/clustered tables (`365d` staging expiration) | 10 GB storage + 1 TB/mo queries free | `$0.00` |
| **Secret Manager (6) & Cloud Monitoring** | 6 consolidated secret shells (`<= 6` versions); 7-day log retention | 6 secret versions + 50 GiB logs free | `$0.00` |
| **External Databases** | Neon Serverless Postgres (`pgvector`), MongoDB Atlas M0, Upstash Redis | Always Free Tiers (`0.5 GB`, `512 MB`, `10k/d`) | `$0.00` |
| **LLM API Budget (`P-07`..`P-11`)** | `gpt-4o-mini`, `LLM_SMOKE_MODE=fake` in CI/health, `$2.00/mo` hard cap | Application token guardrails | `~$1.50` |
| **Total Steady-State Spend** | **Guarded by `$10/mo` Cloud Billing Budget (`50%`, `80%`, `100%` alerts)** | **83.8% buffer under `$10/mo` ceiling** | **`~$1.62/mo`** |

---

## 6. Documentation Index & Quality Gates

- **Master Deployment Guide**: [`docs/deployment_guide.md`](docs/deployment_guide.md)
- **Portfolio Audit Inventory**: [`docs/inventory.md`](docs/inventory.md)
- **Target GCP Architecture & ADRs**: [`docs/architecture.md`](docs/architecture.md)
- **External Free-Tier Databases Runbook**: [`docs/external_databases.md`](docs/external_databases.md)
- **Hibernation, Teardown & Cost Verification Runbook**: [`docs/teardown.md`](docs/teardown.md)
- **Milestone & Issue Roadmap (`M0`–`M5`)**: [`docs/roadmap.md`](docs/roadmap.md)

```bash
make help           # Show all available self-documented commands
make check          # Run fmt-check + validate + lint + security + smoke check
make fmt            # Format all Terraform files recursively
```

