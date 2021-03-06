output cloud_config {
    value                      = data.cloudinit_config.user_data.rendered
}
output computer_name {
    value                      = local.computer_name
}
output name {
    value                      = local.vm_name
}
output os_version {
    value                      = local.os_version
}
output os_version_latest {
    value                      = local.os_version_latest
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
