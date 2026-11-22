# tflint --init && tflint --recursive
config {
  call_module_type = "local"
}

plugin "terraform" {
  enabled = true
  preset  = "all"
}

plugin "azurerm" {
  enabled = true
  version = "0.33.0"
  source  = "github.com/terraform-linters/tflint-ruleset-azurerm"
}

# prevent_destroy would block destroying a deployment (the storage account and NFS share are removed with it by
# design); a user reviews the destroy plan before anything is deleted.
rule "azurerm_resources_missing_prevent_destroy" {
  enabled = false
}
