output "private_subnet_id" {
  value = azurerm_subnet.private_subnet.id
}

output "data_subnet_id" {
  value = azurerm_subnet.data_subnet.id
}

output "postgres_dns_zone_id" {
  value = azurerm_private_dns_zone.postgres_dns_zone.id
}
