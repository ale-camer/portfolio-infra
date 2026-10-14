# Issue 20: Provision Cloud Monitoring Uptime Checks, Log-Based Error Alerts, and Latency Dashboard

**Branch**: `feature/issue-20-monitoring-uptime-alerts`
**Status**: Done
**PR**: opened by `make finish-issue` → `develop` (Closes #20)
**Milestone**: M5 - Observability & Cost

## Objective
Provision the free-tier observability stack in `infra/platform/monitoring.tf` covering:
1. **7-Day Log Retention Guardrail**: `google_logging_project_bucket_config` for the `_Default` log bucket (`retention_days = 7`) to stay strictly within the 50 GiB/month Cloud Logging Free Tier (`$0.00/month`).
2. **Low-Frequency Cloud Monitoring HTTP `/health` Uptime Checks**: `google_monitoring_uptime_check_config` across the deployed Cloud Run Services (`p03-market-events`, `p05-hub-api`, `p06-anomaly-api`, `p07-docs-rag`, `p08-market-intel`, `p09-research-agent`, `p10-trading-analyst`, `p11-multi-agent`) at `900s` (`15 min`) intervals (configurable via `enable_uptime_checks` in `infra/platform/variables.tf` so idle scale-to-zero instances are not kept warm unnecessarily).
3. **Error & Latency Alert Policies**: `google_monitoring_alert_policy` resources wired to `google_monitoring_notification_channel.budget_email.id` for:
   - Log-based `severity >= ERROR` spikes on Cloud Run Services and Jobs (`cloud_run_revision` / `cloud_run_job`),
   - HTTP `5xx` error responses and `p95` request latency breaches on Cloud Run Services,
   - Uptime check failure alerts when `enable_uptime_checks = true`.
4. **Unified Cloud Monitoring Dashboard**: `google_monitoring_dashboard` (`portfolio-platform-observability`) visualizing Cloud Run request throughput, `p50`/`p95`/`p99` request latency, `5xx` error rates, container CPU/memory utilization, and Cloud Run Job execution outcomes.

## Acceptance Criteria
- [x] `infra/platform/variables.tf` defines `enable_uptime_checks` (`bool`, default `true`) and `log_retention_days` (`number`, default `7`, validated between `1` and `30`)
- [x] `infra/platform/monitoring.tf` configures `google_logging_project_bucket_config` on `_Default` (`location = "global"`, `retention_days = var.log_retention_days`)
- [x] `infra/platform/monitoring.tf` provisions `google_monitoring_uptime_check_config` (`period = "900s"`, `timeout = "10s"`, path `"/health"`) for the platform's public Cloud Run Services when `var.enable_uptime_checks` is enabled
- [x] `infra/platform/monitoring.tf` provisions `google_monitoring_alert_policy` resources for Cloud Run `severity >= ERROR` log entries, Cloud Run `5xx` / high `p95` latency, and uptime check failures, all notifying `google_monitoring_notification_channel.budget_email.id`
- [x] `infra/platform/monitoring.tf` provisions a `google_monitoring_dashboard` (`mosaicLayout`) tracking Cloud Run Service latency (`p50`/`p95`/`p99`), request count by response code class, container memory/CPU utilization, and Cloud Run Job executions
- [x] `infra/platform/outputs.tf` exports `monitoring_dashboard_id`, `monitoring_uptime_check_ids`, and `monitoring_alert_policy_ids`
- [x] Observability architecture, free-tier cost controls, and verification commands are documented in `docs/issue_20_monitoring_uptime_alerts.md`
- [x] `make check` passes (`fmt-check`, `validate`, `tflint`, `shellcheck`, and `checkov` with zero failed checks)


## Implementation Tasks

### 1. Preparation & Branching
```bash
make start-issue ID=20 NAME=monitoring-uptime-alerts
```

### 2. Provision Cloud Logging Retention, Uptime Checks, Alert Policies & Latency Dashboard (`infra/platform/variables.tf`, `infra/platform/monitoring.tf` & `infra/platform/outputs.tf`)
- **File**: `infra/platform/variables.tf`, `infra/platform/monitoring.tf`, `infra/platform/outputs.tf`
- **Change**: Added `enable_uptime_checks` and `log_retention_days` to `infra/platform/variables.tf`. Created `infra/platform/monitoring.tf` with the `_Default` log bucket 7-day retention config, low-frequency (`900s`) HTTPS `/health` uptime checks across all Cloud Run Services, log-based and metric-based `google_monitoring_alert_policy` rules wired to `google_monitoring_notification_channel.budget_email.id`, and the `google_monitoring_dashboard` JSON specification. Exported monitoring resource IDs in `infra/platform/outputs.tf`.

### 3. Document Cloud Monitoring & Free-Tier Observability Runbook (`docs/issue_20_monitoring_uptime_alerts.md`)
- **File**: `docs/issue_20_monitoring_uptime_alerts.md`
- **Change**: Documented the observability topology, alert thresholds, scale-to-zero uptime check frequency trade-off (`900s` vs `enable_uptime_checks = false`), and `gcloud monitoring` verification commands below.

### 4. Verification & Quality Gates
```bash
make check
```

### 5. Git & Issue Finish
```bash
make finish-issue ID=20 MSG="feat(monitoring): provision uptime checks, error alerts and latency dashboard"
```

---

## Observability Architecture & Free-Tier Cost Controls

### 1. Resource Inventory (`infra/platform/monitoring.tf`)

| Terraform Resource | GCP Service | Configuration | Free-Tier Cost Control |
|---|---|---|---|
| `google_logging_project_bucket_config.default_retention` | Cloud Logging (`_Default`) | `location = "global"`, `retention_days = 7` (`var.log_retention_days`) | Caps log storage well below the **50 GiB/month Always Free** ingestion allowance (`$0.00/mo`). |
| `google_monitoring_uptime_check_config.cloud_run_health` | Cloud Monitoring Uptime Checks | `HTTPS GET /health` (`port = 443`, `validate_ssl = true`), `period = "900s"` (`15 min`), `timeout = "10s"` across 8 services (`p03`, `p05`, `p06`, `p07`, `p08`, `p09`, `p10`, `p11`) | Maximum allowed `900s` interval minimizes cold starts (~2,880 requests/month/service vs. 2M Free Tier). Can be toggled off (`enable_uptime_checks = false`) during hibernation. |
| `google_monitoring_alert_policy.cloud_run_log_errors` | Cloud Monitoring Alerting | `condition_matched_log`: `(resource.type = "cloud_run_revision" OR resource.type = "cloud_run_job") AND severity >= ERROR` | Rate-limited to `1 notification / hour` (`3600s`) with `24h` auto-close (`$0.00/mo`). |
| `google_monitoring_alert_policy.cloud_run_5xx_and_latency` | Cloud Monitoring Alerting | `OR` policy: (1) HTTP `5xx` count `> 5` over `300s`; (2) `p95` latency `> 15,000 ms` over `300s` | Uses built-in `run.googleapis.com/*` system metrics (zero custom metric ingestion charge). |
| `google_monitoring_alert_policy.cloud_run_uptime_failure` | Cloud Monitoring Alerting | Triggers when `monitoring.googleapis.com/uptime_check/check_passed` fails over a `900s` window | Uses free GCP system uptime metrics; notifies `google_monitoring_notification_channel.budget_email`. |
| `google_monitoring_dashboard.platform_observability` | Cloud Monitoring Dashboards | 5-tile `mosaicLayout`: Request throughput (`req/s`), Latency (`p50`/`p95`/`p99`), HTTP `4xx`/`5xx` stacked bar, Container CPU & Memory (`p95`), and Batch Job task attempts | Queries free `run.googleapis.com/*` platform metrics (`$0.00/mo`). |

### 2. Scale-to-Zero vs. Uptime Probe Trade-off
- By default (`enable_uptime_checks = true`), Cloud Monitoring probes each public Cloud Run Service's `/health` endpoint every **15 minutes (`900s`)**.
- Because lightweight `/health` handlers respond in `< 50 ms` without invoking external LLMs or heavy database queries, the aggregate compute footprint remains within the **Cloud Run Always Free tier** (`180,000 vCPU-seconds` and `360,000 GiB-seconds` per month in `us-central1`).
- To achieve **zero cold-start invocations** when the portfolio is not being actively demonstrated, set `enable_uptime_checks = false` in `terraform.tfvars`:
  ```bash
  terraform -chdir=infra/platform apply -var="enable_uptime_checks=false"
  ```

### 3. Operational Verification Commands
```bash
# 1. Verify _Default log bucket retention (expected: 7 days)
gcloud logging buckets describe _Default --location=global --format="value(retentionDays)"

# 2. List provisioned HTTPS /health uptime checks
gcloud monitoring uptime list-configs --format="table(displayName,period,httpCheck.path,monitoredResource.labels.host)"

# 3. List active Cloud Monitoring alert policies
gcloud alpha monitoring policies list --format="table(displayName,enabled,conditions.displayName)"

# 4. List provisioned Cloud Monitoring dashboards
gcloud monitoring dashboards list --format="table(displayName,name)"
```

## Decisions
- **15-Minute (`900s`) Uptime Check Period + `enable_uptime_checks` Toggle**: Cloud Monitoring's maximum uptime check period (`900s`) minimizes cold-start invocations on scale-to-zero Cloud Run Services (~2,880 requests/month per service, well within the 2M requests/month Always Free tier) while allowing instant disablement (`enable_uptime_checks = false`) during zero-traffic hibernation.
- **7-Day `_Default` Log Bucket Retention**: Enforces a strict 7-day retention window on Cloud Logging (`_Default`) so container stdout/stderr and request logs remain at `$0.00/month` under the 50 GiB/month free tier.

