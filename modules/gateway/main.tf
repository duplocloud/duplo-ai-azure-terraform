locals {
  is_waf        = var.sku_name == "WAF_v2"
  use_key_vault = var.key_vault_secret_id != ""

  frontend_public = "public"
  placeholder     = "placeholder"
}

resource "azurerm_public_ip" "this" {
  name                = "${var.name}-pip-appgw"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = var.zones
  tags                = var.tags
}

resource "azurerm_web_application_firewall_policy" "this" {
  count = local.is_waf ? 1 : 0

  name                = "${var.name}-wafpolicy"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  policy_settings {
    enabled            = true
    mode               = var.waf_mode
    request_body_check = true
  }

  managed_rules {
    managed_rule_set {
      type    = "Microsoft_DefaultRuleSet"
      version = "2.1"
    }
  }
}

resource "azurerm_application_gateway" "this" {
  name                = "${var.name}-appgw"
  location            = var.location
  resource_group_name = var.resource_group_name
  zones               = var.zones
  firewall_policy_id  = local.is_waf ? azurerm_web_application_firewall_policy.this[0].id : null
  tags                = var.tags

  sku {
    name = var.sku_name
    tier = var.sku_name
  }

  autoscale_configuration {
    min_capacity = var.min_capacity
    max_capacity = var.max_capacity
  }

  # Only needed to read a certificate from Key Vault.
  dynamic "identity" {
    for_each = local.use_key_vault ? [1] : []
    content {
      type         = "UserAssigned"
      identity_ids = [var.key_vault_identity_id]
    }
  }

  gateway_ip_configuration {
    name      = "appgw-ipcfg"
    subnet_id = var.subnet_id
  }

  frontend_ip_configuration {
    name                 = local.frontend_public
    public_ip_address_id = azurerm_public_ip.this.id
  }

  frontend_port {
    name = "port-80"
    port = 80
  }

  # Referenced by the ingress annotation appgw.ingress.kubernetes.io/appgw-ssl-certificate.
  ssl_certificate {
    name                = var.ssl_certificate_name
    data                = local.use_key_vault ? null : var.ssl_certificate_pfx_base64
    password            = local.use_key_vault ? null : var.ssl_certificate_password
    key_vault_secret_id = local.use_key_vault ? var.key_vault_secret_id : null
  }

  ssl_policy {
    policy_type = "Predefined"
    policy_name = var.ssl_policy_name
  }

  # Placeholders: Application Gateway needs one pool/setting/listener/rule at
  # creation. The ingress controller (AGIC) replaces them from the Kubernetes Ingress.
  backend_address_pool {
    name = local.placeholder
  }

  backend_http_settings {
    name                  = local.placeholder
    cookie_based_affinity = "Disabled"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 30
  }

  http_listener {
    name                           = local.placeholder
    frontend_ip_configuration_name = local.frontend_public
    frontend_port_name             = "port-80"
    protocol                       = "Http"
  }

  request_routing_rule {
    name                       = local.placeholder
    rule_type                  = "Basic"
    http_listener_name         = local.placeholder
    backend_address_pool_name  = local.placeholder
    backend_http_settings_name = local.placeholder
    priority                   = 20000
  }

  # AGIC owns routing at runtime; Terraform keeps the SKU, identity, frontend IP,
  # TLS certificate and TLS policy.
  lifecycle {
    ignore_changes = [
      backend_address_pool,
      backend_http_settings,
      frontend_port,
      http_listener,
      probe,
      redirect_configuration,
      request_routing_rule,
      rewrite_rule_set,
      url_path_map,
      tags,
    ]

    precondition {
      condition     = local.use_key_vault || var.ssl_certificate_provided
      error_message = "The gateway needs a TLS certificate: secrets.tls_pfx_base64 and secrets.tls_pfx_password, or gateway.values.key_vault_secret_id with key_vault_identity_id."
    }

    precondition {
      condition     = !local.use_key_vault || var.key_vault_identity_id != ""
      error_message = "key_vault_secret_id requires key_vault_identity_id (a user-assigned identity with Key Vault Secrets User on the vault)."
    }
  }
}
