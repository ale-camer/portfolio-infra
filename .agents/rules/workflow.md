# Engineering & Infrastructure Workflow Rules

This living document governs all development, Infrastructure as Code (IaC), and deployment operations in `portfolio-infra` (P-12).

## 1. Day 0 Empty Scaffolding
- Issue 0 creates only the directory skeleton (`.gitkeep`), templates (`.gitignore`, `.env.example`, `terraform.tfvars.example`, `.tflint.hcl`, `.checkov.yaml`), `Makefile`, `README.md` draft, `docs/roadmap.md`, `.agents/rules/workflow.md`, `.github/workflows/ci.yml`, `scripts/bootstrap_github.sh`, and `scripts/smoke_check.sh`.
- **NEVER** define real Terraform resources (`resource "..."`) or deployment logic on Day 0.

## 2. Repository Structure & Scope
- Required folders: `infra/bootstrap/`, `infra/platform/`, `infra/modules/`, `scripts/`, `docs/`, `.github/workflows/`, `.agents/rules/`.
- **Read access**: Any of the 11 sibling repositories (`P-01` to `P-11`) under `/home/alejandrocamerlengo/Projects/`.
- **Write access**: Strictly `/home/alejandrocamerlengo/Projects/portfolio-infra/`.
- Sibling repo changes (`.github/workflows/cd.yml`, `Dockerfile`, env vars, healthchecks) are proposed in `portfolio-infra` issues first and implemented later on a dedicated branch of that repo following its `.agents/rules/workflow.md`. Business logic is never modified without explicit user approval.
- **Zero secrets in Git**: Only `.env.example` and `terraform.tfvars.example` with fake values are committed. Real secrets live in Secret Manager or GitHub Secrets.

## 3. Git Flow
- Permanent branches: `main` (always green) and `develop`. Never work directly on them.
- One branch per issue from `develop`: `feature/issue-X-short-name` or `fix/issue-X-short-name`.
- Issue PRs target `develop` via **Squash Merge**; `develop` merges into `main` via **Merge Commit** (no squash) only when closing a milestone.
- Commits follow **Conventional Commits** (`type(scope): description`).

## 4. Two-Phase Issue Lifecycle
- **Phase A (Plan)**: Create **ONLY** `docs/issue_X_name.md` (`Status: Planned`). User runs `make start-issue ID=X NAME=short-name`.
- **Phase B (Implementation)**: Set `Status: In Progress`, implement **ONLY** points `2..N` (out-of-scope items go to `## Decisions` or a new issue), run point `N+1` (`make check`), mark `[x]` Acceptance Criteria, set `Status: Done`, and report.
- User runs `make finish-issue ID=X MSG="..."` (and `make finish-milestone MILESTONE=MX` if closing a milestone in `docs/roadmap.md`).
- Do not start Phase A of the next issue until the user confirms `finish-issue` completed.

## 5. Issue Document Format
Every `docs/issue_X_name.md` uses the exact template: header metadata (`Branch`, `Status`, `PR`, `Milestone`), `## Objective`, `## Acceptance Criteria`, `## Implementation Tasks` (`1. Preparation & Branching`, `2..N` atomic tasks with `File` and `Change`, `N+1. Verification & Quality Gates`, `N+2. Git & Issue Finish`, optional `N+3. Milestone Finish`), and `## Decisions` (2–3 lines per architectural decision).

## 6. Makefile & Quality Gates
- Self-documented `Makefile` (`help` by default) with parameter validation.
- User-only targets: `start-issue`, `finish-issue` (`ID=0` omits `Closes #0` and `gh issue close`), `finish-milestone`.
- Agent quality targets: `fmt`, `fmt-check`, `validate`, `lint` (`tflint` + `shellcheck`), `security` (`checkov`), `check` (`fmt-check` + `validate` + `lint` + `security`), `plan` (user-authorized only), `clean`.
- Missing tools must fail with a one-line installation command; never skip checks or silence rules without justification in `## Decisions`.

## 7. Language, Autonomy & Execution Boundaries
- **Language**: 100% English in repository files; Spanish in chat.
- **Technical Autonomy**: Choose the simplest, cheapest, most robust option and record it in `## Decisions`. Answer user questions first.
- **Execution Boundaries**: User runs state-changing Git/GitHub and GCP commands (`terraform apply/destroy`, `gcloud ... create/delete`, `gh ...`). Agent runs read-only commands and local checks (`make fmt`, `make check`).
- **Ultra-Brief Reporting**:
  - Phase A: `✅ Plan: docs/issue_X_nombre.md (N tareas)` + `▶️ Próximo comando: make start-issue ID=X NAME=nombre-corto`
  - Phase B: `✅ Hecho: [1-3 líneas]` + `🧪 Checks: fmt ✅ · validate ✅ · lint ✅ · security ✅` + `▶️ Próximo comando: make finish-issue ID=X MSG="..."` (+ `🏁 Después: make finish-milestone MILESTONE=MX` if closing milestone)

## 8. GCP Guidelines (< $10/month)
- **Region & Env**: Single project (`portfolio-platform-<suffix>`), `us-central1`, single `prod` environment, labels `project=portfolio`, `repo=<name>`, `env=prod`.
- **State & Budget**: `infra/bootstrap/` (local state) creates the versioned GCS state bucket for `infra/platform/`. `google_billing_budget` ($10/mo, 50/80/100% email alerts) is created first in M2.
- **Auth & Compute**: Workload Identity Federation (OIDC) with per-repo least-privilege SAs (no JSON keys). Cloud Run Services (`min-instances=0`), Cloud Run Jobs + Cloud Scheduler (no Cloud Composer), Artifact Registry cleanup policies.
- **Data & AI**: Pub/Sub free tier or local Kafka demo; Neon/Supabase (`pgvector`), MongoDB Atlas M0, BigQuery, and GCS free tiers (no Cloud SQL); LLM spend limits and serverless/batch inference.
- **M2 Prerequisites**: `gcloud` authenticated (`gcloud auth list`, `gcloud auth application-default login`), active billing-enabled GCP project, and `terraform` installed.
