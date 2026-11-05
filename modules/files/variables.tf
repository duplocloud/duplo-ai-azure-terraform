variable "name" {
  description = "Name prefix for the storage resources"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "resource_group_name" {
  description = "Resource group for the storage account"
  type        = string
}

variable "vnet_id" {
  description = "VNet linked to the privatelink.file.core.windows.net zone"
  type        = string
}

variable "private_endpoint_subnet_id" {
  description = "Subnet for the storage private endpoint"
  type        = string
}

variable "account_name" {
  description = "Storage account name (3-24 lowercase letters and digits). Empty generates one."
  type        = string
  default     = ""
  nullable    = false

  validation {
    condition     = var.account_name == "" || can(regex("^[a-z0-9]{3,24}$", var.account_name))
    error_message = "account_name must be 3-24 lowercase letters and digits."
  }
}

variable "replication" {
  description = "Replication: LRS or ZRS"
  type        = string
  default     = "LRS"
  nullable    = false

  validation {
    condition     = contains(["LRS", "ZRS"], var.replication)
    error_message = "replication must be LRS or ZRS."
  }
}

variable "backend_quota_gib" {
  description = "Size of the share in GiB (Premium minimum 100)"
  type        = number
  default     = 100
  nullable    = false

  validation {
    condition     = var.backend_quota_gib >= 100
    error_message = "backend_quota_gib must be at least 100."
  }
}

variable "tags" {
  description = "Tags applied to all resources"
  type        = map(string)
  default     = {}
  nullable    = false
}
