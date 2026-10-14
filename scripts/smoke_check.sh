#!/usr/bin/env bash
set -euo pipefail

REQUIRED_DIRS=(
  "infra/bootstrap"
  "infra/platform"
  "infra/modules"
  "scripts"
  "docs"
  ".github/workflows"
  ".agents/rules"
)

REQUIRED_FILES=(
  ".gitignore"
  ".env.example"
  "terraform.tfvars.example"
  ".tflint.hcl"
  ".checkov.yaml"
  "Makefile"
  "README.md"
  "docs/roadmap.md"
  "docs/issue_0_setup.md"
  ".agents/rules/workflow.md"
  ".github/workflows/ci.yml"
  "scripts/bootstrap_github.sh"
)

for dir in "${REQUIRED_DIRS[@]}"; do
  if [[ ! -d "$dir" ]]; then
    echo "ERROR: Required directory '$dir' is missing." >&2
    exit 1
  fi
done

for file in "${REQUIRED_FILES[@]}"; do
  if [[ ! -f "$file" ]]; then
    echo "ERROR: Required file '$file' is missing." >&2
    exit 1
  fi
done

if [[ -f ".env" ]] && git ls-files --error-unmatch .env >/dev/null 2>&1; then
  echo "ERROR: '.env' must never be tracked by git." >&2
  exit 1
fi

if git ls-files | grep -E '\.(tfvars|tfstate)$' | grep -v '^terraform\.tfvars\.example$' >/dev/null 2>&1; then
  echo "ERROR: Sensitive Terraform state or variable files are tracked by git." >&2
  exit 1
fi

if ! compgen -G "docs/issue_[1-9]*.md" >/dev/null && grep -rnE '^\s*resource\s+"' infra/ >/dev/null 2>&1; then
  echo "ERROR: Day 0 scaffolding must not contain real Terraform resource blocks." >&2
  exit 1
fi

echo "Smoke check passed: repository structure and security boundaries verified."
