locals {
  # linux_virtual_machine_data     = jsonencode(module.linux_vm)
  # linux_virtual_machine_data     = jsonencode({
  #   for vm in module.linux_vm : vm.location => vm.vm_id
  # })
  linux_virtual_machine_data     = jsonencode({
    for vm in module.linux_vm : vm.location => {
      id                         : vm.vm_id,
      public_fqdn                : vm.public_fqdn,
      public_ip_address          : vm.public_ip_address
      private_fqdn               : vm.private_fqdn,
      private_ip_address         : vm.private_ip_address
    }
  })
}

resource local_file linux_bastion_script {
  content                      = templatefile("${path.root}/scripts/connect_linux_vm.ps1",
  {
    bastion_id                 = module.region_network[azurerm_resource_group.vm_resource_group.location].bastion_id
    default_location           = azurerm_resource_group.vm_resource_group.location
    locations                  = var.locations
    user_name                  = var.admin_username
    ssh_private_key            = var.ssh_private_key
    virtual_machine_data       = local.linux_virtual_machine_data
  })
  filename                     = "${path.root}/../data/${terraform.workspace}/connect_linux_vm.ps1"
}

resource local_file windows_bastion_script {
  content                      = templatefile("${path.root}/scripts/connect_windows_vm.ps1",
  {
    bastion_id                 = module.region_network[azurerm_resource_group.vm_resource_group.location].bastion_id
    private_ip_address         = module.linux_vm[each.value].public_ip_address
    private_fqdn               = module.linux_vm[each.value].public_fqdn
    public_ip_address          = module.linux_vm[each.value].public_ip_address
    public_fqdn                = module.linux_vm[each.value].public_fqdn
    resource_group_name        = azurerm_resource_group.vm_resource_group.name
    user_name                  = var.admin_username
    ssh_private_key            = var.ssh_private_key
    vm_id                      = module.linux_vm[each.value].vm_id
  })
  filename                     = "${path.root}/../data/${terraform.workspace}/connect_windows_vm_${each.value}.ps1"

  for_each                     = var.deploy_bastion ? toset(var.locations) : toset([])
}