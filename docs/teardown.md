# Platform Hibernation, Teardown & `< $10/month` Cost Verification Runbook

This runbook documents the three graduated cost-reduction and decommission modes for the **Financial Markets Intelligence Platform** (`P-01` through `P-11` managed by `portfolio-infra` / `P-12`), followed by an executable **Monthly Cost & Quota Verification Checklist** that guarantees steady-state GCP and external database spend stays strictly within **`~$1.62/month`** (hard budget ceiling: **`$10.00/month`**).

---

## 1. Three-Mode Cost Control & Teardown Strategy

| Mode | Objective | Steady-State Cost | Data & State Preserved? | Recovery Time |
|:---|:---|:---:|:---|:---:|
| **Mode 1 — Zero-Compute Hibernation** | Pause scheduled jobs and 15-minute uptime checks while keeping all services at `min_instances = 0` | **`~$0.12/mo`** | Yes (GCS, BigQuery, Neon, Atlas M0, Upstash, Artifact Registry, TF state) | `< 1 min` |
| **Mode 2 — Platform Stack Teardown** | Destroy all `infra/platform` resources via Terraform while retaining the `infra/bootstrap` state bucket | **`$0.00/mo`** | Remote TF state bucket (`<project>-tfstate`) + external Free Tier DBs | `~5 min` |
| **Mode 3 — Complete Decommission** | Destroy `infra/platform`, empty/destroy `infra/bootstrap`, decommission external DBs, and optionally shut down the GCP project | **`$0.00/mo`** | None (clean slate) | `~15 min` |

---

## 2. Mode 1 — Zero-Compute Hibernation (Keep All Data & State)

Because every Cloud Run Service (`p03-market-events`, `p05-hub-api`, `p06-anomaly-api`, `p07-docs-rag`, `p08-market-intel`, `p09-research-agent`, `p10-trading-analyst`, `p11-multi-agent`) is provisioned with `min_instance_count = 0` and CPU throttling enabled (`cpu_idle = true`), **idle HTTP services cost $0.00/month**.

During periods when no demos or batch pipelines are needed, you can eliminate all background container invocations in two steps:

### Step 1.1 — Pause Cloud Scheduler Cron Triggers (`P-01`, `P-02`, `P-05`)
```bash
export GCP_PROJECT_ID="portfolio-platform-000000"
export GCP_REGION="us-central1"

for JOB in sched-p01-daily-etl sched-p02-crypto-etl sched-p05-dbt-build; do
  gcloud scheduler jobs pause "${JOB}" \
    --project="${GCP_PROJECT_ID}" \
    --location="${GCP_REGION}"
done
```

### Step 1.2 — Disable 15-Minute Cloud Monitoring Uptime Probes via Terraform
Set `enable_uptime_checks = false` to remove the 8 periodic `GET /health` probes so Cloud Run Services remain scaled at `0` instances indefinitely until an explicit user request arrives:
```bash
terraform -chdir=infra/platform apply \
  -var="enable_uptime_checks=false"
```

### Step 1.3 — Resume Normal Operations from Hibernation
```bash
terraform -chdir=infra/platform apply \
  -var="enable_uptime_checks=true"

for JOB in sched-p01-daily-etl sched-p02-crypto-etl sched-p05-dbt-build; do
  gcloud scheduler jobs resume "${JOB}" \
    --project="${GCP_PROJECT_ID}" \
    --location="${GCP_REGION}"
done
```

---

## 3. Mode 2 — Full Platform Stack Teardown (`infra/platform`)

Mode 2 destroys all GCP application, messaging, observability, storage, BigQuery, Artifact Registry, Secret Manager, and Workload Identity Federation resources managed in `infra/platform/` while preserving the remote Terraform state bucket (`infra/bootstrap/`).

### Step 2.1 — Empty Non-Empty GCS Data Buckets (If `force_destroy` Is Restricted)
Both `${GCP_PROJECT_ID}-data-lake` and `${GCP_PROJECT_ID}-artifacts` are configured with `force_destroy = true`, so Terraform can remove them directly. If you want to archive or explicitly purge objects beforehand:
```bash
gcloud storage rm --recursive "gs://${GCP_PROJECT_ID}-data-lake/**" || true
gcloud storage rm --recursive "gs://${GCP_PROJECT_ID}-artifacts/**" || true
```

### Step 2.2 — Run `terraform destroy` on `infra/platform`
```bash
terraform -chdir=infra/platform init
terraform -chdir=infra/platform destroy
```
> **Result**: All 8 Cloud Run Services, 5 Cloud Run Jobs, 3 Cloud Scheduler triggers, Pub/Sub topics/DLQs (`p03-market-events`, `p03-market-events-dlq`), BigQuery datasets (`crypto_analytics`, `market_intelligence`), GCS buckets (`data-lake`, `artifacts`), Artifact Registry (`portfolio-apps`), 6 Secret Manager shells, WIF pool/provider, and Cloud Monitoring dashboards/alerts/uptime checks are cleanly destroyed.

---

## 4. Mode 3 — Complete Decommission (`infra/bootstrap` + External DBs + GCP Project)

Use Mode 3 only when permanently retiring the entire portfolio environment.

### Step 3.1 — Complete Mode 2 (`infra/platform` Destroy)
Verify `infra/platform` has zero remaining resources in remote state:
```bash
terraform -chdir=infra/platform state list
```

### Step 3.2 — Empty and Destroy the Versioned Remote State Bucket (`infra/bootstrap`)
Because `google_storage_bucket.tfstate` in `infra/bootstrap/main.tf` enforces `lifecycle { prevent_destroy = true }` and object versioning (`versioning { enabled = true }`), follow these steps to remove it intentionally:
```bash
# 1. Remove all live and noncurrent object versions from the state bucket
gcloud storage rm --all-versions --recursive "gs://${GCP_PROJECT_ID}-tfstate/**" || true

# 2. Temporarily set prevent_destroy = false in infra/bootstrap/main.tf, then run:
terraform -chdir=infra/bootstrap destroy
```

### Step 3.3 — Decommission External Always-Free Databases
1. **Neon Serverless PostgreSQL (`pgvector`)**: Open the [Neon Console](https://console.neon.tech) → Select project `portfolio-platform` → **Settings → Delete Project**.
2. **MongoDB Atlas M0**: Open [MongoDB Atlas](https://cloud.mongodb.com) → Select cluster `portfolio-m0` → **Terminate Cluster**.
3. **Upstash Serverless Redis**: Open [Upstash Console](https://console.upstash.com) → Select database `portfolio-redis` → **Delete Database**.

### Step 3.4 — (Optional) Shut Down the GCP Project
```bash
gcloud projects delete "${GCP_PROJECT_ID}"
```

---

## 5. Monthly `< $10.00/month` Cost & Quota Verification Checklist

Run the following verification commands once per month (or after any major rollout) to confirm every FinOps guardrail remains active and steady-state spend stays at **`~$1.62/month`** (`< $10.00/month` hard ceiling).

### Checklist Summary Table

| # | Guardrail | Free-Tier / Budget Limit | Steady-State Target |Est. Monthly Cost |
|:---:|:---|:---|:---|:---:|
| 1 | **Cloud Billing Budget** | `$10.00/month` hard cap | Alerts at `50%` ($5), `80%` ($8), `100%` ($10 Actual & Forecasted) | `$0.00` |
| 2 | **Cloud Run Services (8 APIs)** | 2M reqs, 180k vCPU-sec, 360k GiB-sec/mo (`us-central1`) | `min_instance_count = 0`, `cpu_idle = true`, `max <= 2` | `$0.00` |
| 3 | **Cloud Run Jobs (5 Batch Jobs)** | Shared with Cloud Run Free Tier (`us-central1`) | `task_count = 1`, `max_retries <= 1`, `timeout <= 1800s` | `$0.00` |
| 4 | **Cloud Scheduler** | 3 jobs free per billing account | 3 scheduled jobs (`sched-p01-daily-etl`, `sched-p02-crypto-etl`, `sched-p05-dbt-build`) | `$0.00` |
| 5 | **Artifact Registry (`portfolio-apps`)** | 0.5 GB/month free (`us-central1`) | Cleanup policies: delete untagged `> 7d`, keep last `3` tagged versions per package | `~$0.10` |
| 6 | **Cloud Storage (`tfstate`, `data-lake`, `artifacts`)** | 5 GB/month Standard Storage free (`us-central1`) | `data-lake` auto-delete at `30d`, `artifacts` auto-delete at `90d`, `tfstate` keeps `3` versions | `~$0.02` |
| 7 | **BigQuery (`crypto_analytics`, `market_intelligence`)** | 10 GB storage + 1 TB/month queries free | Partitioned & clustered tables; `365d` partition expiration on staging | `$0.00` |
| 8 | **Cloud Pub/Sub (`p03-market-events` + DLQ)** | 10 GB/month messages free | 7-day retention (`604800s`), dead-letter after `5` attempts | `$0.00` |
| 9 | **Secret Manager (6 Consolidated Secrets)** | 6 active secret versions + 10k accesses/mo free | Exactly 6 secret shells (`<= 6` active versions; old versions disabled on rotation) | `$0.00` |
| 10 | **Cloud Logging & Monitoring** | 50 GiB/mo logs free; GCP native metrics free | `_Default` bucket retention = `7` days; 15-min (`900s`) uptime probes | `$0.00` |
| 11 | **External Databases (Neon, Atlas M0, Upstash)** | Always Free Tiers (`0.5 GB`, `512 MB`, `10k cmds/day`) | Scale-to-zero compute (`pool_size=2`, `maxPoolSize=5`) | `$0.00` |
| 12 | **LLM API Guardrails (`P-07`..`P-11`)** | Application-enforced `$2.00/month` hard ceiling | `gpt-4o-mini`, `LLM_SMOKE_MODE=fake` in CI/uptime, `DAILY_TOKEN_BUDGET=50000` | `~$1.50` |
| — | **Total Estimated Monthly Platform Spend** | **Hard Cap: `$10.00/month`** | **83.8% safety buffer below `$10.00/month` ceiling** | **`~$1.62/mo`** |

---

### Executable Verification Commands

#### 1. Verify Cloud Run Services All Have `minScale = 0` (`$0` Idle Compute)
```bash
gcloud run services list \
  --project="${GCP_PROJECT_ID}" \
  --region="${GCP_REGION}" \
  --format="table(metadata.name,spec.template.metadata.annotations['autoscaling.knative.dev/minScale'],spec.template.metadata.annotations['autoscaling.knative.dev/maxScale'])"
```
- [ ] Confirm all 8 services (`p03-market-events`, `p05-hub-api`, `p06-anomaly-api`, `p07-docs-rag`, `p08-market-intel`, `p09-research-agent`, `p10-trading-analyst`, `p11-multi-agent`) report `minScale = 0` (or unset/0) and `maxScale <= 2`.

#### 2. Verify Cloud Scheduler Active Job Count (`<= 3` Always-Free Jobs)
```bash
gcloud scheduler jobs list \
  --project="${GCP_PROJECT_ID}" \
  --location="${GCP_REGION}" \
  --format="table(name.basename(),schedule,state)"
```
- [ ] Confirm at most 3 jobs exist (`sched-p01-daily-etl`, `sched-p02-crypto-etl`, `sched-p05-dbt-build`).

#### 3. Verify Secret Manager Active Version Count (`<= 6` Always-Free Versions)
```bash
for SECRET in $(gcloud secrets list --project="${GCP_PROJECT_ID}" --format="value(name)"); do
  ACTIVE_COUNT=$(gcloud secrets versions list "${SECRET}" --project="${GCP_PROJECT_ID}" --filter="state=ENABLED" --format="value(name)" | wc -l)
  echo "${SECRET}: ${ACTIVE_COUNT} enabled version(s)"
done
```
- [ ] Confirm each of the 6 consolidated secrets has at most `1` `ENABLED` version (`<= 6` total across the project).

#### 4. Verify Cloud Logging `_Default` Bucket Retention (`7` Days)
```bash
gcloud logging buckets describe _Default \
  --location=global \
  --project="${GCP_PROJECT_ID}" \
  --format="table(name,retentionDays,lifecycleState)"
```
- [ ] Confirm `retentionDays = 7` (`<= 50 GiB/month` Free Tier).

#### 5. Verify Artifact Registry Size & Cleanup Policies (`portfolio-apps`)
```bash
gcloud artifacts repositories describe portfolio-apps \
  --project="${GCP_PROJECT_ID}" \
  --location="${GCP_REGION}"
```
- [ ] Confirm `delete-untagged-after-7d` and `keep-recent-3-tagged` cleanup policies are active.

#### 6. Verify Zero Terraform Drift Across `infra/platform`
```bash
terraform -chdir=infra/platform plan -detailed-exitcode
```
- [ ] Confirm exit code `0` (`No changes. Your infrastructure matches the configuration.`).

