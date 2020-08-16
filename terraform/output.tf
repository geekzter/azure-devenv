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

output linux_fqdn {
    value                      = replace(azurerm_dns_a_record.linux_fqdn.fqdn,"/\\W*$/","")
}
output linux_os_sku {
    value                      = module.linux_vm.os_sku
}
output linux_os_latest_version {
    value                      = module.linux_vm.os_latest_version
}
output linux_os_latest_version_command {
    value                      = module.linux_vm.os_latest_version_command
}
output linux_new_os_version_available {
    value                      = module.linux_vm.os_version != module.linux_vm.os_latest_version ? "NEW ${var.linux_os_offer} VERSION AVAILABLE: ${module.linux_vm.os_latest_version}" : null
}
output linux_os_version {
    value                      = module.linux_vm.os_version
}

output windows_fqdn {
    value                      = replace(azurerm_dns_a_record.windows_fqdn.fqdn,"/\\W*$/","")
}
output windows_os_sku {
    value                      = module.windows_vm.os_sku
}
output windows_os_latest_version {
    value                      = module.windows_vm.os_latest_version
}
output windows_os_latest_version_command {
    value                      = module.windows_vm.os_latest_version_command
}
output windows_new_os_version_available {
    value                      = module.windows_vm.os_version != module.windows_vm.os_latest_version ? "NEW WINDOWS VERSION AVAILABLE: ${module.windows_vm.os_latest_version}" : null
}
output windows_os_version {
    value                      = module.windows_vm.os_version
}
