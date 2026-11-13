output "resource_group_name" {
  value = local.resource_group_name
}

output "location" {
  value = local.location
}

output "vpc_id" {
  description = "VNet resource ID (the name AWS and GCP use for the network)"
  value       = local.vnet_id
}

output "aks_subnet_id" {
  value = local.aks_subnet_id
}

output "app_gateway_subnet_id" {
  value = local.app_gateway_subnet_id
}

output "private_endpoint_subnet_id" {
  value = local.private_endpoint_subnet_id
}

output "nat_public_ip" {
  description = "Outbound IP of the cluster; allow it wherever Helpdesk calls out (e.g. a restricted Foundry resource)"
  value       = local.nat_public_ip
}

output "app_gateway_id" {
  value = local.app_gateway_id
}

output "app_gateway_public_ip" {
  description = "Public IP every Helpdesk hostname must resolve to"
  value       = local.app_gateway_public_ip
}

output "ssl_certificate_name" {
  description = "Gateway TLS certificate name referenced by the Helm ingress"
  value       = local.ssl_certificate_name
}

output "cluster_name" {
  value = local.aks_cluster_name
}

output "cluster_id" {
  value = local.cluster_id
}

output "cluster_endpoint" {
  value = local.cluster_endpoint
}

output "cluster_ca_certificate" {
  value = local.cluster_ca_certificate
}

output "oidc_issuer_url" {
  value = local.oidc_issuer_url
}

output "storage_account_name" {
  value = local.storage_account_name
}

output "storage_resource_group_name" {
  value = local.storage_resource_group_name
}

output "backend_share_name" {
  value = local.backend_share_name
}

output "backend_share_gib" {
  value = local.backend_share_gib
}

output "dns_mode" {
  description = "DNS layer mode: azure_dns | external"
  value       = var.dns.mode
}

output "dns_records" {
  description = "A records for the Helpdesk hosts; created by Terraform in azure_dns mode, by you in external mode"
  value       = local.dns_records
}
