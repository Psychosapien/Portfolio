resource "azurerm_recovery_services_vault" "vault" {
    name    = "A GOOD NAME FOR YOUR RECOVERY VAULT"
    location = var.location
    resource_group_name = var.backup_rg
    sku     = "Standard"
}

resource "azurerm_backup_policy_vm" "policy" {
  name                = "A GOOD NAME FOR A BACKUP POLICY"
  resource_group_name = var.backup_rg
  recovery_vault_name = "${azurerm_recovery_services_vault.vault.name}"

# Change the values below according to how you would like backups to run
  backup {
    frequency = "Daily"
    time      = "23:00"
  }

  retention_daily {
    count = 30
  }
  }