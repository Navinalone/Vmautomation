
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.0.1"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id =
  tenant_id           = 
}

data "azuread_client_config" "current" {}


resource "azurerm_resource_group" "rg" {
  name     = "VMautomation-rg"
  location = "East US2"
  tags = {
    Project = "Vm automation"
    Owner = "Navin"
  }
}

resource "azurerm_virtual_network" "vnet" {
  name                = "vm-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}


resource "azurerm_subnet" "subnet" {
  name                 = "vmautomation-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}


resource "azurerm_network_security_group" "nsg" {
  name                = "vm-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "allow-rdp"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"  
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow-http"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"  
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow-https"
    priority                   = 300
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443" 
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}


variable "vm_names" {
  default = {
    "vm1"  = "vm-1"
    "vm2"  = "vm-2"
    "vm3"  = "vm-3"
    "vm4"  = "vm-4"
    "vm5"  = "vm-5"
    "vm6"  = "vm-6"
    "vm7"  = "vm-7"
    "vm8"  = "vm-8"
    "vm9"  = "vm-9"
    "vm10" = "vm-10"
  }
}

resource "azurerm_public_ip" "vm_public_ip" {
  for_each            = var.vm_names
  name                = "${each.value}-public-ip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
}


resource "azurerm_network_interface" "vm_nic" {
  for_each            = var.vm_names
  name                = "${each.value}-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id = azurerm_public_ip.vm_public_ip[each.key].id
  }
}

resource "azurerm_network_interface_security_group_association" "nsg_association" {
  for_each                   = var.vm_names
  network_interface_id        = azurerm_network_interface.vm_nic[each.key].id
  network_security_group_id   = azurerm_network_security_group.nsg.id
}

resource "azurerm_windows_virtual_machine" "vm" {
  for_each            = var.vm_names
  name                = each.value
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  network_interface_ids = [
    azurerm_network_interface.vm_nic[each.key].id
  ]
  size = "Standard_DS1_v2"

  admin_username = "navin"
  admin_password = "Password1234!"

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }
}


resource "azurerm_automation_account" "AutomationAc" {
  name                = "Vmshutdownstartup-acc"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku_name            = "Basic"

  identity {
    type = "SystemAssigned"  
  }
    tags = {
    AccountPurpose = "Vm autoshutdownstartup"
    Owner = "Navin"
  }
}

resource "azurerm_role_assignment" "roleassignment" {
  principal_id         = azurerm_automation_account.AutomationAc.identity[0].principal_id
  role_definition_name = "Virtual Machine Contributor"  
  scope                = azurerm_resource_group.rg.id
}

resource "azurerm_automation_runbook" "Vmstartrunbook" {
  name                    = "vm-start"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  automation_account_name = azurerm_automation_account.AutomationAc.name
  log_verbose             = true
  log_progress            = true
  description             = "Runbook to start and stop virtual machines"
  runbook_type            = "PowerShell"
  content                 = file("../Scripts/Vmstart.ps1")  
    tags = {
    RunbookPurpose = "Vm autostartup"
    Owner = "Navin"
  }
  depends_on = [
    azurerm_automation_account.AutomationAc
  ]
}

resource "azurerm_automation_runbook" "Vmstoprunbook" {
  name                    = "vm-stop"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  automation_account_name = azurerm_automation_account.AutomationAc.name
  log_verbose             = true
  log_progress            = true
  description             = "Runbook to start and stop virtual machines"
  runbook_type            = "PowerShell"
  content                 = file("../Scripts/Vmstop.ps1")  
    tags = {
    RunbookPurpose = "Vm autoshutdown"
    Owner = "Navin"
  }
  depends_on = [
    azurerm_automation_account.AutomationAc
  ]
}


######## schduler for auto startup  ###########

resource "azurerm_automation_schedule" "startup_schedule" {
  name                    = "daily-startup-schedule"
  resource_group_name      = azurerm_resource_group.rg.name
  automation_account_name = azurerm_automation_account.AutomationAc.name
  frequency               = "Day"
  interval                = 1
  timezone                = "UTC"
  start_time              = "2024-10-24T05:30:00Z"
}

###############  Link the Schedule with the Runbook #########

resource "azurerm_automation_job_schedule" "startup_job" {
 automation_account_name = azurerm_automation_account.AutomationAc.name
  schedule_name           = azurerm_automation_schedule.startup_schedule.name
  runbook_name            = azurerm_automation_runbook.Vmstartrunbook.name
  resource_group_name     = azurerm_resource_group.rg.name
}


######## schduler for auto shut down ###########
resource "azurerm_automation_schedule" "shutdown_schedule" {
  name                    = "daily-shutdown-schedule"
  resource_group_name      = azurerm_resource_group.rg.name
  automation_account_name = azurerm_automation_account.AutomationAc.name
  frequency               = "Day"
  interval                = 1
  timezone                = "UTC"
  start_time              = "2024-10-24T14:30:00Z"
}


###############  Link the Schedule with the Runbook #########

resource "azurerm_automation_job_schedule" "shutdown_job" {
 automation_account_name = azurerm_automation_account.AutomationAc.name
  schedule_name           = azurerm_automation_schedule.shutdown_schedule.name
  runbook_name            = azurerm_automation_runbook.Vmstoprunbook.name
  resource_group_name     = azurerm_resource_group.rg.name
}



resource "azurerm_recovery_services_vault" "rcvault" {
  name                = "azbackup-vault"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "Standard"

  tags = {
    Project     = "VM Backup"
    Owner       = "Navin"
  }
}


resource "azurerm_backup_policy_vm" "backuppolicy" {
  name                = "daily-backup-policy"
  resource_group_name = azurerm_resource_group.rg.name
  recovery_vault_name = azurerm_recovery_services_vault.rcvault.name

  backup {
    frequency = "Daily"
    time      = "23:00"
  }

  retention_daily {
    count = 30
  }
}

resource "azurerm_backup_protected_vm" "vm_backup" {
 # count               = 10  
  for_each             = var.vm_names
  resource_group_name = azurerm_resource_group.rg.name
  recovery_vault_name = azurerm_recovery_services_vault.rcvault.name
  source_vm_id        = azurerm_windows_virtual_machine.vm[each.key].id
  backup_policy_id    = azurerm_backup_policy_vm.backuppolicy.id

  depends_on = [
    azurerm_recovery_services_vault.rcvault,
    azurerm_backup_policy_vm.backuppolicy
  ]
}