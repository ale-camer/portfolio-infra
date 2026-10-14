# Issue 0: Day 0 Repository Setup & Scaffolding

**Branch**: `feature/issue-0-setup`
**Status**: Done
**PR**: opened by `make finish-issue` → `develop`
**Milestone**: M0 - Setup

## Objective
Establish the Day 0 directory structure, engineering workflow rules, roadmap (M1–M5), quality gate automation (`Makefile` and CI workflow), and GitHub bootstrap script for `portfolio-infra` without introducing any real Terraform resources.

## Acceptance Criteria
- [x] `docs/issue_0_setup.md`, `.agents/rules/workflow.md`, `README.md`, and `docs/roadmap.md` created in English
- [x] Empty directory scaffolding created with `.gitkeep` in `infra/bootstrap/`, `infra/platform/`, `infra/modules/`, `scripts/`, and `docs/`
- [x] `.gitignore`, `.env.example`, `terraform.tfvars.example`, `.tflint.hcl`, and `.checkov.yaml` created with safe placeholders and no secrets
- [x] `Makefile` created with self-documented `help` default and all lifecycle (`start-issue`, `finish-issue`, `finish-milestone`) and IaC quality targets (`fmt`, `fmt-check`, `validate`, `lint`, `security`, `check`, `plan`, `clean`)
- [x] `.github/workflows/ci.yml`, `scripts/bootstrap_github.sh`, and `scripts/smoke_check.sh` created
- [x] Zero real Terraform resource definitions (`resource "..."`) exist in the repository on Day 0
- [x] `make check` passes

## Implementation Tasks

### 1. Preparation & Branching
```bash
# Already executed by the user before starting this session:
git init -b main
git commit --allow-empty -m "chore: initial commit"
git checkout -b develop
git checkout -b feature/issue-0-setup
```

### 2. Workflow Rules & Core Documentation
- **File**: `.agents/rules/workflow.md`
- **Change**: Document all mandatory engineering rules (Day 0 empty scaffolding, directory layout, Git Flow, two-phase issue lifecycle, identical issue template, Makefile targets, English-only repo, technical autonomy, execution boundaries, quality gates, ultra-brief communication, GCP prerequisites) and the GCP low-cost guidelines (< $10/month budget, `us-central1`, two-stage Terraform state, WIF/OIDC without JSON keys, scale-to-zero Cloud Run, free-tier storage/DBs).
- **File**: `README.md`
- **Change**: Create initial draft documenting the Financial Markets Intelligence Platform deployment architecture (P-01 to P-11), the < $10/month GCP design in `us-central1`, directory layout, and quality gates.
- **File**: `docs/roadmap.md`
- **Change**: Define Milestones M1 (`Audit`), M2 (`Foundations`), M3 (`Pilot Deploy`), M4 (`Rollout`), and M5 (`Observability & Cost`) mapped to 21 atomic issues (#1 to #21), explicitly marking which issue closes each milestone.

### 3. Directory Scaffolding & Configuration Templates
- **File**: `infra/bootstrap/.gitkeep`, `infra/platform/.gitkeep`, `infra/modules/.gitkeep`, `scripts/.gitkeep`, `docs/.gitkeep`
- **Change**: Create empty `.gitkeep` files to track the required folder hierarchy in Git without adding Terraform resources.
- **File**: `.gitignore`
- **Change**: Ignore `*.tfstate*`, `.terraform/`, `*.tfvars*`, `.env*` (except `.env.example` and `terraform.tfvars.example`), crash logs, and IDE/OS artifacts.
- **File**: `.env.example`
- **Change**: Provide non-sensitive placeholder environment variables (`GCP_PROJECT_ID`, `GCP_REGION=us-central1`, `GCP_BILLING_ACCOUNT_ID`, `BUDGET_ALERT_EMAIL`, `GITHUB_OWNER=ale-camer`).
- **File**: `terraform.tfvars.example`
- **Change**: Provide example Terraform input variables with fake values (`project_id`, `region`, `billing_account_id`, `alert_email`, `github_owner`, `environment = "prod"`).
- **File**: `.tflint.hcl`, `.checkov.yaml`
- **Change**: Configure `tflint` and `checkov` baseline rules so `make lint` and `make security` run reproducibly from Day 0.

### 4. Makefile Automation
- **File**: `Makefile`
- **Change**: Implement self-documented `help` (default), Git lifecycle commands (`start-issue`, `finish-issue` with `ID=0` handling, `finish-milestone`), and IaC quality gate commands (`fmt`, `fmt-check`, `validate`, `lint`, `security`, `check`, `plan`, `clean`) including `shellcheck` verification and the Day 0 smoke check.

### 5. CI Workflow, Smoke Check & GitHub Bootstrap Script
- **File**: `.github/workflows/ci.yml`
- **Change**: Configure GitHub Actions workflow triggered on push and pull request to `main` and `develop` running `terraform fmt -check`, `terraform validate`, `tflint`, `checkov`, and `shellcheck`.
- **File**: `scripts/smoke_check.sh`
- **Change**: Create a Bash smoke validation script verifying required directories/files exist, no secret files are tracked, and zero real Terraform resources exist on Day 0.
- **File**: `scripts/bootstrap_github.sh`
- **Change**: Create an idempotent script (executed manually by the user) that creates the public repo `ale-camer/portfolio-infra`, pushes `main` and `develop`, creates milestones M1–M5, and creates issues #1–#21 in numerical order before any PR.

### 6. Verification & Quality Gates
```bash
make check
```

### 7. Git & Issue Finish
```bash
bash scripts/bootstrap_github.sh
make finish-issue ID=0 MSG="chore(setup): day 0 scaffolding"
```

## Decisions
- **Split Terraform into `infra/bootstrap/` and `infra/platform/`**: Terraform cannot store its state in a GCS bucket that does not exist yet. `infra/bootstrap/` uses local state once to create the versioned state bucket, and `infra/platform/` then stores all platform state remotely in that bucket.
- **Single region `us-central1` and single `prod` environment**: Cloud Run and GCS Standard free tiers both apply in `us-central1`, and running a single `prod` environment avoids duplicating infrastructure costs while keeping monthly spend well below $10.
- **21-issue roadmap across M1–M5**: Structuring the roadmap into 21 sequential issues (2 in M1, 6 in M2, 2 in M3, 9 in M4, 2 in M5) audits all 11 repos first, builds shared Terraform modules second, validates with one pilot repo in M3, and rolls out remaining repos in dependency order.
