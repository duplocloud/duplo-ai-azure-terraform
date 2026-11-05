variable "name" {
  description = "Name prefix for the gateway resources"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "resource_group_name" {
  description = "Resource group for the gateway"
  type        = string
}

variable "subnet_id" {
  description = "Dedicated Application Gateway subnet ID"
  type        = string
}

variable "sku_name" {
  description = "Application Gateway SKU: Standard_v2 or WAF_v2"
  type        = string
  default     = "Standard_v2"
  nullable    = false

  validation {
    condition     = contains(["Standard_v2", "WAF_v2"], var.sku_name)
    error_message = "sku_name must be Standard_v2 or WAF_v2 (the only SKUs AGIC supports)."
  }
}

variable "waf_mode" {
  description = "WAF mode when sku_name is WAF_v2: Detection or Prevention"
  type        = string
  default     = "Prevention"
  nullable    = false

  validation {
    condition     = contains(["Detection", "Prevention"], var.waf_mode)
    error_message = "waf_mode must be Detection or Prevention."
  }
}

variable "min_capacity" {
  description = "Minimum autoscale instance count"
  type        = number
  default     = 2
  nullable    = false
}

variable "max_capacity" {
  description = "Maximum autoscale instance count"
  type        = number
  default     = 3
  nullable    = false
}

variable "zones" {
  description = "Availability zones for the gateway and its public IP. Use [] in regions without zones."
  type        = list(string)
  default     = ["1", "2", "3"]
  nullable    = false
}

variable "ssl_policy_name" {
  description = "Predefined TLS policy"
  type        = string
  default     = "AppGwSslPolicy20220101S"
  nullable    = false
}

variable "ssl_certificate_name" {
  description = "Name of the gateway TLS certificate; the Helm ingress references it"
  type        = string
  default     = "helpdesk-tls"
  nullable    = false
}

variable "ssl_certificate_pfx_base64" {
  description = "Base64-encoded PFX with the certificate chain and private key"
  type        = string
  default     = ""
  nullable    = false
  sensitive   = true
}

variable "ssl_certificate_password" {
  description = "Password of the PFX"
  type        = string
  default     = ""
  nullable    = false
  sensitive   = true
}

variable "ssl_certificate_provided" {
  description = "Whether a PFX was supplied (kept separate so the check is not itself sensitive)"
  type        = bool
  default     = false
  nullable    = false
}

variable "key_vault_secret_id" {
  description = "Use a Key Vault certificate instead of a PFX: its versionless secret ID"
  type        = string
  default     = ""
  nullable    = false
}

variable "key_vault_identity_id" {
  description = "User-assigned identity the gateway uses to read key_vault_secret_id (needs Key Vault Secrets User)"
  type        = string
  default     = ""
  nullable    = false
}

variable "tags" {
  description = "Tags applied to all resources"
  type        = map(string)
  default     = {}
  nullable    = false
}
