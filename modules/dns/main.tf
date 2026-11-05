locals {
  zone = lower(var.zone_name)

  # host => record name relative to the zone ("@" for the apex)
  records = {
    for host in distinct(compact(var.hostnames)) :
    host => host == local.zone ? "@" : trimsuffix(host, ".${local.zone}")
  }
}

resource "azurerm_dns_a_record" "this" {
  for_each = local.records

  name                = each.value
  zone_name           = var.zone_name
  resource_group_name = var.zone_resource_group_name
  ttl                 = var.ttl
  records             = [var.ip_address]
  tags                = var.tags

  lifecycle {
    precondition {
      condition     = each.key == local.zone || endswith(each.key, ".${local.zone}")
      error_message = "Hostname ${each.key} is not inside the DNS zone ${var.zone_name}."
    }
  }
}
