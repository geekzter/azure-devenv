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
    value                      = [for vm in module.linux_vm : vm.public_fqdn]
}
output linux_os_sku {
    value                      = [for vm in module.linux_vm : vm.os_sku]
}
output linux_os_latest_version {
    value                      = [for vm in module.linux_vm : vm.os_latest_version]
}
output linux_os_latest_version_command {
    value                      = [for vm in module.linux_vm : vm.os_latest_version_command]
}
output linux_new_os_version_available {
    value                      = [for vm in module.linux_vm : "NEW ${var.linux_os_offer} VERSION AVAILABLE: ${vm.os_latest_version}" if vm.os_version != vm.os_latest_version]
}
output linux_os_version {
    value                      = [for vm in module.linux_vm : vm.os_version]
}
output linux_vm_id {
    value                      = [for vm in module.linux_vm : vm.vm_id]
}

output windows_fqdn {
    value                      = [for vm in module.windows_vm : vm.public_fqdn]
}
output windows_os_sku {
    value                      = [for vm in module.windows_vm : vm.os_sku]
}
output windows_os_latest_version {
    value                      = [for vm in module.windows_vm : vm.os_latest_version]
}
output windows_os_latest_version_command {
    value                      = [for vm in module.windows_vm : vm.os_latest_version_command]
}
output windows_new_os_version_available {
    value                      = [for vm in module.windows_vm : "NEW WINDOWS VERSION AVAILABLE: ${vm.os_latest_version}" if vm.os_version != vm.os_latest_version]
}
output windows_os_version {
    value                      = [for vm in module.windows_vm : vm.os_version]
}
output windows_vm_id {
    value                      = [for vm in module.windows_vm : vm.vm_id]
}
