resource "google_monitoring_notification_channel" "budget_email" {
  project      = var.project_id
  display_name = "Portfolio Platform Budget & Ops Alert Email (${var.environment})"
  type         = "email"

  labels = {
    email_address = var.alert_email
  }

  user_labels = local.common_labels

  depends_on = [
    google_project_service.platform_apis["monitoring.googleapis.com"],
  ]
}

resource "google_billing_budget" "monthly_cap" {
  billing_account = upper(var.billing_account_id)
  display_name    = "${var.project_id}-${var.environment}-monthly-budget-${var.monthly_budget_usd}usd"

  budget_filter {
    projects               = ["projects/${var.project_id}"]
    credit_types_treatment = "INCLUDE_ALL_CREDITS"
    calendar_period        = "MONTH"
  }

  amount {
    specified_amount {
      currency_code = "USD"
      units         = tostring(var.monthly_budget_usd)
    }
  }

  threshold_rules {
    threshold_percent = 0.5
    spend_basis       = "CURRENT_SPEND"
  }

  threshold_rules {
    threshold_percent = 0.8
    spend_basis       = "CURRENT_SPEND"
  }

  threshold_rules {
    threshold_percent = 1.0
    spend_basis       = "CURRENT_SPEND"
  }

  threshold_rules {
    threshold_percent = 1.0
    spend_basis       = "FORECASTED_SPEND"
  }

  all_updates_rule {
    monitoring_notification_channels = [
      google_monitoring_notification_channel.budget_email.id,
    ]
    disable_default_iam_recipients = false
  }

  depends_on = [
    google_project_service.platform_apis["billingbudgets.googleapis.com"],
    google_project_service.platform_apis["cloudbilling.googleapis.com"],
  ]
}
