resource "azurerm_role_assignment" "terraform_blob_access" {
  scope                = azurerm_resource_group.main.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "azurerm_role_assignment" "fn_ingest_kv_read" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_function_app_flex_consumption.ingest.identity[0].principal_id
}

# App Insights AAD auth requires the MI to publish metrics/traces. Paired
# with the APPLICATIONINSIGHTS_AUTHENTICATION_STRING=Authorization=AAD app
# setting so telemetry uses MI instead of connection-string auth (the latter
# is on Microsoft's deprecation path).
resource "azurerm_role_assignment" "fn_ingest_appinsights_publish" {
  scope                = azurerm_application_insights.main.id
  role_definition_name = "Monitoring Metrics Publisher"
  principal_id         = azurerm_function_app_flex_consumption.ingest.identity[0].principal_id
}

# Flex runtime + deployment storage. The Functions host uses this account for
# host locks (azure-webjobs-hosts), secrets cache (azure-webjobs-secrets), and
# the deployment package container. Account-level Storage Blob Data Owner
# covers all three; anything narrower breaks runtime coordination.
resource "azurerm_role_assignment" "fn_ingest_functions_storage" {
  scope                = azurerm_storage_account.functions.id
  role_definition_name = "Storage Blob Data Owner"
  principal_id         = azurerm_function_app_flex_consumption.ingest.identity[0].principal_id
}

# Durable Functions task hub uses Storage queues (control queues) and tables
# (history + instance state). Blob Data Owner above does not cover these
# sub-services — queue and table data planes are separate RBAC surfaces.
resource "azurerm_role_assignment" "fn_ingest_functions_queue" {
  scope                = azurerm_storage_account.functions.id
  role_definition_name = "Storage Queue Data Contributor"
  principal_id         = azurerm_function_app_flex_consumption.ingest.identity[0].principal_id
}

resource "azurerm_role_assignment" "fn_ingest_functions_table" {
  scope                = azurerm_storage_account.functions.id
  role_definition_name = "Storage Table Data Contributor"
  principal_id         = azurerm_function_app_flex_consumption.ingest.identity[0].principal_id
}
