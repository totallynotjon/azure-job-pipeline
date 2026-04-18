resource "time_sleep" "wait_rbac" {
  depends_on      = [azurerm_role_assignment.terraform_blob_access]
  create_duration = "60s"
}

resource "azurerm_storage_account" "main" {
  name                            = "stjonjobpipeline"
  resource_group_name             = azurerm_resource_group.main.name
  location                        = azurerm_resource_group.main.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  account_kind                    = "StorageV2"
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  shared_access_key_enabled       = false

  tags = var.default_project_tags
}

resource "azurerm_storage_container" "raw_jobs" {
  name                  = "raw-jobs"
  storage_account_id    = azurerm_storage_account.main.id
  container_access_type = "private"
  depends_on            = [time_sleep.wait_rbac]
}

resource "azurerm_storage_container" "eventgrid_deadletter" {
  name                  = "eg-deadletter"
  storage_account_id    = azurerm_storage_account.main.id
  container_access_type = "private"
  depends_on            = [time_sleep.wait_rbac]
}

resource "azurerm_storage_account" "functions" {
  name                            = "stjonjobpipelinefn"
  resource_group_name             = azurerm_resource_group.main.name
  location                        = azurerm_resource_group.main.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  account_kind                    = "StorageV2"
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  shared_access_key_enabled       = true

  tags = var.default_project_tags
}
