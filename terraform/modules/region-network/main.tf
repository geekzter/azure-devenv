
resource azurerm_virtual_network region_network {
  name                         = "${var.resource_group_name}-${var.location}-network"
  location                     = var.location
  resource_group_name          = var.resource_group_name
  address_space                = [var.address_space]

  tags                         = var.tags
}
resource azurerm_monitor_diagnostic_setting region_network {
  name                         = "${azurerm_virtual_network.region_network.name}-logs"
  target_resource_id           = azurerm_virtual_network.region_network.id
  log_analytics_workspace_id   = var.log_analytics_workspace_id

  log {
    category                   = "VMProtectionAlerts"
    enabled                    = true

    retention_policy {
      enabled                  = false
    }
  }

  metric {
    category                   = "AllMetrics"

    retention_policy {
      enabled                  = false
    }
  }
}

resource azurerm_subnet vm_subnet {
  name                         = "VirtualMachines"
  virtual_network_name         = azurerm_virtual_network.region_network.name
  resource_group_name          = azurerm_virtual_network.region_network.resource_group_name
  address_prefixes             = [cidrsubnet(azurerm_virtual_network.region_network.address_space[0],8,1)]
  service_endpoints            = [
                                  "Microsoft.KeyVault",
  ]
}

resource azurerm_subnet bastion_subnet {
  name                         = "AzureBastionSubnet"
  virtual_network_name         = azurerm_virtual_network.region_network.name
  resource_group_name          = azurerm_virtual_network.region_network.resource_group_name
  address_prefixes             = [cidrsubnet(azurerm_virtual_network.region_network.address_space[0],11,0)]

  count                        = var.deploy_bastion ? 1 : 0
}
resource azurerm_public_ip bastion_ip {
  name                         = "${azurerm_virtual_network.region_network.name}-bastion-ip"
  location                     = var.location
  resource_group_name          = azurerm_virtual_network.region_network.resource_group_name
  allocation_method            = "Static"
  sku                          = "Standard"

  tags                         = var.tags

  count                        = var.deploy_bastion ? 1 : 0
}
resource azurerm_monitor_diagnostic_setting bastion_ip {
  name                         = "${azurerm_public_ip.bastion_ip.0.name}-logs"
  target_resource_id           = azurerm_public_ip.bastion_ip.0.id
  log_analytics_workspace_id   = var.log_analytics_workspace_id

  log {
    category                   = "DDoSProtectionNotifications"
    enabled                    = true

    retention_policy {
      enabled                  = false
    }
  }
  log {
    category                   = "DDoSMitigationFlowLogs"
    enabled                    = true

    retention_policy {
      enabled                  = false
    }
  }
  log {
    category                   = "DDoSMitigationReports"
    enabled                    = true

    retention_policy {
      enabled                  = false
    }
  }  

  metric {
    category                   = "AllMetrics"

    retention_policy {
      enabled                  = false
    }
  }

  count                        = var.deploy_bastion ? 1 : 0
} 

resource azurerm_bastion_host bastion {
  name                         = "${azurerm_virtual_network.region_network.name}-bastion"
  location                     = var.location
  resource_group_name          = azurerm_virtual_network.region_network.resource_group_name

  ip_configuration {
    name                       = "configuration"
    subnet_id                  = azurerm_subnet.bastion_subnet.0.id
    public_ip_address_id       = azurerm_public_ip.bastion_ip.0.id
  }

  tags                         = var.tags

  count                        = var.deploy_bastion ? 1 : 0
}
resource azurerm_monitor_diagnostic_setting bastion {
  name                         = "${azurerm_bastion_host.bastion.0.name}-logs"
  target_resource_id           = azurerm_bastion_host.bastion.0.id
  log_analytics_workspace_id   = var.log_analytics_workspace_id

  log {
    category                   = "BastionAuditLogs"
    enabled                    = true

    retention_policy {
      enabled                  = false
    }
  }

  count                        = var.deploy_bastion ? 1 : 0
} 

resource azurerm_nat_gateway egress {
  name                         = "${azurerm_virtual_network.region_network.name}-natgw"
  location                     = var.location
  resource_group_name          = azurerm_virtual_network.region_network.resource_group_name
  sku_name                     = "Standard"
}
resource azurerm_public_ip egress {
  name                         = "${azurerm_nat_gateway.egress.name}-ip"
  location                     = var.location
  resource_group_name          = azurerm_virtual_network.region_network.resource_group_name
  allocation_method            = "Static"
  sku                          = "Standard"
}
resource azurerm_nat_gateway_public_ip_association egress {
  nat_gateway_id               = azurerm_nat_gateway.egress.id
  public_ip_address_id         = azurerm_public_ip.egress.id
}
resource azurerm_subnet_nat_gateway_association vm_subnet {
  subnet_id                    = azurerm_subnet.vm_subnet.id
  nat_gateway_id               = azurerm_nat_gateway.egress.id

  depends_on                   = [azurerm_nat_gateway_public_ip_association.egress]
}

resource azurerm_private_dns_zone_virtual_network_link internal_link {
  name                         = "${azurerm_virtual_network.region_network.name}-internal-link"
  resource_group_name          = azurerm_virtual_network.region_network.resource_group_name
  private_dns_zone_name        = var.private_dns_zone_name
  virtual_network_id           = azurerm_virtual_network.region_network.id

  tags                         = var.tags
}

resource azurerm_storage_account diagnostics_storage {
  name                         = "dev${var.location}diag${var.tags["suffix"]}"
  location                     = var.location
  resource_group_name          = var.resource_group_name
  account_kind                 = "StorageV2"
  account_tier                 = "Standard"
  account_replication_type     = "LRS"
  enable_https_traffic_only    = true

  tags                         = var.tags
}