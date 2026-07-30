data "azurerm_subscription" "current" {}

resource "azurerm_management_group" "main" {
  display_name = "RaffaLabManagementGroup"
}

data "azurerm_subscription" "main" {
  subscription_id = data.azurerm_subscription.current.subscription_id
}

resource "azurerm_management_group_subscription_association" "main" {
  management_group_id = azurerm_management_group.main.id
  subscription_id     = data.azurerm_subscription.main.id
}