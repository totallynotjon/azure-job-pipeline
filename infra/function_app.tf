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
  }

  app_settings = {
    "FUNCTIONS_WORKER_RUNTIME"              = "python"
    "AzureWebJobsFeatureFlags"              = "EnableWorkerIndexing"
    "APPLICATIONINSIGHTS_CONNECTION_STRING" = azurerm_application_insights.main.connection_string
    "ADZUNA_APP_ID"                         = "@Microsoft.KeyVault(VaultName=${azurerm_key_vault.main.name};SecretName=adzuna-id)"
    "ADZUNA_APP_KEY"                        = "@Microsoft.KeyVault(VaultName=${azurerm_key_vault.main.name};SecretName=adzuna-key)"
    "RAW_JOBS_STORAGE_ACCOUNT"              = azurerm_storage_account.main.name
    "RAW_JOBS_CONTAINER"                    = azurerm_storage_container.raw_jobs.name
    "ADZUNA_COUNTRY"                        = "us"
    "ADZUNA_SEARCHES" = jsonencode([
      { id = "remote", what = "devops engineer remote", where = "", maxDaysOld = 7 },
      { id = "REDACTED", what = "devops engineer", where = "REDACTED", maxDaysOld = 7 },
    ])
  }

  # Set by the Functions Deploy workflow (points to the uploaded zip).
  # Terraform owns infra shape; CI/CD owns the code-artifact pointer.
  lifecycle {
    ignore_changes = [
      app_settings["WEBSITE_RUN_FROM_PACKAGE"],
    ]
  }

  tags = var.default_project_tags
}
