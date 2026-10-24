# Issue 4: Configure `infra/platform` Backend, Required GCP APIs, and $10 `google_billing_budget`

**Branch**: `feature/issue-4-gcp-project-apis-budget`
**Status**: Done
**PR**: opened by `make finish-issue` → `develop` (Closes #4)
**Milestone**: M2 - Foundations

## Objective
Initialize the Stage 2 platform Terraform stack in `infra/platform/` with a remote GCS state backend (`prefix = "platform/prod"`), enable all required GCP service APIs for the portfolio (`Cloud Run`, `Artifact Registry`, `Secret Manager`, `Cloud Scheduler`, `Pub/Sub`, `BigQuery`, `Monitoring`, `Logging`, `Billing Budgets`, `IAM Credentials`, `STS`), and provision the hard **$10/month `google_billing_budget`** with email notification alerts at 50%, 80%, and 100% spend thresholds.

## Acceptance Criteria
- [x] `infra/platform/versions.tf` defines Terraform `>= 1.5.0`, pinned `hashicorp/google` provider (`~> 6.0`), and `backend "gcs" { prefix = "platform/prod" }`
- [x] `infra/platform/variables.tf` defines typed, documented, and validated variables (`project_id`, `region`, `environment`, `billing_account_id`, `alert_email`, `github_owner`, `monthly_budget_usd`) matching `terraform.tfvars.example`
- [x] `infra/platform/apis.tf` enables all core GCP APIs required by `P-01` through `P-12` with `disable_on_destroy = false`
- [x] `infra/platform/budget.tf` provisions a `google_monitoring_notification_channel` (email) and `google_billing_budget` (`$10/month` default, actual + forecasted thresholds at `0.5`, `0.8`, and `1.0`)
- [x] `infra/platform/outputs.tf` exports enabled API service names, budget name, and notification channel ID with descriptions
- [x] `make check` passes (`fmt-check`, `validate`, `tflint`, `shellcheck`, and `checkov` with zero failed checks)

## Implementation Tasks

### 1. Preparation & Branching
```bash
make start-issue ID=4 NAME=gcp-project-apis-budget
```

### 2. Configure Remote GCS Backend, Provider, and Platform Variables (`infra/platform/`)
- **File**: `infra/platform/versions.tf`, `infra/platform/variables.tf`
- **Change**: Create `versions.tf` locking `required_version = ">= 1.5.0"`, `hashicorp/google` (`~> 6.0`), and `backend "gcs" { prefix = "platform/prod" }` (bucket passed via `-backend-config="bucket=<project_id>-tfstate"` or backend config). Create `variables.tf` with typed, documented, and validated inputs for `project_id`, `region` (`us-central1`), `environment` (`prod`), `billing_account_id`, `alert_email`, `github_owner` (`ale-camer`), and `monthly_budget_usd` (`10`, validated `<= 10`).

### 3. Enable Required GCP Platform APIs (`infra/platform/apis.tf`)
- **File**: `infra/platform/apis.tf`
- **Change**: Define `local.common_labels` and `google_project_service.platform_apis` enabling: `artifactregistry.googleapis.com`, `bigquery.googleapis.com`, `billingbudgets.googleapis.com`, `cloudbilling.googleapis.com`, `cloudresourcemanager.googleapis.com`, `cloudscheduler.googleapis.com`, `iam.googleapis.com`, `iamcredentials.googleapis.com`, `logging.googleapis.com`, `monitoring.googleapis.com`, `pubsub.googleapis.com`, `run.googleapis.com`, `secretmanager.googleapis.com`, `storage.googleapis.com`, and `sts.googleapis.com`.

### 4. Provision $10 Monthly Billing Budget & Email Alert Channel (`infra/platform/budget.tf` & `outputs.tf`)
- **File**: `infra/platform/budget.tf`, `infra/platform/outputs.tf`
- **Change**: Provision `google_monitoring_notification_channel.budget_email` (`type = "email"`, `labels = { email_address = var.alert_email }`) and `google_billing_budget.monthly_cap` scoped to `projects/${var.project_id}` for `var.monthly_budget_usd` USD with threshold rules at `0.5`, `0.8`, and `1.0` (`CURRENT_SPEND`) plus `1.0` (`FORECASTED_SPEND`). Export `enabled_apis`, `budget_resource_name`, and `budget_notification_channel_id` in `outputs.tf`.

### 5. Verification & Quality Gates
```bash
make check
```

### 6. Git & Issue Finish
```bash
make finish-issue ID=4 MSG="feat(platform): configure GCS backend, GCP APIs, and $10 billing budget"
```

## Decisions
- **Enforce `monthly_budget_usd <= 10` at the Terraform variable validation layer**: Adding a hard `validation { condition = var.monthly_budget_usd > 0 && var.monthly_budget_usd <= 10 }` rule in `variables.tf` prevents accidental misconfiguration above the portfolio's `$10/month` ceiling before `terraform plan` even runs.
- **Use partial GCS backend configuration (`prefix = "platform/prod"`) in `versions.tf`**: Keeping `bucket` parameterized via `terraform init -backend-config="bucket=${PROJECT_ID}-tfstate"` avoids hardcoding a specific GCP project ID in committed `.tf` files while allowing `terraform init -backend=false` in CI (`make validate`) to succeed cleanly.
