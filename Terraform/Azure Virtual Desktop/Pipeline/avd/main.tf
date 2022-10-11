terraform {
  backend "azurerm" {
    resource_group_name  = "RESOURCE GROUP FOR STORAGE ACCOUNT"
    storage_account_name = "STORAGE ACCOUNT NAME"
    container_name       = "STORAGE CONTAINER NAME"
    sas_token            = "SAS TOKEN FOR YOUR CONTAINER"
  }
}

provider "azurerm" {
  subscription_id = "SUBSCRIPTION ID FOR RESOURCES"
  client_id       = "CLIENT ID FOR SERVICE PRINCIPLE"
  client_secret   = "CLIENT SECRET FOR SERVICE PRINCIPLE - DON'T PUT IT IN HERE THOUGH, USE AN OBSCURED VARIABLE"
  tenant_id       = "TENANT ID FOR SERVICE PRINCIPLE"
  features {}
}