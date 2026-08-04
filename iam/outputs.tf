output "platform_admins_group_id" {
  value = azuread_group.platform_admins.object_id
}

output "readers_group_id" {
  value = azuread_group.readers.object_id
}

output "data_admins_group_id" {
  value = azuread_group.data_admins.object_id
}

output "psql_admins_group_id" {
  value = azuread_group.psql_admins.object_id
}

output "psql_admins_group_name" {
  value = azuread_group.psql_admins.display_name
}
