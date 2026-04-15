resource "azurerm_log_analytics_workspace" "main" {
  name                = "log-azure-job-pipeline"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  daily_quota_gb      = 0.1
  depends_on          = [azurerm_resource_provider_registration.operational_insights]

  tags = var.default_project_tags
}
