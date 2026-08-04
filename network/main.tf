resource "azurerm_resource_group" "main" {
  name     = "rg-${var.application_name}-${var.environment_name}"
  location = var.region
  tags     = local.tags
}

locals {
  public_address_space  = cidrsubnet(var.base_address_space, 2, 0)
  private_address_space = cidrsubnet(var.base_address_space, 2, 1)
  // Quarter 2 is subdivided into small slices for delegated services (indexes 8-11 of a /4 split); quarter 3 is untouched reserve
  data_address_space = cidrsubnet(var.base_address_space, 4, 8)
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
  destination_port_range      = "*"
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

// Data subnet: delegated to PostgreSQL flexible servers (exclusive to them by Azure rule)
resource "azurerm_subnet" "data_subnet" {
  name                 = "snet-data"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [local.data_address_space]
  service_endpoints    = ["Microsoft.Storage"]

  delegation {
    name = "postgres-flexible-server"
    service_delegation {
      name    = "Microsoft.DBforPostgreSQL/flexibleServers"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

resource "azurerm_network_security_group" "data_nsg" {
  name                = "nsg-${var.application_name}-data"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.tags
}

resource "azurerm_network_security_rule" "data_nsg_allow_postgres_inbound" {
  name                        = "allow-postgres-inbound"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "5432"
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.data_nsg.name
}

// Flexible server needs outbound HTTPS to Azure Storage (backups); allow it before denying internet
resource "azurerm_network_security_rule" "data_nsg_allow_storage_outbound" {
  name                        = "allow-storage-outbound"
  priority                    = 100
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "*"
  destination_address_prefix  = "Storage"
  resource_group_name         = azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.data_nsg.name
}

resource "azurerm_network_security_rule" "data_nsg_deny_internet_outbound" {
  name                        = "deny-internet-outbound"
  priority                    = 110
  direction                   = "Outbound"
  access                      = "Deny"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "Internet"
  resource_group_name         = azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.data_nsg.name
}

resource "azurerm_subnet_network_security_group_association" "data_subnet_security_group" {
  subnet_id                 = azurerm_subnet.data_subnet.id
  network_security_group_id = azurerm_network_security_group.data_nsg.id
}

// Private DNS for PostGreSQL flexible servers
resource "azurerm_private_dns_zone" "postgres_dns_zone" {
  name                = "${var.environment_name}.raffalab.postgres.database.azure.com"
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "main" {
  name                  = "link-postgres-dns-${var.environment_name}"
  private_dns_zone_name = azurerm_private_dns_zone.postgres_dns_zone.name
  resource_group_name   = azurerm_resource_group.main.name
  virtual_network_id    = azurerm_virtual_network.main.id
  tags                  = local.tags
}
