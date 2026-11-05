variable "name" {
  description = "Name prefix for the network resources"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "resource_group_name" {
  description = "Resource group for the network resources"
  type        = string
}

variable "vnet_cidr" {
  description = "VNet address space"
  type        = string
  default     = "10.40.0.0/16"
  nullable    = false
}

variable "aks_nodes_cidr" {
  description = "Subnet for the AKS nodes"
  type        = string
  default     = "10.40.0.0/22"
  nullable    = false
}

variable "app_gateway_cidr" {
  description = "Subnet for the Application Gateway; /24 or smaller (Azure CNI Overlay requirement)"
  type        = string
  default     = "10.40.4.0/24"
  nullable    = false

  validation {
    condition     = can(cidrhost(var.app_gateway_cidr, 0)) && tonumber(split("/", var.app_gateway_cidr)[1]) >= 24
    error_message = "app_gateway_cidr must be a valid IPv4 CIDR of /24 or smaller."
  }
}

variable "private_endpoints_cidr" {
  description = "Subnet for private endpoints (Azure Files NFS)"
  type        = string
  default     = "10.40.5.0/27"
  nullable    = false
}

variable "app_gateway_allowed_source_prefixes" {
  description = "Sources allowed to reach the Application Gateway on 80/443: a single service tag (default Internet) or a list of CIDRs"
  type        = list(string)
  default     = ["Internet"]
  nullable    = false

  validation {
    condition     = length(var.app_gateway_allowed_source_prefixes) > 0
    error_message = "app_gateway_allowed_source_prefixes must not be empty."
  }
}

variable "nat_idle_timeout_minutes" {
  description = "NAT gateway idle timeout in minutes"
  type        = number
  default     = 4
  nullable    = false
}

variable "tags" {
  description = "Tags applied to all resources"
  type        = map(string)
  default     = {}
  nullable    = false
}
