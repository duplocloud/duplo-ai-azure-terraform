# Mock-only: the AKS module on its own, which modes.tftest.hcl overrides as a whole. The cluster mock
# fills the computed AGIC identity and kube_config the module reads at plan time; the provider's mock
# expects a configured block's override as an object.
mock_provider "azurerm" {
  mock_resource "azurerm_user_assigned_identity" {
    defaults = { id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/acme-rg/providers/Microsoft.ManagedIdentity/userAssignedIdentities/acme-id" }
  }
  mock_resource "azurerm_kubernetes_cluster" {
    defaults = {
      id                          = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/acme-rg/providers/Microsoft.ContainerService/managedClusters/acme-aks"
      kube_config                 = [{ host = "https://acme-aks.hcp.westus2.azmk8s.io:443", cluster_ca_certificate = "Q0E=", client_certificate = "", client_key = "", password = "", username = "" }]
      ingress_application_gateway = { ingress_application_gateway_identity = [{ object_id = "33333333-3333-3333-3333-333333333333", client_id = "", user_assigned_identity_id = "" }] }
    }
  }
  mock_data "azurerm_client_config" {
    defaults = {
      tenant_id = "11111111-1111-1111-1111-111111111111"
      object_id = "22222222-2222-2222-2222-222222222222"
    }
  }
}

run "aks_node_os_defaults_to_azure_linux" {
  command = plan

  module {
    source = "../modules/aks"
  }

  variables {
    cluster_name          = "acme-aks"
    location              = "westus2"
    resource_group_name   = "acme-rg"
    resource_group_id     = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/acme-rg"
    vnet_id               = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/acme-rg/providers/Microsoft.Network/virtualNetworks/acme-vnet"
    aks_subnet_id         = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/acme-rg/providers/Microsoft.Network/virtualNetworks/acme-vnet/subnets/snet-aks-nodes"
    app_gateway_id        = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/acme-rg/providers/Microsoft.Network/applicationGateways/acme-appgw"
    app_gateway_subnet_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/acme-rg/providers/Microsoft.Network/virtualNetworks/acme-vnet/subnets/snet-appgw"
  }

  assert {
    condition     = azurerm_kubernetes_cluster.this.default_node_pool[0].os_sku == "AzureLinux3"
    error_message = "nodes default to Azure Linux 3: Ubuntu 24.04 denies the agent's bwrap sandbox a user namespace"
  }
}
