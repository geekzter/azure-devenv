locals {
  dns_zone_name                = element(split("/",var.dns_zone_id),length(split("/",var.dns_zone_id))-1)
  dns_zone_rg                  = element(split("/",var.dns_zone_id),length(split("/",var.dns_zone_id))-5)
  password                     = ".Az9${random_string.password.result}"
  suffix                       = random_string.suffix.result
  tags                         = map(
      "application",             "Development Environment",
      "environment",             "dev",
      "provisioner",             "terraform",
      "suffix",                  local.suffix,
      "workspace",               terraform.workspace
  )
}

# Data sources
data azurerm_client_config current {}

data azurerm_resource_group development_resource_group {
  name                         = var.development_resource_group
}

data azurerm_virtual_network development_network {
  name                         = var.development_network
  resource_group_name          = data.azurerm_resource_group.development_resource_group.name
}

data azurerm_subnet vm_subnet {
  name                         = var.vm_subnet
  virtual_network_name         = data.azurerm_virtual_network.development_network.name
  resource_group_name          = data.azurerm_resource_group.development_resource_group.name
}

data azurerm_dns_zone dns {
  name                         = local.dns_zone_name
  resource_group_name          = local.dns_zone_rg
}

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
  location                     = data.azurerm_resource_group.development_resource_group.location
  tags                         = local.tags
}

resource azurerm_role_assignment vm_admin {
  scope                        = azurerm_resource_group.vm_resource_group.id
  role_definition_name         = "Virtual Machine Administrator Login"
  principal_id                 = var.admin_object_id

  count                        = var.admin_object_id != null ? 1 : 0
}

resource azurerm_key_vault vault {
  name                         = "${azurerm_resource_group.vm_resource_group.name}-vault"
  location                     = azurerm_resource_group.vm_resource_group.location
  resource_group_name          = azurerm_resource_group.vm_resource_group.name
  tenant_id                    = data.azurerm_client_config.current.tenant_id

  enabled_for_disk_encryption  = true
  purge_protection_enabled     = true
  sku_name                     = "premium"
  soft_delete_enabled          = true

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
    virtual_network_subnet_ids = [
                                  data.azurerm_subnet.vm_subnet.id
    ]
  }

  tags                         = local.tags
}

resource azurerm_storage_account automation_storage {
  name                         = "${lower(replace(data.azurerm_resource_group.development_resource_group.name,"-",""))}${local.suffix}aut"
  location                     = data.azurerm_resource_group.development_resource_group.location
  resource_group_name          = data.azurerm_resource_group.development_resource_group.name
  account_kind                 = "StorageV2"
  account_tier                 = "Standard"
  account_replication_type     = "LRS"
  enable_https_traffic_only    = true

  tags                         = local.tags
}

resource azurerm_storage_container scripts {
  name                         = "scripts"
  storage_account_name         = azurerm_storage_account.automation_storage.name
  container_access_type        = "container"
}

resource azurerm_storage_account diagnostics_storage {
  name                         = "${lower(replace(data.azurerm_resource_group.development_resource_group.name,"-",""))}${local.suffix}diag"
  location                     = data.azurerm_resource_group.development_resource_group.location
  resource_group_name          = data.azurerm_resource_group.development_resource_group.name
  account_kind                 = "StorageV2"
  account_tier                 = "Standard"
  account_replication_type     = "LRS"
  enable_https_traffic_only    = true

  tags                         = local.tags
}

module windows_vm {
  source                       = "./modules/windows-virtual-machine"

  aad_login                    = true
  admin_username               = var.admin_username
  admin_password               = local.password
  bg_info                      = true
  dependency_monitor           = true
  diagnostics                  = true
  disk_encryption              = true
  diagnostics_storage_id       = azurerm_storage_account.diagnostics_storage.id
  enable_accelerated_networking = true
  git_email                    = var.git_email
  git_name                     = var.git_name
  key_vault_id                 = azurerm_key_vault.vault.id
  log_analytics_workspace_id   = var.log_analytics_workspace_id
  name                         = "windev"
  network_watcher              = true
  scripts_container_id         = azurerm_storage_container.scripts.id
  resource_group_name          = azurerm_resource_group.vm_resource_group.name
  vm_size                      = var.windows_vm_size
  vm_subnet_id                 = data.azurerm_subnet.vm_subnet.id

  tags                         = local.tags
}

locals {
  vm_name                      = element(split("/",module.windows_vm.vm_id),length(split("/",module.windows_vm.vm_id))-1)
}

resource azurerm_dns_cname_record windows_fqdn {
  name                         = "${local.vm_name}-cname"
  zone_name                    = data.azurerm_dns_zone.dns.name
  resource_group_name          = data.azurerm_dns_zone.dns.resource_group_name
  ttl                          = 300
  record                       = module.windows_vm.public_fqdn

  tags                         = local.tags
}