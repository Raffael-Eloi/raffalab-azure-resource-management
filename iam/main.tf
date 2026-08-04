data "azuread_client_config" "current" {}

data "terraform_remote_state" "management_group" {
  backend = "azurerm"
  config = {
    resource_group_name  = "rg-tfstates-${var.environment_name}"
    storage_account_name = "straffalab${var.environment_name}"
    container_name       = "tfstates"
    key                  = "management_group.tfstate"
  }
}

locals {
  management_group_id = data.terraform_remote_state.management_group.outputs.management_group_id
}

// Platform personas
resource "azuread_group" "platform_admins" {
  display_name     = "grp-platform-admins-${var.environment_name}"
  description      = "Platform operators: full control over the raffalab management group (network, policies, governance, state infra)."
  security_enabled = true
  owners           = [data.azuread_client_config.current.object_id]
}

resource "azuread_group" "readers" {
  display_name     = "grp-readers-${var.environment_name}"
  description      = "Read-only visibility over everything under the raffalab management group."
  security_enabled = true
  owners           = [data.azuread_client_config.current.object_id]
}

// Workload personas
resource "azuread_group" "data_admins" {
  display_name     = "grp-data-admins-${var.environment_name}"
  description      = "Operators of the data workload. Contributor on rg-data-${var.environment_name} is assigned by the data module to avoid a circular dependency between states."
  security_enabled = true
  owners           = [data.azuread_client_config.current.object_id]
}

// Data-plane only: PostgreSQL Entra administrators. Deliberately holds no Azure RBAC
// role — being DB admin must not imply any right to change Azure resources.
resource "azuread_group" "psql_admins" {
  display_name     = "grp-psql-admins-${var.environment_name}"
  description      = "Microsoft Entra administrators of the PostgreSQL flexible server (data plane only)."
  security_enabled = true
  owners           = [data.azuread_client_config.current.object_id]
}

// Management-group-scope role assignments
resource "azurerm_role_assignment" "platform_admins_owner" {
  scope                = local.management_group_id
  role_definition_name = "Owner"
  principal_id         = azuread_group.platform_admins.object_id
}

resource "azurerm_role_assignment" "readers_reader" {
  scope                = local.management_group_id
  role_definition_name = "Reader"
  principal_id         = azuread_group.readers.object_id
}
