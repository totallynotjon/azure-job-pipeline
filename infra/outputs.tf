# Output values — printed after apply, useful for referencing deployed resource IDs

# Object ID of the SQL server's system-assigned MI. Needed for the one-time
# manual grant of Directory Readers Entra role (Portal → Entra ID → Roles →
# Directory Readers → Add assignments). Without that role, the SQL server
# cannot resolve Entra principal names and CREATE USER FROM EXTERNAL PROVIDER
# fails with Msg 15151.
output "sql_server_mi_principal_id" {
  description = "Azure SQL server system-assigned MI object_id (for Directory Readers manual grant)"
  value       = azurerm_mssql_server.main.identity[0].principal_id
}
