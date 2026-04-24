# Entra group used as a stable SQL database principal. The Function App's MI
# joins this group; DACPAC PreDeploy creates a CREATE USER FROM EXTERNAL PROVIDER
# for the group (not the fn MI directly), so the SQL side never needs to know
# the fn app's dynamic name. Add more functions later by making them group
# members — no schema change required.
resource "azuread_group" "sql_data_writers" {
  display_name     = "sql-data-writers-jobpipeline"
  security_enabled = true
  owners           = [data.azurerm_client_config.current.object_id]
}

resource "azuread_group_member" "fn_ingest" {
  group_object_id  = azuread_group.sql_data_writers.object_id
  member_object_id = azurerm_function_app_flex_consumption.ingest.identity[0].principal_id
}
