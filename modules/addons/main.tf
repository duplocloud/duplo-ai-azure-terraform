# The ingress controller (AGIC) and the Azure Disk / Azure Files CSI drivers are
# AKS add-ons enabled by the cluster layer, so only storage classes live here.

# Azure Disk class with Immediate binding for the MongoDB backup volume. The
# backup PVC is mounted only by the nightly CronJob; with the WaitForFirstConsumer
# built-in classes it stays Pending until the first run and the Helm install
# times out waiting for it.
resource "kubernetes_storage_class_v1" "disk_immediate" {
  metadata {
    name = var.disk_immediate_storage_class_name
  }

  storage_provisioner    = "disk.csi.azure.com"
  reclaim_policy         = "Delete"
  volume_binding_mode    = "Immediate"
  allow_volume_expansion = true

  parameters = {
    skuName = var.disk_sku
  }
}
