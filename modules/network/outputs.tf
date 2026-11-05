output "vnet_id" {
  value = azurerm_virtual_network.this.id
}

output "aks_subnet_id" {
  value = azurerm_subnet.aks_nodes.id
}

output "app_gateway_subnet_id" {
  value = azurerm_subnet.app_gateway.id
}

output "private_endpoint_subnet_id" {
  value = azurerm_subnet.private_endpoints.id
}

output "nat_public_ip" {
  description = "Outbound (NAT) public IP of the AKS nodes"
  value       = azurerm_public_ip.nat.ip_address
}
