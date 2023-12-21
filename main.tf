# Provider configuration
provider "azurerm" {
  features {}
}

# We strongly recommend using the required_providers block to set the
# Azure Provider source and version being used
terraform {
  required_providers {
    azapi = {
      source = "azure/azapi"
    }
  }
}

provider "azapi" {
}
# Resource group
resource "azurerm_resource_group" "rg" {
  name     = "my-resource-group"
  location = "South Central US"
}

# Virtual network
resource "azurerm_virtual_network" "vnet" {
  name                = "lm-sql-virtual-network"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# Subnet
resource "azurerm_subnet" "subnet" {
  name                 = "my-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Public IP address
resource "azurerm_public_ip" "pip" {
  name                = "my-public-ip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
}

# Network interface
resource "azurerm_network_interface" "nic" {
  name                = "my-network-interface"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "my-ip-configuration"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.pip.id
  }
}

# Virtual machine
resource "azurerm_virtual_machine" "sqlvm" {
  name                  = "my-virtual-machine"
  location              = azurerm_resource_group.rg.location
  resource_group_name   = azurerm_resource_group.rg.name
  network_interface_ids = [azurerm_network_interface.nic.id]
  vm_size               = "Standard_DS2_v2"

  storage_image_reference {
    publisher = "MicrosoftSQLServer"
    offer     = "SQL2019-WS2019"
    sku       = "Enterprise"
    version   = "latest"
  }

  storage_os_disk {
    name              = "my-os-disk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name  = "lm-sql-computer"
    admin_username = "colliga"
    admin_password = "Ssn**767Ssn**767"
  }

  os_profile_windows_config {
    enable_automatic_upgrades = true
    provision_vm_agent        = true
  }
}


resource "azurerm_virtual_machine_extension" "sql" {
  name                 = "sql"
  virtual_machine_id   = azurerm_virtual_machine.sqlvm.id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.9"

  settings = <<SETTINGS
    {
        "commandToExecute": "powershell.exe -Command \"Invoke-Sqlcmd -Query 'CREATE DATABASE exampleDB' -ServerInstance 'localhost' -U 'sa' -P 'YourStrongPassword1'\""
    }
SETTINGS
}


# Bastion Subnet
resource "azurerm_subnet" "bastion_subnet" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/27"]
}

# Public IP for Bastion
resource "azurerm_public_ip" "bastion_pip" {
  name                = "bastion-public-ip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# Bastion Host
resource "azurerm_bastion_host" "bastion" {
  name                = "my-bastion-host"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.bastion_subnet.id
    public_ip_address_id = azurerm_public_ip.bastion_pip.id
  }
}







resource "azapi_resource" "backup_fabric_protection_container" {
  type = "Microsoft.RecoveryServices/vaults/backupFabrics/protectionContainers@2023-01-01"
  name = "vault-lidlh4do/Azure/lm-sql-computer-container"
  location = "Central US"
  parent_id = "/subscriptions/${var.subid}/resourceGroups/my-resource-group/providers/Microsoft.RecoveryServices/vaults/vault-lidlh4do/Azure/VMAppContainer;Compute;my-resource-group;my-virtual-machine"

  body = jsonencode({
    properties = {
      backupManagementType = "AzureWorkload"
      workloadType         = "SQLDataBase"
      containerType        = "VMAppContainer"
      sourceResourceId     = "/subscriptions/${var.subid}/resourceGroups/my-resource-group/providers/Microsoft.Compute/virtualMachines/my-virtual-machine"
      operationType        = "Register"
    }
  })
}






resource "azapi_resource" "protected_item" {
  #for_each = toset(var.protectedItems)
  
  type = "Microsoft.RecoveryServices/vaults/backupFabrics/protectionContainers@2023-01-01"
  name = "master-db"
  location = "Central US" # Update this with the actual location
  resource_group_name = "Central US"

  parent_id = "/subscriptions/${var.vaultSubID}/resourceGroups/${var.vaultRG}/providers/Microsoft.RecoveryServices/vaults/${var.vaultName}"

  body = jsonencode({
    properties = {
      containerName = backup_fabric_protection_container.name
      policyId = "/subscriptions/${var.vaultSubID}/resourceGroups/${var.vaultRG}/providers/${var.armProviderNamespace}/vaults/backupPolicies/${var.policyName}"
      policyName = "${var.policyName}" #this needs to be dependent on an output from another terraform resource. 
      protectedItemType = "AzureVmWorkloadSQLDatabase"
      parentName = "MSSQLSERVER"
      parentType = "Microsoft.Compute/virtualMachines"
      protectedItemDataSourceId = backup_fabric_protection_container.id
      serverName = "lm-sql-computer"
      
    }
  })
}

