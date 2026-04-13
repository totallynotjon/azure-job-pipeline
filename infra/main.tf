# Project resources go here (resource group, function app, sql, etc.)
resource "azurerm_resource_group" "main" {
  name     = "rg-azure-job-pipeline"
  location = var.location
}
