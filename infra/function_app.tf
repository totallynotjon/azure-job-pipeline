resource "azurerm_service_plan" "main" {
  name                = "asp-jobpipeline"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  os_type             = "Linux"
  sku_name            = "FC1"

  tags = var.default_project_tags
}

resource "azurerm_function_app_flex_consumption" "ingest" {
  name                = "fn-ingest-jobs-${random_string.kv_suffix.result}"
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
    "APPLICATIONINSIGHTS_CONNECTION_STRING" = azurerm_application_insights.main.connection_string
    "AzureWebJobsFeatureFlags"              = "EnableWorkerIndexing"
    # Identity-based runtime storage for the Functions host. Pairs with the
    # account-level Storage Blob Data Owner grant on stjonjobpipelinefn so the
    # host can acquire its lock lease and manage azure-webjobs-* containers.
    "AzureWebJobsStorage__accountName" = azurerm_storage_account.functions.name
    "ADZUNA_APP_ID"                    = "@Microsoft.KeyVault(VaultName=${azurerm_key_vault.main.name};SecretName=adzuna-id)"
    "ADZUNA_APP_KEY"                   = "@Microsoft.KeyVault(VaultName=${azurerm_key_vault.main.name};SecretName=adzuna-key)"
    "ADZUNA_COUNTRY"                   = "us"
    "ADZUNA_SEARCHES"                  = var.adzuna_searches
  }

  # Flex auto-injects a broken keyless AzureWebJobsStorage connection string on
  # create; we override auth via AzureWebJobsStorage__accountName above and
  # leave the platform-managed key alone so TF doesn't fight it.
  lifecycle {
    ignore_changes = [
      app_settings["AzureWebJobsStorage"],
    ]
  }

  tags = var.default_project_tags
}
