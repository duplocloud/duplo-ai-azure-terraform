terraform {
  required_version = ">= 1.10.0"

  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

# Kubernetes access with an Entra ID token (AKS local accounts are disabled). The endpoint and
# CA come from the platform root's state. The token is fetched by the kubelogin exec plugin, or,
# with kube_login = "token", read by both providers from the KUBE_TOKEN environment variable (for
# automation that mints the token itself and has no kubelogin binary). An environment value is not saved in the plan, so a fresh token at apply
# time does not invalidate a saved plan the way a variable would.
locals {
  # Microsoft's fixed application ID of the AKS Entra ID server, the same in every tenant.
  aks_server_id = "6dae42f8-4368-4678-94ff-3960e28e3630"
  use_kubelogin = var.kube_login != "token"
  kubelogin_args = concat(
    ["get-token", "--login", var.kube_login, "--server-id", local.aks_server_id],
    var.kube_login == "spn" ? ["--use-azurerm-env-vars"] : [],
  )
}

provider "helm" {
  kubernetes {
    host                   = local.platform.cluster_endpoint
    cluster_ca_certificate = base64decode(local.platform.cluster_ca_certificate)

    dynamic "exec" {
      for_each = local.use_kubelogin ? [1] : []
      content {
        api_version = "client.authentication.k8s.io/v1beta1"
        command     = "kubelogin"
        args        = local.kubelogin_args
      }
    }
  }
}

provider "kubernetes" {
  host                   = local.platform.cluster_endpoint
  cluster_ca_certificate = base64decode(local.platform.cluster_ca_certificate)

  dynamic "exec" {
    for_each = local.use_kubelogin ? [1] : []
    content {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "kubelogin"
      args        = local.kubelogin_args
    }
  }
}
