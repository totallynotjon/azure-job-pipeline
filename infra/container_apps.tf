resource "azurerm_container_app_environment" "main" {
  name                       = "cae-azure-job-pipeline"
  location                   = azurerm_resource_group.main.location
  resource_group_name        = azurerm_resource_group.main.name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id

  tags = var.default_project_tags
}

resource "azurerm_container_app_job" "scraper" {
  name                         = "job-scraper"
  resource_group_name          = azurerm_resource_group.main.name
  location                     = azurerm_resource_group.main.location
  container_app_environment_id = azurerm_container_app_environment.main.id

  replica_timeout_in_seconds = 300
  replica_retry_limit        = 1

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.scraper_job.id]
  }

  schedule_trigger_config {
    cron_expression          = "0 */6 * * *" # every 6 hours
    parallelism              = 1
    replica_completion_count = 1
  }

  template {
    container {
      name   = "scraper"
      image  = "alpine:latest" # placeholder — replace with ACR image after Dockerfile exists
      cpu    = 0.5
      memory = "1Gi"

      env {
        name  = "STORAGE_ACCOUNT_NAME"
        value = azurerm_storage_account.main.name
      }

      env {
        name  = "STORAGE_CONTAINER_NAME"
        value = azurerm_storage_container.raw_jobs.name
      }
    }
  }

  tags = var.default_project_tags
}
