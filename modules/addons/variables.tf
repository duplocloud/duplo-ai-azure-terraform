variable "disk_immediate_storage_class_name" {
  description = "Name of the Immediate-binding Azure Disk storage class (MongoDB backup volume)"
  type        = string
  default     = "helpdesk-disk-immediate"
  nullable    = false
}

variable "disk_sku" {
  description = "Azure Disk SKU of that storage class"
  type        = string
  default     = "StandardSSD_LRS"
  nullable    = false
}
