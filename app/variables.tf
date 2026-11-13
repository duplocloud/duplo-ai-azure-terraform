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
# values: local_admin_email (required; sign-in is the local admin only, who is also the
#   super user), and optional azure_base_url, chart_version, namespace, release_name,
#   xterm_enabled, mongodb_backup_enabled, helpdesk_mcp_enabled, backend_image_tag,
#   frontend_image_tag, slack_*
variable "helpdesk" {
  description = "Helpdesk layer"
  type        = any

  validation {
    condition     = try(var.helpdesk.mode, "") == "create"
    error_message = "helpdesk.mode must be \"create\"."
  }

  # Google and Microsoft sign-in were removed (SSO is a Helpdesk setting after deployment): a
  # deployment that set them must move to the local admin instead of silently losing them.
  validation {
    condition     = try(coalesce(var.helpdesk.values.login_method, "local"), "local") == "local"
    error_message = "Google and Microsoft sign-in are no longer supported. Remove helpdesk.values.login_method (and the OAuth client values), and set helpdesk.values.local_admin_email and secrets.local_admin_password."
  }

  validation {
    condition     = can(regex("^[^@\\s,]+@[^@\\s,]+\\.[^@\\s,]+$", try(trimspace(var.helpdesk.values.local_admin_email), "")))
    error_message = "Helpdesk needs helpdesk.values.local_admin_email, an email address (the admin who signs in first)."
  }

  validation {
    condition     = length(try(var.helpdesk.values.azure_base_url, "")) == 0 || length(lookup(var.secrets, "azure_api_key", "")) > 0
    error_message = "secrets.azure_api_key is required when helpdesk.values.azure_base_url is set."
  }
}

variable "secrets" {
  description = "User-entered secrets. Keys: licensing_token, azure_api_key, local_admin_password, slack_app_token, slack_bot_token"
  type        = map(string)
  default     = {}
  sensitive   = true

  validation {
    condition     = length(lookup(var.secrets, "local_admin_password", "")) > 0
    error_message = "secrets.local_admin_password is required (the local admin's password)."
  }
}

variable "common_tags" {
  description = "Tags applied to all resources"
  type        = map(string)
  default     = {}
}
