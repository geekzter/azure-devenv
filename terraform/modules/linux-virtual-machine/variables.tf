variable admin_cidr_ranges {
    type                       = list
    default                    = []
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
variable domain {}
variable disk_encryption {
    type                       = bool
    default                    = false
}
variable diagnostics_storage_id {}
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
variable enable_dns_proxy {
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
variable install_tools {
  type                         = bool
  default                      = false
}
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
variable os_image_id {
  default                      = null
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
variable prepare_host {
  type                         = bool
  default                      = true
}
variable private_dns_zone {}
variable enable_public_access {
  type                         = bool
}
variable resource_group_name {}
variable shutdown_time {}
variable ssh_private_key {}
variable ssh_public_key {}
variable tags {}
variable terraform_cidr {}
variable timezone {}
variable user_assigned_identity_id {}
variable user_name {}
variable user_password {}
variable virtual_network_has_gateway {}
variable vm_size {}
variable vm_subnet_id {}