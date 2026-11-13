output "cluster_name" {
  description = "AKS cluster name"
  value       = azurerm_kubernetes_cluster.this.name
}

output "cluster_id" {
  description = "AKS cluster resource ID"
  value       = azurerm_kubernetes_cluster.this.id
}

# kube_config is marked sensitive as a whole; the API host and CA are not secret
# (with local accounts disabled it holds no credentials).
output "cluster_endpoint" {
  description = "Kubernetes API server URL"
  value       = nonsensitive(azurerm_kubernetes_cluster.this.kube_config[0].host)
}

output "cluster_ca_certificate" {
  description = "Base64-encoded cluster CA certificate"
  value       = nonsensitive(azurerm_kubernetes_cluster.this.kube_config[0].cluster_ca_certificate)
}

output "oidc_issuer_url" {
  description = "OIDC issuer URL of the cluster (workload identity)"
  value       = azurerm_kubernetes_cluster.this.oidc_issuer_url
}

output "node_resource_group" {
  description = "Resource group AKS manages for the node resources"
  value       = azurerm_kubernetes_cluster.this.node_resource_group
}
