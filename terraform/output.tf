output admin_password {
    sensitive                  = true
    value                      = local.password
}
output admin_username {
    sensitive                  = false
    value                      = var.admin_username
}
output resource_group_id {
    value                      = azurerm_resource_group.vm_resource_group.id
}
output resource_group_name {
    value                      = azurerm_resource_group.vm_resource_group.name
}
output windows_fqdn {
    value                      = replace(azurerm_dns_a_record.windows_fqdn.fqdn,"/\\W*$/","")
}
output windows_os_sku {
    value                      = module.windows_vm.os_sku
}
output windows_os_version {
    value                      = module.windows_vm.os_version
}
output windows_os_latest_version_command {
    value                      = module.windows_vm.os_latest_version_command
}