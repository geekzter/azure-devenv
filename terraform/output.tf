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

output client_cert_common_name {
  value                        = var.deploy_vpn ? module.vpn.0.client_cert_common_name : null
}

output client_cert_merged_pem {
  sensitive                    = true
  value                        = var.deploy_vpn ? module.vpn.0.client_cert_merged_pem : null
}

output client_cert_private_pem {
  sensitive                    = true
  value                        = var.deploy_vpn ? module.vpn.0.client_cert_private_pem : null
}

output client_cert_public_pem {
  sensitive                    = true
  value                        = var.deploy_vpn ? module.vpn.0.client_cert_public_pem : null
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

output linux_private_fqdn {
    value                      = [for vm in module.linux_vm : vm.private_fqdn]
}
output linux_public_fqdn {
    value                      = [for vm in module.linux_vm : vm.public_fqdn]
}
output linux_os_version {
    value                      = [for vm in module.linux_vm : vm.os_version]
}
output linux_os_version_latest {
    value                      = [for vm in module.linux_vm : vm.os_version_latest]
}
output linux_new_os_version_available {
    value                      = [for vm in module.linux_vm : "NEW ${var.linux_os_offer} VERSION AVAILABLE: ${vm.os_latest_version}" if vm.os_version != vm.os_version_latest]
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

output root_cert_common_name {
  value                        = var.deploy_vpn ? module.vpn.0.root_cert_common_name : null
}

output root_cert_merged_pem {
  sensitive                    = true
  value                        = var.deploy_vpn ? module.vpn.0.root_cert_merged_pem : null
}

output root_cert_private_pem {
  sensitive                    = true
  value                        = var.deploy_vpn ? module.vpn.0.root_cert_private_pem : null
}

output root_cert_public_pem {
  sensitive                    = true
  value                        = var.deploy_vpn ? module.vpn.0.root_cert_public_pem : null
}

output virtual_network_id {
    value                      = {for region in var.locations : region => azurerm_virtual_network.development_network[region].id}
}

output windows_private_fqdn {
    value                      = [for vm in module.windows_vm : vm.private_fqdn]
}
output windows_public_fqdn {
    value                      = [for vm in module.windows_vm : vm.public_fqdn]
}
output windows_os_sku {
    value                      = var.windows_sku
}
output windows_os_version {
    value                      = [for vm in module.windows_vm : vm.os_version]
}
output windows_os_version_latest {
    value                      = [for vm in module.windows_vm : vm.os_version_latest]
}
output windows_new_os_version_available {
    value                      = [for vm in module.windows_vm : "NEW WINDOWS VERSION AVAILABLE: ${vm.os_latest_version}" if vm.os_version != vm.os_version_latest]
}
output windows_vm_id {
    value                      = [for vm in module.windows_vm : vm.vm_id]
}
