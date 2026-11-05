variable "hostnames" {
  description = "Hostnames to point at the gateway"
  type        = list(string)
}

variable "ip_address" {
  description = "Gateway public IP"
  type        = string
}

variable "zone_name" {
  description = "Existing Azure DNS zone (e.g. example.com) that contains the hostnames"
  type        = string
  default     = ""
  nullable    = false
}

variable "zone_resource_group_name" {
  description = "Resource group of the Azure DNS zone"
  type        = string
  default     = ""
  nullable    = false
}

variable "ttl" {
  description = "Record TTL in seconds"
  type        = number
  default     = 300
  nullable    = false
}

variable "tags" {
  description = "Tags applied to all resources"
  type        = map(string)
  default     = {}
  nullable    = false
}
