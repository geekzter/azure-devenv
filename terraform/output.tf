output admin_password {
    sensitive                  = true
    value                      = local.password
}
output admin_username {
    sensitive                  = false
    value                      = var.admin_username
}

output cert_password {
  sensitive                    = true
  value                        = var.deploy_vpn ? module.vpn.0.cert_password : null
}

output client_cert {
  sensitive                    = true
  value                        = var.deploy_vpn ? module.vpn.0.client_cert : null
}

output client_key {
  sensitive                    = true
  value                        = var.deploy_vpn ? module.vpn.0.client_key : null
}

output cloud_config {
    sensitive                  = true
    value                      = [for vm in module.linux_vm : vm.cloud_config]
}

output dns_server_address {
    value                      = module.linux_vm[azurerm_resource_group.vm_resource_group.location].private_ip_address
}

output gateway_id {
  value                        = var.deploy_vpn ? module.vpn.0.gateway_id : null
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
    value                      = module.linux_vm[var.locations[0]].os_latest_version_command
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

output resource_group_id {
    value                      = azurerm_resource_group.vm_resource_group.id
}
output resource_group_name {
    value                      = azurerm_resource_group.vm_resource_group.name
}

output root_cert_cer {
  sensitive                    = true
  value                        = var.deploy_vpn ? module.vpn.0.root_cert_cer : null
}

output virtual_network_id {
    value                      = {for region in var.locations : region => azurerm_virtual_network.development_network[region].id}
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
    value                      = module.windows_vm[var.locations[0]].os_latest_version_command
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
