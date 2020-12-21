variable aad_login {
    type                       = bool
    default                    = false
}
variable admin_username {}
variable admin_password {}
variable bg_info {
    type                       = bool
    default                    = false
}
variable dependency_monitor {
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
variable dns_zone_id {
    default                    = null
}
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
variable log_analytics_workspace_id {
    default                    = null
}
variable moniker {}
variable network_watcher {
    type                       = bool
    default                    = false
}
variable os_sku_match {
    default                    = "-ent-g2"
}
variable os_version {
    default                    = "latest"
}
variable private_dns_zone {}
variable resource_group_name {}
variable scripts_container_id {}
variable tags {}
variable vm_size {}
variable vm_subnet_id {}