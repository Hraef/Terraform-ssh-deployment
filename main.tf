terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.29.1"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "lotr-rg" {
  name     = "lotr-resources"
  location = "eastus"
  tags = {
    environment = "dev"
  }
}

resource "azurerm_virtual_network" "mordor-vn" {
  name                = "mordor-network"
  resource_group_name = azurerm_resource_group.lotr-rg.name
  location            = azurerm_resource_group.lotr-rg.location
  address_space       = ["10.123.0.0/16"]
  tags = {
    "environment" = "dev"
  }
}

resource "azurerm_subnet" "lotr-subnet" {
  name                 = "lotr-subnet"
  resource_group_name  = azurerm_resource_group.lotr-rg.name
  virtual_network_name = azurerm_virtual_network.mordor-vn.name
  address_prefixes     = ["10.123.1.0/24"]
}

resource "azurerm_network_security_group" "lotr-sg" {
  name                = "lotr-sg"
  location            = azurerm_resource_group.lotr-rg.location
  resource_group_name = azurerm_resource_group.lotr-rg.name
  tags = {
    "environment" = "dev"
  }
}

resource "azurerm_network_security_rule" "lotr-sr" {
  name                        = "lotr-sr"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "76.204.24.15/32"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.lotr-rg.name
  network_security_group_name = azurerm_network_security_group.lotr-sg.name
}

resource "azurerm_subnet_network_security_group_association" "lotr-sga" {
  subnet_id                 = azurerm_subnet.lotr-subnet.id
  network_security_group_id = azurerm_network_security_group.lotr-sg.id
}

resource "azurerm_public_ip" "lotr-ip" {
  name                = "lotr-ip.0"
  resource_group_name = azurerm_resource_group.lotr-rg.name
  location            = azurerm_resource_group.lotr-rg.location
  allocation_method   = "Dynamic"

  tags = {
    environment = "dev"
  }
}

resource "azurerm_network_interface" "lotr-nic" {
  name                = "lotr-nic"
  location            = azurerm_resource_group.lotr-rg.location
  resource_group_name = azurerm_resource_group.lotr-rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.lotr-subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.lotr-ip.id
  }

  tags = {
    "environment" = "dev"
  }
}

resource "azurerm_linux_virtual_machine" "mordor-vm" {
  name                  = "mordor-vm"
  resource_group_name   = azurerm_resource_group.lotr-rg.name
  location              = azurerm_resource_group.lotr-rg.location
  size                  = "standard_F2"
  admin_username        = "adminuser"
  network_interface_ids = [azurerm_network_interface.lotr-nic.id]

  custom_data = filebase64("customdata.tpl")

  admin_ssh_key {
    username   = "adminuser"
    public_key = file("~/.ssh/lotrazkey.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }

  provisioner "local-exec" {
    command = templatefile("${var.host_os}-ssh-script.tpl", {
      hostname     = self.public_ip_address,
      user         = "adminuser",
      identityfile = "~/.ssh/lotrazkey"
    })
    interpreter = var.host_os == "windows" ? ["Powershell", "-command"] : ["bash", "-c"]
  }

  tags = {
    "environment" = "dev"
  }
}

data "azurerm_public_ip" "lotr-ip-data" {
  name = azurerm_public_ip.lotr-ip.name
  resource_group_name = azurerm_resource_group.lotr-rg.name
}

output "public_ip_address" {
  value = "${azurerm_linux_virtual_machine.mordor-vm.name}: ${data.azurerm_public_ip.lotr-ip-data.ip_address}"
}