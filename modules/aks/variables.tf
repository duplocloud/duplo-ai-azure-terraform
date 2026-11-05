variable "cluster_name" {
  description = "Name of the AKS cluster"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "resource_group_name" {
  description = "Resource group for the cluster"
  type        = string
}

variable "resource_group_id" {
  description = "Resource group ID (the ingress controller gets Reader on it)"
  type        = string
}

variable "vnet_id" {
  description = "VNet ID (the control plane identity gets Network Contributor on it)"
  type        = string
}

variable "aks_subnet_id" {
  description = "Subnet for the nodes"
  type        = string
}

variable "app_gateway_id" {
  description = "Application Gateway the AGIC add-on manages"
  type        = string
}

variable "app_gateway_subnet_id" {
  description = "Application Gateway subnet ID"
  type        = string
}

variable "app_gateway_identity_id" {
  description = "User-assigned identity of the gateway, if it has one (Key Vault certificate)"
  type        = string
  default     = ""
  nullable    = false
}

variable "nat_public_ip" {
  description = "NAT egress IP, added to the API allowlist when the allowlist is used"
  type        = string
  default     = ""
  nullable    = false
}

variable "kubernetes_version" {
  description = "Kubernetes version, e.g. 1.33. Null uses the AKS default."
  type        = string
  default     = null
}

variable "sku_tier" {
  description = "AKS control plane tier: Free, Standard (uptime SLA) or Premium"
  type        = string
  default     = "Standard"
  nullable    = false

  validation {
    condition     = contains(["Free", "Standard", "Premium"], var.sku_tier)
    error_message = "sku_tier must be Free, Standard or Premium."
  }
}

variable "node_vm_size" {
  description = "VM size of the nodes (x86-64, at least 4 vCPU / 16 GiB)"
  type        = string
  default     = "Standard_D4s_v5"
  nullable    = false
}

variable "node_count" {
  description = "Number of nodes (the minimum when autoscaling)"
  type        = number
  default     = 3
  nullable    = false

  validation {
    condition     = var.node_count >= 3
    error_message = "node_count must be at least 3."
  }
}

variable "node_autoscaling" {
  description = "Enable the cluster autoscaler"
  type        = bool
  default     = false
  nullable    = false
}

variable "node_max_count" {
  description = "Maximum number of nodes when autoscaling"
  type        = number
  default     = 5
  nullable    = false
}

variable "node_zones" {
  description = "Availability zones for the nodes. Use [] in regions without zones."
  type        = list(string)
  default     = ["1", "2", "3"]
  nullable    = false
}

variable "node_os_sku" {
  description = "Node OS: Ubuntu or AzureLinux3"
  type        = string
  default     = "Ubuntu"
  nullable    = false
}

variable "node_disk_size" {
  description = "OS disk size in GB"
  type        = number
  default     = 128
  nullable    = false
}

variable "api_authorized_ip_ranges" {
  description = "IPv4 CIDRs allowed to reach the Kubernetes API (include the machine running Terraform). Empty allows any address."
  type        = list(string)
  default     = []
  nullable    = false

  validation {
    condition     = alltrue([for c in var.api_authorized_ip_ranges : can(cidrhost(c, 0))])
    error_message = "api_authorized_ip_ranges must contain IPv4 CIDRs such as 203.0.113.10/32."
  }
}

variable "admin_group_object_ids" {
  description = "Entra ID groups granted cluster admin"
  type        = list(string)
  default     = []
  nullable    = false
}

variable "additional_admin_principal_ids" {
  description = "Extra users, groups or service principals (object IDs) granted cluster admin"
  type        = list(string)
  default     = []
  nullable    = false
}

variable "grant_deployer_cluster_admin" {
  description = "Grant the identity running Terraform cluster admin (needed to apply the app root)"
  type        = bool
  default     = true
  nullable    = false
}

variable "pod_cidr" {
  description = "Overlay pod CIDR; must not overlap the VNet or service CIDR"
  type        = string
  default     = "192.168.0.0/16"
  nullable    = false
}

variable "service_cidr" {
  description = "Kubernetes service CIDR"
  type        = string
  default     = "172.16.0.0/16"
  nullable    = false
}

variable "dns_service_ip" {
  description = "Cluster DNS service IP inside service_cidr"
  type        = string
  default     = "172.16.0.10"
  nullable    = false
}

variable "automatic_upgrade_channel" {
  description = "AKS automatic upgrade channel"
  type        = string
  default     = "patch"
  nullable    = false
}

variable "node_os_upgrade_channel" {
  description = "Node OS upgrade channel"
  type        = string
  default     = "NodeImage"
  nullable    = false
}

variable "azure_policy_enabled" {
  description = "Azure Policy add-on. Set to the cluster's actual value when subscription governance manages it."
  type        = bool
  default     = false
  nullable    = false
}

variable "microsoft_defender_log_analytics_workspace_id" {
  description = "Log Analytics workspace of the Microsoft Defender profile, when subscription governance enables Defender. Empty means no profile."
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
