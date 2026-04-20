resource "azurerm_log_analytics_workspace" "main" {
  name                = "log-azure-job-pipeline"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  daily_quota_gb      = 0.1

  tags = var.default_project_tags
}

resource "azurerm_application_insights" "main" {
  name                = "appi-jobpipeline"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  workspace_id        = azurerm_log_analytics_workspace.main.id
  application_type    = "web"

  tags = var.default_project_tags
}
