output "resource_group_name" {
  description = "Resource group of the deployment"
  value       = local.resource_group_name
}

output "location" {
  description = "Azure region of the deployment"
  value       = local.location
}

output "vpc_id" {
  description = "VNet resource ID (the name AWS and GCP use for the network)"
  value       = local.vnet_id
}

output "aks_subnet_id" {
  description = "Subnet of the AKS nodes"
  value       = local.aks_subnet_id
}

output "app_gateway_subnet_id" {
  description = "Subnet of the Application Gateway"
  value       = local.app_gateway_subnet_id
}

output "private_endpoint_subnet_id" {
  description = "Subnet of the private endpoints (Azure Files)"
  value       = local.private_endpoint_subnet_id
}

output "nat_public_ip" {
  description = "Outbound IP of the cluster; allow it wherever DuploCloud AI calls out (e.g. a restricted Foundry resource)"
  value       = local.nat_public_ip
}

output "app_gateway_id" {
  description = "Application Gateway resource ID"
  value       = local.app_gateway_id
}

output "app_gateway_public_ip" {
  description = "Public IP every DuploCloud AI hostname must resolve to"
  value       = local.app_gateway_public_ip
}

output "ssl_certificate_name" {
  description = "Gateway TLS certificate name referenced by the Helm ingress"
  value       = local.ssl_certificate_name
}

output "cluster_name" {
  description = "AKS cluster name"
  value       = local.aks_cluster_name
}

output "cluster_id" {
  description = "AKS cluster resource ID"
  value       = local.cluster_id
}

output "cluster_endpoint" {
  description = "Kubernetes API server URL"
  value       = local.cluster_endpoint
}

output "cluster_ca_certificate" {
  description = "Base64-encoded cluster CA certificate"
  value       = local.cluster_ca_certificate
}

output "oidc_issuer_url" {
  description = "OIDC issuer URL of the cluster (workload identity)"
  value       = local.oidc_issuer_url
}

output "storage_account_name" {
  description = "Storage account holding the NFS share"
  value       = local.storage_account_name
}

output "storage_resource_group_name" {
  description = "Resource group of that storage account"
  value       = local.storage_resource_group_name
}

output "backend_share_name" {
  description = "NFS share for the DuploCloud AI backend"
  value       = local.backend_share_name
}

output "backend_share_gib" {
  description = "Size of the backend share in GiB"
  value       = local.backend_share_gib
}

output "dns_mode" {
  description = "DNS layer mode: azure_dns | external"
  value       = var.dns.mode
}

output "dns_records" {
  description = "A records for the DuploCloud AI hosts; created by Terraform in azure_dns mode, by you in external mode"
  value       = local.dns_records
}
