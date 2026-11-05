# Mock-only: mocked values are random strings, which fail the provider's UUID and
# resource ID validation where one resource feeds another.
mock_provider "azurerm" {
  mock_data "azurerm_client_config" {
    defaults = {
      tenant_id = "11111111-1111-1111-1111-111111111111"
      object_id = "22222222-2222-2222-2222-222222222222"
    }
  }
}
mock_provider "random" {}

variables {
  deployment = {
    name            = "acme"
    region          = "westus2"
    host            = "helpdesk.example.com"
    xterm_host      = "xterm.example.com"
    subscription_id = "00000000-0000-0000-0000-000000000000"
  }
  resource_group = { mode = "create", values = {}, provides = {} }
  network        = { mode = "create", values = {}, provides = {} }
  gateway        = { mode = "create", values = {}, provides = {} }
  cluster        = { mode = "create", values = {}, provides = {} }
  storage        = { mode = "create", values = {}, provides = {} }
  dns = {
    mode     = "azure_dns"
    values   = { zone_name = "example.com", zone_resource_group_name = "dns-rg" }
    provides = {}
  }
  secrets     = { tls_pfx_base64 = "UEZY", tls_pfx_password = "pw" }
  common_tags = { owner = "test" }
}

run "greenfield" {
  command = plan

  assert {
    condition     = length(azurerm_resource_group.this) == 1 && azurerm_resource_group.this[0].name == "acme-rg"
    error_message = "resource group should be created as <name>-rg"
  }

  assert {
    condition     = length(module.network) == 1 && length(module.gateway) == 1 && length(module.aks) == 1 && length(module.files) == 1
    error_message = "every create-mode layer should run its module"
  }

  assert {
    condition     = length(module.dns) == 1
    error_message = "azure_dns mode should run the dns module"
  }

  assert {
    condition     = azurerm_resource_group.this[0].tags["duplocloud:deployment"] == "acme" && azurerm_resource_group.this[0].tags["owner"] == "test"
    error_message = "common_tags and the deployment tags should be applied"
  }

  assert {
    condition     = output.cluster_name == "acme-aks" && output.dns_mode == "azure_dns"
    error_message = "cluster and dns outputs should resolve"
  }
}

run "existing_everything" {
  command = plan

  variables {
    resource_group = { mode = "existing", values = {}, provides = { name = "shared-rg" } }
    network = {
      mode   = "existing"
      values = {}
      provides = {
        vnet_id                    = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/net/providers/Microsoft.Network/virtualNetworks/v"
        aks_subnet_id              = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/net/providers/Microsoft.Network/virtualNetworks/v/subnets/aks"
        app_gateway_subnet_id      = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/net/providers/Microsoft.Network/virtualNetworks/v/subnets/appgw"
        private_endpoint_subnet_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/net/providers/Microsoft.Network/virtualNetworks/v/subnets/pe"
        nat_public_ip              = "20.0.0.1"
      }
    }
    gateway = {
      mode   = "existing"
      values = {}
      provides = {
        app_gateway_id       = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/shared-rg/providers/Microsoft.Network/applicationGateways/gw"
        public_ip            = "20.0.0.2"
        ssl_certificate_name = "wildcard"
      }
    }
    cluster = {
      mode   = "existing"
      values = {}
      provides = {
        cluster_name           = "shared-aks"
        cluster_id             = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/shared-rg/providers/Microsoft.ContainerService/managedClusters/shared-aks"
        cluster_endpoint       = "https://shared.hcp.westus2.azmk8s.io:443"
        cluster_ca_certificate = "Y2E="
      }
    }
    storage = {
      mode   = "existing"
      values = {}
      provides = {
        account_name        = "sharednfs"
        resource_group_name = "storage-rg"
        backend_share_name  = "hd-backend"
      }
    }
    dns     = { mode = "external", values = {}, provides = {} }
    secrets = {}
  }

  assert {
    condition     = length(azurerm_resource_group.this) == 0 && length(module.network) == 0 && length(module.gateway) == 0 && length(module.aks) == 0 && length(module.files) == 0 && length(module.dns) == 0
    error_message = "adopt modes must not create anything"
  }

  assert {
    condition     = output.resource_group_name == "shared-rg" && output.cluster_name == "shared-aks" && output.ssl_certificate_name == "wildcard"
    error_message = "adopted values should pass through to the outputs"
  }

  assert {
    condition     = output.storage_account_name == "sharednfs" && output.storage_resource_group_name == "storage-rg" && output.backend_share_gib == 100
    error_message = "adopted storage should pass through, with default share sizes"
  }

  assert {
    condition     = output.dns_records == [{ name = "helpdesk.example.com", type = "A", value = "20.0.0.2" }, { name = "xterm.example.com", type = "A", value = "20.0.0.2" }]
    error_message = "dns_records should list A records for both hosts"
  }
}

run "dns_external" {
  command = plan

  variables {
    dns = { mode = "external", values = {}, provides = {} }
  }

  assert {
    condition     = length(module.dns) == 0 && output.dns_mode == "external"
    error_message = "external mode should create no DNS records"
  }
}

run "gateway_needs_certificate" {
  command = plan

  variables {
    secrets = {}
  }

  expect_failures = [var.gateway]
}

run "gateway_key_vault_certificate" {
  command = plan

  variables {
    secrets = {}
    gateway = {
      mode = "create"
      values = {
        key_vault_secret_id   = "https://kv.vault.azure.net/secrets/helpdesk-tls"
        key_vault_identity_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/acme-rg/providers/Microsoft.ManagedIdentity/userAssignedIdentities/appgw"
      }
      provides = {}
    }
  }

  assert {
    condition     = length(module.gateway) == 1
    error_message = "a Key Vault certificate should replace the PFX"
  }
}

run "azure_dns_requires_zone" {
  command = plan

  variables {
    dns = { mode = "azure_dns", values = {}, provides = {} }
  }

  expect_failures = [var.dns]
}

run "rejects_unknown_mode" {
  command = plan

  variables {
    network = { mode = "adopt", values = {}, provides = {} }
  }

  expect_failures = [var.network]
}
