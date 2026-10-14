# Roadmap: Portfolio Infrastructure & Deployment (P-12)

This roadmap defines the 5 milestones (`M1`–`M5`) and 21 atomic issues required to audit, provision, deploy, and monitor the 11 projects of the Financial Markets Intelligence Platform (`P-01` to `P-11`) on GCP under **$10/month**.

## Milestone Overview

| Milestone | Name | Objective | Issues | Closing Issue |
|:---:|:---|:---|:---:|:---:|
| **M0** | Setup | Day 0 repository scaffolding, governance rules, quality gates, and GitHub bootstrap | #0 | #0 |
| **M1** | Audit | Read-only audit of P-01..P-11 (`docs/inventory.md`) and target low-cost GCP design (`docs/architecture.md`) | #1–#2 | **#2** |
| **M2** | Foundations | Terraform state bootstrap, project APIs, $10 billing budget, Artifact Registry, Secret Manager, WIF/OIDC, reusable Cloud Run modules, and IaC CI hardening | #3–#8 | **#8** |
| **M3** | Pilot Deploy | End-to-end deployment of the simplest service repo, reusable `cd.yml` template, and operational runbook (`docs/runbook.md`) | #9–#10 | **#10** |
| **M4** | Rollout | Progressive infrastructure provisioning and CD rollout plans for the remaining 10 repositories in dependency order | #11–#19 | **#19** |
| **M5** | Observability & Cost | Cloud Monitoring uptime checks/alerts, cost audit, teardown guide (`docs/teardown.md`), and final documentation | #20–#21 | **#21** |

---

## Issues Table

| ID | Milestone | Short Name | Issue Title | Closes Milestone? |
|:---:|:---|:---|:---|:---:|
| 0 | M0 - Setup | `setup` | Day 0 repository setup and scaffolding | N/A |
| 1 | M1 - Audit | `portfolio-inventory` | Audit P-01 to P-11 services, databases, secrets, CI, and costs in `docs/inventory.md` | No |
| 2 | M1 - Audit | `target-architecture` | Define target GCP architecture and component decisions in `docs/architecture.md` | **Yes (M1)** |
| 3 | M2 - Foundations | `tf-state-bootstrap` | Implement `infra/bootstrap` for versioned GCS Terraform state bucket | No |
| 4 | M2 - Foundations | `gcp-project-apis-budget` | Configure `infra/platform` backend, required GCP APIs, and $10 `google_billing_budget` | No |
| 5 | M2 - Foundations | `artifact-registry-storage` | Provision Artifact Registry with cleanup policies, shared GCS buckets, and BigQuery datasets | No |
| 6 | M2 - Foundations | `secret-manager-baseline` | Provision Secret Manager secret shells and IAM access bindings | No |
| 7 | M2 - Foundations | `wif-github-oidc` | Configure Workload Identity Federation (OIDC) and `deploy-service-account` module | No |
| 8 | M2 - Foundations | `cloud-run-modules` | Create reusable `cloud-run-service` and `cloud-run-job` Terraform modules | **Yes (M2)** |
| 9 | M3 - Pilot Deploy | `pilot-infra-provision` | Provision Cloud Run infrastructure, secrets, and WIF SA for pilot repo (P-04) | No |
| 10 | M3 - Pilot Deploy | `pilot-cd-runbook` | Create reusable `cd.yml` workflow template, P-04 deployment spec, and `docs/runbook.md` | **Yes (M3)** |
| 11 | M4 - Rollout | `external-free-tier-dbs` | Configure external free-tier database connectivity (Neon `pgvector` and MongoDB Atlas M0) | No |
| 12 | M4 - Rollout | `rollout-p01-daily-pipeline` | Provision Cloud Run Job + Scheduler and rollout specification for P-01 | No |
| 13 | M4 - Rollout | `rollout-p02-crypto-analytics` | Provision Cloud Run Job + BigQuery/GCS bindings and rollout specification for P-02 | No |
| 14 | M4 - Rollout | `rollout-p03-market-events` | Provision Pub/Sub streaming replacement (or local demo spec) and bindings for P-03 | No |
| 15 | M4 - Rollout | `rollout-p05-intelligence-hub` | Provision Cloud Run Service infrastructure and rollout specification for P-05 | No |
| 16 | M4 - Rollout | `rollout-p06-anomaly-mlops` | Provision serverless batch/API infrastructure and rollout specification for P-06 | No |
| 17 | M4 - Rollout | `rollout-p07-documents-rag` | Provision Cloud Run Service + `pgvector` secret bindings and rollout specification for P-07 | No |
| 18 | M4 - Rollout | `rollout-p08-e2e-intelligence` | Provision Cloud Run Service infrastructure and rollout specification for P-08 | No |
| 19 | M4 - Rollout | `rollout-p09-p10-p11-agents` | Provision Cloud Run Services with LLM budget guardrails for AI Agent repos (P-09, P-10, P-11) | **Yes (M4)** |
| 20 | M5 - Observability & Cost | `monitoring-uptime-alerts` | Provision Cloud Monitoring uptime checks, log-based error alerts, and latency dashboard | No |
| 21 | M5 - Observability & Cost | `teardown-and-final-docs` | Create `docs/teardown.md`, cost verification checklist, and finalize `README.md` | **Yes (M5)** |
