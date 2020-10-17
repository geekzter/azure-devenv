variable aad_login {
    type                       = bool
    default                    = false
}
variable dependency_monitor {
    type                       = bool
    default                    = false
}
variable bootstrap {
    type                       = bool
    default                    = false
}
variable diagnostics {
    type                       = bool
    default                    = false
}
variable disk_encryption {
    type                       = bool
    default                    = false
}
variable diagnostics_storage_id {}
variable enable_accelerated_networking {
    type                       = bool
    default                    = false
}
variable environment_variables {
  type                         = map
} 
variable git_email {}
variable git_name {}
variable key_vault_id {}
variable location {}
variable log_analytics_workspace_id {}
variable moniker {}
variable network_watcher {
    type                       = bool
    default                    = false
}
variable os_offer {
  default                      = "UbuntuServer"
}
variable os_publisher {
  default                      = "Canonical"
}
variable os_sku {
  default                      = "18.04-LTS"
}
variable os_version {
    default                    = "latest"
}
variable resource_group_name {}
variable scripts_container_id {}
variable ssh_public_key {}
variable tags {}
variable user_name {}
variable user_password {}
variable vm_size {}
variable vm_subnet_id {}