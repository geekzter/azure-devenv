locals {
  address_space                = "10.16.0.0/12"
  config_directory             = "${formatdate("YYYY",timestamp())}/${formatdate("MM",timestamp())}/${formatdate("DD",timestamp())}/${formatdate("hhmm",timestamp())}"
  dns_zone_name                = try(element(split("/",var.dns_zone_id),length(split("/",var.dns_zone_id))-1),null)
  dns_zone_rg                  = try(element(split("/",var.dns_zone_id),length(split("/",var.dns_zone_id))-5),null)
  password                     = ".Az9${random_string.password.result}"
  peering_pairs                = [for pair in setproduct(var.locations,var.locations) : pair if pair[0] != pair[1]]
  short_resource_name          = "dev${local.suffix}"
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

resource azurerm_subnet bastion_subnet {
  name                         = "AzureBastionSubnet"
  virtual_network_name         = azurerm_virtual_network.development_network[each.key].name
  resource_group_name          = azurerm_virtual_network.development_network[each.key].resource_group_name
  address_prefixes             = [cidrsubnet(azurerm_virtual_network.development_network[each.value].address_space[0],11,0)]

  for_each                     = toset(var.locations)
}

resource azurerm_public_ip bastion_ip {
  name                         = "${azurerm_virtual_network.development_network[each.key].name}-bastion-ip"
  location                     = each.key
  resource_group_name          = azurerm_virtual_network.development_network[each.key].resource_group_name
  allocation_method            = "Static"
  sku                          = "Standard"

  for_each                     = toset(var.locations)
}

resource azurerm_bastion_host bastion {
  name                         = "${azurerm_virtual_network.development_network[each.key].name}-bastion"
  location                     = each.key
  resource_group_name          = azurerm_virtual_network.development_network[each.key].resource_group_name

  ip_configuration {
    name                       = "configuration"
    subnet_id                  = azurerm_subnet.bastion_subnet[each.key].id
    public_ip_address_id       = azurerm_public_ip.bastion_ip[each.key].id
  }

  for_each                     = toset(var.locations)
}

resource azurerm_virtual_network_peering global_peering {
  name                         = "${azurerm_virtual_network.development_network[local.peering_pairs[count.index][0]].name}-${local.peering_pairs[count.index][1]}-peering"
  resource_group_name          = azurerm_resource_group.vm_resource_group.name
  virtual_network_name         = azurerm_virtual_network.development_network[local.peering_pairs[count.index][0]].name
  remote_virtual_network_id    = azurerm_virtual_network.development_network[local.peering_pairs[count.index][1]].id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = (var.deploy_vpn && (local.peering_pairs[count.index][0] == azurerm_resource_group.vm_resource_group.location)) ? true : false
  use_remote_gateways          = (var.deploy_vpn && (local.peering_pairs[count.index][1] == azurerm_resource_group.vm_resource_group.location)) ? true : false

  count                        = var.global_vnet_peering ? length(local.peering_pairs) : 0

  depends_on                   = [module.vpn]
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
    virtual_network_subnet_ids = [for subnet in azurerm_subnet.vm_subnet : subnet.id]
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

  admin_cidr_ranges            = local.admin_cidr_ranges
  user_name                    = var.admin_username
  user_password                = local.password
  bootstrap                    = var.linux_bootstrap
  dependency_monitor           = true
  domain                       = var.vm_domain
  diagnostics                  = true
  disk_encryption              = false
  diagnostics_storage_id       = azurerm_storage_account.diagnostics_storage[each.value].id
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
  ssh_private_key              = var.ssh_private_key
  ssh_public_key               = var.ssh_public_key
  tags                         = azurerm_resource_group.vm_resource_group.tags
  resource_group_name          = azurerm_resource_group.vm_resource_group.name
  vm_size                      = var.linux_vm_size
  vm_subnet_id                 = azurerm_subnet.vm_subnet[each.key].id

  for_each                     = toset(var.locations)
  depends_on                   = [azurerm_private_dns_zone_virtual_network_link.internal_link]
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
  diagnostics_storage_id       = azurerm_storage_account.diagnostics_storage[each.value].id
  dns_zone_id                  = var.dns_zone_id
  enable_accelerated_networking = true
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
  vm_size                      = var.windows_vm_size
  vm_subnet_id                 = azurerm_subnet.vm_subnet[each.key].id

  for_each                     = toset(var.locations)
  depends_on                   = [azurerm_private_dns_zone_virtual_network_link.internal_link]
}

module vpn {
  source                       = "./modules/p2s-vpn"
  resource_group_id            = azurerm_resource_group.vm_resource_group.id
  location                     = azurerm_resource_group.vm_resource_group.location
  tags                         = azurerm_resource_group.vm_resource_group.tags

  dns_ip_address               = [module.linux_vm[azurerm_resource_group.vm_resource_group.location].private_ip_address]
  organization                 = var.organization
  virtual_network_id           = azurerm_virtual_network.development_network[azurerm_resource_group.vm_resource_group.location].id
  subnet_range                 = cidrsubnet(azurerm_virtual_network.development_network[azurerm_resource_group.vm_resource_group.location].address_space[0],11,4)
  vpn_range                    = var.vpn_range

  count                        = var.deploy_vpn ? 1 : 0
}