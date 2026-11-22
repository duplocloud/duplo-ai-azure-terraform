variable "region" {
  description = "Azure region (rendered as config.infraRegion)"
  type        = string
}

variable "release_name" {
  description = "Helm release name"
  type        = string
  default     = "helpdesk"
  nullable    = false
}

variable "namespace" {
  description = "Kubernetes namespace for the release"
  type        = string
  default     = "helpdesk"
  nullable    = false
}

variable "chart_version" {
  description = "Helm chart version"
  type        = string
  default     = "0.2.24-hotfix.1"
  nullable    = false
}

variable "helpdesk_dns" {
  description = "DuploCloud AI DNS hostname (e.g. duplo-ai.example.com)"
  type        = string
}

variable "helpdesk_xterm_dns" {
  description = "DuploCloud AI xterm DNS hostname"
  type        = string
}

variable "ssl_certificate_name" {
  description = "Application Gateway TLS certificate the ingress uses"
  type        = string
}

# ── Storage ───────────────────────────────────────────────────────────────────
variable "storage_account_name" {
  description = "Azure Files NFS storage account"
  type        = string
}

variable "storage_resource_group_name" {
  description = "Resource group of the storage account"
  type        = string
}

variable "backend_share_name" {
  description = "NFS share for the backend volume (also mounted by the agent)"
  type        = string
}

variable "backend_share_gib" {
  description = "Size of the share in GiB"
  type        = number
}

variable "backup_storage_class_name" {
  description = "Storage class of the MongoDB backup volume (must bind Immediately)"
  type        = string
  default     = "helpdesk-disk-immediate"
  nullable    = false
}

# ── Model ─────────────────────────────────────────────────────────────────────
variable "azure_base_url" {
  description = "Microsoft Foundry Anthropic endpoint, e.g. https://<resource>.services.ai.azure.com/anthropic. Its key is secrets.azure_api_key."
  type        = string
  default     = ""
  nullable    = false
}

# ── Authentication ────────────────────────────────────────────────────────────
# Sign-in is the local admin only; SSO is configured in DuploCloud AI after deployment.
variable "local_admin_email" {
  description = "Email of the local admin, who signs in first with secrets.local_admin_password and is the only super user"
  type        = string

  validation {
    condition     = can(regex("^[^@\\s,]+@[^@\\s,]+\\.[^@\\s,]+$", var.local_admin_email))
    error_message = "local_admin_email must be an email address."
  }
}

# ── Secrets (never rendered into the values document) ────────────────────────
variable "secrets" {
  description = "User-entered secrets: licensing_token, azure_api_key, local_admin_password, slack_app_token, slack_bot_token"
  type        = map(string)
  default     = {}
  nullable    = false
  sensitive   = true
}

variable "jwt_shared_secret" {
  description = "JWT shared secret"
  type        = string
  sensitive   = true
}

variable "mongodb_root_password" {
  description = "MongoDB root password"
  type        = string
  sensitive   = true
}

# ── Features ──────────────────────────────────────────────────────────────────
variable "xterm_enabled" {
  description = "Enable the browser terminal (served on the xterm host)"
  type        = bool
  default     = true
  nullable    = false
}

variable "mongodb_backup_enabled" {
  description = "Enable the nightly MongoDB backup CronJob"
  type        = bool
  default     = true
  nullable    = false
}

variable "helpdesk_mcp_enabled" {
  description = "Enable the helpdesk-mcp deployment"
  type        = bool
  default     = true
  nullable    = false
}

variable "backend_image_tag" {
  description = "Override for backend.image.tag. Empty string uses the chart default."
  type        = string
  default     = ""
  nullable    = false
}

variable "frontend_image_tag" {
  description = "Override for frontend.image.tag. Empty string uses the chart default."
  type        = string
  default     = ""
  nullable    = false
}

# ── Slack backend ─────────────────────────────────────────────────────────────
variable "slack_backend_enabled" {
  description = "Enable the Slack backend"
  type        = bool
  default     = false
  nullable    = false
}

variable "slack_backend_image_tag" {
  description = "Slack backend image tag. Empty string uses the chart default."
  type        = string
  default     = ""
  nullable    = false
}

variable "slack_helpdesk_default_agent" {
  description = "Default agent for Slack helpdesk"
  type        = string
  default     = ""
  nullable    = false
}

variable "slack_helpdesk_default_workspace" {
  description = "Default workspace for Slack helpdesk"
  type        = string
  default     = ""
  nullable    = false
}

variable "slack_app_portals" {
  description = "Slack app portals JSON config"
  type        = string
  default     = ""
  nullable    = false
}
