output "disk_immediate_storage_class_name" {
  description = "Managed-disk storage class with Immediate binding (the MongoDB backup volume)"
  value       = kubernetes_storage_class_v1.disk_immediate.metadata[0].name
}
