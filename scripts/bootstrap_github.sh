#!/usr/bin/env bash
set -euo pipefail

REPO_NAME="ale-camer/portfolio-infra"

echo "==> Creating public GitHub repository ${REPO_NAME} (if not exists)..."
if ! gh repo view "${REPO_NAME}" >/dev/null 2>&1; then
  gh repo create "${REPO_NAME}" \
    --public \
    --description "Centralized GCP Terraform IaC and CI/CD for the Financial Markets Intelligence Platform (P-01 to P-11)" \
    --source=. \
    --remote=origin
fi

echo "==> Pushing main and develop branches..."
git push -u origin main
git push -u origin develop

create_milestone() {
  local title="$1"
  local description="$2"
  if ! gh api repos/:owner/:repo/milestones --jq '.[].title' | grep -Fxq "$title"; then
    gh api repos/:owner/:repo/milestones -f title="$title" -f description="$description" >/dev/null
    echo "Created milestone: $title"
  fi
}

echo "==> Creating Milestones M1 to M5..."
create_milestone "M1 - Audit" "Read-only inventory of P-01..P-11 and low-cost GCP architecture (<10 USD/mo)."
create_milestone "M2 - Foundations" "State bootstrap, GCP APIs, 10 USD budget, Artifact Registry, Secret Manager, WIF/OIDC, Cloud Run modules."
create_milestone "M3 - Pilot Deploy" "End-to-end deployment of pilot repo (P-04), reusable cd.yml workflow, and runbook."
create_milestone "M4 - Rollout" "Progressive infrastructure provisioning and rollout specs for the remaining 10 repos."
create_milestone "M5 - Observability & Cost" "Cloud Monitoring uptime checks/alerts, cost verification, teardown guide, and final docs."

create_issue() {
  local ms="$1"
  local title="$2"
  local body="$3"
  gh issue create --title "$title" --body "$body" --milestone "$ms"
}

echo "==> Creating Issues #1 to #21 in strict numerical order..."
# M1 - Audit (#1 - #2)
create_issue "M1 - Audit" "Issue 1: Audit P-01 to P-11 services, databases, secrets, CI, and costs in docs/inventory.md" "Read-only audit of all 11 sibling repositories."
create_issue "M1 - Audit" "Issue 2: Define target GCP architecture and component decisions in docs/architecture.md" "Target GCP architecture (<10 USD/mo) and per-component decisions. Closes M1."

# M2 - Foundations (#3 - #8)
create_issue "M2 - Foundations" "Issue 3: Implement infra/bootstrap for versioned GCS Terraform state bucket" "Local-state bootstrap stack for remote Terraform state bucket."
create_issue "M2 - Foundations" "Issue 4: Configure infra/platform backend, required GCP APIs, and 10 USD google_billing_budget" "Remote state backend, GCP APIs, and 10 USD/month budget alerts (50/80/100%)."
create_issue "M2 - Foundations" "Issue 5: Provision Artifact Registry with cleanup policies, shared GCS buckets, and BigQuery datasets" "Container registry with retention policy plus free-tier GCS and BigQuery."
create_issue "M2 - Foundations" "Issue 6: Provision Secret Manager secret shells and IAM access bindings" "Secret Manager containers without secret values in Terraform state."
create_issue "M2 - Foundations" "Issue 7: Configure Workload Identity Federation (OIDC) and deploy-service-account module" "Keyless GitHub Actions authentication to GCP with per-repo least-privilege SAs."
create_issue "M2 - Foundations" "Issue 8: Create reusable cloud-run-service and cloud-run-job Terraform modules" "Scale-to-zero Cloud Run service and scheduled job modules. Closes M2."

# M3 - Pilot Deploy (#9 - #10)
create_issue "M3 - Pilot Deploy" "Issue 9: Provision Cloud Run infrastructure, secrets, and WIF SA for pilot repo (P-04)" "Platform infrastructure for financial-news-intelligence-api."
create_issue "M3 - Pilot Deploy" "Issue 10: Create reusable cd.yml workflow template, P-04 deployment spec, and docs/runbook.md" "Reusable GitHub Actions CD workflow and pilot deployment runbook. Closes M3."

# M4 - Rollout (#11 - #19)
create_issue "M4 - Rollout" "Issue 11: Configure external free-tier database connectivity (Neon pgvector and MongoDB Atlas M0)" "Secret bindings and connection patterns for external free-tier databases."
create_issue "M4 - Rollout" "Issue 12: Provision Cloud Run Job + Scheduler and rollout specification for P-01" "Serverless batch schedule and rollout spec for financial-markets-pipeline."
create_issue "M4 - Rollout" "Issue 13: Provision Cloud Run Job + BigQuery/GCS bindings and rollout specification for P-02" "Batch schedule and lakehouse bindings for crypto-analytics-platform."
create_issue "M4 - Rollout" "Issue 14: Provision Pub/Sub streaming replacement (or local demo spec) and bindings for P-03" "Event streaming infrastructure and rollout spec for real-time-market-events."
create_issue "M4 - Rollout" "Issue 15: Provision Cloud Run Service infrastructure and rollout specification for P-05" "Scale-to-zero API infrastructure and rollout spec for market-intelligence-hub."
create_issue "M4 - Rollout" "Issue 16: Provision serverless batch/API infrastructure and rollout specification for P-06" "MLOps anomaly detection infrastructure for asset-anomaly-detection."
create_issue "M4 - Rollout" "Issue 17: Provision Cloud Run Service + pgvector secret bindings and rollout specification for P-07" "RAG API infrastructure for financial-documents-rag."
create_issue "M4 - Rollout" "Issue 18: Provision Cloud Run Service infrastructure and rollout specification for P-08" "End-to-end intelligence API infrastructure for ai-powered-market-intelligence."
create_issue "M4 - Rollout" "Issue 19: Provision Cloud Run Services with LLM budget guardrails for AI Agent repos (P-09, P-10, P-11)" "Infrastructure and spend guardrails for P-09, P-10, and P-11. Closes M4."

# M5 - Observability & Cost (#20 - #21)
create_issue "M5 - Observability & Cost" "Issue 20: Provision Cloud Monitoring uptime checks, log-based error alerts, and latency dashboard" "Free-tier Cloud Monitoring observability for deployed services."
create_issue "M5 - Observability & Cost" "Issue 21: Create docs/teardown.md, cost verification checklist, and finalize README.md" "Platform teardown runbook and final documentation. Closes M5."

echo "==> GitHub bootstrap completed."
