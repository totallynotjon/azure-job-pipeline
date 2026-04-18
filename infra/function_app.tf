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
      node_version = "22"
    }
  }

  app_settings = {
    "FUNCTIONS_WORKER_RUNTIME"              = "node"
    "APPLICATIONINSIGHTS_CONNECTION_STRING" = azurerm_application_insights.main.connection_string
    "ADZUNA_APP_ID"                         = "@Microsoft.KeyVault(VaultName=${azurerm_key_vault.main.name};SecretName=adzuna-id)"
    "ADZUNA_APP_KEY"                        = "@Microsoft.KeyVault(VaultName=${azurerm_key_vault.main.name};SecretName=adzuna-key)"
    "RAW_JOBS_STORAGE_ACCOUNT"              = azurerm_storage_account.main.name
    "RAW_JOBS_CONTAINER"                    = azurerm_storage_container.raw_jobs.name
    "ADZUNA_COUNTRY"                        = "us"
    "ADZUNA_SEARCHES" = jsonencode([
      { id = "remote", what = "devops engineer remote", where = "", maxDaysOld = 7 },
      { id = "louisville", what = "devops engineer", where = "louisville, ky", maxDaysOld = 7 },
    ])
  }

  tags = var.default_project_tags
}
