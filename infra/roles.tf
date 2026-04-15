resource "azurerm_role_assignment" "terraform_blob_access" {
  scope                = azurerm_resource_group.main.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "azurerm_role_assignment" "acr_push" {
  scope                = azurerm_resource_group.main.id
  role_definition_name = "AcrPush"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "azurerm_role_assignment" "scraper_blob_access" {
  scope                = azurerm_storage_container.raw_jobs.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.scraper_job.principal_id
}

resource "azurerm_role_assignment" "scraper_acr_pull" {
  scope                = azurerm_container_registry.main.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.scraper_job.principal_id
}
