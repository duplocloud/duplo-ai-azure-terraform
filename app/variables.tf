variable "deployment" {
  description = "Deployment identity: { name, region, host, xterm_host, account_id }. account_id is the Azure subscription ID (the name AWS and GCP use)"
  type = object({
    name       = string
    region     = string
    host       = string
    xterm_host = string
    account_id = string
  })
}

variable "state" {
  description = "Where the platform root's state lives, in the shape AWS and GCP use: bucket is the storage account name, platform_key the blob name. region is accepted for that shape and not used by azurerm. resource_group_name and container_name default to the names the Cloud Deployment agent creates."
  type = object({
    bucket              = string
    region              = optional(string)
    platform_key        = string
    resource_group_name = optional(string, "duplo-helpdesk-tfstate")
    container_name      = optional(string, "tfstate")
  })
}

# How the Kubernetes and Helm providers get an Entra ID token for AKS (kubelogin):
#   "azurecli" uses your `az login`; "spn" uses the service principal in ARM_CLIENT_ID /
#   ARM_CLIENT_SECRET (or ARM_CLIENT_CERTIFICATE_PATH) / ARM_TENANT_ID; "workloadidentity"
#   and "msi" are for CI runners in Azure. "token" skips kubelogin: the providers read a
#   pre-minted token for the AKS server app (6dae42f8-4368-4678-94ff-3960e28e3630/.default) from
#   the KUBE_TOKEN environment variable.
variable "kube_login" {
  description = "kubelogin login method: azurecli, spn, workloadidentity or msi; token reads KUBE_TOKEN instead"
  type        = string
  default     = "azurecli"

  validation {
    condition     = contains(["azurecli", "spn", "workloadidentity", "msi", "token"], var.kube_login)
    error_message = "kube_login must be one of: azurecli, spn, workloadidentity, msi, token."
  }
}


# addons: { mode = "create" | "existing", values }
#   "create" installs the storage classes; "existing" adopts them (module count = 0).
# values (all optional): disk_immediate_storage_class_name, disk_sku
variable "addons" {
  description = "Cluster add-ons layer"
  type        = any

  validation {
    condition     = contains(["create", "existing"], try(var.addons.mode, ""))
    error_message = "addons.mode must be \"create\" or \"existing\"."
  }
}

# helpdesk: { mode = "create", values }
# values (all optional): login_method (local|google|microsoft, default local),
#   local_admin_email, google_client_id, microsoft_client_id, microsoft_tenant_id,
#   auth_super_users, azure_base_url, chart_version, namespace, release_name,
#   xterm_enabled, mongodb_backup_enabled, helpdesk_mcp_enabled, backend_image_tag,
#   frontend_image_tag, slack_*
variable "helpdesk" {
  description = "Helpdesk layer"
  type        = any

  validation {
    condition     = try(var.helpdesk.mode, "") == "create"
    error_message = "helpdesk.mode must be \"create\"."
  }

  validation {
    condition     = contains(["local", "google", "microsoft"], try(var.helpdesk.values.login_method, "local"))
    error_message = "helpdesk.values.login_method must be one of: local, google, microsoft."
  }

  validation {
    condition     = try(var.helpdesk.values.login_method, "local") != "local" || length(try(var.helpdesk.values.local_admin_email, "")) > 0
    error_message = "helpdesk.values.local_admin_email is required for local login."
  }

  validation {
    condition     = try(var.helpdesk.values.login_method, "local") != "local" || length(lookup(var.secrets, "local_admin_password", "")) > 0
    error_message = "secrets.local_admin_password is required for local login."
  }

  validation {
    condition     = try(var.helpdesk.values.login_method, "local") != "microsoft" || (length(try(var.helpdesk.values.microsoft_client_id, "")) > 0 && length(try(var.helpdesk.values.microsoft_tenant_id, "")) > 0)
    error_message = "helpdesk.values.microsoft_client_id and microsoft_tenant_id are required for microsoft login."
  }

  validation {
    condition     = try(var.helpdesk.values.login_method, "local") != "microsoft" || length(lookup(var.secrets, "microsoft_client_secret", "")) > 0
    error_message = "secrets.microsoft_client_secret is required for microsoft login."
  }

  validation {
    condition     = length(try(var.helpdesk.values.azure_base_url, "")) == 0 || length(lookup(var.secrets, "azure_api_key", "")) > 0
    error_message = "secrets.azure_api_key is required when helpdesk.values.azure_base_url is set."
  }
}

variable "secrets" {
  description = "User-entered secrets. Keys: licensing_token, azure_api_key, local_admin_password, google_client_secret, microsoft_client_secret, slack_app_token, slack_bot_token"
  type        = map(string)
  default     = {}
  sensitive   = true
}

variable "common_tags" {
  description = "Tags applied to all resources"
  type        = map(string)
  default     = {}
}
