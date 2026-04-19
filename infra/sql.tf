resource "azurerm_mssql_server" "main" {
  name                         = "sql-jonsjobpipeline"
  resource_group_name          = azurerm_resource_group.main.name
  location                     = var.sql_location
  version                      = "12.0"
  minimum_tls_version          = "1.2"
  public_network_access_enabled = true

  azuread_administrator {
    login_username              = var.sql_admin_login
    object_id                   = var.sql_admin_object_id
    azuread_authentication_only = true
  }

  tags = var.default_project_tags
}

resource "azurerm_mssql_firewall_rule" "allow_azure_services" {
  name             = "AllowAzureServices"
  server_id        = azurerm_mssql_server.main.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

resource "azurerm_mssql_database" "main" {
  name                        = "sqldb-jobpipeline"
  server_id                   = azurerm_mssql_server.main.id
  sku_name                    = "GP_S_Gen5_1"
  min_capacity                = 0.5
  auto_pause_delay_in_minutes = 15
  max_size_gb                 = 2
  collation                   = "SQL_Latin1_General_CP1_CI_AS"
  zone_redundant              = false

  tags = var.default_project_tags
}
