resource "azurerm_container_registry" "main" {
  name                = "acrjonjobpipeline"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "Basic"
  admin_enabled       = false

  tags = var.default_project_tags
}
