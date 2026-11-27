data "azurerm_client_config" "current" {}

locals {
  # The NAT gateway egress IP is not the load balancer outbound IP; it must be in the
  # allowlist or the cluster's own calls to its API (from nodes) are blocked.
  authorized_ip_ranges = length(var.api_authorized_ip_ranges) == 0 ? [] : distinct(concat(
    var.api_authorized_ip_ranges,
    var.nat_public_ip == "" ? [] : ["${var.nat_public_ip}/32"],
  ))

  agic_principal_id = azurerm_kubernetes_cluster.this.ingress_application_gateway[0].ingress_application_gateway_identity[0].object_id

  # Principals that get Kubernetes data-plane admin (Entra ID + Azure RBAC). The
  # deployer is included so the app root can install Helm with the same credentials.
  cluster_admins = toset(concat(
    var.grant_deployer_cluster_admin ? [data.azurerm_client_config.current.object_id] : [],
    var.additional_admin_principal_ids,
  ))
}

# Control plane identity. With a custom VNet AKS needs Network Contributor on it.
resource "azurerm_user_assigned_identity" "control_plane" {
  name                = "${var.cluster_name}-identity"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_role_assignment" "control_plane_network" {
  scope                = var.vnet_id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.control_plane.principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_kubernetes_cluster" "this" {
  name                = var.cluster_name
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = var.cluster_name
  kubernetes_version  = var.kubernetes_version
  sku_tier            = var.sku_tier
  node_resource_group = "${var.resource_group_name}-aks-nodes"
  tags                = var.tags

  dynamic "api_server_access_profile" {
    for_each = length(local.authorized_ip_ranges) > 0 ? [1] : []
    content {
      authorized_ip_ranges = local.authorized_ip_ranges
    }
  }

  local_account_disabled            = true
  role_based_access_control_enabled = true

  azure_active_directory_role_based_access_control {
    azure_rbac_enabled     = true
    tenant_id              = data.azurerm_client_config.current.tenant_id
    admin_group_object_ids = var.admin_group_object_ids
  }

  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  automatic_upgrade_channel = var.automatic_upgrade_channel
  node_os_upgrade_channel   = var.node_os_upgrade_channel

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.control_plane.id]
  }

  default_node_pool {
    name                        = "system"
    temporary_name_for_rotation = "systemtmp"
    vm_size                     = var.node_vm_size
    node_count                  = var.node_autoscaling ? null : var.node_count
    auto_scaling_enabled        = var.node_autoscaling
    min_count                   = var.node_autoscaling ? var.node_count : null
    max_count                   = var.node_autoscaling ? var.node_max_count : null
    zones                       = var.node_zones
    vnet_subnet_id              = var.aks_subnet_id
    os_sku                      = var.node_os_sku
    os_disk_size_gb             = var.node_disk_size
    max_pods                    = 110

    upgrade_settings {
      max_surge = "1"
    }
  }

  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    pod_cidr            = var.pod_cidr
    service_cidr        = var.service_cidr
    dns_service_ip      = var.dns_service_ip
    outbound_type       = "userAssignedNATGateway"
    load_balancer_sku   = "standard"
  }

  # Application Gateway Ingress Controller add-on, bound to the gateway layer.
  ingress_application_gateway {
    gateway_id = var.app_gateway_id
  }

  storage_profile {
    disk_driver_enabled = true
    file_driver_enabled = true
  }

  # Subscription governance (Azure Policy / Defender for Cloud) may enable these after
  # creation. Declared so a later plan keeps them instead of removing them.
  azure_policy_enabled = var.azure_policy_enabled

  dynamic "microsoft_defender" {
    for_each = var.microsoft_defender_log_analytics_workspace_id == "" ? [] : [var.microsoft_defender_log_analytics_workspace_id]
    content {
      # ARM reports this ID with "resourcegroups"; the provider requires "resourceGroups".
      log_analytics_workspace_id = replace(microsoft_defender.value, "/\\/resourcegroups\\//", "/resourceGroups/")
    }
  }

  depends_on = [azurerm_role_assignment.control_plane_network]
}

# ── AGIC add-on identity (created by AKS) ─────────────────────────────────────
# Manage the gateway, read the resource group, join the gateway subnet.
resource "azurerm_role_assignment" "agic_gateway" {
  scope                            = var.app_gateway_id
  role_definition_name             = "Contributor"
  principal_id                     = local.agic_principal_id
  principal_type                   = "ServicePrincipal"
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "agic_resource_group" {
  scope                            = var.resource_group_id
  role_definition_name             = "Reader"
  principal_id                     = local.agic_principal_id
  principal_type                   = "ServicePrincipal"
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "agic_subnet" {
  scope                            = var.app_gateway_subnet_id
  role_definition_name             = "Network Contributor"
  principal_id                     = local.agic_principal_id
  principal_type                   = "ServicePrincipal"
  skip_service_principal_aad_check = true
}

# A gateway with a user-assigned identity (Key Vault certificate) can only be
# written by a principal that may assign that identity.
resource "azurerm_role_assignment" "agic_gateway_identity" {
  count = var.app_gateway_identity_id == "" ? 0 : 1

  scope                            = var.app_gateway_identity_id
  role_definition_name             = "Managed Identity Operator"
  principal_id                     = local.agic_principal_id
  principal_type                   = "ServicePrincipal"
  skip_service_principal_aad_check = true
}

# The AGIC pod starts with the cluster, before the role assignments above exist, and Entra ID takes
# a few minutes to propagate them. Wait here so the app root (which restarts AGIC once, keyed on
# agic_restart_key) never starts against a gateway AGIC cannot read yet. Keyed on the assignment IDs,
# so a platform apply that leaves them unchanged does not wait again.
resource "time_sleep" "agic_role_propagation" {
  create_duration = "5m"

  triggers = {
    gateway          = azurerm_role_assignment.agic_gateway.id
    resource_group   = azurerm_role_assignment.agic_resource_group.id
    subnet           = azurerm_role_assignment.agic_subnet.id
    gateway_identity = try(azurerm_role_assignment.agic_gateway_identity[0].id, "")
  }
}

# ── Kubernetes access ─────────────────────────────────────────────────────────
resource "azurerm_role_assignment" "cluster_admin" {
  for_each = local.cluster_admins

  scope                = azurerm_kubernetes_cluster.this.id
  role_definition_name = "Azure Kubernetes Service RBAC Cluster Admin"
  principal_id         = each.key
}

# Lets the same principals fetch a kubeconfig (az aks get-credentials).
resource "azurerm_role_assignment" "cluster_user" {
  for_each = local.cluster_admins

  scope                = azurerm_kubernetes_cluster.this.id
  role_definition_name = "Azure Kubernetes Service Cluster User Role"
  principal_id         = each.key
}
