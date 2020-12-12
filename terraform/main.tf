locals {
  address_space                = "10.16.0.0/12"
  dns_zone_name                = try(element(split("/",var.dns_zone_id),length(split("/",var.dns_zone_id))-1),null)
  dns_zone_rg                  = try(element(split("/",var.dns_zone_id),length(split("/",var.dns_zone_id))-5),null)
  password                     = ".Az9${random_string.password.result}"
  peering_pairs                = [for pair in setproduct(var.locations,var.locations) : pair if pair[0] != pair[1]]
  short_resource_name          = "dev${local.suffix}"
  suffix                       = random_string.suffix.result
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

resource azurerm_virtual_network development_network {
  name                         = "${azurerm_resource_group.vm_resource_group.name}-${each.value}-network"
  location                     = each.value
  resource_group_name          = azurerm_resource_group.vm_resource_group.name
  address_space                = [cidrsubnet(local.address_space,4,index(var.locations,each.value))]

  tags                         = azurerm_resource_group.vm_resource_group.tags
  for_each                     = toset(var.locations)
}

resource azurerm_subnet vm_subnet {
  name                         = "VirtualMachines"
  virtual_network_name         = azurerm_virtual_network.development_network[each.key].name
  resource_group_name          = azurerm_virtual_network.development_network[each.key].resource_group_name
  address_prefixes             = [cidrsubnet(azurerm_virtual_network.development_network[each.value].address_space[0],8,1)]
  service_endpoints            = [
                                  "Microsoft.KeyVault",
  ]

  for_each                     = toset(var.locations)
}

resource azurerm_virtual_network_peering global_peering {
  name                         = "${azurerm_virtual_network.development_network[local.peering_pairs[count.index][0]].name}-${local.peering_pairs[count.index][1]}-peering"
  resource_group_name          = azurerm_resource_group.vm_resource_group.name
  virtual_network_name         = azurerm_virtual_network.development_network[local.peering_pairs[count.index][0]].name
  remote_virtual_network_id    = azurerm_virtual_network.development_network[local.peering_pairs[count.index][1]].id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true

  # Must be set to false for Global Peering
  allow_gateway_transit        = false

  count                        = var.global_vnet_peering ? length(local.peering_pairs) : 0
}

resource azurerm_key_vault vault {
  name                         = "${azurerm_resource_group.vm_resource_group.name}-vault"
  location                     = azurerm_resource_group.vm_resource_group.location
  resource_group_name          = azurerm_resource_group.vm_resource_group.name
  tenant_id                    = data.azurerm_client_config.current.tenant_id

  enabled_for_disk_encryption  = true
  purge_protection_enabled     = false
  sku_name                     = "premium"
  soft_delete_enabled          = false

  # Grant access to self
  access_policy {
    tenant_id                  = data.azurerm_client_config.current.tenant_id
    object_id                  = data.azurerm_client_config.current.object_id

    key_permissions            = [
                                "create",
                                "get",
                                "delete",
                                "list",
                                "recover",
                                "wrapkey",
                                "unwrapkey"
    ]
    secret_permissions         = [
                                "get",
                                "delete",
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
      ]

      secret_permissions       = [
                                "set",
      ]
    }
  }

  network_acls {
    default_action             = "Deny"
    # When enabled_for_disk_encryption is true, network_acls.bypass must include "AzureServices"
    bypass                     = "AzureServices"
    ip_rules                   = [
                                  jsondecode(chomp(data.http.localpublicprefix.body)).data.prefix
    ]
    virtual_network_subnet_ids = [for subnet in azurerm_subnet.vm_subnet : subnet.id]
  }

  tags                         = azurerm_resource_group.vm_resource_group.tags
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

resource azurerm_storage_account diagnostics_storage {
  name                         = "${local.short_resource_name}${each.value}diag"
  location                     = each.value
  resource_group_name          = azurerm_resource_group.vm_resource_group.name
  account_kind                 = "StorageV2"
  account_tier                 = "Standard"
  account_replication_type     = "LRS"
  enable_https_traffic_only    = true

  tags                         = azurerm_resource_group.vm_resource_group.tags

  for_each                     = toset(var.locations)
}

module linux_vm {
  source                       = "./modules/linux-virtual-machine"

  user_name                    = var.admin_username
  user_password                = local.password
  bootstrap                    = var.linux_bootstrap
  dependency_monitor           = true
  domain                       = var.vm_domain
  diagnostics                  = true
  disk_encryption              = false
  diagnostics_storage_id       = azurerm_storage_account.diagnostics_storage[each.value].id
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
  scripts_container_id         = azurerm_storage_container.scripts.id
  ssh_public_key               = var.ssh_public_key
  resource_group_name          = azurerm_resource_group.vm_resource_group.name
  vm_size                      = var.linux_vm_size
  vm_subnet_id                 = azurerm_subnet.vm_subnet[each.key].id

  for_each                     = toset(var.locations)
  tags                         = azurerm_resource_group.vm_resource_group.tags
}

module windows_vm {
  source                       = "./modules/windows-virtual-machine"

  aad_login                    = true
  admin_username               = var.admin_username
  admin_password               = local.password
  bg_info                      = true
  dependency_monitor           = true
  diagnostics                  = true
  disk_encryption              = false
  diagnostics_storage_id       = azurerm_storage_account.diagnostics_storage[each.value].id
  enable_accelerated_networking = true
  environment_variables        = var.environment_variables
  git_email                    = var.git_email
  git_name                     = var.git_name
  key_vault_id                 = azurerm_key_vault.vault.id
  location                     = each.value
  log_analytics_workspace_id   = var.log_analytics_workspace_id
  moniker                      = "w"
  network_watcher              = true
  os_sku_match                 = var.windows_sku_match
  os_version                   = var.windows_os_version
  scripts_container_id         = azurerm_storage_container.scripts.id
  resource_group_name          = azurerm_resource_group.vm_resource_group.name
  vm_size                      = var.windows_vm_size
  vm_subnet_id                 = azurerm_subnet.vm_subnet[each.key].id

  for_each                     = toset(var.locations)
  tags                         = azurerm_resource_group.vm_resource_group.tags
}

# Private DNS
resource azurerm_private_dns_zone internal_dns {
  name                         = var.vm_domain
  resource_group_name          = azurerm_resource_group.vm_resource_group.name

  tags                         = azurerm_resource_group.vm_resource_group.tags
}

resource azurerm_private_dns_zone_virtual_network_link internal_link {
  name                         = "${azurerm_virtual_network.development_network[each.key].name}-internal-link"
  resource_group_name          = azurerm_resource_group.vm_resource_group.name
  private_dns_zone_name        = azurerm_private_dns_zone.internal_dns.name
  virtual_network_id           = azurerm_virtual_network.development_network[each.key].id

  tags                         = azurerm_resource_group.vm_resource_group.tags

  for_each                     = toset(var.locations)
}

resource azurerm_private_dns_a_record linux_vm_computer_name {
  name                         = module.linux_vm[each.key].computer_name
  zone_name                    = azurerm_private_dns_zone.internal_dns.name
  resource_group_name          = azurerm_private_dns_zone.internal_dns.resource_group_name
  ttl                          = 300
  records                      = [module.linux_vm[each.key].private_ip_address]

  tags                         = azurerm_resource_group.vm_resource_group.tags

  for_each                     = toset(var.locations)
}

resource azurerm_private_dns_a_record linux_vm_name {
  name                         = module.linux_vm[each.key].name
  zone_name                    = azurerm_private_dns_zone.internal_dns.name
  resource_group_name          = azurerm_private_dns_zone.internal_dns.resource_group_name
  ttl                          = 300
  records                      = [module.linux_vm[each.key].private_ip_address]

  tags                         = azurerm_resource_group.vm_resource_group.tags

  for_each                     = toset(var.locations)
}

resource azurerm_private_dns_a_record windows_vm_computer_name {
  name                         = module.windows_vm[each.key].computer_name
  zone_name                    = azurerm_private_dns_zone.internal_dns.name
  resource_group_name          = azurerm_private_dns_zone.internal_dns.resource_group_name
  ttl                          = 300
  records                      = [module.windows_vm[each.key].private_ip_address]

  tags                         = azurerm_resource_group.vm_resource_group.tags

  for_each                     = toset(var.locations)
}

resource azurerm_private_dns_a_record windows_vm_name {
  name                         = module.windows_vm[each.key].name
  zone_name                    = azurerm_private_dns_zone.internal_dns.name
  resource_group_name          = azurerm_private_dns_zone.internal_dns.resource_group_name
  ttl                          = 300
  records                      = [module.windows_vm[each.key].private_ip_address]

  tags                         = azurerm_resource_group.vm_resource_group.tags

  for_each                     = toset(var.locations)
}

# Public DNS
data azurerm_dns_zone dns {
  name                         = local.dns_zone_name
  resource_group_name          = local.dns_zone_rg

  count                        = local.dns_zone_name != null ? 1: 0
}

resource azurerm_dns_a_record linux_fqdn {
  name                         = replace(each.value.name,"-${local.suffix}","") # Canonical name
  zone_name                    = data.azurerm_dns_zone.dns.0.name
  resource_group_name          = data.azurerm_dns_zone.dns.0.resource_group_name
  ttl                          = 300
  target_resource_id           = each.value.public_ip_id

  tags                         = azurerm_resource_group.vm_resource_group.tags

  for_each                     = local.dns_zone_name != null ? module.linux_vm : null
}

resource azurerm_dns_a_record windows_fqdn {
  name                         = replace(each.value.name,"-${local.suffix}","") # Canonical name
  zone_name                    = data.azurerm_dns_zone.dns.0.name
  resource_group_name          = data.azurerm_dns_zone.dns.0.resource_group_name
  ttl                          = 300
  target_resource_id           = each.value.public_ip_id

  tags                         = azurerm_resource_group.vm_resource_group.tags

  for_each                     = local.dns_zone_name != null ? module.windows_vm : null
}