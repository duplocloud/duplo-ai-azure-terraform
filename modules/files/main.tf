# Premium Azure Files NFS share for the ReadWriteMany volume the backend and the
# agent share (the chart mounts the backend claim in both).
# Reached only through a private endpoint; no public access and no account keys.
# The app root binds it as a static Kubernetes volume, so AKS needs no storage
# permissions.

resource "random_string" "suffix" {
  count = var.account_name == "" ? 1 : 0

  length  = 6
  special = false
  upper   = false
}

locals {
  account_name = var.account_name != "" ? var.account_name : substr("st${replace(var.name, "-", "")}nfs${random_string.suffix[0].result}", 0, 24)
}

resource "azurerm_storage_account" "this" {
  name                            = local.account_name
  resource_group_name             = var.resource_group_name
  location                        = var.location
  account_kind                    = "FileStorage"
  account_tier                    = "Premium"
  account_replication_type        = var.replication
  https_traffic_only_enabled      = false # NFSv4.1 does not use HTTPS; isolated behind the private endpoint
  public_network_access_enabled   = false
  shared_access_key_enabled       = false
  default_to_oauth_authentication = true
  min_tls_version                 = "TLS1_2"
  tags                            = var.tags

  network_rules {
    default_action = "Deny"
    bypass         = ["None"]
  }
}

# storage_account_id selects the ARM API (not the key-authenticated data plane).
resource "azurerm_storage_share" "backend" {
  name               = "backend"
  storage_account_id = azurerm_storage_account.this.id
  enabled_protocol   = "NFS"
  access_tier        = "Premium"
  quota              = var.backend_quota_gib
}

resource "azurerm_private_dns_zone" "file" {
  name                = "privatelink.file.core.windows.net"
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "file" {
  name                  = "${var.name}-file"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.file.name
  virtual_network_id    = var.vnet_id
  registration_enabled  = false
  tags                  = var.tags
}

resource "azurerm_private_endpoint" "file" {
  name                = "${var.name}-pe-nfs"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoint_subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "nfs"
    private_connection_resource_id = azurerm_storage_account.this.id
    subresource_names              = ["file"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "nfs"
    private_dns_zone_ids = [azurerm_private_dns_zone.file.id]
  }
}
