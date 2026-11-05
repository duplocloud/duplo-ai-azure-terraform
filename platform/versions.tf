terraform {
  required_version = ">= 1.10.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.30"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

# Credentials come from `az login` or the ARM_* environment variables.
provider "azurerm" {
  features {}

  subscription_id     = var.deployment.subscription_id
  storage_use_azuread = true
}
