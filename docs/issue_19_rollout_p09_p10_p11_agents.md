# Issue 19: Provision Cloud Run Services with LLM Budget Guardrails for AI Agent Repos (P-09, P-10, P-11)

**Branch**: `feature/issue-19-rollout-p09-p10-p11-agents`
**Status**: Done
**PR**: opened by `make finish-issue` → `develop` (Closes #19)
**Milestone**: M4 - Rollout (Closes M4)

## Objective
Provision the scale-to-zero AI Agent Cloud Run Services for **P-09 (`financial-research-agent`)**, **P-10 (`autonomous-trading-agent`)**, and **P-11 (`multi-agent-market-intelligence`)** in `infra/platform/p09_p10_p11_agents.tf` using `infra/modules/cloud-run-service` — enforcing strict LLM spend/token/step guardrails (`LLM_PROVIDER = "fake"` default for automated smoke/paper-trading cycles, `LLM_MAX_TOKENS_PER_REQ`, `AGENT_MAX_ITERATIONS`, `DAILY_TOKEN_BUDGET`), inter-agent URL wiring (`P-10` -> `P-09` and `P-11` -> `P-09`/`P-10`), Neon PostgreSQL 16 + `pgvector` bindings (`p09_research`, `p10_trading`), GCS artifact/trace storage (`<project_id>-data-lake`, `<project_id>-artifacts`), and Secret Manager access (`portfolio-llm-api-key`, `portfolio-postgres-url`, `portfolio-market-api-keys`, `portfolio-app-signing-keys`), alongside the keyless GitHub Actions CD rollout specification that completes **Milestone M4 (Rollout)**.

## Acceptance Criteria
- [x] `infra/platform/variables.tf` defines `p09_image_tag`, `p10_image_tag`, and `p11_image_tag` (defaulting to `"latest"` or immutable release SHA overrides) with non-empty validation rules
- [x] `infra/platform/p09_p10_p11_agents.tf` instantiates `module "p09_research_agent"` (`service_name = "p09-research-agent"`, `repo_name = "financial-research-agent"`, `1 vCPU`, `512Mi`, `min=0`, `max=2`, port `8000`) with Neon PostgreSQL (`p09_research`), GCS (`<project_id>-data-lake`), `portfolio-llm-api-key`, `portfolio-market-api-keys`, and LLM token/iteration guardrails
- [x] `infra/platform/p09_p10_p11_agents.tf` instantiates `module "p10_trading_analyst"` (`service_name = "p10-trading-analyst"`, `repo_name = "autonomous-trading-agent"`, `1 vCPU`, `512Mi`, `min=0`, `max=1`, port `8080`) wired to `RESEARCH_AGENT_URL = module.p09_research_agent.service_uri`, Neon PostgreSQL + `pgvector` (`p10_trading`), GCS (`<project_id>-artifacts`), `portfolio-llm-api-key`, `portfolio-market-api-keys`, and paper-trading/LLM guardrails (`TRADING_MODE = "paper"`, `LLM_SMOKE_MODE = "fake"`)
- [x] `infra/platform/p09_p10_p11_agents.tf` instantiates `module "p11_multi_agent"` (`service_name = "p11-multi-agent"`, `repo_name = "multi-agent-market-intelligence"`, `1 vCPU`, `512Mi`, `min=0`, `max=1`, port `8000`) wired to `RESEARCH_AGENT_URL` (`P-09`) and `TRADING_AGENT_URL` (`P-10`), `portfolio-llm-api-key`, `portfolio-market-api-keys`, `portfolio-app-signing-keys`, and LangGraph step/token budget guardrails
- [x] `infra/platform/outputs.tf` exports `p09_research_agent_*`, `p10_trading_analyst_*`, and `p11_multi_agent_*` (`service_name`, `service_url`, and `sa_email`)
- [x] Rollout specification for `P-09`, `P-10`, and `P-11` is documented in `docs/issue_19_rollout_p09_p10_p11_agents.md` (Section `P-09, P-10 & P-11 AI Agents Rollout & CI/CD Specification`)
- [x] `make check` passes (`fmt-check`, `validate`, `tflint`, `shellcheck`, and `checkov` with zero failed checks)

## Implementation Tasks

### 1. Preparation & Branching
```bash
make start-issue ID=19 NAME=rollout-p09-p10-p11-agents
```

### 2. Provision `p09-research-agent`, `p10-trading-analyst` & `p11-multi-agent` Cloud Run Services (`infra/platform/variables.tf`, `infra/platform/p09_p10_p11_agents.tf` & `infra/platform/outputs.tf`)
- **File**: `infra/platform/variables.tf`, `infra/platform/p09_p10_p11_agents.tf`, `infra/platform/outputs.tf`
- **Change**: Add `p09_image_tag`, `p10_image_tag`, and `p11_image_tag` to `infra/platform/variables.tf`. Create `infra/platform/p09_p10_p11_agents.tf` instantiating `module "p09_research_agent"`, `module "p10_trading_analyst"`, and `module "p11_multi_agent"` with least-privilege runtime SAs, inter-service URLs, GCS bucket roles, Secret Manager bindings, and explicit LLM cost guardrails (`LLM_MAX_TOKENS_PER_REQ`, `AGENT_MAX_ITERATIONS`, `DAILY_TOKEN_BUDGET`, `LLM_SMOKE_MODE = "fake"`). Export `p09_*`, `p10_*`, and `p11_*` outputs in `infra/platform/outputs.tf`.

### 3. Document P-09, P-10 & P-11 Multi-Agent Rollout & LLM Budget Guardrail Specification (`docs/issue_19_rollout_p09_p10_p11_agents.md`)
- **File**: `docs/issue_19_rollout_p09_p10_p11_agents.md`
- **Change**: Document the runtime contract, inter-agent service discovery (`P-11` -> `P-09`/`P-10`), LLM token/cost guardrails (`$2.00/mo` hard cap + `--mock`/`fake` smoke mode), and keyless GitHub Actions CD deployment commands for `P-09`, `P-10`, and `P-11`.

### 4. Verification & Quality Gates
```bash
make check
```

### 5. Git, Issue & Milestone M4 Finish
```bash
make finish-issue ID=19 MSG="feat(agents): provision p09, p10 and p11 Cloud Run services with LLM guardrails" CLOSE_MILESTONE=1
```

## Decisions
- **Enforce `AGENT_MAX_ITERATIONS`, `LLM_MAX_TOKENS_PER_REQ`, and `LLM_SMOKE_MODE = "fake"` via Terraform `env_vars` (`ADR-004` & Section 4.4)**: Prevents recursive ReAct/LangGraph loops across `P-09`, `P-10`, and `P-11` from exhausting LLM token budgets while keeping automated CI/CD smoke tests at **$0.00 token spend**.
- **Trigger `P-10` paper-trading cycles (`POST /cycles`) on-demand / via GitHub Actions instead of a 4th Cloud Scheduler job**: Keeps Cloud Scheduler strictly within the 3-job GCP Always Free limit (`$0.00/month`).

---

## P-09, P-10 & P-11 AI Agents Rollout & CI/CD Specification

### 1. Runtime & Container Contract
| Workload | Cloud Run Service | Image URI | Compute & Scaling | Port / Probe | Runtime Service Account |
|---|---|---|---|---|---|
| **P-09** (`financial-research-agent`) | `p09-research-agent` | `us-central1-docker.pkg.dev/<project_id>/portfolio-apps/p09-research-agent:<git-sha>` | `1 vCPU`, `512Mi`, `min=0`, `max=2` | `8000` (`GET /health`, `POST /research`) | `sa-run-p09-research-agent@<project_id>.iam.gserviceaccount.com` |
| **P-10** (`autonomous-trading-agent`) | `p10-trading-analyst` | `us-central1-docker.pkg.dev/<project_id>/portfolio-apps/p10-trading-analyst:<git-sha>` | `1 vCPU`, `512Mi`, `min=0`, `max=1` | `8080` (`GET /health`, `POST /cycles`) | `sa-run-p10-trading-analyst@<project_id>.iam.gserviceaccount.com` |
| **P-11** (`multi-agent-market-intelligence`) | `p11-multi-agent` | `us-central1-docker.pkg.dev/<project_id>/portfolio-apps/p11-multi-agent:<git-sha>` | `1 vCPU`, `512Mi`, `min=0`, `max=1` | `8000` (`GET /health`, `POST /orchestrate`) | `sa-run-p11-multi-agent@<project_id>.iam.gserviceaccount.com` |

### 2. LLM Spend Guardrails & Inter-Agent Service Discovery
- **LLM Spend Guardrails (`local.agent_llm_budget_guardrails`)**:
  - `LLM_MODEL = "gpt-4o-mini"`, `LLM_SMOKE_MODE = "fake"` (`$0.00` token cost for CI smoke tests and scheduled paper-trading cycles)
  - `LLM_MAX_TOKENS_PER_REQ = "1024"`, `AGENT_MAX_ITERATIONS = "5"`, `DAILY_TOKEN_BUDGET = "50000"`, `MONTHLY_LLM_BUDGET_USD = "2.00"`
- **Inter-Agent Topology**:
  - `p10-trading-analyst` receives `RESEARCH_AGENT_URL = module.p09_research_agent.service_uri` and `TRADING_MODE = "paper"`.
  - `p11-multi-agent` receives `RESEARCH_AGENT_URL` (`P-09`), `TRADING_AGENT_URL` (`P-10`), `MARKET_INTEL_URL` (`P-08`), and `DOCS_RAG_URL` (`P-07`).

### 3. Keyless GitHub Actions CD Rollout (`P-09`, `P-10`, `P-11`)
1. Authenticate with GitHub OIDC via `google-github-actions/auth@v2` assuming `sa-cicd-deployer@<project_id>.iam.gserviceaccount.com`.
2. Build, push, and deploy each agent service revision with smoke verification:
   ```bash
   for SERVICE in p09-research-agent p10-trading-analyst p11-multi-agent; do
     gcloud run deploy "${SERVICE}" \
       --project="${GCP_PROJECT_ID}" \
       --region="us-central1" \
       --image="us-central1-docker.pkg.dev/${GCP_PROJECT_ID}/portfolio-apps/${SERVICE}:${GITHUB_SHA}"

     SERVICE_URL="$(gcloud run services describe "${SERVICE}" --project="${GCP_PROJECT_ID}" --region="us-central1" --format='value(status.url)')"
     curl --fail --silent --show-error --max-time 20 "${SERVICE_URL}/health"
   done
   ```

