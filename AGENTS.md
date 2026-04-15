# AGENTS.md

## Resource Provider Registration

The `azurerm` provider (v4.x) defaults to `resource_provider_registrations = "legacy"`, which auto-registers the providers listed below. Do not add `azurerm_resource_provider_registration` resources for any of these — Terraform will error.

Only add `azurerm_resource_provider_registration` for providers **not** in this list. Example: `Microsoft.App` (used in this project, see `infra/registrations.tf`).

### Auto-registered by default (legacy set)

- Microsoft.AVS
- Microsoft.ApiManagement
- Microsoft.AppConfiguration
- Microsoft.AppPlatform
- Microsoft.Authorization
- Microsoft.Automation
- Microsoft.Blueprint
- Microsoft.BotService
- Microsoft.Cache
- Microsoft.Cdn
- Microsoft.CognitiveServices
- Microsoft.Compute
- Microsoft.ContainerInstance
- Microsoft.ContainerRegistry
- Microsoft.ContainerService
- Microsoft.CostManagement
- Microsoft.CustomProviders
- Microsoft.DBforMariaDB
- Microsoft.DBforMySQL
- Microsoft.DBforPostgreSQL
- Microsoft.DataFactory
- Microsoft.DataLakeAnalytics
- Microsoft.DataLakeStore
- Microsoft.DataMigration
- Microsoft.DataProtection
- Microsoft.Databricks
- Microsoft.DesktopVirtualization
- Microsoft.DevTestLab
- Microsoft.Devices
- Microsoft.DocumentDB
- Microsoft.EventGrid
- Microsoft.EventHub
- Microsoft.GuestConfiguration
- Microsoft.HDInsight
- Microsoft.HealthcareApis
- Microsoft.KeyVault
- Microsoft.Kusto
- Microsoft.Logic
- Microsoft.MachineLearningServices
- Microsoft.Maintenance
- Microsoft.ManagedIdentity
- Microsoft.ManagedServices
- Microsoft.Management
- Microsoft.Maps
- Microsoft.MarketplaceOrdering
- Microsoft.MixedReality
- Microsoft.Network
- Microsoft.NotificationHubs
- Microsoft.OperationalInsights
- Microsoft.OperationsManagement
- Microsoft.PolicyInsights
- Microsoft.PowerBIDedicated
- Microsoft.RecoveryServices
- Microsoft.Relay
- Microsoft.Resources
- Microsoft.Search
- Microsoft.Security
- Microsoft.SecurityInsights
- Microsoft.ServiceBus
- Microsoft.ServiceFabric
- Microsoft.SignalRService
- Microsoft.Sql
- Microsoft.Storage
- Microsoft.StreamAnalytics
- Microsoft.Web
- microsoft.insights

Source: [`internal/resourceproviders/required.go`](https://github.com/hashicorp/terraform-provider-azurerm/blob/main/internal/resourceproviders/required.go)
