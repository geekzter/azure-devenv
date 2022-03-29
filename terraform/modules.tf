module region_network {
  source                       = "./modules/region-network"
  resource_group_name          = azurerm_resource_group.vm_resource_group.name
  location                     = each.value
  tags                         = azurerm_resource_group.vm_resource_group.tags

  address_space                = cidrsubnet(var.address_space,4,index(var.locations,each.value))
  admin_cidr_ranges            = local.admin_cidr_ranges
  deploy_bastion               = var.deploy_bastion && index(var.locations,each.value) == 0
  enable_public_access         = var.enable_public_access
  log_analytics_workspace_id   = local.log_analytics_workspace_id
  private_dns_zone_name        = azurerm_private_dns_zone.internal_dns.name
  vpn_range                    = var.vpn_range

  for_each                     = toset(var.locations)
  depends_on                   = [time_sleep.script_wrapper_check]
}

module linux_vm {
  source                       = "./modules/linux-virtual-machine"

  admin_cidr_ranges            = local.admin_cidr_ranges
  user_name                    = var.admin_username
  user_password                = local.password
  bootstrap_branch             = var.bootstrap_branch
  dependency_monitor           = var.deploy_azure_monitor_extensions
  deploy_azure_monitor_extensions = var.deploy_azure_monitor_extensions
  domain                       = var.vm_domain
  disk_encryption              = var.enable_disk_encryption
  diagnostics_storage_id       = module.region_network[each.key].diagnostics_storage_id
  dns_zone_id                  = var.dns_zone_id
  enable_aad_login             = var.enable_aad_login
  enable_accelerated_networking = false
  enable_dns_proxy             = false # var.deploy_vpn
  enable_policy_extension      = var.enable_policy_extensions
  enable_public_access         = var.enable_public_access
  enable_security_center       = var.enable_policy_extensions
  enable_vm_diagnostics        = var.enable_vm_diagnostics
  environment_variables        = var.environment_variables
  git_email                    = var.git_email
  git_name                     = var.git_name
  install_tools                = var.install_tools
  key_vault_id                 = azurerm_key_vault.vault.id
  location                     = each.value
  log_analytics_workspace_id   = local.log_analytics_workspace_id
  moniker                      = "l"
  network_watcher              = var.deploy_azure_monitor_extensions
  os_image_id                  = var.linux_os_image_id
  os_offer                     = var.linux_os_offer
  os_publisher                 = var.linux_os_publisher
  os_sku                       = var.linux_os_sku
  os_version                   = var.linux_os_version
  prepare_host                 = var.prepare_host
  private_dns_zone             = azurerm_private_dns_zone.internal_dns.name
  shutdown_time                = var.shutdown_time
  ssh_private_key              = var.ssh_private_key
  ssh_public_key               = var.ssh_public_key
  tags                         = azurerm_resource_group.vm_resource_group.tags
  terraform_cidr               = local.terraform_cidr
  timezone                     = var.timezone
  resource_group_name          = azurerm_resource_group.vm_resource_group.name
  user_assigned_identity_id    = azurerm_user_assigned_identity.service_principal.id
  virtual_network_has_gateway  = var.deploy_vpn
  vm_size                      = var.linux_vm_size
  vm_subnet_id                 = module.region_network[each.key].vm_subnet_id

  for_each                     = var.deploy_linux ? toset(var.locations) : toset([])
  depends_on                   = [
    azurerm_key_vault.vault,
    azurerm_log_analytics_linked_service.automation,
    azurerm_log_analytics_solution.security_center,
    module.region_network,
    time_sleep.script_wrapper_check
  ]
}

module windows_vm {
  source                       = "./modules/windows-virtual-machine"

  admin_cidr_ranges            = local.admin_cidr_ranges
  admin_username               = var.admin_username
  admin_password               = local.password
  bg_info                      = true
  bootstrap_branch             = var.bootstrap_branch
  dependency_monitor           = var.deploy_azure_monitor_extensions
  deploy_azure_monitor_extensions = var.deploy_azure_monitor_extensions
  disk_encryption              = var.enable_disk_encryption
  diagnostics_storage_id       = module.region_network[each.key].diagnostics_storage_id
  dns_zone_id                  = var.dns_zone_id
  enable_aad_login             = var.enable_aad_login
  enable_accelerated_networking = var.windows_accelerated_networking
  enable_policy_extension      = var.enable_policy_extensions
  enable_public_access         = var.enable_public_access
  enable_security_center       = var.enable_policy_extensions
  enable_vm_diagnostics        = var.enable_vm_diagnostics
  environment_variables        = var.environment_variables
  git_email                    = var.git_email
  git_name                     = var.git_name
  key_vault_id                 = azurerm_key_vault.vault.id
  location                     = each.value
  log_analytics_workspace_id   = local.log_analytics_workspace_id
  moniker                      = "w"
  network_watcher              = var.deploy_azure_monitor_extensions
  os_image_id                  = var.windows_os_image_id
  os_offer                     = var.windows_os_offer
  os_publisher                 = var.windows_os_publisher
  os_sku                       = var.windows_os_sku
  os_version                   = var.windows_os_version
  packages                     = var.install_tools ? ["Developer"] : ["None"]
  prepare_host                 = var.prepare_host
  private_dns_zone             = azurerm_private_dns_zone.internal_dns.name
  resource_group_name          = azurerm_resource_group.vm_resource_group.name
  tags                         = azurerm_resource_group.vm_resource_group.tags
  shutdown_time                = var.shutdown_time
  timezone                     = var.timezone
  user_assigned_identity_id    = azurerm_user_assigned_identity.service_principal.id
  virtual_network_has_gateway  = var.deploy_vpn
  vm_size                      = var.windows_vm_size
  vm_subnet_id                 = module.region_network[each.key].vm_subnet_id

  for_each                     = var.deploy_windows ? toset(var.locations) : toset([])
  depends_on                   = [
    azurerm_key_vault.vault,
    azurerm_log_analytics_linked_service.automation,
    azurerm_log_analytics_solution.security_center,
    azurerm_role_assignment.terraform_storage_owner,
    module.region_network,
    time_sleep.script_wrapper_check
  ]
}

module vpn {
  source                       = "./modules/p2s-vpn"
  resource_group_id            = azurerm_resource_group.vm_resource_group.id
  location                     = azurerm_resource_group.vm_resource_group.location
  tags                         = azurerm_resource_group.vm_resource_group.tags

  dns_ip_addresses             = var.deploy_linux ? [module.linux_vm[azurerm_resource_group.vm_resource_group.location].private_ip_address] : []
  log_analytics_workspace_id   = local.log_analytics_workspace_id
  organization                 = var.organization
  virtual_network_id           = module.region_network[azurerm_resource_group.vm_resource_group.location].virtual_network_id
  subnet_range                 = cidrsubnet(module.region_network[azurerm_resource_group.vm_resource_group.location].address_space,11,4)
  vpn_range                    = var.vpn_range

  count                        = var.deploy_vpn ? 1 : 0

  depends_on                   = [
    time_sleep.script_wrapper_check
  ]
}