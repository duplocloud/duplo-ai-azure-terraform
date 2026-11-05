locals {
  create_resource_group = var.resource_group.mode == "create"
  create_network        = var.network.mode == "create"
  create_gateway        = var.gateway.mode == "create"
  create_cluster        = var.cluster.mode == "create"
  create_storage        = var.storage.mode == "create"
  create_dns            = var.dns.mode == "azure_dns"

  name     = var.deployment.name
  location = var.deployment.region
  tags = merge(var.common_tags, {
    "duplocloud:deployment" = var.deployment.name
    "duplocloud:managed-by" = "cloud-deployment-agent"
  })

  cluster_name = try(var.cluster.values.cluster_name, "${local.name}-aks")

  # Whether a PFX was supplied is not itself secret.
  tls_pfx_base64   = lookup(var.secrets, "tls_pfx_base64", "")
  tls_pfx_password = lookup(var.secrets, "tls_pfx_password", "")
  tls_pfx_provided = nonsensitive(length(local.tls_pfx_base64) > 0)

  # Resolved layer outputs: module output when created, else var.<layer>.provides.<name>
  resource_group_name = local.create_resource_group ? azurerm_resource_group.this[0].name : try(var.resource_group.provides.name, null)
  resource_group_id   = "/subscriptions/${var.deployment.subscription_id}/resourceGroups/${local.resource_group_name}"

  vnet_id                    = local.create_network ? module.network[0].vnet_id : try(var.network.provides.vnet_id, null)
  aks_subnet_id              = local.create_network ? module.network[0].aks_subnet_id : try(var.network.provides.aks_subnet_id, null)
  app_gateway_subnet_id      = local.create_network ? module.network[0].app_gateway_subnet_id : try(var.network.provides.app_gateway_subnet_id, null)
  private_endpoint_subnet_id = local.create_network ? module.network[0].private_endpoint_subnet_id : try(var.network.provides.private_endpoint_subnet_id, null)
  nat_public_ip              = local.create_network ? module.network[0].nat_public_ip : try(var.network.provides.nat_public_ip, "")

  app_gateway_id          = local.create_gateway ? module.gateway[0].app_gateway_id : try(var.gateway.provides.app_gateway_id, null)
  app_gateway_public_ip   = local.create_gateway ? module.gateway[0].public_ip : try(var.gateway.provides.public_ip, null)
  ssl_certificate_name    = local.create_gateway ? module.gateway[0].ssl_certificate_name : try(var.gateway.provides.ssl_certificate_name, null)
  app_gateway_identity_id = local.create_gateway ? module.gateway[0].identity_id : try(var.gateway.provides.identity_id, "")

  aks_cluster_name       = local.create_cluster ? module.aks[0].cluster_name : try(var.cluster.provides.cluster_name, null)
  cluster_id             = local.create_cluster ? module.aks[0].cluster_id : try(var.cluster.provides.cluster_id, null)
  cluster_endpoint       = local.create_cluster ? module.aks[0].cluster_endpoint : try(var.cluster.provides.cluster_endpoint, null)
  cluster_ca_certificate = local.create_cluster ? module.aks[0].cluster_ca_certificate : try(var.cluster.provides.cluster_ca_certificate, null)
  oidc_issuer_url        = local.create_cluster ? module.aks[0].oidc_issuer_url : try(var.cluster.provides.oidc_issuer_url, "")

  storage_account_name        = local.create_storage ? module.files[0].account_name : try(var.storage.provides.account_name, null)
  storage_resource_group_name = local.create_storage ? module.files[0].resource_group_name : try(var.storage.provides.resource_group_name, local.resource_group_name)
  backend_share_name          = local.create_storage ? module.files[0].backend_share_name : try(var.storage.provides.backend_share_name, null)
  backend_share_gib           = local.create_storage ? module.files[0].backend_share_gib : try(var.storage.provides.backend_share_gib, 100)

  hostnames = [var.deployment.host, var.deployment.xterm_host]
  dns_records = [
    for host in local.hostnames : { name = host, type = "A", value = local.app_gateway_public_ip }
  ]
}

# A deployer scoped to an administrator-created group uses mode "existing";
# destroying this root then never deletes the group.
resource "azurerm_resource_group" "this" {
  count = local.create_resource_group ? 1 : 0

  name     = try(var.resource_group.values.name, "${local.name}-rg")
  location = local.location
  tags     = local.tags
}

module "network" {
  source = "../modules/network"
  count  = local.create_network ? 1 : 0

  name                                = local.name
  location                            = local.location
  resource_group_name                 = local.resource_group_name
  vnet_cidr                           = try(var.network.values.vnet_cidr, null)
  aks_nodes_cidr                      = try(var.network.values.aks_nodes_cidr, null)
  app_gateway_cidr                    = try(var.network.values.app_gateway_cidr, null)
  private_endpoints_cidr              = try(var.network.values.private_endpoints_cidr, null)
  app_gateway_allowed_source_prefixes = try(var.network.values.app_gateway_allowed_source_prefixes, null)
  nat_idle_timeout_minutes            = try(var.network.values.nat_idle_timeout_minutes, null)
  tags                                = local.tags
}

module "gateway" {
  source = "../modules/gateway"
  count  = local.create_gateway ? 1 : 0

  name                       = local.name
  location                   = local.location
  resource_group_name        = local.resource_group_name
  subnet_id                  = local.app_gateway_subnet_id
  sku_name                   = try(var.gateway.values.sku_name, null)
  waf_mode                   = try(var.gateway.values.waf_mode, null)
  min_capacity               = try(var.gateway.values.min_capacity, null)
  max_capacity               = try(var.gateway.values.max_capacity, null)
  zones                      = try(var.gateway.values.zones, null)
  ssl_policy_name            = try(var.gateway.values.ssl_policy_name, null)
  ssl_certificate_name       = try(var.gateway.values.ssl_certificate_name, null)
  ssl_certificate_pfx_base64 = local.tls_pfx_base64
  ssl_certificate_password   = local.tls_pfx_password
  ssl_certificate_provided   = local.tls_pfx_provided
  key_vault_secret_id        = try(var.gateway.values.key_vault_secret_id, null)
  key_vault_identity_id      = try(var.gateway.values.key_vault_identity_id, null)
  tags                       = local.tags
}

module "aks" {
  source = "../modules/aks"
  count  = local.create_cluster ? 1 : 0

  cluster_name            = local.cluster_name
  location                = local.location
  resource_group_name     = local.resource_group_name
  resource_group_id       = local.resource_group_id
  vnet_id                 = local.vnet_id
  aks_subnet_id           = local.aks_subnet_id
  app_gateway_id          = local.app_gateway_id
  app_gateway_subnet_id   = local.app_gateway_subnet_id
  app_gateway_identity_id = local.app_gateway_identity_id
  nat_public_ip           = local.nat_public_ip

  kubernetes_version                            = try(var.cluster.values.kubernetes_version, null)
  sku_tier                                      = try(var.cluster.values.sku_tier, null)
  node_vm_size                                  = try(var.cluster.values.node_vm_size, null)
  node_count                                    = try(var.cluster.values.node_count, null)
  node_autoscaling                              = try(var.cluster.values.node_autoscaling, null)
  node_max_count                                = try(var.cluster.values.node_max_count, null)
  node_zones                                    = try(var.cluster.values.node_zones, null)
  node_os_sku                                   = try(var.cluster.values.node_os_sku, null)
  node_disk_size                                = try(var.cluster.values.node_disk_size, null)
  api_authorized_ip_ranges                      = try(var.cluster.values.api_authorized_ip_ranges, null)
  admin_group_object_ids                        = try(var.cluster.values.admin_group_object_ids, null)
  additional_admin_principal_ids                = try(var.cluster.values.additional_admin_principal_ids, null)
  grant_deployer_cluster_admin                  = try(var.cluster.values.grant_deployer_cluster_admin, null)
  pod_cidr                                      = try(var.cluster.values.pod_cidr, null)
  service_cidr                                  = try(var.cluster.values.service_cidr, null)
  dns_service_ip                                = try(var.cluster.values.dns_service_ip, null)
  automatic_upgrade_channel                     = try(var.cluster.values.automatic_upgrade_channel, null)
  node_os_upgrade_channel                       = try(var.cluster.values.node_os_upgrade_channel, null)
  azure_policy_enabled                          = try(var.cluster.values.azure_policy_enabled, null)
  microsoft_defender_log_analytics_workspace_id = try(var.cluster.values.microsoft_defender_log_analytics_workspace_id, null)
  tags                                          = local.tags
}

module "files" {
  source = "../modules/files"
  count  = local.create_storage ? 1 : 0

  name                       = local.name
  location                   = local.location
  resource_group_name        = local.resource_group_name
  vnet_id                    = local.vnet_id
  private_endpoint_subnet_id = local.private_endpoint_subnet_id
  account_name               = try(var.storage.values.account_name, null)
  replication                = try(var.storage.values.replication, null)
  backend_quota_gib          = try(var.storage.values.backend_quota_gib, null)
  tags                       = local.tags
}

module "dns" {
  source = "../modules/dns"
  count  = local.create_dns ? 1 : 0

  hostnames                = local.hostnames
  ip_address               = local.app_gateway_public_ip
  zone_name                = try(var.dns.values.zone_name, null)
  zone_resource_group_name = try(var.dns.values.zone_resource_group_name, null)
  ttl                      = try(var.dns.values.ttl, null)
  tags                     = local.tags
}
