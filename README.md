# Portfolio Infrastructure & Deployment (`portfolio-infra`)

Centralized Infrastructure as Code (Terraform) and CI/CD blueprints for deploying the **Financial Markets Intelligence Platform** (projects **P-01 to P-11**) on Google Cloud Platform (GCP) under a strict **< $10/month** budget.

---

## 1. Platform Overview

The 11 repositories in this portfolio form a unified Data Engineering, MLOps, and AI Agents ecosystem:

| ID | Repository | Layer | Primary Workload |
|:---:|:---|:---|:---|
| P-01 | `financial-markets-pipeline` | DE | Daily market data ETL pipeline |
| P-02 | `crypto-analytics-platform` | DE | Crypto lakehouse & BigQuery analytics |
| P-03 | `real-time-market-events` | DE | Market event streaming & processing |
| P-04 | `financial-news-intelligence-api` | DE / API | Financial news ingestion & FastAPI service |
| P-05 | `market-intelligence-hub` | DE / API | Unified market data hub & API |
| P-06 | `asset-anomaly-detection` | MLOps | Anomaly detection training & inference |
| P-07 | `financial-documents-rag` | AI / L1 | Financial documents RAG with `pgvector` |
| P-08 | `ai-powered-market-intelligence` | AI / L2 | End-to-end AI market intelligence platform |
| P-09 | `financial-research-agent` | Agents / L2-L3 | Tool-using financial research agent |
| P-10 | `autonomous-trading-analyst` | Agents / L3 | ReAct autonomous trading analyst |
| P-11 | `multi-agent-market-intelligence` | Agents / L4 | Multi-agent orchestration API |

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
├── .agents/rules/workflow.md   # Engineering & GCP governance rules
├── .github/workflows/ci.yml    # Formatting, validation, linting & security CI
├── docs/                       # Roadmap, audit inventory, architecture, issue plans
├── infra/
│   ├── bootstrap/              # Stage 1: GCS state bucket (local state, run once)
│   ├── platform/               # Stage 2: Shared GCP platform resources (remote state)
│   └── modules/                # Reusable modules (cloud-run-service, cloud-run-job, etc.)
├── scripts/                    # GitHub bootstrap and smoke check scripts
├── .checkov.yaml               # Security scanner configuration
├── .env.example                # Non-sensitive environment variable template
├── .tflint.hcl                 # Terraform linter configuration
├── Makefile                    # Self-documented automation & quality gates
└── terraform.tfvars.example    # Example Terraform variable inputs
```

---

## 4. Quality Gates & Usage

```bash
make help           # Show all available self-documented commands
make check          # Run fmt-check + validate + lint + security + smoke check
make fmt            # Format all Terraform files recursively
```
