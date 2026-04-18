resource "azurerm_role_assignment" "terraform_blob_access" {
  scope                = azurerm_resource_group.main.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "azurerm_role_assignment" "fn_ingest_blob_write" {
  scope                = azurerm_storage_account.main.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_linux_function_app.ingest.identity[0].principal_id
}

resource "azurerm_role_assignment" "fn_ingest_kv_read" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_linux_function_app.ingest.identity[0].principal_id
}

resource "azurerm_role_assignment" "eg_raw_jobs_deadletter_write" {
  scope                = azurerm_storage_container.eventgrid_deadletter.resource_manager_id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_eventgrid_system_topic.raw_jobs.identity[0].principal_id
}
