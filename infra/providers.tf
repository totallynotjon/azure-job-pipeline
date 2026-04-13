terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }

  backend "azurerm" {
    resource_group_name  = "rg-tfstate"
    storage_account_name = "stjontfstate"
    container_name       = "tfstate"
    key                  = "azure-job-pipeline.tfstate"
  }
}

provider "azurerm" {
  features {}
  use_oidc        = true
  subscription_id = "6e7ea10d-a544-4af1-8b4f-a6c8626b112d"
}
