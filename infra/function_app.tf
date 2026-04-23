resource "azurerm_service_plan" "main" {
  name                = "asp-jobpipeline"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  os_type             = "Linux"
  sku_name            = "Y1"

  tags = var.default_project_tags
}

resource "azurerm_linux_function_app" "ingest" {
  name                = "fn-ingest-jobs-${random_string.kv_suffix.result}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  service_plan_id     = azurerm_service_plan.main.id

  storage_account_name       = azurerm_storage_account.functions.name
  storage_account_access_key = azurerm_storage_account.functions.primary_access_key

  identity {
    type = "SystemAssigned"
  }

  site_config {
    application_stack {
      python_version = "3.12"
    }

    # First-class App Insights wiring. The provider sets
    # APPLICATIONINSIGHTS_CONNECTION_STRING + the hidden-link tag for us, so
    # neither needs to be managed via app_settings / tags directly.
    application_insights_connection_string = azurerm_application_insights.main.connection_string
  }

  app_settings = {
    "FUNCTIONS_WORKER_RUNTIME" = "python"
    "AzureWebJobsFeatureFlags" = "EnableWorkerIndexing"
    "ADZUNA_APP_ID"            = "@Microsoft.KeyVault(VaultName=${azurerm_key_vault.main.name};SecretName=adzuna-id)"
    "ADZUNA_APP_KEY"           = "@Microsoft.KeyVault(VaultName=${azurerm_key_vault.main.name};SecretName=adzuna-key)"
    "RAW_JOBS_STORAGE_ACCOUNT" = azurerm_storage_account.main.name
    "RAW_JOBS_CONTAINER"       = azurerm_storage_container.raw_jobs.name
    "ADZUNA_COUNTRY"           = "us"
    "ADZUNA_SEARCHES"          = var.adzuna_searches
  }

  # Settings set by the Functions Deploy workflow, not by us:
  #   - WEBSITE_RUN_FROM_PACKAGE: SAS URL pointing at the uploaded zip
  #   - WEBSITE_ENABLE_SYNC_UPDATE_SITE: set by the deploy action
  # Terraform owns infra shape; CI/CD owns deploy-artifact wiring.
  lifecycle {
    ignore_changes = [
      app_settings["WEBSITE_RUN_FROM_PACKAGE"],
      app_settings["WEBSITE_ENABLE_SYNC_UPDATE_SITE"],
    ]
  }

  tags = var.default_project_tags
}
