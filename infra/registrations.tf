resource "azurerm_resource_provider_registration" "app" {
  name = "Microsoft.App"
}

resource "azurerm_resource_provider_registration" "container_registry" {
  name = "Microsoft.ContainerRegistry"
}

resource "azurerm_resource_provider_registration" "storage" {
  name = "Microsoft.Storage"
}

resource "azurerm_resource_provider_registration" "operational_insights" {
  name = "Microsoft.OperationalInsights"
}

resource "azurerm_resource_provider_registration" "managed_identity" {
  name = "Microsoft.ManagedIdentity"
}