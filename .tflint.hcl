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

# prevent_destroy would block the agent's own destroy of a deployment (the storage account and NFS share are
# removed with it by design); the agent shows the destroy plan to the user before anything is deleted.
rule "azurerm_resources_missing_prevent_destroy" {
  enabled = false
}
