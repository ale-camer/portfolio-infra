.DEFAULT_GOAL := help
SHELL := /usr/bin/env bash

.PHONY: help fmt fmt-check validate lint security check plan clean start-issue finish-issue finish-milestone

TF_DIRS := infra/bootstrap infra/platform

help: ## Show this help message
	@echo "Portfolio Infrastructure & Deployment (P-12) - Available targets:"
	@grep -E '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}'

fmt: ## Format all Terraform files recursively
	@command -v terraform >/dev/null 2>&1 || { echo "Missing terraform: sudo dnf install -y terraform"; exit 1; }
	terraform fmt -recursive infra/

fmt-check: ## Check Terraform formatting recursively
	@command -v terraform >/dev/null 2>&1 || { echo "Missing terraform: sudo dnf install -y terraform"; exit 1; }
	terraform fmt -check -recursive infra/

validate: ## Run smoke check and terraform init -backend=false + validate on all active stacks
	@command -v terraform >/dev/null 2>&1 || { echo "Missing terraform: sudo dnf install -y terraform"; exit 1; }
	bash scripts/smoke_check.sh
	@for dir in $(TF_DIRS) $$(find infra/modules -mindepth 1 -maxdepth 1 -type d 2>/dev/null); do \
		if compgen -G "$$dir/*.tf" > /dev/null; then \
			echo "==> Validating $$dir"; \
			terraform -chdir="$$dir" init -backend=false -input=false >/dev/null && \
			terraform -chdir="$$dir" validate; \
		fi; \
	done

lint: ## Run tflint on Terraform files and shellcheck on shell scripts
	@command -v tflint >/dev/null 2>&1 || { echo "Missing tflint: curl -s https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh | bash"; exit 1; }
	@command -v shellcheck >/dev/null 2>&1 || { echo "Missing shellcheck: sudo dnf install -y ShellCheck"; exit 1; }
	shellcheck scripts/*.sh
	tflint --init --config "$$(pwd)/.tflint.hcl" >/dev/null
	@for dir in $(TF_DIRS) $$(find infra/modules -mindepth 1 -maxdepth 1 -type d 2>/dev/null); do \
		if compgen -G "$$dir/*.tf" > /dev/null; then \
			echo "==> Linting $$dir"; \
			tflint --config "$$(pwd)/.tflint.hcl" --chdir="$$dir"; \
		fi; \
	done

security: ## Run checkov security scan on Terraform and GitHub Actions
	@command -v checkov >/dev/null 2>&1 || { echo "Missing checkov: pipx install checkov (or pip install --user checkov)"; exit 1; }
	checkov --config-file .checkov.yaml

check: fmt-check validate lint security ## Run all quality gates (fmt-check + validate + lint + security)

plan: ## Run informative terraform plan on infra/platform (requires user authorization and GCP credentials)
	@command -v terraform >/dev/null 2>&1 || { echo "Missing terraform: sudo dnf install -y terraform"; exit 1; }
	terraform -chdir=infra/platform plan -input=false

clean: ## Remove local .terraform caches and temporary files
	find infra/ -type d -name ".terraform" -prune -exec rm -rf {} +
	find infra/ -type f -name "*.tfplan" -delete

start-issue: ## Start a new issue branch from develop (requires ID=X NAME=short-name [TYPE=feature|fix])
	@if [ -z "$(ID)" ] || [ -z "$(NAME)" ]; then echo "Error: ID and NAME are required (e.g., make start-issue ID=1 NAME=portfolio-inventory)"; exit 1; fi
	$(eval TYPE ?= feature)
	git checkout develop
	git pull origin develop
	git checkout -b $(TYPE)/issue-$(ID)-$(NAME)

finish-issue: ## Validate, commit, push, PR, squash-merge, and close issue (requires ID=X MSG="type(scope): desc")
	@if [ -z "$(ID)" ] || [ -z "$(MSG)" ]; then echo "Error: ID and MSG are required"; exit 1; fi
	@BRANCH=$$(git rev-parse --abbrev-ref HEAD); \
	if [[ ! "$$BRANCH" =~ ^(feature|fix)/issue-$(ID)- ]]; then \
		echo "Error: Current branch $$BRANCH does not match issue-$(ID)-*"; exit 1; \
	fi
	$(MAKE) check
	git add -A
	git commit -m "$(MSG)"
	git push -u origin HEAD
	@BRANCH=$$(git rev-parse --abbrev-ref HEAD); \
	if [ "$(ID)" = "0" ]; then \
		gh pr create --base develop --head "$$BRANCH" --title "$(MSG)" --body "Day 0 repository setup and scaffolding." || true; \
		gh pr merge "$$BRANCH" --squash --delete-branch || true; \
	else \
		gh pr create --base develop --head "$$BRANCH" --title "$(MSG)" --body "Closes #$(ID)" || true; \
		gh pr merge "$$BRANCH" --squash --delete-branch || true; \
		gh issue close $(ID) || true; \
	fi
	git checkout develop
	git pull origin develop
	@git branch -D "$$BRANCH" 2>/dev/null || true

finish-milestone: ## Merge develop into main (merge commit), tag milestone, and close it (requires MILESTONE=MX)
	@if [ -z "$(MILESTONE)" ]; then echo "Error: MILESTONE is required (e.g., make finish-milestone MILESTONE=M1)"; exit 1; fi
	git checkout develop
	git pull origin develop
	gh pr create --base main --head develop --title "chore(release): finish milestone $(MILESTONE)" --body "Merge develop into main for milestone $(MILESTONE)" || true
	gh pr merge develop --merge || true
	git checkout main
	git pull origin main
	git tag -a $(MILESTONE) -m "Release $(MILESTONE)"
	git push origin $(MILESTONE)
	@MS_NUM=$$(gh api repos/:owner/:repo/milestones --jq ".[] | select(.title | startswith(\"$(MILESTONE)\")) | .number"); \
	if [ -n "$$MS_NUM" ]; then gh api -X PATCH "repos/:owner/:repo/milestones/$$MS_NUM" -f state=closed >/dev/null; fi
	git checkout develop
