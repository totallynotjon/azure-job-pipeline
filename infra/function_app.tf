resource "azurerm_service_plan" "main" {
  name                = "asp-jobpipeline"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  os_type             = "Linux"
  sku_name            = "FC1"

  tags = var.default_project_tags
}

resource "azurerm_function_app_flex_consumption" "ingest" {
  name                = "fn-pipeline-${random_string.kv_suffix.result}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  service_plan_id     = azurerm_service_plan.main.id

  storage_container_type      = "blobContainer"
  storage_container_endpoint  = "${azurerm_storage_account.functions.primary_blob_endpoint}${azurerm_storage_container.fn_deployment.name}"
  storage_authentication_type = "SystemAssignedIdentity"

  runtime_name           = "python"
  runtime_version        = "3.12"
  instance_memory_in_mb  = 2048
  maximum_instance_count = 40

  identity {
    type = "SystemAssigned"
  }

  site_config {}

  app_settings = {
    "APPLICATIONINSIGHTS_CONNECTION_STRING"     = azurerm_application_insights.main.connection_string
    "APPLICATIONINSIGHTS_AUTHENTICATION_STRING" = "Authorization=AAD"
    "AzureWebJobsFeatureFlags"                  = "EnableWorkerIndexing"

    # Flex Consumption canonical identity-based runtime storage. The four
    # __credential/__blobServiceUri/__queueServiceUri/__tableServiceUri
    # settings together tell the Functions host to use MI across blob/queue/
    # table. This matches the Microsoft Flex reference Bicep (Azure-Samples/
    # azure-functions-flex-consumption-samples). The single-setting
    # AzureWebJobsStorage__accountName shortcut documented for Consumption/
    # Premium plans is NOT the Flex pattern; without these four, the host
    # falls back to Azure's auto-injected broken-empty-key connection string
    # and 403s on host lock lease.
    "AzureWebJobsStorage__credential"      = "managedidentity"
    "AzureWebJobsStorage__blobServiceUri"  = azurerm_storage_account.functions.primary_blob_endpoint
    "AzureWebJobsStorage__queueServiceUri" = azurerm_storage_account.functions.primary_queue_endpoint
    "AzureWebJobsStorage__tableServiceUri" = azurerm_storage_account.functions.primary_table_endpoint

    "ADZUNA_APP_ID"   = "@Microsoft.KeyVault(VaultName=${azurerm_key_vault.main.name};SecretName=adzuna-id)"
    "ADZUNA_APP_KEY"  = "@Microsoft.KeyVault(VaultName=${azurerm_key_vault.main.name};SecretName=adzuna-key)"
    "ADZUNA_COUNTRY"  = "us"
    "ADZUNA_SEARCHES" = var.adzuna_searches
    "SQL_SERVER"      = azurerm_mssql_server.main.name
    "SQL_DATABASE"    = azurerm_mssql_database.main.name
  }

  # Azure and the azurerm provider both auto-inject empty-key connection
  # strings for AzureWebJobsStorage and DEPLOYMENT_STORAGE_CONNECTION_STRING
  # regardless of our MI config. Tracked in hashicorp/terraform-provider-
  # azurerm issues #29149, #29693, #30732; fix pending in unmerged PR #29910
  # (as of 2026-04). Ignoring both here avoids perpetual drift. The canonical
  # __credential/__*ServiceUri settings above take precedence at runtime so
  # the empty-key injections are inert noise.
  lifecycle {
    ignore_changes = [
      app_settings["AzureWebJobsStorage"],
      app_settings["DEPLOYMENT_STORAGE_CONNECTION_STRING"],
    ]
  }

  tags = var.default_project_tags
}
