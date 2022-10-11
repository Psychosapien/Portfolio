variable "name" {
  type        = string
  default     = ""
  description = "Name for resources - This will get used everywhere so make it catchy"
}
 
variable "location" {
  type        = string
  default     = "uksouth"
  description = "Azure Location of resources"
}
  
variable "kubernetes_cluster_rbac_enabled" {
  default = "true"
}
 
variable "kubernetes_version" {
  default = "1.24.3"
  description = "Probably go and check the most recent version and update this if you need to."
}
 
variable "agent_count" {
  default = "1"
}
 
variable "vm_size" {
  default = "standard_b2s"
}
 
variable "ssh_public_key" {
  default = "Get yourself an ssh key to assign to the agent pool"
}
 
variable "aks_admins_group_object_id" {
  default = ""
  description = "object ID for an AAD group to assign AKS admin rights to"
}

variable "network_address_space" {
  default = "192.168.0.0/16"
  type        = string
  description = "Azure VNET Address Space"
}
 
variable "aks_subnet_address_name" {
  default = "aks"
  type        = string
  description = "AKS Subnet Address Name"
}
 
variable "aks_subnet_address_prefix" {
  default = "192.168.0.0/24"
  type        = string
  description = "AKS Subnet Address Space"
}
 
variable "subnet_address_name" {
  default = "appgw"
  type        = string
  description = "Subnet Address Name"
}
 
variable "subnet_address_prefix" {
  default = "192.168.1.0/24"
  type        = string
  description = "Subnet Address Space"
}

variable "client_secret" {
type = string
}

variable "client_id" {
type = string
}