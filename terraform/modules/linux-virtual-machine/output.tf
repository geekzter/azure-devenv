output cloud_config {
    value                      = data.cloudinit_config.user_data.rendered
}
output computer_name {
    value                      = local.computer_name
}
output name {
    value                      = local.vm_name
}
output os_image_id {
    value                      = azurerm_linux_virtual_machine.vm.source_image_id
}
output os_sku {
    value                      = length(azurerm_linux_virtual_machine.vm.source_image_reference) == 0 ? null : azurerm_linux_virtual_machine.vm.source_image_reference.0.sku
}
output os_version {
    value                      = length(azurerm_linux_virtual_machine.vm.source_image_reference) == 0 ? null : azurerm_linux_virtual_machine.vm.source_image_reference.0.version
}
output os_version_latest {
    value                      = length(azurerm_linux_virtual_machine.vm.source_image_reference) == 0 ? null : local.os_version_latest
}
output private_ip_address {
    value                      = azurerm_network_interface.nic.private_ip_address
}
output private_fqdn {
    value                      = replace(azurerm_private_dns_a_record.computer_name.fqdn,"/\\W*$/","")
}
output public_ip_id {
    value                      = azurerm_public_ip.pip.id
}
output public_ip_address {
    value                      = azurerm_public_ip.pip.ip_address
}
output public_fqdn {
    value                      = local.dns_zone_rg != null ? replace(azurerm_dns_a_record.fqdn.0.fqdn,"/\\W*$/","") : azurerm_public_ip.pip.fqdn
}
output vm_id {
    value                      = azurerm_linux_virtual_machine.vm.id
}
