resource "azurerm_log_analytics_workspace" "Log_Analytics_WorkSpace" {
    # The WorkSpace name has to be unique across the whole of azure, not just the current subscription/tenant.
    name                = "A GOOD NAME FOR YOUR LOG ANALYTICS WORKSPACE"
    location            = var.location
    resource_group_name = var.logAnalytics_rg
    sku                 = "PerGB2018"
}