locals {
  tags = {
    environment = var.environment_name
    project     = var.application_name
    owner       = var.owner
    managed_by  = var.managed_by
    cost_center = var.cost_center
  }
}