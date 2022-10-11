resource "azurerm_virtual_desktop_workspace" "workspace" {
  name                = "A GOOD NAME FOR YOUR WORKSPACE"
  location            = var.location
  resource_group_name = var.workspace_rg

  friendly_name = "THIE IS THE NAME PEOPLE WILL SEE FOR THE WORKSPACE SO MAKE IT NICE"
  description   = "SOME KIND OF HELPFUL DESCRIPTION FOR THE WORKSPACE"
}
