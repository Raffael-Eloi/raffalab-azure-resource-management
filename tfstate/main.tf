locals {
  tags = {
    environment = var.environment_name
    project     = var.application_name
    owner       = var.owner
    managed_by  = var.managed_by
    cost_center = var.cost_center
  }
}

resource "azurerm_resource_group" "main" {
  name     = "rg-${var.application_name}-${var.environment_name}"
  location = var.region
  tags = local.tags
}

resource "azurerm_storage_account" "main" {
  name                     = "straffalab${var.environment_name}"
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  tags = local.tags
}

resource "azurerm_storage_container" "main" {
  name                  = var.application_name
  storage_account_id    = azurerm_storage_account.main.id
  container_access_type = "private"
}
