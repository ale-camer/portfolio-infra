# Issue 3: Implement `infra/bootstrap` for Versioned GCS Terraform State Bucket

**Branch**: `feature/issue-3-tf-state-bootstrap`
**Status**: Done
**PR**: opened by `make finish-issue` → `develop` (Closes #3)
**Milestone**: M2 - Foundations

## Objective
Implement the Stage 1 Terraform bootstrap stack in `infra/bootstrap/` (using local state) to enable core storage APIs and provision a hardened, versioned Google Cloud Storage bucket (`<project_id>-tfstate`) that will serve as the remote state backend for `infra/platform/` from Issue #4 onward.

## Acceptance Criteria
- [x] `infra/bootstrap/versions.tf` defines Terraform `>= 1.5.0`, pinned `hashicorp/google` provider (`~> 6.0`), and explicit `backend "local" {}`
- [x] `infra/bootstrap/variables.tf` defines typed, documented, and validated variables (`project_id`, `region` defaulting to `us-central1`, `environment` defaulting to `prod`)
- [x] `infra/bootstrap/main.tf` enables `storage.googleapis.com` and `iam.googleapis.com` and provisions `google_storage_bucket.tfstate` (`<project_id>-tfstate`) with versioning, `uniform_bucket_level_access = true`, `public_access_prevention = "enforced"`, lifecycle cleanup for old noncurrent state versions, and standard portfolio labels
- [x] `infra/bootstrap/outputs.tf` exports `tfstate_bucket_name`, `tfstate_bucket_url`, and `backend_config_snippet` with descriptions
- [x] `make check` passes (`fmt-check`, `validate`, `tflint`, `shellcheck`, and `checkov` with zero failed checks)

## Implementation Tasks

### 1. Preparation & Branching
```bash
make start-issue ID=3 NAME=tf-state-bootstrap
```

### 2. Define Terraform Versions, Provider, and Input Variables (`infra/bootstrap/`)
- **File**: `infra/bootstrap/versions.tf`, `infra/bootstrap/variables.tf`
- **Change**: Create `versions.tf` locking `required_version = ">= 1.5.0"`, `hashicorp/google` provider `~> 6.0`, and `backend "local" {}`. Create `variables.tf` with typed, documented, and validated inputs for `project_id`, `region` (`us-central1`), and `environment` (`prod`) satisfying all `tflint` rules (`terraform_documented_variables`, `terraform_typed_variables`).

### 3. Provision Required APIs and Hardened GCS State Bucket (`infra/bootstrap/main.tf`)
- **File**: `infra/bootstrap/main.tf`
- **Change**: Provision `google_project_service` for `storage.googleapis.com` and `iam.googleapis.com` (`disable_on_destroy = false`) and `google_storage_bucket.tfstate` (`name = "${var.project_id}-tfstate"`, `location = var.region`, `storage_class = "STANDARD"`, `uniform_bucket_level_access = true`, `public_access_prevention = "enforced"`, `versioning { enabled = true }`, lifecycle rule keeping up to 5 noncurrent versions / 30 days, and labels `project=portfolio`, `env=prod`, `repo=portfolio-infra`, `managed_by=terraform`). Document any Checkov justification if customer-managed CMEK is skipped to stay within the `< $10/month` budget (using free Google-managed encryption instead of paid Cloud KMS keys).

### 4. Export State Bucket Outputs & Usage Documentation (`infra/bootstrap/outputs.tf`)
- **File**: `infra/bootstrap/outputs.tf`
- **Change**: Export `tfstate_bucket_name`, `tfstate_bucket_url`, and `backend_config_snippet` (satisfying `tflint` `terraform_documented_outputs`) so `infra/platform` in Issue #4 can reference the exact GCS backend configuration.

### 5. Verification & Quality Gates
```bash
make check
```

### 6. Git & Issue Finish
```bash
make finish-issue ID=3 MSG="feat(bootstrap): add GCS remote state bootstrap stack"
```

## Decisions
- **Use Google-managed encryption (GMEK) instead of Cloud KMS (CMEK) on the state bucket**: Cloud KMS charges `$0.06/key version/month` plus operation fees and creates a circular key-state dependency during bootstrap. Using default Google-managed AES-256 encryption with Checkov skip justification (`CKV_GCP_62` bucket access logging self-loop and CMEK if flagged) keeps encryption at `$0.00/month`.
- **Retain last 5 noncurrent state versions with 30-day lifecycle expiry**: Object versioning protects against accidental state corruption, while the lifecycle rule (`num_newer_versions = 5`, `days_since_noncurrent_time = 30`) prevents unbounded historical state objects from consuming the 5 GB GCS Standard Free Tier.
