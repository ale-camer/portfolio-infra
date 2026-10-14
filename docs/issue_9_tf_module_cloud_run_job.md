# Issue 9: Implement Reusable `infra/modules/cloud-run-job` + Cloud Scheduler Terraform Module

**Branch**: `feature/issue-9-tf-module-cloud-run-job`
**Status**: Done
**PR**: opened by `make finish-issue` → `develop` (Closes #9)
**Milestone**: M3 - Modules & Pilot

## Objective
Implement the reusable `infra/modules/cloud-run-job/` Terraform module (`versions.tf`, `variables.tf`, `main.tf`, `outputs.tf`) to standardize deployment of batch ETL, ML training, Monte Carlo benchmark, and stream-burst workloads (`P-01` scanner, `P-02`, `P-05`, `P-09` trainer, `P-10`, `P-11`) on Cloud Run v2 Jobs with strict execution caps (`task_count = 1`, `max_retries <= 1`, `timeout_seconds <= 900`), per-job runtime Service Accounts, Secret Manager / GCS / BigQuery / Pub/Sub IAM bindings, and optional Cloud Scheduler cron triggers.

## Acceptance Criteria
- [x] `infra/modules/cloud-run-job/versions.tf` locks `required_version = ">= 1.5.0"` and `hashicorp/google` (`~> 6.0`)
- [x] `infra/modules/cloud-run-job/variables.tf` defines typed, documented, and validated inputs (`project_id`, `region`, `job_name`, `repo_name`, `image`, `command`, `args`, `cpu`, `memory`, `max_retries`, `timeout_seconds`, `task_count`, `schedule_cron`, `schedule_timezone`, `schedule_paused`, `env_vars`, `secret_env_vars`, `cicd_deployer_sa_email`, `storage_bucket_roles`, `bigquery_dataset_roles`, `pubsub_topic_roles`, `pubsub_subscription_roles`, `labels`) enforcing `max_retries <= 1` and `task_count == 1`
- [x] `infra/modules/cloud-run-job/main.tf` provisions a dedicated runtime `google_service_account` (`sa-job-<job_name>`), scoped Secret Manager / GCS / BigQuery / Pub/Sub IAM bindings, `google_cloud_run_v2_job.job`, and (when `schedule_cron != null`) a dedicated Scheduler invoker binding + `google_cloud_scheduler_job.trigger` invoking the Cloud Run Jobs v2 `:run` API via OAuth token
- [x] `infra/modules/cloud-run-job/outputs.tf` exports `job_name`, `job_id`, `service_account_email`, and `scheduler_job_name` with descriptions
- [x] `make check` passes (`fmt-check`, `validate`, `tflint`, `shellcheck`, and `checkov` with zero failed checks)

## Implementation Tasks

### 1. Preparation & Branching
```bash
make start-issue ID=9 NAME=tf-module-cloud-run-job
```

### 2. Define Module Provider Constraints & Validated Input Contract (`infra/modules/cloud-run-job/versions.tf` & `variables.tf`)
- **File**: `infra/modules/cloud-run-job/versions.tf`, `infra/modules/cloud-run-job/variables.tf`
- **Change**: Create `versions.tf` locking Terraform `>= 1.5.0` and `hashicorp/google ~> 6.0`. Create `variables.tf` with validation blocks enforcing `max_retries >= 0 && max_retries <= 1` (preventing retry storms), `task_count == 1`, `timeout_seconds >= 10 && timeout_seconds <= 900`, `cpu` in `["1", "2"]`, `memory` in `["256Mi", "512Mi", "1Gi", "2Gi"]`, optional `schedule_cron`, and IAM grant maps for GCS, BigQuery, and Pub/Sub.

### 3. Implement Cloud Run v2 Job, Least-Privilege Runtime SA, and Optional Cloud Scheduler Trigger (`infra/modules/cloud-run-job/main.tf` & `outputs.tf`)
- **File**: `infra/modules/cloud-run-job/main.tf`, `infra/modules/cloud-run-job/outputs.tf`
- **Change**: Provision `google_service_account.runtime`, scoped IAM bindings (`google_secret_manager_secret_iam_member`, `google_storage_bucket_iam_member`, `google_bigquery_dataset_iam_member`, `google_pubsub_topic_iam_member`, `google_pubsub_subscription_iam_member`, and `roles/bigquery.jobUser` when `bigquery_dataset_roles` is non-empty), `google_cloud_run_v2_job.job`, and conditional `google_cloud_run_v2_job_iam_member.scheduler_invoker` + `google_cloud_scheduler_job.trigger` (targeting `https://${var.region}-run.googleapis.com/apis/run.googleapis.com/v1/namespaces/${var.project_id}/jobs/${google_cloud_run_v2_job.job.name}:run` with `oauth_token`). Export `job_name`, `job_id`, `service_account_email`, and `scheduler_job_name` in `outputs.tf`.

### 4. Verification & Quality Gates
```bash
make check
```

### 5. Git & Issue Finish
```bash
make finish-issue ID=9 MSG="feat(modules): implement cloud-run-job and Cloud Scheduler module"
```

## Decisions
- **Enforce `max_retries <= 1` and `task_count == 1` via Terraform variable validation**: Capping retries at 1 and tasks at 1 prevents failing batch or ETL jobs from entering retry loops that exhaust the monthly 180,000 vCPU-second Cloud Run Free Tier (`ADR-003`).
- **Make `schedule_cron` optional (`null` by default)**: Consolidating scheduled jobs into <= 3 active Cloud Scheduler jobs stays within the 3-job GCP Always Free quota (`$0.00/mo`), while allowing on-demand jobs (`P-09` trainer, `P-10` benchmarks, `P-11` stream bursts) to be triggered via `gcloud run jobs execute` or GitHub Actions `workflow_dispatch` at zero scheduler cost.
