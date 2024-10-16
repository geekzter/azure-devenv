variable admin_cidr_ranges {
    type                       = list
    default                    = []
}
variable admin_username {}
variable admin_password {}
variable bg_info {
    type                       = bool
    default                    = false
}
variable bootstrap_branch {
    default                    = "master"
}
variable dependency_monitor {
    type                       = bool
    default                    = false
}
variable deploy_azure_monitor_extensions {
  type                         = bool
}
variable diagnostics_storage_id {}
variable disk_encryption {
    type                       = bool
    default                    = false
}
variable dns_zone_id {
    default                    = null
}
variable enable_aad_login {
    type                       = bool
    default                    = false
}
variable enable_accelerated_networking {
    type                       = bool
    default                    = false
}
variable enable_policy_extension {
    type                       = bool
    default                    = false
}
variable enable_security_center {
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
# Input for https://github.com/geekzter/bootstrap-os/blob/master/windows/bootstrap_windows.ps1
variable packages {
    type                       = list
    default                    = ["Minimal"]
}
variable moniker {}
variable network_watcher {
    type                       = bool
    default                    = false
}
variable os_image_id {
  default                      = null
}
variable os_offer {
    default                    = "visualstudio2022"
}
variable os_publisher {
    default                    = "microsoftvisualstudio"
}
variable os_sku {
    default                    = "vs-2022-comm-latest-win11-n"
}
variable os_version {
    default                    = "latest"
}
variable enable_public_access {
  type                         = bool
}
variable prepare_host {
  type                         = bool
  default                      = true
}
variable private_dns_zone {}
variable resource_group_name {}
variable user_assigned_identity_id {}
variable shutdown_time {}
variable tags {}
variable timezone {}
variable virtual_network_has_gateway {}
variable vm_size {}
variable vm_subnet_id {}