# Issue 8: Implement Reusable `infra/modules/cloud-run-service` Terraform Module (Scale-to-Zero Enforced)

**Branch**: `feature/issue-8-tf-module-cloud-run-service`
**Status**: Done
**PR**: opened by `make finish-issue` → `develop` (Closes #8)
**Milestone**: M3 - Modules & Pilot

## Objective
Implement the reusable `infra/modules/cloud-run-service/` Terraform module (`versions.tf`, `variables.tf`, `main.tf`, `outputs.tf`) to standardize deployment of the 7 HTTP/API/UI workloads (`P-01`, `P-03`, `P-04`, `P-06`, `P-07`, `P-08`, `P-09`) on Cloud Run v2 with hard cost guardrails (`min_instance_count = 0`, `max_instance_count <= 2`, `cpu_idle = true`), dedicated least-privilege runtime Service Accounts, Secret Manager volume/env bindings, and startup/liveness probes.

## Acceptance Criteria
- [x] `infra/modules/cloud-run-service/versions.tf` locks `required_version = ">= 1.5.0"` and `hashicorp/google` (`~> 6.0`)
- [x] `infra/modules/cloud-run-service/variables.tf` defines typed, documented, and validated inputs (`project_id`, `region`, `service_name`, `repo_name`, `image`, `port`, `cpu`, `memory`, `min_instance_count`, `max_instance_count`, `concurrency`, `timeout_seconds`, `allow_public_invoker`, `env_vars`, `secret_env_vars`, `health_check_path`, `storage_bucket_roles`, `bigquery_dataset_roles`, `labels`) enforcing `min_instance_count == 0` and `max_instance_count <= 2`
- [x] `infra/modules/cloud-run-service/main.tf` provisions a dedicated `google_service_account` (`sa-run-<service_name>`), binds `roles/secretmanager.secretAccessor` only to referenced secrets, binds `roles/iam.serviceAccountUser` for `sa-cicd-deployer` (when provided), provisions `google_cloud_run_v2_service` (`cpu_idle = true`, `startup_cpu_boost = true`, startup/liveness HTTP probes), and conditionally configures `roles/run.invoker` (`allUsers` when `allow_public_invoker = true`)
- [x] `infra/modules/cloud-run-service/outputs.tf` exports `service_name`, `service_id`, `service_uri`, and `service_account_email` with descriptions
- [x] `make check` passes (`fmt-check`, `validate`, `tflint`, `shellcheck`, and `checkov` with zero failed checks)

## Implementation Tasks

### 1. Preparation & Branching
```bash
make start-issue ID=8 NAME=tf-module-cloud-run-service
```

### 2. Define Module Provider Constraints & Hardened Input Contract (`infra/modules/cloud-run-service/versions.tf` & `variables.tf`)
- **File**: `infra/modules/cloud-run-service/versions.tf`, `infra/modules/cloud-run-service/variables.tf`
- **Change**: Create `versions.tf` locking Terraform `>= 1.5.0` and `hashicorp/google ~> 6.0`. Create `variables.tf` with validation blocks enforcing `min_instance_count == 0` (hard scale-to-zero per `ADR-003`), `max_instance_count >= 1 && max_instance_count <= 2` (hard concurrency cap), `cpu` in `["1", "2"]`, `memory` in `["256Mi", "512Mi", "1Gi", "2Gi"]`, and typed maps for `env_vars`, `secret_env_vars`, `storage_bucket_roles`, and `bigquery_dataset_roles`.

### 3. Implement Cloud Run v2 Service, Least-Privilege Runtime SA, and Secret/Storage IAM (`infra/modules/cloud-run-service/main.tf` & `outputs.tf`)
- **File**: `infra/modules/cloud-run-service/main.tf`, `infra/modules/cloud-run-service/outputs.tf`
- **Change**: Provision `google_service_account.runtime`, per-secret `google_secret_manager_secret_iam_member.secret_accessor` (deduplicated across `secret_env_vars`), optional `google_storage_bucket_iam_member` / `google_bigquery_dataset_iam_member` bindings, optional `roles/iam.serviceAccountUser` for `cicd_deployer_sa_email`, `google_cloud_run_v2_service.service` (`ingress = "INGRESS_TRAFFIC_ALL"`, `scaling { min_instance_count = 0, max_instance_count = var.max_instance_count }`, `resources { cpu_idle = true, startup_cpu_boost = true }`, HTTP `startup_probe` and `liveness_probe` on `var.health_check_path`), and conditional `google_cloud_run_v2_service_iam_member.public_invoker`. Export `service_name`, `service_id`, `service_uri`, and `service_account_email` in `outputs.tf`.

### 4. Verification & Quality Gates
```bash
make check
```

### 5. Git & Issue Finish
```bash
make finish-issue ID=8 MSG="feat(modules): implement cloud-run-service module with scale-to-zero guardrails"
```

## Decisions
- **Enforce `min_instance_count == 0` and `max_instance_count <= 2` via Terraform variable validation**: Rejecting non-zero minimum instances or high max instance counts at validation time guarantees that no service can accidentally burn 24/7 vCPU/GiB-seconds outside the Cloud Run Always Free tier (`ADR-003`).
- **Scope `roles/secretmanager.secretAccessor` strictly to `toset([for s in values(var.secret_env_vars) : s.secret_id])`**: A Cloud Run service only receives IAM access to the specific Secret Manager containers it mounts, enforcing per-workload secret isolation even when the 6 platform secrets are shared across the portfolio.
