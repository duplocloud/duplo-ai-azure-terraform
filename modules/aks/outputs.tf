output "cluster_name" {
  value = azurerm_kubernetes_cluster.this.name
}

output "cluster_id" {
  value = azurerm_kubernetes_cluster.this.id
}

# kube_config is marked sensitive as a whole; the API host and CA are not secret
# (with local accounts disabled it holds no credentials).
output "cluster_endpoint" {
  value = nonsensitive(azurerm_kubernetes_cluster.this.kube_config[0].host)
}

output "cluster_ca_certificate" {
  description = "Base64-encoded cluster CA certificate"
  value       = nonsensitive(azurerm_kubernetes_cluster.this.kube_config[0].cluster_ca_certificate)
}

output "oidc_issuer_url" {
  value = azurerm_kubernetes_cluster.this.oidc_issuer_url
}

output "node_resource_group" {
  value = azurerm_kubernetes_cluster.this.node_resource_group
}
