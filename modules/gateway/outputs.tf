output "app_gateway_id" {
  description = "Application Gateway resource ID"
  value       = azurerm_application_gateway.this.id
}

output "public_ip" {
  description = "Public IP every Helpdesk hostname must resolve to"
  value       = azurerm_public_ip.this.ip_address
}

output "ssl_certificate_name" {
  description = "Gateway TLS certificate name referenced by the Helm ingress"
  value       = var.ssl_certificate_name
}

output "identity_id" {
  description = "User-assigned identity of the gateway; empty when the certificate is a PFX"
  value       = var.key_vault_identity_id
}
