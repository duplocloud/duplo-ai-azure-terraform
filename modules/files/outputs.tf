output "account_name" {
  value = azurerm_storage_account.this.name
}

output "resource_group_name" {
  value = var.resource_group_name
}

output "backend_share_name" {
  value = azurerm_storage_share.backend.name
}

output "backend_share_gib" {
  value = azurerm_storage_share.backend.quota
}
