variable "subscription_id" {}
variable "client_id" {}
variable "client_secret" {}
variable "tenant_id" {}
variable "location" {
  default = "East US"
}
variable "env_name" {}

# Configure the Microsoft Azure Provider
provider "azurerm" {
  subscription_id = "${var.subscription_id}"
  client_id       = "${var.client_id}"
  client_secret   = "${var.client_secret}"
  tenant_id       = "${var.tenant_id}"
}
# Create a resource group
resource "azurerm_resource_group" "Azure_rg_bosh" {
  name     = "${var.env_name}-rg"
  location = "${var.location}"
}
# Create a virtual network in the Azure_rg_bosh resource group
resource "azurerm_virtual_network" "Azure_bosh_network" {
  name                = "Azure_bosh_network"
  address_space       = ["10.0.0.0/16"]
  location            = "${var.location}"
  resource_group_name = "${azurerm_resource_group.Azure_rg_bosh.name}"
}

resource "azurerm_subnet" "Azure_bosh_subnet" {
  name                 = "Azure_bosh_subnet"
  resource_group_name  = "${azurerm_resource_group.Azure_rg_bosh.name}"
  virtual_network_name = "${azurerm_virtual_network.Azure_bosh_network.name}"
  address_prefix       = "10.0.0.0/24"
}

resource "azurerm_subnet" "Azure_bosh_subnet_2" {
  name                 = "Azure_bosh_subnet_2"
  resource_group_name  = "${azurerm_resource_group.Azure_rg_bosh.name}"
  virtual_network_name = "${azurerm_virtual_network.Azure_bosh_network.name}"
  address_prefix       = "10.0.1.0/24"
}

resource "azurerm_subnet" "Azure_BATs_subnet" {
  name                 = "Azure_BATs_subnet"
  resource_group_name  = "${azurerm_resource_group.Azure_rg_bosh.name}"
  virtual_network_name = "${azurerm_virtual_network.Azure_bosh_network.name}"
  address_prefix       = "10.0.16.0/24"
}

resource "azurerm_subnet" "Azure_BATs_subnet_2" {
  name                 = "Azure_BATs_subnet_2"
  resource_group_name  = "${azurerm_resource_group.Azure_rg_bosh.name}"
  virtual_network_name = "${azurerm_virtual_network.Azure_bosh_network.name}"
  address_prefix       = "10.0.17.0/24"
}

# Create a Storage Account in the Azure_rg_bosh resouce group
resource "azurerm_storage_account" "azureboshsa" {
  name                = "${replace(var.env_name, "-", "")}"
  resource_group_name = "${azurerm_resource_group.Azure_rg_bosh.name}"
  location            = "${var.location}"
  account_type        = "Standard_LRS"
}
# Create a Storage Container for the bosh director
resource "azurerm_storage_container" "azureboshcontainer" {
  name                  = "bosh"
  resource_group_name   = "${azurerm_resource_group.Azure_rg_bosh.name}"
  storage_account_name  = "${azurerm_storage_account.azureboshsa.name}"
  container_access_type = "private"
}
# Create a Storage Container for the stemcells
resource "azurerm_storage_container" "azurestemcontainer" {
  name                  = "stemcell"
  resource_group_name   = "${azurerm_resource_group.Azure_rg_bosh.name}"
  storage_account_name  = "${azurerm_storage_account.azureboshsa.name}"
  container_access_type = "blob"
}


# Create a Network Securtiy Group
resource "azurerm_network_security_group" "Azure_bosh_nsg" {
  name                = "Azure_bosh_nsg"
  location            = "${var.location}"
  resource_group_name = "${azurerm_resource_group.Azure_rg_bosh.name}"

  security_rule {
    name                       = "ssh"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "bosh-agent"
    priority                   = 201
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "6868"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "bosh-director"
    priority                   = 202
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "25555"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "dns"
    priority                   = 203
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "53"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Public IP Address for bosh
resource "azurerm_public_ip" "Azure_IP_bosh" {
  name                         = "Azure_IP_bosh"
  location                     = "${var.location}"
  resource_group_name          = "${azurerm_resource_group.Azure_rg_bosh.name}"
  public_ip_address_allocation = "static"
}

# Public IP Address for BATS
resource "azurerm_public_ip" "Azure_IP_bats" {
  name                         = "Azure_IP_bats"
  location                     = "${var.location}"
  resource_group_name          = "${azurerm_resource_group.Azure_rg_bosh.name}"
  public_ip_address_allocation = "static"
}

output "DirectorPublicIP" {
  value = "${azurerm_public_ip.Azure_IP_bosh.ip_address}"
}
output "Network" {
  value = "${azurerm_virtual_network.Azure_bosh_network.name}"
}
output "Subnetwork" {
  value = "${azurerm_subnet.Azure_bosh_subnet.name}"
}
output "ResourceGroupName" {
  value = "${azurerm_resource_group.Azure_rg_bosh.name}"
}
output "StorageAccountName" {
  value = "${azurerm_storage_account.azureboshsa.name}"
}
output "DefaultSecurityGroup" {
  value = "${azurerm_network_security_group.Azure_bosh_nsg.name}"
}
output "InternalCIDR" {
  value = "${azurerm_subnet.Azure_bosh_subnet.address_prefix}"
}
output "InternalGateway" {
  value = "${cidrhost(azurerm_subnet.Azure_bosh_subnet.address_prefix, 1)}"
}
output "ReservedRange" {
  value = "${cidrhost(azurerm_subnet.Azure_bosh_subnet.address_prefix, 2)}-${cidrhost(azurerm_subnet.Azure_bosh_subnet.address_prefix, 6)}"
}
output "BATsPublicIP" {
  value = "${azurerm_public_ip.Azure_IP_bats.ip_address}"
}
output "BATsNetwork" {
  value = {
    Name = "${azurerm_subnet.Azure_BATs_subnet.name}"
    CIDR = "${azurerm_subnet.Azure_BATs_subnet.address_prefix}"
    Gateway = "${cidrhost(azurerm_subnet.Azure_BATs_subnet.address_prefix, 1)}"
    ReservedRange = "${cidrhost(azurerm_subnet.Azure_BATs_subnet.address_prefix, 2)}-${cidrhost(azurerm_subnet.Azure_BATs_subnet.address_prefix, 3)}"
    StaticRange =  "${cidrhost(azurerm_subnet.Azure_BATs_subnet.address_prefix, 4)}-${cidrhost(azurerm_subnet.Azure_BATs_subnet.address_prefix, 10)}"
    StaticIP = "${cidrhost(azurerm_subnet.Azure_BATs_subnet.address_prefix, 4)}"
    StaticIP_2 = "${cidrhost(azurerm_subnet.Azure_BATs_subnet.address_prefix, 5)}"
  }
}
output "BATsSecondNetwork" {
  value = {
    Name = "${azurerm_subnet.Azure_BATs_subnet_2.name}"
    CIDR = "${azurerm_subnet.Azure_BATs_subnet_2.address_prefix}"
    Gateway = "${cidrhost(azurerm_subnet.Azure_BATs_subnet_2.address_prefix, 1)}"
    ReservedRange = "${cidrhost(azurerm_subnet.Azure_BATs_subnet_2.address_prefix, 2)}-${cidrhost(azurerm_subnet.Azure_BATs_subnet_2.address_prefix, 3)}"
    StaticRange =  "${cidrhost(azurerm_subnet.Azure_BATs_subnet_2.address_prefix, 4)}-${cidrhost(azurerm_subnet.Azure_BATs_subnet_2.address_prefix, 10)}"
    StaticIP = "${cidrhost(azurerm_subnet.Azure_BATs_subnet_2.address_prefix, 4)}"
  }
}
