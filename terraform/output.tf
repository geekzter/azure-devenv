output admin_password {
  sensitive                    = true
  value                        = local.password
}
output admin_username {
  sensitive                    = true
  value                        = var.admin_username
}

output bastion_fqdn {
    value                      = var.deploy_bastion ? module.region_network[azurerm_resource_group.vm_resource_group.location].bastion_fqdn : null
}
output bastion_id {
    value                      = var.deploy_bastion ? module.region_network[azurerm_resource_group.vm_resource_group.location].bastion_id : null
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

output dns_server_address {
  value                        = var.deploy_vpn && var.deploy_linux ? module.linux_vm[azurerm_resource_group.vm_resource_group.location].private_ip_address : null
}

output gateway_id {
  value                        = var.deploy_vpn ? module.vpn.0.gateway_id : null
}

output key_vault_name {
  value                        = azurerm_key_vault.vault.name
}

output linux_cloud_config {
  sensitive                    = true
  value                        = var.deploy_linux ? module.linux_vm[azurerm_resource_group.vm_resource_group.location].cloud_config : null
}
output linux_main_fqdn {
  value                        = var.deploy_linux ? module.linux_vm[azurerm_resource_group.vm_resource_group.location].public_fqdn : null
}
output linux_main_id {
  value                        = var.deploy_linux ? module.linux_vm[azurerm_resource_group.vm_resource_group.location].vm_id : null
}
output linux_os_image_id {
  value                        = var.deploy_linux ? module.linux_vm[azurerm_resource_group.vm_resource_group.location].os_image_id : null
}
output linux_os_sku {
  value                        = var.deploy_linux ? module.linux_vm[azurerm_resource_group.vm_resource_group.location].os_sku : null
}
output linux_os_version {
  value                        = var.deploy_linux ? module.linux_vm[azurerm_resource_group.vm_resource_group.location].os_version : null
}
output linux_os_version_latest {
  value                        = var.deploy_linux ? module.linux_vm[azurerm_resource_group.vm_resource_group.location].os_version_latest : null
}
output linux_new_os_version_available {
  value                        = [for vm in module.linux_vm : "NEW ${var.linux_os_offer} VERSION AVAILABLE: ${vm.os_version_latest}" if vm.os_version != vm.os_version_latest]
}

output log_analytics_workspace_id {
  value                        = local.log_analytics_workspace_id
}

output locations {
  value                        = var.locations
}

output main_location {
  value                        = azurerm_resource_group.vm_resource_group.location
}

output managed_identity_name {
  value                        = azurerm_user_assigned_identity.service_principal.name
}
output managed_identity_object_id {
  description                  = "The Object ID / Principal ID of the Service Principal created as User Assigned Identity"
  value                        = azurerm_user_assigned_identity.service_principal.principal_id
}
output managed_identity_client_id {
  description                  = "The App ID / Client ID of the Service Principal created as User Assigned Identity"
  value                        = azurerm_user_assigned_identity.service_principal.client_id
}

output resource_group_id {
    value                      = azurerm_resource_group.vm_resource_group.id
}
output resource_group_name {
    value                      = azurerm_resource_group.vm_resource_group.name
}
output resource_suffix {
  value                        = local.suffix
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

output ssh_private_key_id {
  value                        = azurerm_key_vault_secret.ssh_private_key.id
}
output ssh_public_key_id {
  value                        = azurerm_ssh_public_key.ssh_key.id
}

output virtual_network_id {
  value                        = {for region in var.locations : region => module.region_network[region].virtual_network_id}
}

output virtual_machine_id {
  value                        = merge(
    {for vm in module.linux_vm : format("linux_%s",vm.location) => vm.vm_id},
    {for vm in module.windows_vm : format("windows_%s",vm.location) => vm.vm_id}
  )
}
output vm_os_version {
  value                        = merge(
    {for vm in module.linux_vm : vm.name => vm.os_version},
    {for vm in module.windows_vm : vm.name => vm.os_version}
  )
}
output vm_private_fqdn {
  value                        = merge(
    {for vm in module.linux_vm : vm.name => vm.private_fqdn},
    {for vm in module.windows_vm : vm.name => vm.private_fqdn}
  )
}
output vm_private_ip_address {
  value                        = merge(
    {for vm in module.linux_vm : vm.name => vm.private_ip_address},
    {for vm in module.windows_vm : vm.name => vm.private_ip_address}
  )
}
output vm_public_fqdn {
  value                        = merge(
    {for vm in module.linux_vm : vm.name => vm.public_fqdn},
    {for vm in module.windows_vm : vm.name => vm.public_fqdn}
  )
}

output windows_main_fqdn {
  value                        = var.deploy_windows ? module.windows_vm[azurerm_resource_group.vm_resource_group.location].public_fqdn : null
}
output windows_os_image_id {
  value                        = var.deploy_windows ? module.windows_vm[azurerm_resource_group.vm_resource_group.location].os_image_id : null
}
output windows_os_sku {
  value                        = var.deploy_windows ? module.windows_vm[azurerm_resource_group.vm_resource_group.location].os_sku : null
}
output windows_os_version {
  value                        = var.deploy_windows ? module.windows_vm[azurerm_resource_group.vm_resource_group.location].os_version : null
}
output windows_os_version_latest {
  value                        = var.deploy_windows ? module.windows_vm[azurerm_resource_group.vm_resource_group.location].os_version_latest : null
}
output windows_new_os_version_available {
  value                        = [for vm in module.windows_vm : "NEW WINDOWS VERSION AVAILABLE: ${vm.os_version_latest}" if vm.os_version != vm.os_version_latest]
}
