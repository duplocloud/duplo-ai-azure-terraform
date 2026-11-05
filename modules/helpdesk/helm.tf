locals {
  is_local     = var.login_method == "local"
  is_google    = var.login_method == "google"
  is_microsoft = var.login_method == "microsoft"

  super_users = join(",", compact(concat(
    compact(split(",", var.auth_super_users)),
    local.is_local ? [var.local_admin_email] : []
  )))

  # Non-secret backend environment, rendered into the values document.
  extra_env = local.is_local ? [
    { name = "Authentication__LocalAdminEmail", value = var.local_admin_email }
  ] : []

  rendered_values = templatefile("${path.module}/templates/values.yml.tftpl", {
    helpdesk_dns                     = var.helpdesk_dns
    helpdesk_xterm_dns               = var.helpdesk_xterm_dns
    infra_region                     = var.region
    ssl_certificate_name             = var.ssl_certificate_name
    azure_base_url                   = var.azure_base_url
    backend_claim                    = kubernetes_persistent_volume_claim_v1.static["backend"].metadata[0].name
    backend_size                     = local.static_volumes.backend.size
    backup_storage_class_name        = var.backup_storage_class_name
    mongodb_backup_enabled           = var.mongodb_backup_enabled
    xterm_enabled                    = var.xterm_enabled
    google_client_id                 = local.is_google ? var.google_client_id : ""
    microsoft_client_id              = local.is_microsoft ? var.microsoft_client_id : ""
    microsoft_tenant_id              = local.is_microsoft ? var.microsoft_tenant_id : ""
    auth_super_users                 = local.super_users
    backend_extra_env                = local.extra_env
    slack_backend_enabled            = var.slack_backend_enabled
    slack_backend_image_tag          = var.slack_backend_image_tag
    slack_helpdesk_default_agent     = var.slack_helpdesk_default_agent
    slack_helpdesk_default_workspace = var.slack_helpdesk_default_workspace
    slack_app_portals                = var.slack_app_portals
    helpdesk_mcp_enabled             = var.helpdesk_mcp_enabled
    backend_image_tag                = var.backend_image_tag
    frontend_image_tag               = var.frontend_image_tag
  })

  # Secret values by key. Sensitive: only ever reach Helm through set_sensitive.
  secret_values = merge(
    { for k, v in var.secrets : k => v },
    {
      jwt_shared_secret     = var.jwt_shared_secret
      mongodb_root_password = var.mongodb_root_password
    }
  )

  # Whether a secret is present is not itself secret; this keeps the
  # set_sensitive for_each key set known and non-sensitive.
  secret_present = { for k in nonsensitive(keys(local.secret_values)) : k => nonsensitive(length(local.secret_values[k]) > 0) }

  # label: logical name (non-sensitive, shown in outputs); path: Helm value path; key: secret_values key.
  sensitive_candidates = [
    { label = "secrets.licensingToken", path = "secrets.licensingToken", key = "licensing_token", on = true },
    { label = "secrets.jwtSharedSecret", path = "secrets.jwtSharedSecret", key = "jwt_shared_secret", on = true },
    { label = "mongodb.auth.rootPassword", path = "mongodb.auth.rootPassword", key = "mongodb_root_password", on = true },
    { label = "secrets.azureApiKey", path = "secrets.azureApiKey", key = "azure_api_key", on = var.azure_base_url != "" },
    { label = "secrets.googleClientSecret", path = "secrets.googleClientSecret", key = "google_client_secret", on = local.is_google },
    { label = "secrets.microsoftClientSecret", path = "secrets.microsoftClientSecret", key = "microsoft_client_secret", on = local.is_microsoft },
    {
      label = "backend.extraEnv.Authentication__LocalAdminPassword"
      path  = "backend.extraEnv[${length(local.extra_env)}].value"
      key   = "local_admin_password"
      on    = local.is_local
    },
    { label = "slackBackend.envFromSecret.data.SLACK_APP_TOKEN", path = "slackBackend.envFromSecret.data.SLACK_APP_TOKEN", key = "slack_app_token", on = var.slack_backend_enabled },
    { label = "slackBackend.envFromSecret.data.SLACK_BOT_TOKEN", path = "slackBackend.envFromSecret.data.SLACK_BOT_TOKEN", key = "slack_bot_token", on = var.slack_backend_enabled },
  ]

  sensitive_entries = [for c in local.sensitive_candidates : c if c.on && lookup(local.secret_present, c.key, false)]
}

resource "helm_release" "helpdesk" {
  name       = var.release_name
  repository = "oci://quay.io/duplocloud"
  chart      = "helpdesk"
  version    = var.chart_version
  namespace  = var.namespace
  timeout    = 1200

  values = [local.rendered_values]

  # The secret env var's name sits next to its sensitive value in extraEnv.
  dynamic "set" {
    for_each = local.is_local ? [1] : []
    content {
      name  = "backend.extraEnv[${length(local.extra_env)}].name"
      value = "Authentication__LocalAdminPassword"
    }
  }

  # Helm's --set parser treats , \ { } specially, so they are backslash-escaped;
  # type "string" stops values like "true" or "123" being coerced.
  dynamic "set_sensitive" {
    for_each = local.sensitive_entries
    content {
      name  = set_sensitive.value.path
      value = replace(replace(replace(replace(local.secret_values[set_sensitive.value.key], "\\", "\\\\"), ",", "\\,"), "{", "\\{"), "}", "\\}")
      type  = "string"
    }
  }

  depends_on = [
    kubernetes_namespace.this,
    kubernetes_persistent_volume_claim_v1.static,
  ]
}
