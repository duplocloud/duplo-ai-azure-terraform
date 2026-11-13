# Same constraints as the roots, so the module can be validated and tested on its own.
terraform {
  required_version = ">= 1.10.0"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
  }
}
