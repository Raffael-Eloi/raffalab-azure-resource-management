data "terraform_remote_state" "network" {
  backend = "azurerm"
  config = {
    resource_group_name  = "rg-tfstates-${var.environment_name}"
    storage_account_name = "straffalab${var.environment_name}"
    container_name       = "tfstates"
    key                  = "network.tfstate"
  }
}

data "terraform_remote_state" "iam" {
  backend = "azurerm"
  config = {
    resource_group_name  = "rg-tfstates-${var.environment_name}"
    storage_account_name = "straffalab${var.environment_name}"
    container_name       = "tfstates"
    key                  = "iam.tfstate"
  }
}

data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "main" {
  name     = "rg-${var.application_name}-${var.environment_name}"
  location = var.region
  tags     = local.tags
}

resource "azurerm_postgresql_flexible_server" "postgres_server" {
  name                          = "psql-${var.application_name}-${var.environment_name}"
  resource_group_name           = azurerm_resource_group.main.name
  location                      = azurerm_resource_group.main.location
  version                       = "18"
  delegated_subnet_id           = data.terraform_remote_state.network.outputs.data_subnet_id
  private_dns_zone_id           = data.terraform_remote_state.network.outputs.postgres_dns_zone_id
  public_network_access_enabled = false
  zone                          = "1"

  authentication {
    active_directory_auth_enabled = true
    password_auth_enabled         = false
    tenant_id                     = data.azurerm_client_config.current.tenant_id
  }

  storage_mb   = 32768
  storage_tier = "P4"

  sku_name = "B_Standard_B1ms"
  tags     = local.tags
}

// Workload operators: Contributor over this module's RG (assigned here, not in iam/, to avoid a state cycle)
resource "azurerm_role_assignment" "data_admins_contributor" {
  scope                = azurerm_resource_group.main.id
  role_definition_name = "Contributor"
  principal_id         = data.terraform_remote_state.iam.outputs.data_admins_group_id
}

// Entra-only auth: this group is the server's administrator (data plane).
resource "azurerm_postgresql_flexible_server_active_directory_administrator" "psql_admins" {
  server_name         = azurerm_postgresql_flexible_server.postgres_server.name
  resource_group_name = azurerm_resource_group.main.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  object_id           = data.terraform_remote_state.iam.outputs.psql_admins_group_id
  principal_name      = data.terraform_remote_state.iam.outputs.psql_admins_group_name
  principal_type      = "Group"
}
