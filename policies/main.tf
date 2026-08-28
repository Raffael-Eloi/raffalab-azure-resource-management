data "azurerm_subscription" "current" {}

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
  allowed_locations   = [var.region1, var.region2]
  required_tags       = ["environment", "project", "owner", "managed_by", "cost_center"]
}

data "azurerm_policy_definition_built_in" "require_tag_on_resources" {
  display_name = "Require a tag on resources"
}

data "azurerm_policy_definition_built_in" "require_tag_on_resource_groups" {
  display_name = "Require a tag on resource groups"
}

data "azurerm_policy_definition_built_in" "allowed_locations" {
  display_name = "Allowed locations"
}

data "azurerm_policy_definition_built_in" "allowed_locations_resource_groups" {
  display_name = "Allowed locations for resource groups"
}

resource "azurerm_management_group_policy_set_definition" "baseline" {
  name                = "baseline-governance"
  policy_type         = "Custom"
  display_name        = "RaffaLab Baseline Governance"
  description         = "Requires the standard tag set on all resources and resource groups, and restricts deployments to the approved region."
  management_group_id = local.management_group_id
  metadata = jsonencode({
    category = "Governance"
  })

  dynamic "policy_definition_reference" {
    for_each = local.required_tags
    content {
      policy_definition_id = data.azurerm_policy_definition_built_in.require_tag_on_resources.id
      reference_id         = "require-tag-resource-${policy_definition_reference.value}"
      parameter_values = jsonencode({
        tagName = { value = policy_definition_reference.value }
      })
    }
  }

  dynamic "policy_definition_reference" {
    for_each = local.required_tags
    content {
      policy_definition_id = data.azurerm_policy_definition_built_in.require_tag_on_resource_groups.id
      reference_id         = "require-tag-rg-${policy_definition_reference.value}"
      parameter_values = jsonencode({
        tagName = { value = policy_definition_reference.value }
      })
    }
  }

  policy_definition_reference {
    policy_definition_id = data.azurerm_policy_definition_built_in.allowed_locations.id
    reference_id         = "allowed-locations-resources"
    parameter_values = jsonencode({
      listOfAllowedLocations = { value = local.allowed_locations }
    })
  }

  policy_definition_reference {
    policy_definition_id = data.azurerm_policy_definition_built_in.allowed_locations_resource_groups.id
    reference_id         = "allowed-locations-resource-groups"
    parameter_values = jsonencode({
      listOfAllowedLocations = { value = local.allowed_locations }
    })
  }
}

resource "azurerm_management_group_policy_assignment" "baseline" {
  name                 = "baseline-governance"
  management_group_id  = local.management_group_id
  policy_definition_id = azurerm_management_group_policy_set_definition.baseline.id
  display_name         = "RaffaLab Baseline Governance"
  description          = azurerm_management_group_policy_set_definition.baseline.description
  enforce              = true

  not_scopes = [
    "${data.azurerm_subscription.current.id}/resourceGroups/NetworkWatcherRG",
  ]

  non_compliance_message {
    content = "This resource violates the RaffaLab Baseline Governance initiative. See the specific message below for what to fix."
  }

  dynamic "non_compliance_message" {
    for_each = local.required_tags
    content {
      content                        = "This resource is missing the required '${non_compliance_message.value}' tag."
      policy_definition_reference_id = "require-tag-resource-${non_compliance_message.value}"
    }
  }

  dynamic "non_compliance_message" {
    for_each = local.required_tags
    content {
      content                        = "This resource group is missing the required '${non_compliance_message.value}' tag."
      policy_definition_reference_id = "require-tag-rg-${non_compliance_message.value}"
    }
  }

  non_compliance_message {
    content                        = "Resources may only be deployed to ${var.region1} or ${var.region2}."
    policy_definition_reference_id = "allowed-locations-resources"
  }

  non_compliance_message {
    content                        = "Resource groups may only be created in ${var.region1} or ${var.region2}."
    policy_definition_reference_id = "allowed-locations-resource-groups"
  }
}
