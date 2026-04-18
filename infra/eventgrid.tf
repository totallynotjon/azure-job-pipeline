resource "azurerm_eventgrid_system_topic" "raw_jobs" {
  name                   = "egst-raw-jobs"
  resource_group_name    = azurerm_resource_group.main.name
  location               = azurerm_resource_group.main.location
  source_resource_id     = azurerm_storage_account.main.id
  topic_type             = "Microsoft.Storage.StorageAccounts"

  identity {
    type = "SystemAssigned"
  }

  tags = var.default_project_tags
}
