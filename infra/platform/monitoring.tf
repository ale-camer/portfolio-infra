# ==============================================================================
# Issue 20: Free-Tier Cloud Monitoring Uptime Checks, Error Alerts & Dashboard
# ==============================================================================
# 1. Enforces a 7-day retention window on the `_Default` Cloud Logging bucket
#    so container stdout/stderr and HTTP request logs stay within the 50 GiB/mo
#    Always Free tier ($0.00/month).
# 2. Provisions low-frequency (900s / 15-minute) HTTPS GET /health uptime checks
#    across deployed Cloud Run Services (gated by `var.enable_uptime_checks`).
# 3. Provisions log-based (`severity >= ERROR`) and metric-based (`5xx` rate,
#    `p95` latency, and uptime check failure) alert policies notifying the
#    central budget/ops email channel (`google_monitoring_notification_channel.budget_email`).
# 4. Provisions a unified Cloud Monitoring Mosaic Dashboard tracking request
#    throughput, p50/p95/p99 latency, 5xx errors, CPU/memory utilization, and
#    Cloud Run Job executions.
# ==============================================================================

locals {
  monitored_cloud_run_services = {
    "p03-market-events" = {
      service_name = module.p03_market_events.service_name
      service_uri  = module.p03_market_events.service_uri
      project_code = "p03"
    }
    "p05-hub-api" = {
      service_name = module.p05_hub_api.service_name
      service_uri  = module.p05_hub_api.service_uri
      project_code = "p05"
    }
    "p06-anomaly-api" = {
      service_name = module.p06_anomaly_api.service_name
      service_uri  = module.p06_anomaly_api.service_uri
      project_code = "p06"
    }
    "p07-docs-rag" = {
      service_name = module.p07_docs_rag.service_name
      service_uri  = module.p07_docs_rag.service_uri
      project_code = "p07"
    }
    "p08-market-intel" = {
      service_name = module.p08_market_intel.service_name
      service_uri  = module.p08_market_intel.service_uri
      project_code = "p08"
    }
    "p09-research-agent" = {
      service_name = module.p09_research_agent.service_name
      service_uri  = module.p09_research_agent.service_uri
      project_code = "p09"
    }
    "p10-trading-analyst" = {
      service_name = module.p10_trading_analyst.service_name
      service_uri  = module.p10_trading_analyst.service_uri
      project_code = "p10"
    }
    "p11-multi-agent" = {
      service_name = module.p11_multi_agent.service_name
      service_uri  = module.p11_multi_agent.service_uri
      project_code = "p11"
    }
  }
}

# ------------------------------------------------------------------------------
# 1. Cloud Logging _Default Bucket Retention Guardrail (7 Days)
# ------------------------------------------------------------------------------
resource "google_logging_project_bucket_config" "default_retention" {
  project        = var.project_id
  location       = "global"
  bucket_id      = "_Default"
  retention_days = var.log_retention_days

  depends_on = [
    google_project_service.platform_apis["logging.googleapis.com"],
  ]
}

# ------------------------------------------------------------------------------
# 2. Low-Frequency (15-Minute / 900s) HTTPS /health Uptime Checks
# ------------------------------------------------------------------------------
resource "google_monitoring_uptime_check_config" "cloud_run_health" {
  for_each = var.enable_uptime_checks ? local.monitored_cloud_run_services : {}

  project      = var.project_id
  display_name = "${each.key}-health-uptime (${var.environment})"
  period       = "900s"
  timeout      = "10s"

  http_check {
    path           = "/health"
    port           = 443
    use_ssl        = true
    validate_ssl   = true
    request_method = "GET"

    accepted_response_status_codes {
      status_class = "STATUS_CLASS_2XX"
    }
  }

  monitored_resource {
    type = "uptime_url"
    labels = {
      project_id = var.project_id
      host       = trimprefix(each.value.service_uri, "https://")
    }
  }

  checker_type = "STATIC_IP_CHECKERS"

  user_labels = merge(local.common_labels, {
    component    = "uptime-check"
    service_name = each.key
    portfolio_id = each.value.project_code
  })

  depends_on = [
    google_project_service.platform_apis["monitoring.googleapis.com"],
  ]
}

# ------------------------------------------------------------------------------
# 3. Cloud Monitoring Alert Policies (Logs, 5xx/Latency, and Uptime Failures)
# ------------------------------------------------------------------------------

# 3a. Log-Based Severity >= ERROR Alert Policy (Cloud Run Services & Jobs)
resource "google_monitoring_alert_policy" "cloud_run_log_errors" {
  project      = var.project_id
  display_name = "Portfolio Cloud Run Error Log Alert (severity >= ERROR)"
  combiner     = "OR"
  enabled      = true

  conditions {
    display_name = "Cloud Run Service or Job emitted severity >= ERROR log entry"

    condition_matched_log {
      filter = "(resource.type = \"cloud_run_revision\" OR resource.type = \"cloud_run_job\") AND severity >= ERROR"
    }
  }

  alert_strategy {
    notification_rate_limit {
      period = "3600s"
    }
    auto_close = "86400s"
  }

  notification_channels = [
    google_monitoring_notification_channel.budget_email.id,
  ]

  documentation {
    content   = "A Cloud Run Service (`cloud_run_revision`) or Batch Job (`cloud_run_job`) in `${var.project_id}` emitted one or more `ERROR`/`CRITICAL` log entries. Inspect Cloud Logging with filter `(resource.type=\"cloud_run_revision\" OR resource.type=\"cloud_run_job\") AND severity>=ERROR`."
    mime_type = "text/markdown"
  }

  user_labels = merge(local.common_labels, {
    component = "log-error-alert"
  })

  depends_on = [
    google_project_service.platform_apis["monitoring.googleapis.com"],
    google_project_service.platform_apis["logging.googleapis.com"],
  ]
}

# 3b. Cloud Run HTTP 5xx Error Rate & High p95 Latency Alert Policy
resource "google_monitoring_alert_policy" "cloud_run_5xx_and_latency" {
  project      = var.project_id
  display_name = "Portfolio Cloud Run 5xx Errors & High p95 Latency Alert"
  combiner     = "OR"
  enabled      = true

  conditions {
    display_name = "Cloud Run HTTP 5xx response count > 5 over 5 minutes"

    condition_threshold {
      filter          = "resource.type = \"cloud_run_revision\" AND metric.type = \"run.googleapis.com/request_count\" AND metric.labels.response_code_class = \"5xx\""
      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = 5

      aggregations {
        alignment_period     = "300s"
        per_series_aligner   = "ALIGN_SUM"
        cross_series_reducer = "REDUCE_SUM"
        group_by_fields      = ["resource.label.service_name"]
      }
    }
  }

  conditions {
    display_name = "Cloud Run p95 request latency > 15000 ms over 5 minutes"

    condition_threshold {
      filter          = "resource.type = \"cloud_run_revision\" AND metric.type = \"run.googleapis.com/request_latencies\""
      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = 15000

      aggregations {
        alignment_period     = "300s"
        per_series_aligner   = "ALIGN_DELTA"
        cross_series_reducer = "REDUCE_PERCENTILE_95"
        group_by_fields      = ["resource.label.service_name"]
      }
    }
  }

  alert_strategy {
    auto_close = "86400s"
  }

  notification_channels = [
    google_monitoring_notification_channel.budget_email.id,
  ]

  documentation {
    content   = "A Cloud Run Service in `${var.project_id}` exceeded either >5 HTTP `5xx` responses or >15s `p95` request latency over a 5-minute window. Verify external free-tier database connectivity (Neon/Atlas/Upstash) and LLM budget caps."
    mime_type = "text/markdown"
  }

  user_labels = merge(local.common_labels, {
    component = "latency-5xx-alert"
  })

  depends_on = [
    google_project_service.platform_apis["monitoring.googleapis.com"],
  ]
}

# 3c. Cloud Monitoring Uptime Check Failure Alert Policy (when enabled)
resource "google_monitoring_alert_policy" "cloud_run_uptime_failure" {
  count = var.enable_uptime_checks ? 1 : 0

  project      = var.project_id
  display_name = "Portfolio Cloud Run /health Uptime Check Failure Alert"
  combiner     = "OR"
  enabled      = true

  conditions {
    display_name = "HTTPS GET /health uptime check failed across >= 2 regions"

    condition_threshold {
      filter          = "resource.type = \"uptime_url\" AND metric.type = \"monitoring.googleapis.com/uptime_check/check_passed\""
      duration        = "900s"
      comparison      = "COMPARISON_LT"
      threshold_value = 1

      aggregations {
        alignment_period     = "900s"
        per_series_aligner   = "ALIGN_NEXT_OLDER"
        cross_series_reducer = "REDUCE_COUNT_FALSE"
        group_by_fields      = ["metric.label.check_id"]
      }

      trigger {
        count = 1
      }
    }
  }

  alert_strategy {
    auto_close = "86400s"
  }

  notification_channels = [
    google_monitoring_notification_channel.budget_email.id,
  ]

  documentation {
    content   = "One or more Cloud Run `/health` uptime checks failed during the 15-minute (`900s`) probe window. Inspect the failing revision in Cloud Run and review recent deployments."
    mime_type = "text/markdown"
  }

  user_labels = merge(local.common_labels, {
    component = "uptime-failure-alert"
  })

  depends_on = [
    google_monitoring_uptime_check_config.cloud_run_health,
  ]
}

# ------------------------------------------------------------------------------
# 4. Unified Cloud Monitoring Latency, Error & Job Execution Dashboard
# ------------------------------------------------------------------------------
locals {
  platform_dashboard_tiles = [
    {
      xPos   = 0
      yPos   = 0
      width  = 6
      height = 4
      widget = {
        title = "Cloud Run Request Throughput by Service (req/s)"
        xyChart = {
          dataSets = [
            {
              plotType = "LINE"
              timeSeriesQuery = {
                timeSeriesFilter = {
                  filter = "resource.type=\"cloud_run_revision\" AND metric.type=\"run.googleapis.com/request_count\""
                  aggregation = {
                    alignmentPeriod    = "60s"
                    perSeriesAligner   = "ALIGN_RATE"
                    crossSeriesReducer = "REDUCE_SUM"
                    groupByFields      = ["resource.label.service_name"]
                  }
                }
              }
            }
          ]
        }
      }
    },
    {
      xPos   = 6
      yPos   = 0
      width  = 6
      height = 4
      widget = {
        title = "Cloud Run Request Latency p50 / p95 / p99 (ms)"
        xyChart = {
          dataSets = [
            {
              plotType       = "LINE"
              legendTemplate = "$${resource.label.service_name} (p50)"
              timeSeriesQuery = {
                timeSeriesFilter = {
                  filter = "resource.type=\"cloud_run_revision\" AND metric.type=\"run.googleapis.com/request_latencies\""
                  aggregation = {
                    alignmentPeriod    = "60s"
                    perSeriesAligner   = "ALIGN_DELTA"
                    crossSeriesReducer = "REDUCE_PERCENTILE_50"
                    groupByFields      = ["resource.label.service_name"]
                  }
                }
              }
            },
            {
              plotType       = "LINE"
              legendTemplate = "$${resource.label.service_name} (p95)"
              timeSeriesQuery = {
                timeSeriesFilter = {
                  filter = "resource.type=\"cloud_run_revision\" AND metric.type=\"run.googleapis.com/request_latencies\""
                  aggregation = {
                    alignmentPeriod    = "60s"
                    perSeriesAligner   = "ALIGN_DELTA"
                    crossSeriesReducer = "REDUCE_PERCENTILE_95"
                    groupByFields      = ["resource.label.service_name"]
                  }
                }
              }
            },
            {
              plotType       = "LINE"
              legendTemplate = "$${resource.label.service_name} (p99)"
              timeSeriesQuery = {
                timeSeriesFilter = {
                  filter = "resource.type=\"cloud_run_revision\" AND metric.type=\"run.googleapis.com/request_latencies\""
                  aggregation = {
                    alignmentPeriod    = "60s"
                    perSeriesAligner   = "ALIGN_DELTA"
                    crossSeriesReducer = "REDUCE_PERCENTILE_99"
                    groupByFields      = ["resource.label.service_name"]
                  }
                }
              }
            }
          ]
        }
      }
    },
    {
      xPos   = 0
      yPos   = 4
      width  = 6
      height = 4
      widget = {
        title = "Cloud Run HTTP 4xx & 5xx Error Count (5m window)"
        xyChart = {
          dataSets = [
            {
              plotType = "STACKED_BAR"
              timeSeriesQuery = {
                timeSeriesFilter = {
                  filter = "resource.type=\"cloud_run_revision\" AND metric.type=\"run.googleapis.com/request_count\" AND (metric.labels.response_code_class=\"4xx\" OR metric.labels.response_code_class=\"5xx\")"
                  aggregation = {
                    alignmentPeriod    = "300s"
                    perSeriesAligner   = "ALIGN_SUM"
                    crossSeriesReducer = "REDUCE_SUM"
                    groupByFields      = ["resource.label.service_name", "metric.label.response_code_class"]
                  }
                }
              }
            }
          ]
        }
      }
    },
    {
      xPos   = 6
      yPos   = 4
      width  = 6
      height = 4
      widget = {
        title = "Cloud Run Container Memory & CPU Utilization (p95)"
        xyChart = {
          dataSets = [
            {
              plotType       = "LINE"
              legendTemplate = "$${resource.label.service_name} Memory p95"
              timeSeriesQuery = {
                timeSeriesFilter = {
                  filter = "resource.type=\"cloud_run_revision\" AND metric.type=\"run.googleapis.com/container/memory/utilizations\""
                  aggregation = {
                    alignmentPeriod    = "60s"
                    perSeriesAligner   = "ALIGN_DELTA"
                    crossSeriesReducer = "REDUCE_PERCENTILE_95"
                    groupByFields      = ["resource.label.service_name"]
                  }
                }
              }
            },
            {
              plotType       = "LINE"
              legendTemplate = "$${resource.label.service_name} CPU p95"
              timeSeriesQuery = {
                timeSeriesFilter = {
                  filter = "resource.type=\"cloud_run_revision\" AND metric.type=\"run.googleapis.com/container/cpu/utilizations\""
                  aggregation = {
                    alignmentPeriod    = "60s"
                    perSeriesAligner   = "ALIGN_DELTA"
                    crossSeriesReducer = "REDUCE_PERCENTILE_95"
                    groupByFields      = ["resource.label.service_name"]
                  }
                }
              }
            }
          ]
        }
      }
    },
    {
      xPos   = 0
      yPos   = 8
      width  = 12
      height = 4
      widget = {
        title = "Cloud Run Batch Job Completed Task Executions (P-01, P-02, P-05, P-06, P-08)"
        xyChart = {
          dataSets = [
            {
              plotType = "STACKED_BAR"
              timeSeriesQuery = {
                timeSeriesFilter = {
                  filter = "resource.type=\"cloud_run_job\" AND metric.type=\"run.googleapis.com/job/completed_task_attempt_count\""
                  aggregation = {
                    alignmentPeriod    = "3600s"
                    perSeriesAligner   = "ALIGN_SUM"
                    crossSeriesReducer = "REDUCE_SUM"
                    groupByFields      = ["resource.label.job_name", "metric.label.result"]
                  }
                }
              }
            }
          ]
        }
      }
    },
  ]
}

resource "google_monitoring_dashboard" "platform_observability" {
  project = var.project_id

  dashboard_json = jsonencode({
    displayName = "Financial Markets Intelligence Platform — Observability & Latency (${var.environment})"
    mosaicLayout = {
      columns = 12
      tiles   = local.platform_dashboard_tiles
    }
  })

  depends_on = [
    google_project_service.platform_apis["monitoring.googleapis.com"],
  ]
}



