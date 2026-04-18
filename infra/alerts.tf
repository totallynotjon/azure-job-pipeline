resource "azurerm_monitor_action_group" "main" {
  name                = "ag-jobpipeline-alerts"
  resource_group_name = azurerm_resource_group.main.name
  short_name          = "jobpipe"

  azure_app_push_receiver {
    name          = "jon-mobile"
    email_address = var.alert_contact_email
  }

  tags = var.default_project_tags
}

resource "azurerm_monitor_metric_alert" "ingest_repeated_failures" {
  name                = "alert-fn-ingest-failures"
  resource_group_name = azurerm_resource_group.main.name
  scopes              = [azurerm_application_insights.main.id]
  description         = "fn-ingest-jobs failed >=2 times in a 12h window (covers ~2 consecutive scheduled runs)"
  severity            = 2
  frequency           = "PT1H"
  window_size         = "PT12H"

  criteria {
    metric_namespace = "microsoft.insights/components"
    metric_name      = "requests/failed"
    aggregation      = "Count"
    operator         = "GreaterThanOrEqual"
    threshold        = 2

    dimension {
      name     = "request/name"
      operator = "Include"
      values   = ["ingestJobs"]
    }
  }

  action {
    action_group_id = azurerm_monitor_action_group.main.id
  }

  tags = var.default_project_tags
}
