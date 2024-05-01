locals {
  dns_zone_name                = try(element(split("/",var.dns_zone_id),length(split("/",var.dns_zone_id))-1),null)
  dns_zone_rg                  = try(element(split("/",var.dns_zone_id),length(split("/",var.dns_zone_id))-5),null)
  owner                        = var.application_owner != "" ? var.application_owner : data.azuread_client_config.current.object_id
  password                     = ".Az9${random_string.password.result}"
  # peering_pairs                = [for pair in setproduct(var.locations,var.locations) : pair if pair[0] != pair[1]]
  peering_pairs_main_region    = [for pair in setproduct(var.locations,var.locations) : pair if (pair[0] != pair[1]) && (pair[0] == azurerm_resource_group.vm_resource_group.location)]
  peering_pairs_other_regions  = [for pair in setproduct(var.locations,var.locations) : pair if (pair[0] != pair[1]) && (pair[0] != azurerm_resource_group.vm_resource_group.location)]
  suffix                       = random_string.suffix.result

  # Networking
  terraform_cidr               = "${chomp(data.http.terraform_ip_address.response_body)}/32"
  # terraform_cidr               = local.terraform_ip_prefix # Too broad
  terraform_ip_address         = data.http.terraform_ip_address.response_body
  terraform_ip_prefix          = jsondecode(chomp(data.http.terraform_ip_prefix.response_body)).data.prefix
  # admin_cidr_ranges            = sort(distinct(concat([for range in var.admin_ip_ranges : cidrsubnet(range,0,0)],tolist([local.terraform_ip_prefix])))) # Make sure ranges have correct base address
  admin_cidr_ranges            = sort(distinct(concat([for range in var.admin_ip_ranges : cidrsubnet(range,0,0)],tolist([local.terraform_cidr])))) # Make sure ranges have correct base address
}

# Data sources
data azuread_client_config current {}
data azurerm_client_config current {}

data http terraform_ip_address {
# Get public IP address of the machine running this terraform template
  url                          = "https://api.ipify.org"
}

data http terraform_ip_prefix {
# Get public IP prefix of the machine running this terraform template
  url                          = "https://stat.ripe.net/data/network-info/data.json?resource=${local.terraform_ip_address}"
}

# Random resource suffix, this will prevent name collisions when creating resources in parallel
resource random_string suffix {
  length                       = 4
  upper                        = false
  lower                        = true
  numeric                      = false
  special                      = false
}

# Random password generator
resource random_string password {
  length                       = 12
  upper                        = true
  lower                        = true
  numeric                       = true
  special                      = true
# override_special             = "!@#$%&*()-_=+[]{}<>:?" # default
# Avoid characters that may cause shell scripts to break
  override_special             = "." 
}

resource null_resource script_wrapper_check {
  # Always run this
  triggers                     = {
    always_run                 = timestamp()
  }

  provisioner local-exec {
    command                    = "echo Terraform should be called from deploy.ps1, hit Ctrl-C to exit"
  }

  count                        = var.script_wrapper_check ? 1 : 0
}

resource time_sleep script_wrapper_check {
  triggers                     = {
    always_run                 = timestamp()
  }

  create_duration              = "999999h"

  count                        = var.script_wrapper_check ? 1 : 0
  depends_on                   = [null_resource.script_wrapper_check]
}

resource azurerm_resource_group vm_resource_group {
  name                         = terraform.workspace == "default" ? "${var.resource_prefix}-${local.suffix}" : "${var.resource_prefix}-${terraform.workspace}-${local.suffix}"
  location                     = var.locations[0]
  tags                         = merge(
    {
      application              = var.application_name
      environment              = "dev"
      owner                    = local.owner
      provisioner              = "terraform"
      provisioner-client-id    = data.azuread_client_config.current.client_id
      provisioner-object-id    = data.azuread_client_config.current.object_id
      repository               = "azure-devenv"
      runid                    = var.run_id
      shutdown                 = "true"
      suffix                   = local.suffix
      workspace                = terraform.workspace
    },
    var.tags
  )  
  depends_on                   = [time_sleep.script_wrapper_check]
}

resource azurerm_role_assignment vm_admin {
  scope                        = azurerm_resource_group.vm_resource_group.id
  role_definition_name         = "Virtual Machine Administrator Login"
  principal_id                 = var.admin_object_id != null ? var.admin_object_id : data.azuread_client_config.current.object_id

  count                        = var.configure_access_control ? 1 : 0 
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
  name                         = "${azurerm_resource_group.vm_resource_group.name}-vlt"
  location                     = azurerm_resource_group.vm_resource_group.location
  resource_group_name          = azurerm_resource_group.vm_resource_group.name
  tenant_id                    = data.azuread_client_config.current.tenant_id

  enabled_for_disk_encryption  = true
  purge_protection_enabled     = false
  sku_name                     = "premium"

  # Grant access to self
  access_policy {
    tenant_id                  = data.azuread_client_config.current.tenant_id
    object_id                  = data.azuread_client_config.current.object_id

    key_permissions            = [
                                "Create",
                                "Delete",
                                "Get",
                                "GetRotationPolicy",
                                "List",
                                "Purge",
                                "Recover",
                                "UnwrapKey",
                                "WrapKey",
    ]
    secret_permissions         = [
                                "Delete",
                                "Get",
                                "List",
                                "Purge",
                                "Set",
    ]
  }

  # Grant access to admin, if defined
  dynamic "access_policy" {
    for_each = range(var.admin_object_id != null && var.admin_object_id != "" ? 1 : 0) 
    content {
      tenant_id                = data.azurerm_client_config.current.tenant_id
      object_id                = var.admin_object_id

      key_permissions          = [
                                "Create",
                                "Get",
                                "GetRotationPolicy",
                                "List",
                                "Purge",
      ]

      secret_permissions       = [
                                "List",
                                "Purge",
                                "Set",
      ]
    }
  }

  network_acls {
    default_action             = "Deny"
    # When enabled_for_disk_encryption is true, network_acls.bypass must include "AzureServices"
    bypass                     = "AzureServices"
    ip_rules                   = local.admin_cidr_ranges
    virtual_network_subnet_ids = [for vnet in module.region_network : vnet.vm_subnet_id]
  }

  tags                         = azurerm_resource_group.vm_resource_group.tags
}
resource azurerm_monitor_diagnostic_setting key_vault {
  name                         = "${azurerm_key_vault.vault.name}-logs"
  target_resource_id           = azurerm_key_vault.vault.id
  log_analytics_workspace_id   = local.log_analytics_workspace_id

  enabled_log {
    category                   = "AuditEvent"
  }

  metric {
    category                   = "AllMetrics"
  }
}

# Useful when using Bastion
resource azurerm_key_vault_secret ssh_private_key {
  name                         = "ssh-private-key"
  value                        = file(var.ssh_private_key)
  key_vault_id                 = azurerm_key_vault.vault.id
}
resource azurerm_key_vault_secret user_name {
  name                         = "user-name"
  value                        = var.admin_username
  key_vault_id                 = azurerm_key_vault.vault.id
}
resource azurerm_key_vault_secret user_password {
  name                         = "user-password"
  value                        = local.password
  key_vault_id                 = azurerm_key_vault.vault.id
}
resource azurerm_ssh_public_key ssh_key {
  name                         = azurerm_resource_group.vm_resource_group.name
  location                     = azurerm_resource_group.vm_resource_group.location
  resource_group_name          = azurerm_resource_group.vm_resource_group.name
  public_key                   = file(var.ssh_public_key)

  tags                         = azurerm_resource_group.vm_resource_group.tags
}

resource azurerm_storage_account automation_storage {
  name                         = "${lower(replace(azurerm_resource_group.vm_resource_group.name,"-",""))}${local.suffix}aut"
  location                     = azurerm_resource_group.vm_resource_group.location
  resource_group_name          = azurerm_resource_group.vm_resource_group.name
  account_kind                 = "StorageV2"
  account_tier                 = "Standard"
  account_replication_type     = "LRS"
  allow_nested_items_to_be_public = false
  blob_properties {
    delete_retention_policy {
      days                     = 365
    }
  }
  enable_https_traffic_only    = true

  tags                         = azurerm_resource_group.vm_resource_group.tags
}

resource azurerm_role_assignment terraform_storage_owner {
  scope                        = azurerm_storage_account.automation_storage.id
  role_definition_name         = "Storage Blob Data Contributor"
  principal_id                 = data.azuread_client_config.current.object_id

  count                        = var.configure_access_control ? 1 : 0 
}
# Wait to prevent race condition during storage access
resource time_sleep terraform_storage_owner {
  depends_on                   = [azurerm_role_assignment.terraform_storage_owner]
  destroy_duration             = "30s"

  count                        = var.configure_access_control ? 1 : 0 
}

resource azurerm_user_assigned_identity service_principal {
  name                         = azurerm_resource_group.vm_resource_group.name
  resource_group_name          = azurerm_resource_group.vm_resource_group.name
  location                     = azurerm_resource_group.vm_resource_group.location

  tags                         = azurerm_resource_group.vm_resource_group.tags
}

resource null_resource disk_encryption_status {
  # Always run this
  triggers                     = {
    always_run                 = timestamp()
  }

  provisioner local-exec {
    command                    = "az vm encryption show --ids $(az vm list -g ${azurerm_resource_group.vm_resource_group.name} --subscription ${data.azurerm_client_config.current.subscription_id} --query '[].id' -o tsv) --query '[].{name:disks[0].name, status:disks[0].statuses[0].displayStatus}' -o table"
  }

  count                        = var.enable_disk_encryption ? 1 : 0
  depends_on                   = [
    module.linux_vm,
    module.windows_vm,
  ]
}