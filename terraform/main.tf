locals {
  address_space                = "10.16.0.0/12"
  config_directory             = "${formatdate("YYYY",timestamp())}/${formatdate("MM",timestamp())}/${formatdate("DD",timestamp())}/${formatdate("hhmm",timestamp())}"
  dns_zone_name                = try(element(split("/",var.dns_zone_id),length(split("/",var.dns_zone_id))-1),null)
  dns_zone_rg                  = try(element(split("/",var.dns_zone_id),length(split("/",var.dns_zone_id))-5),null)
  password                     = ".Az9${random_string.password.result}"
  # peering_pairs                = [for pair in setproduct(var.locations,var.locations) : pair if pair[0] != pair[1]]
  peering_pairs_main_region    = [for pair in setproduct(var.locations,var.locations) : pair if (pair[0] != pair[1]) && (pair[0] == azurerm_resource_group.vm_resource_group.location)]
  peering_pairs_other_regions  = [for pair in setproduct(var.locations,var.locations) : pair if (pair[0] != pair[1]) && (pair[0] != azurerm_resource_group.vm_resource_group.location)]
  suffix                       = random_string.suffix.result

  # Networking
  ipprefix                     = jsondecode(chomp(data.http.localpublicprefix.body)).data.prefix
  admin_cidr_ranges            = concat([for range in var.admin_ip_ranges : cidrsubnet(range,0,0)],tolist([local.ipprefix])) # Make sure ranges have correct base address
}

# Data sources
data azurerm_client_config current {}

data http localpublicip {
# Get public IP address of the machine running this terraform template
  url                          = "http://ipinfo.io/ip"
}

data http localpublicprefix {
# Get public IP prefix of the machine running this terraform template
  url                          = "https://stat.ripe.net/data/network-info/data.json?resource=${chomp(data.http.localpublicip.body)}"
}

# Random resource suffix, this will prevent name collisions when creating resources in parallel
resource random_string suffix {
  length                       = 4
  upper                        = false
  lower                        = true
  number                       = false
  special                      = false
}

# Random password generator
resource random_string password {
  length                       = 12
  upper                        = true
  lower                        = true
  number                       = true
  special                      = true
# override_special             = "!@#$%&*()-_=+[]{}<>:?" # default
# Avoid characters that may cause shell scripts to break
  override_special             = "." 
}

resource azurerm_resource_group vm_resource_group {
  name                         = "dev-${terraform.workspace}-${local.suffix}"
  location                     = var.locations[0]
  tags                         = map(
      "application",             "Development Environment",
      "environment",             "dev",
      "provisioner",             "terraform",
      "repository",              basename(abspath("${path.root}/..")),
      "shutdown",                "true",
      "suffix",                  local.suffix,
      "workspace",               terraform.workspace
  )
}

resource azurerm_role_assignment vm_admin {
  scope                        = azurerm_resource_group.vm_resource_group.id
  role_definition_name         = "Virtual Machine Administrator Login"
  principal_id                 = var.admin_object_id

  count                        = var.admin_object_id != null ? 1 : 0
}

resource azurerm_virtual_network_peering main2other {
  name                         = "${module.region_network[local.peering_pairs_main_region[count.index][0]].virtual_network_name}-${local.peering_pairs_main_region[count.index][1]}-peering"
  resource_group_name          = azurerm_resource_group.vm_resource_group.name
  virtual_network_name         = module.region_network[local.peering_pairs_main_region[count.index][0]].virtual_network_name
  remote_virtual_network_id    = module.region_network[local.peering_pairs_main_region[count.index][1]].virtual_network_id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = var.deploy_vpn
  use_remote_gateways          = (var.deploy_vpn && (local.peering_pairs_main_region[count.index][1] == azurerm_resource_group.vm_resource_group.location)) ? true : false

  count                        = var.global_vnet_peering ? length(local.peering_pairs_main_region) : 0

  depends_on                   = [module.vpn]
}

resource azurerm_virtual_network_peering global_peering {
  name                         = "${module.region_network[local.peering_pairs_other_regions[count.index][0]].virtual_network_name}-${local.peering_pairs_other_regions[count.index][1]}-peering"
  resource_group_name          = azurerm_resource_group.vm_resource_group.name
  virtual_network_name         = module.region_network[local.peering_pairs_other_regions[count.index][0]].virtual_network_name
  remote_virtual_network_id    = module.region_network[local.peering_pairs_other_regions[count.index][1]].virtual_network_id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = (var.deploy_vpn && (local.peering_pairs_other_regions[count.index][0] == azurerm_resource_group.vm_resource_group.location)) ? true : false
  use_remote_gateways          = (var.deploy_vpn && (local.peering_pairs_other_regions[count.index][1] == azurerm_resource_group.vm_resource_group.location)) ? true : false

  count                        = var.global_vnet_peering ? length(local.peering_pairs_other_regions) : 0

  depends_on                   = [
    azurerm_virtual_network_peering.main2other,
    module.vpn
  ]
}

# Private DNS
resource azurerm_private_dns_zone internal_dns {
  name                         = var.vm_domain
  resource_group_name          = azurerm_resource_group.vm_resource_group.name

  tags                         = azurerm_resource_group.vm_resource_group.tags
}

resource azurerm_key_vault vault {
  name                         = "${azurerm_resource_group.vm_resource_group.name}-vault"
  location                     = azurerm_resource_group.vm_resource_group.location
  resource_group_name          = azurerm_resource_group.vm_resource_group.name
  tenant_id                    = data.azurerm_client_config.current.tenant_id

  enabled_for_disk_encryption  = true
  purge_protection_enabled     = false
  sku_name                     = "premium"

  # Grant access to self
  access_policy {
    tenant_id                  = data.azurerm_client_config.current.tenant_id
    object_id                  = data.azurerm_client_config.current.object_id

    key_permissions            = [
                                "create",
                                "delete",
                                "get",
                                "list",
                                "purge",
                                "recover",
                                "unwrapkey",
                                "wrapkey",
    ]
    secret_permissions         = [
                                "delete",
                                "get",
                                "list",
                                "purge",
                                "set",
    ]
  }

  # Grant access to admin, if defined
  dynamic "access_policy" {
    for_each = range(var.admin_object_id != null && var.admin_object_id != "" ? 1 : 0) 
    content {
      tenant_id                = data.azurerm_client_config.current.tenant_id
      object_id                = var.admin_object_id

      key_permissions          = [
                                "create",
                                "get",
                                "list",
                                "purge",
      ]

      secret_permissions       = [
                                "list",
                                "purge",
                                "set",
      ]
    }
  }

  network_acls {
    default_action             = "Deny"
    # When enabled_for_disk_encryption is true, network_acls.bypass must include "AzureServices"
    bypass                     = "AzureServices"
    ip_rules                   = [
                                  local.ipprefix
    ]
    virtual_network_subnet_ids = [for vnet in module.region_network : vnet.vm_subnet_id]
  }

  tags                         = azurerm_resource_group.vm_resource_group.tags
}

# Useful when using Bastion
resource azurerm_key_vault_secret ssh_private_key {
  name                         = "ssh-private-key"
  value                        = file(var.ssh_private_key)
  key_vault_id                 = azurerm_key_vault.vault.id
}

resource azurerm_ssh_public_key ssh_key {
  name                         = azurerm_resource_group.vm_resource_group.name
  location                     = azurerm_resource_group.vm_resource_group.location
  resource_group_name          = azurerm_resource_group.vm_resource_group.name
  public_key                   = file(var.ssh_public_key)
}

resource azurerm_storage_account automation_storage {
  name                         = "${lower(replace(azurerm_resource_group.vm_resource_group.name,"-",""))}${local.suffix}aut"
  location                     = azurerm_resource_group.vm_resource_group.location
  resource_group_name          = azurerm_resource_group.vm_resource_group.name
  account_kind                 = "StorageV2"
  account_tier                 = "Standard"
  account_replication_type     = "LRS"
  allow_blob_public_access     = true
  enable_https_traffic_only    = true

  tags                         = azurerm_resource_group.vm_resource_group.tags
}

resource azurerm_storage_container scripts {
  name                         = "scripts"
  storage_account_name         = azurerm_storage_account.automation_storage.name
  container_access_type        = "container"
}

resource azurerm_storage_container configuration {
  name                         = "configuration"
  storage_account_name         = azurerm_storage_account.automation_storage.name
  container_access_type        = "private"
}

resource azurerm_role_assignment terraform_storage_owner {
  scope                        = azurerm_storage_account.automation_storage.id
  role_definition_name         = "Storage Blob Data Contributor"
  principal_id                 = data.azurerm_client_config.current.object_id
}

resource azurerm_storage_blob terraform_backend_configuration {
  name                         = "${local.config_directory}/backend.tf"
  storage_account_name         = azurerm_storage_account.automation_storage.name
  storage_container_name       = azurerm_storage_container.configuration.name
  type                         = "Block"
  source                       = "${path.root}/backend.tf"

  count                        = fileexists("${path.root}/backend.tf") ? 1 : 0
  depends_on                   = [azurerm_role_assignment.terraform_storage_owner]
}

resource azurerm_storage_blob terraform_auto_vars_configuration {
  name                         = "${local.config_directory}/config.auto.tfvars"
  storage_account_name         = azurerm_storage_account.automation_storage.name
  storage_container_name       = azurerm_storage_container.configuration.name
  type                         = "Block"
  source                       = "${path.root}/config.auto.tfvars"

  count                        = fileexists("${path.root}/config.auto.tfvars") ? 1 : 0
  depends_on                   = [azurerm_role_assignment.terraform_storage_owner]
}

resource azurerm_storage_blob terraform_workspace_vars_configuration {
  name                         = "${local.config_directory}/${terraform.workspace}.tfvars"
  storage_account_name         = azurerm_storage_account.automation_storage.name
  storage_container_name       = azurerm_storage_container.configuration.name
  type                         = "Block"
  source                       = "${path.root}/${terraform.workspace}.tfvars"

  count                        = fileexists("${path.root}/${terraform.workspace}.tfvars") ? 1 : 0
  depends_on                   = [azurerm_role_assignment.terraform_storage_owner]
}

module region_network {
  source                       = "./modules/region-network"
  resource_group_name          = azurerm_resource_group.vm_resource_group.name
  location                     = each.value
  tags                         = azurerm_resource_group.vm_resource_group.tags

  address_space                = cidrsubnet(local.address_space,4,index(var.locations,each.value))
  private_dns_zone_name        = azurerm_private_dns_zone.internal_dns.name

  for_each                     = toset(var.locations)
}

module linux_vm {
  source                       = "./modules/linux-virtual-machine"

  admin_cidr_ranges            = local.admin_cidr_ranges
  user_name                    = var.admin_username
  user_password                = local.password
  bootstrap                    = var.linux_bootstrap
  dependency_monitor           = true
  domain                       = var.vm_domain
  diagnostics                  = true
  disk_encryption              = false
  diagnostics_storage_id       = module.region_network[each.key].diagnostics_storage_id
  dns_zone_id                  = var.dns_zone_id
  enable_aad_login             = false
  enable_accelerated_networking = false
  environment_variables        = var.environment_variables
  git_email                    = var.git_email
  git_name                     = var.git_name
  key_vault_id                 = azurerm_key_vault.vault.id
  location                     = each.value
  log_analytics_workspace_id   = var.log_analytics_workspace_id
  moniker                      = "l"
  network_watcher              = true
  os_offer                     = var.linux_os_offer
  os_publisher                 = var.linux_os_publisher
  os_sku                       = var.linux_os_sku
  os_version                   = var.linux_os_version
  private_dns_zone             = azurerm_private_dns_zone.internal_dns.name
  public_access_enabled        = var.public_access_enabled
  scripts_container_id         = azurerm_storage_container.scripts.id
  shutdown_time                = var.linux_shutdown_time
  ssh_private_key              = var.ssh_private_key
  ssh_public_key               = var.ssh_public_key
  tags                         = azurerm_resource_group.vm_resource_group.tags
  terraform_cidr               = local.ipprefix
  timezone                     = var.timezone
  resource_group_name          = azurerm_resource_group.vm_resource_group.name
  vm_size                      = var.linux_vm_size
  vm_subnet_id                 = module.region_network[each.key].vm_subnet_id

  for_each                     = toset(var.locations)
  depends_on                   = [module.region_network]
}

module windows_vm {
  source                       = "./modules/windows-virtual-machine"

  aad_login                    = true
  admin_cidr_ranges            = local.admin_cidr_ranges
  admin_username               = var.admin_username
  admin_password               = local.password
  bg_info                      = true
  dependency_monitor           = true
  diagnostics                  = true
  disk_encryption              = false
  diagnostics_storage_id       = module.region_network[each.key].diagnostics_storage_id
  dns_zone_id                  = var.dns_zone_id
  enable_accelerated_networking = var.windows_accelerated_networking
  environment_variables        = var.environment_variables
  git_email                    = var.git_email
  git_name                     = var.git_name
  key_vault_id                 = azurerm_key_vault.vault.id
  location                     = each.value
  log_analytics_workspace_id   = var.log_analytics_workspace_id
  moniker                      = "w"
  network_watcher              = true
  os_sku                       = var.windows_sku
  os_version                   = var.windows_os_version
  private_dns_zone             = azurerm_private_dns_zone.internal_dns.name
  public_access_enabled        = var.public_access_enabled
  scripts_container_id         = azurerm_storage_container.scripts.id
  resource_group_name          = azurerm_resource_group.vm_resource_group.name
  tags                         = azurerm_resource_group.vm_resource_group.tags
  shutdown_time                = var.windows_shutdown_time
  timezone                     = var.timezone
  vm_size                      = var.windows_vm_size
  vm_subnet_id                 = module.region_network[each.key].vm_subnet_id

  for_each                     = toset(var.locations)
  depends_on                   = [module.region_network]
}

module vpn {
  source                       = "./modules/p2s-vpn"
  resource_group_id            = azurerm_resource_group.vm_resource_group.id
  location                     = azurerm_resource_group.vm_resource_group.location
  tags                         = azurerm_resource_group.vm_resource_group.tags

  dns_ip_address               = [module.linux_vm[azurerm_resource_group.vm_resource_group.location].private_ip_address]
  organization                 = var.organization
  virtual_network_id           = module.region_network[azurerm_resource_group.vm_resource_group.location].virtual_network_id
  subnet_range                 = cidrsubnet(module.region_network[azurerm_resource_group.vm_resource_group.location].address_space,11,4)
  vpn_range                    = var.vpn_range

  count                        = var.deploy_vpn ? 1 : 0
}