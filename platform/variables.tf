variable "deployment" {
  description = "Deployment identity: { name, region, host, xterm_host, subscription_id }"
  type = object({
    name            = string
    region          = string
    host            = string
    xterm_host      = string
    subscription_id = string
  })

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,14}[a-z0-9]$", var.deployment.name))
    error_message = "deployment.name must be 3-16 chars: lowercase letters, digits and hyphens, starting with a letter."
  }
}

# Each layer: { mode, values, provides }
#   mode     "create" runs the module; "existing" adopts (module count = 0).
#   values   module arguments, read with try(var.<layer>.values.<name>, null)
#   provides outputs of the adopted resource, used when the module is not created.
# dns modes: "azure_dns" (A records in an Azure DNS zone) | "external" (you create them).
variable "resource_group" {
  description = "Resource group layer. values: name. provides (existing): name"
  type        = any

  validation {
    condition     = contains(["create", "existing"], try(var.resource_group.mode, ""))
    error_message = "resource_group.mode must be \"create\" or \"existing\"."
  }
}

variable "network" {
  description = "VNet layer"
  type        = any

  validation {
    condition     = contains(["create", "existing"], try(var.network.mode, ""))
    error_message = "network.mode must be \"create\" or \"existing\"."
  }
}

variable "gateway" {
  description = "Application Gateway layer (public entry point and TLS certificate)"
  type        = any

  validation {
    condition     = contains(["create", "existing"], try(var.gateway.mode, ""))
    error_message = "gateway.mode must be \"create\" or \"existing\"."
  }

  validation {
    condition = try(var.gateway.mode, "") != "create" || length(try(var.gateway.values.key_vault_secret_id, "")) > 0 || (
      length(lookup(var.secrets, "tls_pfx_base64", "")) > 0 && length(lookup(var.secrets, "tls_pfx_password", "")) > 0
    )
    error_message = "gateway mode \"create\" needs a TLS certificate: secrets.tls_pfx_base64 and secrets.tls_pfx_password, or gateway.values.key_vault_secret_id."
  }
}

variable "cluster" {
  description = "AKS cluster layer"
  type        = any

  validation {
    condition     = contains(["create", "existing"], try(var.cluster.mode, ""))
    error_message = "cluster.mode must be \"create\" or \"existing\"."
  }
}

variable "storage" {
  description = "Azure Files NFS layer"
  type        = any

  validation {
    condition     = contains(["create", "existing"], try(var.storage.mode, ""))
    error_message = "storage.mode must be \"create\" or \"existing\"."
  }
}

variable "dns" {
  description = "DNS layer"
  type        = any

  validation {
    condition     = contains(["azure_dns", "external"], try(var.dns.mode, ""))
    error_message = "dns.mode must be \"azure_dns\" or \"external\"."
  }

  validation {
    condition     = try(var.dns.mode, "") != "azure_dns" || (length(try(var.dns.values.zone_name, "")) > 0 && length(try(var.dns.values.zone_resource_group_name, "")) > 0)
    error_message = "dns mode \"azure_dns\" requires values.zone_name and values.zone_resource_group_name."
  }
}

variable "secrets" {
  description = "Platform secrets: tls_pfx_base64 (base64 of the certificate PFX) and tls_pfx_password. Pass as TF_VAR_secrets."
  type        = map(string)
  default     = {}
  sensitive   = true
}

variable "common_tags" {
  description = "Tags applied to all resources"
  type        = map(string)
  default     = {}
}
