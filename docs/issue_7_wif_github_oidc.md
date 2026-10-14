# Issue 7: Provision GitHub Actions Workload Identity Federation (WIF) Pool, OIDC Provider, and Deployer IAM

**Branch**: `feature/issue-7-wif-github-oidc`
**Status**: Done
**PR**: opened by `make finish-issue` → `develop` (Closes #7)
**Milestone**: M2 - Foundations (Closes Milestone)

## Objective
Provision keyless GitHub Actions authentication in `infra/platform/wif.tf` and `infra/platform/iam.tf` using a GCP Workload Identity Pool (`github-actions-pool`), an OIDC provider (`github-oidc-provider`, issuer `https://token.actions.githubusercontent.com`) guarded by `assertion.repository_owner == var.github_owner`, and dedicated least-privilege deployer Service Accounts (`sa-cicd-deployer` for sibling app repos `P-01`..`P-11` and `sa-infra-terraform` for `portfolio-infra`) with zero static JSON service account keys (`ADR-002`).

## Acceptance Criteria
- [x] `infra/platform/wif.tf` provisions `google_iam_workload_identity_pool.github` (`github-actions-pool`) and `google_iam_workload_identity_pool_provider.github_oidc` (`github-oidc-provider`) with OIDC issuer `https://token.actions.githubusercontent.com`, attribute mappings (`google.subject`, `attribute.actor`, `attribute.repository`, `attribute.repository_owner`, `attribute.ref`), and `attribute_condition = "assertion.repository_owner == '${var.github_owner}'"`
- [x] `infra/platform/iam.tf` provisions `google_service_account.cicd_deployer` (`sa-cicd-deployer`) and `google_service_account.infra_terraform` (`sa-infra-terraform`) with zero `google_service_account_key` resources
- [x] `infra/platform/iam.tf` binds `sa-cicd-deployer` to least-privilege deployment roles (`roles/artifactregistry.writer` on `portfolio-apps`, `roles/run.developer`, `roles/iam.serviceAccountUser` for runtime SAs) and binds `roles/iam.workloadIdentityUser` scoped to the 11 sibling repositories (`P-01`..`P-11`) on `sa-cicd-deployer` and `portfolio-infra` on `sa-infra-terraform`
- [x] `infra/platform/outputs.tf` exports `wif_pool_name`, `wif_provider_name`, `cicd_deployer_sa_email`, and `infra_terraform_sa_email` for GitHub Actions `google-github-actions/auth@v2` configuration
- [x] `make check` passes (`fmt-check`, `validate`, `tflint`, `shellcheck`, and `checkov` with zero failed checks)

## Implementation Tasks

### 1. Preparation & Branching
```bash
make start-issue ID=7 NAME=wif-github-oidc
```

### 2. Provision Workload Identity Pool & GitHub OIDC Provider (`infra/platform/wif.tf`)
- **File**: `infra/platform/wif.tf`
- **Change**: Create `google_iam_workload_identity_pool.github` (`workload_identity_pool_id = "github-actions-pool"`) and `google_iam_workload_identity_pool_provider.github_oidc` (`workload_identity_pool_provider_id = "github-oidc-provider"`, `oidc { issuer_uri = "https://token.actions.githubusercontent.com" }`, attribute mappings for `google.subject`, `attribute.actor`, `attribute.repository`, `attribute.repository_owner`, `attribute.ref`, and `attribute_condition = "assertion.repository_owner == '${var.github_owner}'"`).

### 3. Provision Keyless CI/CD Service Accounts & Scoped WIF/IAM Bindings (`infra/platform/iam.tf` & `outputs.tf`)
- **File**: `infra/platform/iam.tf`, `infra/platform/outputs.tf`
- **Change**: Define `local.sibling_repositories` (the 11 sibling repository slugs `P-01`..`P-11`), create `google_service_account.cicd_deployer` (`sa-cicd-deployer`) and `google_service_account.infra_terraform` (`sa-infra-terraform`), bind `roles/artifactregistry.writer` on `google_artifact_registry_repository.portfolio_apps` and project-level `roles/run.developer` to `sa-cicd-deployer`, and bind `roles/iam.workloadIdentityUser` via `principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${var.github_owner}/${repo}` for each sibling repo on `sa-cicd-deployer` and for `portfolio-infra` on `sa-infra-terraform`. Export WIF provider name and SA emails in `infra/platform/outputs.tf`.

### 4. Verification & Quality Gates
```bash
make check
```

### 5. Git & Issue Finish (Closes Milestone M2)
```bash
make finish-issue ID=7 MSG="feat(platform): provision GitHub Actions WIF pool, OIDC provider, and deployer IAM" CLOSE_MILESTONE="M2 - Foundations"
```

## Decisions
- **Separate `sa-cicd-deployer` (application image push + Cloud Run rollout for `P-01`..`P-11`) from `sa-infra-terraform` (`portfolio-infra` IaC plans)**: Isolating sibling repository CI pipelines from Terraform state/IAM administration enforces blast-radius containment (`ADR-002`) so an application repository workflow can only push images to `portfolio-apps` and update Cloud Run revisions.
- **Enforce `attribute_condition = "assertion.repository_owner == '${var.github_owner}'"` at the WIF Provider boundary**: Rejecting OIDC tokens from any other GitHub user/organization at the STS token-exchange boundary satisfies Checkov (`CKV_GCP_125`) and prevents cross-tenant confused-deputy attacks.
