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
    
resource "azurerm_kubernetes_cluster" "k8s" {
  name                = "${var.name}aks"
  location            = var.location
  resource_group_name = azurerm_resource_group.resource_group.name
  dns_prefix          = "${var.name}dns"
  kubernetes_version  = var.kubernetes_version
 
  node_resource_group = "${var.name}-node-rg"
 
  linux_profile {
    admin_username = "ubuntu"
 
    ssh_key {
      key_data = var.ssh_public_key
    }
  }
 
  default_node_pool {
    name                 = "agentpool"
    node_count           = var.agent_count
    vm_size              = var.vm_size
    vnet_subnet_id       = azurerm_subnet.aks_subnet.id
    type                 = "VirtualMachineScaleSets"
    orchestrator_version = var.kubernetes_version
  }
 
  identity {
    type = "SystemAssigned"
  }
 
    ingress_application_gateway {
      subnet_id = azurerm_subnet.app_gwsubnet.id
    }
 

 
  network_profile {
    load_balancer_sku = "standard"
    network_plugin    = "azure"
  }
  
}
 
resource "azurerm_role_assignment" "node_infrastructure_update_scale_set" {
  principal_id         = azurerm_kubernetes_cluster.k8s.kubelet_identity[0].object_id
  scope                = azurerm_resource_group.resource_group.id
  role_definition_name = "Virtual Machine Contributor"
  depends_on = [
    azurerm_kubernetes_cluster.k8s
  ]
}

resource "azurerm_log_analytics_workspace" "Log_Analytics_WorkSpace" {
    # The WorkSpace name has to be unique across the whole of azure, not just the current subscription/tenant.
    name                = "${var.name}-la"
    location            = var.location
    resource_group_name = azurerm_resource_group.resource_group.name
    sku                 = "PerGB2018"
}
 
resource "azurerm_log_analytics_solution" "Log_Analytics_Solution_ContainerInsights" {
    solution_name         = "ContainerInsights"
    location              = azurerm_log_analytics_workspace.Log_Analytics_WorkSpace.location
    resource_group_name   = azurerm_resource_group.resource_group.name
    workspace_resource_id = azurerm_log_analytics_workspace.Log_Analytics_WorkSpace.id
    workspace_name        = azurerm_log_analytics_workspace.Log_Analytics_WorkSpace.name
 
    plan {
        publisher = "Microsoft"
        product   = "OMSGallery/ContainerInsights"
    }
}

resource "azurerm_virtual_network" "virtual_network" {
  name =  "${var.name}-vnet"
  location = var.location
  resource_group_name = azurerm_resource_group.resource_group.name
  address_space = [var.network_address_space]
}
 
resource "azurerm_subnet" "aks_subnet" {
  name = var.aks_subnet_address_name
  resource_group_name  = azurerm_resource_group.resource_group.name
  virtual_network_name = azurerm_virtual_network.virtual_network.name
  address_prefixes = [var.aks_subnet_address_prefix]
}
 
resource "azurerm_subnet" "app_gwsubnet" {
  name = var.subnet_address_name
  resource_group_name  = azurerm_resource_group.resource_group.name
  virtual_network_name = azurerm_virtual_network.virtual_network.name
  address_prefixes = [var.subnet_address_prefix]
}

resource "azurerm_container_registry" "acr" {
  name                = "${var.name}acr"
  resource_group_name = azurerm_resource_group.resource_group.name
  location            = azurerm_resource_group.resource_group.location
  sku                 = "Basic"
  admin_enabled       = false
}

resource "azurerm_role_assignment" "example" {
  principal_id                     = azurerm_kubernetes_cluster.k8s.kubelet_identity[0].object_id
  role_definition_name             = "AcrPull"
  scope                            = azurerm_container_registry.acr.id
  skip_service_principal_aad_check = true
}
