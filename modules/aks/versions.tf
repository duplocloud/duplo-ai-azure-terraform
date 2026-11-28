# Same constraints as the roots, so the module can be validated and tested on its own.
terraform {
  required_version = ">= 1.10.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.30"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.12"
    }
  }
}
