# Issue 21: Create `docs/teardown.md`, Cost Verification Checklist, and Finalize `README.md`

**Branch**: `feature/issue-21-teardown-and-final-docs`
**Status**: Done
**PR**: opened by `make finish-issue` → `develop` (Closes #21)
**Milestone**: M5 - Observability & Cost (Closes Milestone M5)

## Objective
Complete the final operational and documentation deliverables for `portfolio-infra` (`P-12`):
1. **Platform Hibernation & Teardown Runbook (`docs/teardown.md`)**: Document three graduated cost-reduction and decommission modes:
   - **Mode 1 — Zero-Compute Hibernation (Keep Data & State, `~$0.12/month`)**: Pause Cloud Scheduler triggers (`P-01`, `P-02`, `P-05`), disable Cloud Monitoring uptime probes (`enable_uptime_checks = false`), and keep all Cloud Run Services scaled to zero (`min_instances = 0`).
   - **Mode 2 — Full Platform Stack Teardown (`terraform -chdir=infra/platform destroy`, `$0.00/month` active services)**: Ordered destruction of Cloud Run Services/Jobs, Cloud Scheduler, Pub/Sub, Monitoring, BigQuery, GCS data buckets, Artifact Registry, Secret Manager shells, and WIF while preserving the remote state bucket (`infra/bootstrap`).
   - **Mode 3 — Complete GCP & External Free-Tier Decommission (`$0.00/month` total)**: Empty and destroy the versioned `infra/bootstrap` state bucket, clean up external free-tier databases (Neon PostgreSQL, MongoDB Atlas M0, Upstash Redis), and optionally shut down the GCP project.
2. **Monthly `< $10.00/month` Cost Verification Checklist (`docs/teardown.md`)**: Provide an executable `gcloud` / `bq` / `terraform` audit checklist verifying that every GCP and external service stays within its Always Free tier or budgeted ceiling (`~$1.62/month` steady-state vs. `$10.00/month` hard cap).
3. **Finalized `README.md` & `terraform.tfvars.example`**: Update `README.md` with the complete provisioned architecture, module & stack catalog (`P-01` to `P-11`), quickstart bootstrap/deploy/teardown workflows, cost breakdown table, and links to all documentation artifacts (`docs/inventory.md`, `docs/architecture.md`, `docs/external_databases.md`, `docs/teardown.md`, `docs/roadmap.md`), and synchronize `terraform.tfvars.example` with all platform variables.

## Acceptance Criteria
- [x] `docs/teardown.md` documents Mode 1 (Hibernation), Mode 2 (`infra/platform` destroy), and Mode 3 (`infra/bootstrap` + external DB decommission) with copy-pasteable commands
- [x] `docs/teardown.md` includes a comprehensive Monthly Cost Verification Checklist (`< $10/month`) with verification commands for Cloud Billing Budgets, Cloud Run (`min_instances = 0`), Artifact Registry cleanup policies, GCS lifecycle rules, Secret Manager active version count (`<= 6`), Cloud Logging 7-day retention, and LLM spend guardrails (`$2.00/month` cap)
- [x] `terraform.tfvars.example` includes documented defaults for all platform variables (`enable_uptime_checks`, `log_retention_days`, and `p01_image_tag`..`p11_image_tag`)
- [x] `README.md` is finalized with the complete `P-01`..`P-11` GCP deployment matrix, two-stage Terraform workflow (`infra/bootstrap` -> `infra/platform`), reusable CI/CD workflow (`cd-cloud-run.yml`), FinOps summary (`~$1.62/month`), and documentation index
- [x] `scripts/smoke_check.sh` includes `docs/inventory.md`, `docs/architecture.md`, `docs/external_databases.md`, and `docs/teardown.md` in `REQUIRED_FILES`
- [x] `make check` passes (`fmt-check`, `validate`, `tflint`, `shellcheck`, and `checkov` with zero failed checks)

## Implementation Tasks

### 1. Preparation & Branching
```bash
make start-issue ID=21 NAME=teardown-and-final-docs
```

### 2. Create Platform Hibernation, Teardown & Cost Verification Runbook (`docs/teardown.md`)
- **File**: `docs/teardown.md`
- **Change**: Author the step-by-step runbook for Mode 1 (Zero-Compute Hibernation), Mode 2 (`infra/platform` destroy), Mode 3 (`infra/bootstrap` & external DB teardown), and the `< $10.00/month` Cost & Quota Verification Checklist with `gcloud` commands.

### 3. Finalize `README.md`, `terraform.tfvars.example` & `scripts/smoke_check.sh`
- **File**: `README.md`, `terraform.tfvars.example`, `scripts/smoke_check.sh`, `docs/issue_21_teardown_and_final_docs.md`
- **Change**: Update `README.md` with the complete production topology, workload table (`P-01`..`P-11`), operational quickstart, FinOps cost table, and documentation links. Add optional variable defaults to `terraform.tfvars.example` and enforce core docs in `scripts/smoke_check.sh`. Mark `docs/issue_21_teardown_and_final_docs.md` as `Status: Done`.

### 4. Verification & Quality Gates
```bash
make check
```

### 5. Git & Issue Finish (Closes Issue #21 and Milestone M5)
```bash
make finish-issue ID=21 MSG="docs(platform): add teardown runbook, cost verification checklist and final README" CLOSE_MILESTONE=1
```

## Decisions
- **Three-Tier Teardown Strategy**: Separating *Hibernation* (`enable_uptime_checks = false` + paused Cloud Scheduler jobs) from *Platform Destroy* (`terraform destroy` on `infra/platform`) and *Bootstrap Destroy* (`infra/bootstrap`) lets the operator pause compute costs in 10 seconds without losing databases or container images, while still providing a deterministic path to `$0.00` total decommission.
