output "record_fqdns" {
  description = "FQDNs of the A records created"
  value       = [for r in azurerm_dns_a_record.this : r.fqdn]
}
