mock_provider "helm" {}
mock_provider "kubernetes" {}
# Mock-only: the mock cannot honour `length`, so assertions check the configured length.
mock_provider "random" {}

override_data {
  target = data.terraform_remote_state.platform
  values = {
    outputs = {
      resource_group_name         = "acme-rg"
      location                    = "westus2"
      cluster_name                = "acme-aks"
      cluster_endpoint            = "https://acme-aks.hcp.westus2.azmk8s.io:443"
      cluster_ca_certificate      = "Y2E="
      app_gateway_public_ip       = "20.0.0.2"
      ssl_certificate_name        = "helpdesk-tls"
      storage_account_name        = "stacmenfsabc123"
      storage_resource_group_name = "acme-rg"
      backend_share_name          = "backend"
      backend_share_gib           = 200
      dns_mode                    = "external"
    }
  }
}

variables {
  deployment = {
    name            = "acme"
    region          = "westus2"
    host            = "helpdesk.example.com"
    xterm_host      = "xterm.example.com"
    subscription_id = "00000000-0000-0000-0000-000000000000"
  }
  state = {
    resource_group_name  = "tfstate-rg"
    storage_account_name = "tfstate123"
    container_name       = "tfstate"
    platform_key         = "helpdesk/platform.tfstate"
  }
  addons = { mode = "create", values = {} }
  helpdesk = {
    mode = "create"
    values = {
      login_method        = "microsoft"
      microsoft_client_id = "33333333-3333-3333-3333-333333333333"
      microsoft_tenant_id = "11111111-1111-1111-1111-111111111111"
      auth_super_users    = "admin@example.com"
      azure_base_url      = "https://acme.services.ai.azure.com/anthropic"
    }
  }
  secrets = {
    microsoft_client_secret = "ms-secret"
    azure_api_key           = "foundry-key"
  }
}

run "microsoft_login" {
  command = apply

  assert {
    condition     = length(module.addons) == 1
    error_message = "addons module should be created"
  }

  assert {
    condition     = yamldecode(module.helpdesk.rendered_values).secrets.microsoftClientId == "33333333-3333-3333-3333-333333333333"
    error_message = "the Microsoft client ID should be rendered"
  }

  assert {
    condition     = yamldecode(module.helpdesk.rendered_values).config.authSuperUsers == "admin@example.com"
    error_message = "super users should be rendered"
  }

  assert {
    condition     = yamldecode(module.helpdesk.rendered_values).config.azureBaseUrl == "https://acme.services.ai.azure.com/anthropic"
    error_message = "the Foundry endpoint should be rendered"
  }

  assert {
    condition     = contains(module.helpdesk.sensitive_value_labels, "secrets.microsoftClientSecret") && contains(module.helpdesk.sensitive_value_labels, "secrets.azureApiKey")
    error_message = "the client secret and model key should be sensitive set values"
  }

  assert {
    condition     = !strcontains(module.helpdesk.rendered_values, "ms-secret") && !strcontains(module.helpdesk.rendered_values, "foundry-key")
    error_message = "secrets must never be rendered into the values document"
  }

  assert {
    condition     = !contains(module.helpdesk.sensitive_value_labels, "secrets.licensingToken")
    error_message = "an absent licensing token should not be set"
  }
}

run "azure_ingress_and_storage" {
  command = apply

  assert {
    condition     = yamldecode(module.helpdesk.rendered_values).ingress.className == "azure-application-gateway"
    error_message = "the ingress should use the Application Gateway ingress class"
  }

  assert {
    condition     = yamldecode(module.helpdesk.rendered_values).ingress.annotations["appgw.ingress.kubernetes.io/appgw-ssl-certificate"] == "helpdesk-tls"
    error_message = "the ingress should reference the gateway certificate"
  }

  assert {
    condition     = yamldecode(module.helpdesk.rendered_values).ingress.annotations["alb.ingress.kubernetes.io/ssl-redirect"] == null
    error_message = "the chart's AWS ALB annotation should be removed"
  }

  assert {
    condition     = yamldecode(module.helpdesk.rendered_values).backend.persistence.existingClaim == "helpdesk-backend-static"
    error_message = "the backend should use the static NFS claim"
  }

  assert {
    condition     = yamldecode(module.helpdesk.rendered_values).duploAgent.persistence.existingClaim == "helpdesk-backend-static" && yamldecode(module.helpdesk.rendered_values).backend.persistence.size == "200Gi"
    error_message = "the agent should share the backend claim, sized from the share"
  }

  assert {
    condition     = yamldecode(module.helpdesk.rendered_values).mongodbBackup.storage.storageClass == "helpdesk-disk-immediate"
    error_message = "the backup volume should use the Immediate-binding class"
  }

  assert {
    condition     = yamldecode(module.helpdesk.rendered_values).xterm.hostname == "https://xterm.example.com"
    error_message = "xterm should be served on the xterm host"
  }

  assert {
    condition     = yamldecode(module.helpdesk.rendered_values).bedrockSubscription.enabled == false && yamldecode(module.helpdesk.rendered_values).collector.enabled == false
    error_message = "AWS-only components should be off"
  }
}

run "local_login" {
  command = apply

  variables {
    helpdesk = {
      mode   = "create"
      values = { login_method = "local", local_admin_email = "admin@example.com" }
    }
    secrets = { local_admin_password = "pw", licensing_token = "lic" }
  }

  assert {
    condition     = yamldecode(module.helpdesk.rendered_values).backend.extraEnv[0].name == "Authentication__LocalAdminEmail"
    error_message = "local login should render the admin email env var"
  }

  assert {
    condition     = contains(module.helpdesk.sensitive_value_labels, "backend.extraEnv.Authentication__LocalAdminPassword") && contains(module.helpdesk.sensitive_value_labels, "secrets.licensingToken")
    error_message = "the admin password and licensing token should be sensitive set values"
  }

  assert {
    condition     = yamldecode(module.helpdesk.rendered_values).secrets.microsoftClientId == ""
    error_message = "other providers should be disabled"
  }
}

run "addons_existing" {
  command = apply

  variables {
    addons = { mode = "existing", values = {} }
  }

  assert {
    condition     = length(module.addons) == 0
    error_message = "existing mode should not create the add-ons"
  }
}

run "external_dns_records" {
  command = apply

  assert {
    condition     = length(output.dns_records) == 2 && output.dns_records[0].name == "helpdesk.example.com" && output.dns_records[1].name == "xterm.example.com" && alltrue([for r in output.dns_records : r.type == "A" && r.value == "20.0.0.2"])
    error_message = "external DNS should output A records for both hosts"
  }

  assert {
    condition     = output.helpdesk_url == "https://helpdesk.example.com"
    error_message = "helpdesk_url should use the host"
  }
}

run "generated_secrets" {
  command = apply

  assert {
    condition     = random_password.mongodb_root_password.length == 32 && random_password.mongodb_root_password.special == false
    error_message = "the MongoDB password must be URI-safe"
  }

  assert {
    condition     = contains(module.helpdesk.sensitive_value_labels, "mongodb.auth.rootPassword") && contains(module.helpdesk.sensitive_value_labels, "secrets.jwtSharedSecret")
    error_message = "generated secrets should be passed as sensitive set values"
  }
}

run "rejects_unknown_login_method" {
  command = plan

  variables {
    helpdesk = { mode = "create", values = { login_method = "saml" } }
  }

  expect_failures = [var.helpdesk]
}

run "microsoft_login_requires_secret" {
  command = plan

  variables {
    secrets = { azure_api_key = "foundry-key" }
  }

  expect_failures = [var.helpdesk]
}

run "foundry_requires_key" {
  command = plan

  variables {
    secrets = { microsoft_client_secret = "ms-secret" }
  }

  expect_failures = [var.helpdesk]
}

run "plans_without_platform_outputs" {
  command = plan

  override_data {
    target = data.terraform_remote_state.platform
    values = { outputs = {} }
  }

  assert {
    condition     = length(output.dns_records) == 0
    error_message = "with no platform state the app root should still plan (for destroy)"
  }
}
