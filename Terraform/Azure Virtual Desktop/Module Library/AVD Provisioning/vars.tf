variable "avd_purpose" {
  type        = string
  description = "A general purpose for the AVD, will be used for naming conventions"
}
variable "desktop_name" {
  type        = string
  description = "I.E - General Desktop"
}
variable "region" {
  type        = string
  default     = "uksouth"
  description = "Where should the AVDs live?"
}
variable "friendly_name" {
  type        = string
  description = "A nice, friendly name for the pool - as this is what users will see"
}
variable "description" {
  type        = string
  description = "A helpful description of the pool"
}
variable "subnet_name" {
  type        = string
  description = "The name of the subnet you are provisioning into"
}
variable vnet_name {
  type        = string
  default     = ""
  description = "The name of the vnet you are provisioning to"
}
variable workspace_id {
  type        = string
  description = "Workspace to associate AVD Pool with"
}
variable "vm_size" {
  type        = string
  description = "I.E - standard_b2ms"
}
variable "vm_count" {
  description = "Number of AVD machines to deploy"
}
variable "source_image_id" {
  type        = string
  description = "This must be the full resource id of the shared image you are using"
}
variable diskType {
  type        = string
  default     = "Standard_LRS"
  description = "The type of disk for the AVD to use"
}
variable "ou_path" {
  type        = string
  description = "the CN of the OU you wish to provision the AVD into"
}
variable user_group {
  type        = string
  default     = ""
  description = "Object ID of AD group that will use the AVD"
}
variable loganalytics_id {
  type        = string
  default     = ""
  description = "The ID for the Log Aalytics Workspace you want info sent to"
}
variable backups_rg {
  type        = string
  default     = ""
  description = "Resource group for the backups to be stored in"
}
variable vault_name {
  type        = string
  default     = ""
  description = "The name of the backup vault used for backups"
}
variable policy_id {
  type        = string
  default     = ""
  description = "ID for the backup policy to apply to the AVDs"
}
variable "admin_username" {
  default     = ""
  description = "Local admin username"
}
variable "local_password" {
  description = "Local admin password"
  sensitive   = true
}
variable "domain_password" {
  description = "domain admin password"
  sensitive   = true
}
