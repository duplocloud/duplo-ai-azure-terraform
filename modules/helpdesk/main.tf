locals {
  # Static volume: a Retain PV/PVC pair bound to the Azure Files NFS share. The CSI
  # driver mounts the share through its private endpoint, so AKS needs no storage
  # permissions. The chart mounts this backend claim in the agent pod as well.
  static_volumes = {
    backend = { claim = "${var.release_name}-backend-static", share = var.backend_share_name, size = "${var.backend_share_gib}Gi" }
  }
}

resource "kubernetes_namespace" "this" {
  metadata {
    name = var.namespace
  }

  lifecycle {
    ignore_changes = [metadata[0].labels, metadata[0].annotations]
  }
}

resource "kubernetes_persistent_volume_v1" "static" {
  for_each = local.static_volumes

  metadata {
    name = "${var.namespace}-${each.value.claim}"
  }

  spec {
    capacity = {
      storage = each.value.size
    }
    access_modes                     = ["ReadWriteMany"]
    volume_mode                      = "Filesystem"
    storage_class_name               = ""
    persistent_volume_reclaim_policy = "Retain"
    mount_options                    = ["nconnect=4", "noresvport", "actimeo=30"]

    claim_ref {
      namespace = var.namespace
      name      = each.value.claim
    }

    persistent_volume_source {
      csi {
        driver        = "file.csi.azure.com"
        volume_handle = "${var.storage_resource_group_name}#${var.storage_account_name}#${each.value.share}"
        volume_attributes = {
          resourceGroup  = var.storage_resource_group_name
          storageAccount = var.storage_account_name
          shareName      = each.value.share
          protocol       = "nfs"
        }
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim_v1" "static" {
  for_each = local.static_volumes

  metadata {
    name      = each.value.claim
    namespace = var.namespace
  }

  spec {
    access_modes       = ["ReadWriteMany"]
    volume_mode        = "Filesystem"
    storage_class_name = ""
    volume_name        = kubernetes_persistent_volume_v1.static[each.key].metadata[0].name

    resources {
      requests = {
        storage = each.value.size
      }
    }
  }

  wait_until_bound = true

  depends_on = [kubernetes_namespace.this]
}
