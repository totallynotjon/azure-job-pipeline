resource "azurerm_user_assigned_identity" "scraper_job" {
  name                = "id-scraper-job"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  tags = var.default_project_tags
}
