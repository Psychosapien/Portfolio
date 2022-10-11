#----------------------------------
# Resource Group
#----------------------------------
resource "azurerm_resource_group" "avd_rg" {
  name     = "RG-AVD-${var.avd_purpose}"
  location = var.region
  tags = {
    environment  = "prd"
  }

        lifecycle {
      ignore_changes = [tags]
    }

}

#----------------------------------
# AVD Resources
#----------------------------------

# Set rotation time for registration token
resource "time_rotating" "avd_token" {
  rotation_days = 29
 }
# AVD Hostpool
resource "azurerm_virtual_desktop_host_pool" "hostpool" {
  name                     = "SHP-${var.avd_purpose}-POOL"
  resource_group_name      = azurerm_resource_group.avd_rg.name
  location                 = var.region
  type                     = "Pooled"
  load_balancer_type       = "BreadthFirst" # Options: BreadthFirst / DepthFirst
  custom_rdp_properties    = "audiocapturemode:i:1;audiomode:i:0;redirectclipboard:i:0;camerastoredirect:s:*"
  friendly_name            = var.friendly_name
  description              = "${var.description} - Created by Terraform"
  validate_environment     = false
  maximum_sessions_allowed = 10

  tags = {
    environment  = "prd"
  }

      lifecycle {
    ignore_changes = [tags,
    custom_rdp_properties]
  }

}

resource "azurerm_virtual_desktop_host_pool_registration_info" "hostpooltoken" {
  hostpool_id     = azurerm_virtual_desktop_host_pool.hostpool.id
  expiration_date = time_rotating.avd_token.rotation_rfc3339
}

# AVD App Group - Default Desktop Application Group (DAG)
resource "azurerm_virtual_desktop_application_group" "avd_app_group" {
  name                          = "AVD-${var.avd_purpose}-DAG"
  default_desktop_display_name  = var.desktop_name
  resource_group_name           = azurerm_resource_group.avd_rg.name
  location                      = azurerm_virtual_desktop_host_pool.hostpool.location
  type                          = "Desktop"
  host_pool_id                  = azurerm_virtual_desktop_host_pool.hostpool.id
  friendly_name                 = var.friendly_name
  description                   = "Desktop Application Group for ${azurerm_virtual_desktop_host_pool.hostpool.name} - Created by Terraform"
}

# Connect App Groups to Workspaces
resource "azurerm_virtual_desktop_workspace_application_group_association" "wvd_workspace_appgroup" {
  workspace_id         = var.workspace_id
  application_group_id = azurerm_virtual_desktop_application_group.avd_app_group.id
}

# Add AD Group to App Group
data "azurerm_role_definition" "desktop_virtualization_user" {
  name = "Desktop Virtualization User"
}

resource "azurerm_role_assignment" "avd_users_desktop_virtualization_user" {
  scope              = azurerm_virtual_desktop_application_group.avd_app_group.id
  role_definition_id = data.azurerm_role_definition.desktop_virtualization_user.id
  principal_id       = var.user_group

      lifecycle {
    ignore_changes = all
  }
}

#----------------------------------
# Session Host VM
#----------------------------------

# Create a NIC for the Session Host VM
resource "azurerm_network_interface" "avd_vm_nic" {
  count               = var.vm_count
  name                = "SH-${var.avd_purpose}-${count.index + 1}-nic"
  resource_group_name = azurerm_resource_group.avd_rg.name
  location            = azurerm_resource_group.avd_rg.location

  ip_configuration {
    name                          = "nic${count.index + 1}_config"
    subnet_id                     = "USE THE RESOURCE ID UP TO THE VNET NAME/${var.vnet_name}/subnets/${var.subnet_name}"
    private_ip_address_allocation = "Dynamic"
  }
  tags = {
    environment  = "prd"
  }

      lifecycle {
    ignore_changes = all
  }

}

# Create the Session Host VM
resource "azurerm_windows_virtual_machine" "avd_vm" {
  count                 = var.vm_count
  name                  = "SH-${var.avd_purpose}-${count.index + 1}"
  resource_group_name   = azurerm_resource_group.avd_rg.name
  location              = azurerm_resource_group.avd_rg.location
  size                  = var.vm_size
  network_interface_ids = ["${azurerm_network_interface.avd_vm_nic.*.id[count.index]}"]
  provision_vm_agent    = true
  timezone              = "GMT Standard Time"
  license_type          = "Windows_Client"

  admin_username = var.admin_username
  admin_password = var.local_password

  os_disk {
    name                 = "sh-${lower(var.avd_purpose)}-${count.index + 1}"
    caching              = "ReadWrite"
    storage_account_type = var.diskType
  }

  source_image_id = var.source_image_id

  tags = {
    environment   = "prd"
  }

    lifecycle {
    ignore_changes = all
  }
}

# VM Extension for Domain-join
resource "azurerm_virtual_machine_extension" "vmext_domain_join" {
  count                      = var.vm_count
  name                       = "SH-${var.avd_purpose}-${count.index + 1}-domainJoin"
  virtual_machine_id         = azurerm_windows_virtual_machine.avd_vm.*.id[count.index]
  publisher                  = "Microsoft.Compute"
  type                       = "JsonADDomainExtension"
  type_handler_version       = "1.3"
  auto_upgrade_minor_version = true

  settings = <<-SETTINGS
    {
      "Name": "DOMAIN TO JOIN",
      "OUPath": "${var.ou_path}",
      "User": "UPN FOR A DOMAIN ADMIN ACCOUNT",
      "Restart": "true",
      "Options": "3"
    }
    SETTINGS

  protected_settings = <<-PSETTINGS
    {
      "Password": "${var.domain_password}"
    }
    PSETTINGS

  lifecycle {
    ignore_changes = all
  }
}

# VM Extension for Desired State Config
resource "azurerm_virtual_machine_extension" "vmext_dsc" {

  count                      = var.vm_count
  name                       = "SH-${var.avd_purpose}${count.index + 1}-avd_dsc"
  virtual_machine_id         = azurerm_windows_virtual_machine.avd_vm.*.id[count.index]
  publisher                  = "Microsoft.Powershell"
  type                       = "DSC"
  type_handler_version       = "2.73"
  auto_upgrade_minor_version = true

  settings = <<SETTINGS
  {
    "modulesUrl": "https://wvdportalstorageblob.blob.core.windows.net/galleryartifacts/Configuration_3-10-2021.zip",
    "configurationFunction": "Configuration.ps1\\AddSessionHost",
    "properties": {
      "hostPoolName": "${azurerm_virtual_desktop_host_pool.hostpool.name}",
      "registrationInfoToken": "${azurerm_virtual_desktop_host_pool_registration_info.hostpooltoken.token}"
    }
  }
SETTINGS

  lifecycle {
    ignore_changes = all
  }

  depends_on = [
    azurerm_virtual_machine_extension.vmext_domain_join,
  ]
}

resource "azurerm_monitor_diagnostic_setting" "avd-hostpool" {
  name               = "DIAG-${var.avd_purpose}-POOL"
  target_resource_id = azurerm_virtual_desktop_host_pool.hostpool.id
  log_analytics_workspace_id = var.loganalytics_id

  log {
    category = "Error"
    enabled  = true

    retention_policy {
      enabled = false
    }
  }

  lifecycle {
    ignore_changes = all
  }
}

resource "azurerm_backup_protected_vm" "vm1" {
  count               = var.vm_count
  resource_group_name = var.backups_rg
  recovery_vault_name = var.vault_name
  source_vm_id        = azurerm_windows_virtual_machine.avd_vm.*.id[count.index]
  backup_policy_id    = var.policy_id

        lifecycle {
    ignore_changes = all
  }

}