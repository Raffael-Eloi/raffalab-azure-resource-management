resource "azurerm_resource_group" "main" {
  name     = "rg-${var.application_name}-${var.environment_name}"
  location = var.region
  tags     = local.tags
}

locals {
  public_address_space  = cidrsubnet(var.base_address_space, 2, 0)
  private_address_space = cidrsubnet(var.base_address_space, 2, 1)
}

resource "azurerm_network_security_group" "public_nsg" {
  name                = "nsg-${var.application_name}-public"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.tags
}

resource "azurerm_network_security_rule" "public_nsg_allow_web_inbound" {
  name                        = "allow-web-inbound"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_ranges     = ["80", "443"]
  source_address_prefix       = "Internet"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.public_nsg.name
}

// Deny RDP (3389) and SSH (22)
// Mgmt => stands for Management
resource "azurerm_network_security_rule" "public_nsg_deny_mgmt_inbound" {
  name                        = "deny-mgmt-inbound"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_ranges     = ["22", "3389"]
  source_address_prefix       = "Internet"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.public_nsg.name
}

resource "azurerm_network_security_rule" "public_nsg_deny_db_inbound" {
  name                        = "deny-db-inbound"
  priority                    = 120
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_ranges     = ["1433", "3306", "5432", "445", "139", "5985", "5986"]
  source_address_prefix       = "Internet"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.public_nsg.name
}

resource "azurerm_network_security_rule" "public_nsg_deny_mgmt_outbound_to_private" {
  name                        = "deny-mgmt-outbound-to-private"
  priority                    = 100
  direction                   = "Outbound"
  access                      = "Deny"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_ranges     = ["22", "3389", "1433", "3306", "5432"]
  source_address_prefix       = "*"
  destination_address_prefix  = local.private_address_space
  resource_group_name         = azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.public_nsg.name
}

resource "azurerm_network_security_group" "private_nsg" {
  name                = "nsg-${var.application_name}-private"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.tags
}

resource "azurerm_network_security_rule" "private_nsg_deny_mgmt_inbound" {
  name                        = "deny-mgmt-inbound"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_ranges     = ["22", "3389"]
  source_address_prefix       = local.public_address_space
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.private_nsg.name
}

resource "azurerm_network_security_rule" "allow_app_and_db_traffic" {
  name                        = "allow-app-and-db-traffic"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_ranges     = ["5432", "8080"]
  source_address_prefix       = local.public_address_space
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.private_nsg.name
}

resource "azurerm_network_security_rule" "deny_internet_outbound" {
  name                        = "deny-internet-outbound"
  priority                    = 120
  direction                   = "Outbound"
  access                      = "Deny"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_ranges     = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "Internet"
  resource_group_name         = azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.private_nsg.name
}

// smb   => Server Message Block (Ports 445 and 139)
// winRM => Windows Remote Management (Ports 5985 and 5986) 
resource "azurerm_network_security_rule" "deny_smb_winrm_inbound" {
  name                        = "deny-smb-winrm-inbound"
  priority                    = 130
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_ranges     = ["445", "139", "5985", "5986"]
  source_address_prefix       = local.public_address_space
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.private_nsg.name
}

resource "azurerm_virtual_network" "main" {
  name                = "vnet-${var.application_name}-${var.environment_name}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  address_space       = [var.base_address_space]
  tags                = local.tags
}

resource "azurerm_subnet" "public_subnet" {
  name                 = "snet-public"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [local.public_address_space]
}

resource "azurerm_subnet_network_security_group_association" "public_subnet_security_group" {
  subnet_id                 = azurerm_subnet.public_subnet.id
  network_security_group_id = azurerm_network_security_group.public_nsg.id
}

resource "azurerm_subnet" "private_subnet" {
  name                 = "snet-private"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [local.private_address_space]
}

resource "azurerm_subnet_network_security_group_association" "private_subnet_security_group" {
  subnet_id                 = azurerm_subnet.private_subnet.id
  network_security_group_id = azurerm_network_security_group.private_nsg.id
}