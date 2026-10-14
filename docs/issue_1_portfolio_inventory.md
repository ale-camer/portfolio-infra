# Issue 1: Audit P-01 to P-11 Services, Databases, Secrets, CI, and Costs in `docs/inventory.md`

**Branch**: `feature/issue-1-portfolio-inventory`
**Status**: Done
**PR**: opened by `make finish-issue` → `develop` (Closes #1)
**Milestone**: M1 - Audit

## Objective
Perform a comprehensive read-only technical audit of all 11 sibling repositories (`P-01` to `P-11`) and document their runtime services, data stores, environment variables/secrets, exposed ports, inter-project dependencies, Dockerfile/CI readiness, and estimated monthly GCP cost in `docs/inventory.md`.

## Acceptance Criteria
- [x] All 11 repositories (`P-01` through `P-11`) are audited in read-only mode by inspecting their `pyproject.toml`, `Dockerfile`, `docker-compose.yml`, `.env.example`, `.github/workflows/`, `infra/`, and `README.md`
- [x] `docs/inventory.md` created with a standardized per-repository audit profile (services, databases/storage, required secrets, ports, upstream/downstream dependencies, Dockerfile & CI status, and estimated monthly GCP cost)
- [x] `docs/inventory.md` includes a consolidated cross-repository dependency matrix and pilot repository recommendation for M3
- [x] `docs/inventory.md` includes an aggregated monthly cost breakdown confirming total platform spend stays under $10/month
- [x] `make check` passes

## Implementation Tasks

### 1. Preparation & Branching
```bash
make start-issue ID=1 NAME=portfolio-inventory
```

### 2. Audit & Document Data Engineering & API Repositories (P-01 to P-05)
- **File**: `docs/inventory.md`
- **Change**: Create `docs/inventory.md` with the executive summary table and detailed audit sections for `P-01` (`financial-markets-pipeline`), `P-02` (`crypto-analytics-platform`), `P-03` (`real-time-market-events`), `P-04` (`financial-news-intelligence-api`), and `P-05` (`market-intelligence-hub`), covering runtime processes, Airflow/Kafka/DB usage, secrets, ports, Docker/CI state, and cloud vs. local-demo cost mapping.

### 3. Audit & Document MLOps & AI/RAG Repositories (P-06 to P-08)
- **File**: `docs/inventory.md`
- **Change**: Append detailed audit sections for `P-06` (`asset-anomaly-detection`), `P-07` (`financial-documents-rag`), and `P-08` (`ai-powered-market-intelligence`), documenting MLflow/Evidently/Vertex AI usage, `pgvector` and MongoDB requirements, secrets, ports, Docker/CI readiness, and serverless cost estimates.

### 4. Audit & Document AI Agent Repositories (P-09 to P-11) & Consolidated Matrices
- **File**: `docs/inventory.md`
- **Change**: Append detailed audit sections for `P-09` (`financial-research-agent`), `P-10` (`autonomous-trading-analyst`), and `P-11` (`multi-agent-market-intelligence`), plus the cross-project dependency matrix, shared secret deduplication table, M3 pilot candidate evaluation, and total monthly GCP cost table (< $10/month).

### 5. Verification & Quality Gates
```bash
make check
```

### 6. Git & Issue Finish
```bash
make finish-issue ID=1 MSG="docs(audit): add portfolio inventory for P-01 to P-11"
```

## Decisions
- **Standardized 7-dimension audit schema per repository**: Auditing every repository across the exact same 7 dimensions (services, data stores, secrets, ports, dependencies, Dockerfile/CI status, and cost) prevents missing hidden dependencies like shared Postgres extensions (`pgvector`) or hardcoded local ports before writing Terraform in M2.
- **Deduplicate shared secrets and databases at the platform level**: Several repositories consume the same external API keys (e.g., Alpha Vantage, NewsAPI, OpenAI/Gemini) and database engines. Cataloging shared vs. repo-specific secrets in `docs/inventory.md` keeps Google Secret Manager within the 6 free active secret versions where possible.
