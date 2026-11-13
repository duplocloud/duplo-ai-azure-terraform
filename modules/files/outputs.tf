output "account_name" {
  description = "Premium FileStorage account name"
  value       = azurerm_storage_account.this.name
}

output "resource_group_name" {
  description = "Resource group of the storage account"
  value       = var.resource_group_name
}

output "backend_share_name" {
  description = "NFS share for the Helpdesk backend"
  value       = azurerm_storage_share.backend.name
}

output "backend_share_gib" {
  description = "Size of the backend share in GiB"
  value       = azurerm_storage_share.backend.quota
}
