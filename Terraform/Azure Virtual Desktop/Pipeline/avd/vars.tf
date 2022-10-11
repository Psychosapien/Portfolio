variable "local_password" {
  description = "Local admin password"
  sensitive   = true
}
variable "domain_password" {
  description = "domain admin password"
  sensitive   = true
}
variable "client_id" {
  type = string
}
variable "client_secret" {
  type = string
}
variable location {
  type        = string
  default     = ""
  description = "Location for all of your stuff"
}
variable backup_rg {
  type        = string
  default     = ""
  description = "A decent name for the backups resource group"
}
variable logAnalytics_rg {
  type        = string
  default     = ""
  description = "A decent name for the log analytics resource group"
}
variable workspace_rg {
  type        = string
  default     = ""
  description = "A decent name for the workspace resource group"
}

