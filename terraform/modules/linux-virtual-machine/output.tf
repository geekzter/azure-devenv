output os_sku {
    value                      = data.external.image_info.result.sku
}
output os_version {
    value                      = local.os_version
}
output os_latest_version {
    value                      = data.external.image_info.result.version
}
output os_latest_version_command {
    value                      = join(" ",data.external.image_info.program)
}
output private_ip_address {
    value                      = azurerm_network_interface.nic.private_ip_address
}
output public_ip_id {
    value                      = azurerm_public_ip.pip.id
}
output public_ip_address {
    value                      = azurerm_public_ip.pip.ip_address
}
output public_fqdn {
    value                      = azurerm_public_ip.pip.fqdn
}
output vm_id {
    value                      = azurerm_linux_virtual_machine.vm.id
}
