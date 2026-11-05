data "terraform_remote_state" "platform" {
  backend = "azurerm"

  config = {
    resource_group_name  = var.state.resource_group_name
    storage_account_name = var.state.storage_account_name
    container_name       = var.state.container_name
    key                  = var.state.platform_key
    subscription_id      = var.deployment.subscription_id
    use_azuread_auth     = true
  }
}

locals {
  # Every platform output is read through try(): destroy must still plan when the platform state is
  # partial or gone (an interrupted platform apply, or platform destroyed first), so the app root
  # never blocks the platform's own destroy.
  platform_outputs = data.terraform_remote_state.platform.outputs
  platform = {
    cluster_endpoint            = try(local.platform_outputs.cluster_endpoint, "")
    cluster_ca_certificate      = try(local.platform_outputs.cluster_ca_certificate, "")
    app_gateway_public_ip       = try(local.platform_outputs.app_gateway_public_ip, "")
    ssl_certificate_name        = try(local.platform_outputs.ssl_certificate_name, "helpdesk-tls")
    storage_account_name        = try(local.platform_outputs.storage_account_name, "")
    storage_resource_group_name = try(local.platform_outputs.storage_resource_group_name, "")
    backend_share_name          = try(local.platform_outputs.backend_share_name, "backend")
    backend_share_gib           = try(local.platform_outputs.backend_share_gib, 100)
    dns_mode                    = try(local.platform_outputs.dns_mode, "")
  }

  create_addons = var.addons.mode == "create"

  backup_storage_class_name = try(var.addons.values.disk_immediate_storage_class_name, "helpdesk-disk-immediate")
}

resource "random_password" "jwt_shared_secret" {
  length  = 48
  special = false
}

# The chart embeds this password unescaped in a mongodb:// URI, so no special characters.
resource "random_password" "mongodb_root_password" {
  length  = 32
  special = false
}

module "addons" {
  source = "../modules/addons"
  count  = local.create_addons ? 1 : 0

  disk_immediate_storage_class_name = local.backup_storage_class_name
  disk_sku                          = try(var.addons.values.disk_sku, null)
}

module "helpdesk" {
  source = "../modules/helpdesk"

  region               = var.deployment.region
  helpdesk_dns         = var.deployment.host
  helpdesk_xterm_dns   = var.deployment.xterm_host
  ssl_certificate_name = local.platform.ssl_certificate_name

  storage_account_name        = local.platform.storage_account_name
  storage_resource_group_name = local.platform.storage_resource_group_name
  backend_share_name          = local.platform.backend_share_name
  backend_share_gib           = local.platform.backend_share_gib
  backup_storage_class_name   = local.backup_storage_class_name

  secrets               = var.secrets
  jwt_shared_secret     = random_password.jwt_shared_secret.result
  mongodb_root_password = random_password.mongodb_root_password.result

  release_name   = try(var.helpdesk.values.release_name, null)
  namespace      = try(var.helpdesk.values.namespace, null)
  chart_version  = try(var.helpdesk.values.chart_version, null)
  azure_base_url = try(var.helpdesk.values.azure_base_url, null)

  login_method        = try(var.helpdesk.values.login_method, null)
  local_admin_email   = try(var.helpdesk.values.local_admin_email, null)
  google_client_id    = try(var.helpdesk.values.google_client_id, null)
  microsoft_client_id = try(var.helpdesk.values.microsoft_client_id, null)
  microsoft_tenant_id = try(var.helpdesk.values.microsoft_tenant_id, null)
  auth_super_users    = try(var.helpdesk.values.auth_super_users, null)

  xterm_enabled                    = try(var.helpdesk.values.xterm_enabled, null)
  mongodb_backup_enabled           = try(var.helpdesk.values.mongodb_backup_enabled, null)
  helpdesk_mcp_enabled             = try(var.helpdesk.values.helpdesk_mcp_enabled, null)
  backend_image_tag                = try(var.helpdesk.values.backend_image_tag, null)
  frontend_image_tag               = try(var.helpdesk.values.frontend_image_tag, null)
  slack_backend_enabled            = try(var.helpdesk.values.slack_backend_enabled, null)
  slack_backend_image_tag          = try(var.helpdesk.values.slack_backend_image_tag, null)
  slack_helpdesk_default_agent     = try(var.helpdesk.values.slack_helpdesk_default_agent, null)
  slack_helpdesk_default_workspace = try(var.helpdesk.values.slack_helpdesk_default_workspace, null)
  slack_app_portals                = try(var.helpdesk.values.slack_app_portals, null)

  # The backup storage class must exist first.
  depends_on = [module.addons]
}
