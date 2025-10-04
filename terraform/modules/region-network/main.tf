resource azurerm_virtual_network region_network {
  name                         = "${var.resource_group_name}-${var.location}-network"
  location                     = var.location
  resource_group_name          = var.resource_group_name
  address_space                = [var.address_space]

  tags                         = local.all_bastion_tags
}
resource azurerm_monitor_diagnostic_setting region_network {
  name                         = "${azurerm_virtual_network.region_network.name}-diagnostics"
  target_resource_id           = azurerm_virtual_network.region_network.id
  log_analytics_workspace_id   = var.log_analytics_workspace_id

  enabled_log {
    category                   = "VMProtectionAlerts"
  }

  enabled_metric {
    category                   = "AllMetrics"
  }
}

resource azurerm_subnet vm_subnet {
  name                         = "VirtualMachines"
  virtual_network_name         = azurerm_virtual_network.region_network.name
  resource_group_name          = azurerm_virtual_network.region_network.resource_group_name
  address_prefixes             = [cidrsubnet(tolist(azurerm_virtual_network.region_network.address_space)[0],8,1)]
  default_outbound_access_enabled = false
  service_endpoints            = [
                                  "Microsoft.KeyVault",
  ]
}
resource azurerm_network_security_group vm_nsg {
  name                         = "${azurerm_virtual_network.region_network.name}-nsg"
  location                     = var.location
  resource_group_name          = azurerm_virtual_network.region_network.resource_group_name

  tags                         = var.tags
}
resource azurerm_network_security_rule ras {
  name                         = "AllowVPNRAS"
  priority                     = 201
  direction                    = "Inbound"
  access                       = "Allow"
  protocol                     = "Tcp"
  source_port_range            = "*"
  destination_port_ranges      = ["22","3389"]
  source_address_prefix        = var.vpn_range
  destination_address_prefixes = azurerm_subnet.vm_subnet.address_prefixes
  resource_group_name          = azurerm_network_security_group.vm_nsg.resource_group_name
  network_security_group_name  = azurerm_network_security_group.vm_nsg.name
}
resource azurerm_network_security_rule admin_ras {
  name                         = "AdminRAS"
  priority                     = 202
  direction                    = "Inbound"
  access                       = var.enable_public_access ? "Allow" : "Deny"
  protocol                     = "Tcp"
  source_port_range            = "*"
  destination_port_ranges      = ["22","3389"]
  source_address_prefixes      = var.admin_cidr_ranges
  destination_address_prefixes = azurerm_subnet.vm_subnet.address_prefixes
  resource_group_name          = azurerm_network_security_group.vm_nsg.resource_group_name
  network_security_group_name  = azurerm_network_security_group.vm_nsg.name
}
resource azurerm_subnet_network_security_group_association vm_nsg {
  subnet_id                    = azurerm_subnet.vm_subnet.id
  network_security_group_id    = azurerm_network_security_group.vm_nsg.id
}

resource azurerm_nat_gateway egress {
  name                         = "${azurerm_virtual_network.region_network.name}-natgw"
  location                     = var.location
  resource_group_name          = azurerm_virtual_network.region_network.resource_group_name
  sku_name                     = "Standard"

  tags                         = var.tags
}
resource azurerm_public_ip egress {
  name                         = "${azurerm_nat_gateway.egress.name}-ip"
  location                     = var.location
  resource_group_name          = azurerm_virtual_network.region_network.resource_group_name
  allocation_method            = "Static"
  ip_tags                      = var.ip_tags
  sku                          = "Standard"

  tags                         = var.tags
}
resource azurerm_nat_gateway_public_ip_association egress {
  nat_gateway_id               = azurerm_nat_gateway.egress.id
  public_ip_address_id         = azurerm_public_ip.egress.id
}
resource azurerm_subnet_nat_gateway_association bastion_subnet {
  subnet_id                    = azurerm_subnet.bastion_subnet.id
  nat_gateway_id               = azurerm_nat_gateway.egress.id

  depends_on                   = [azurerm_nat_gateway_public_ip_association.egress]
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

resource azurerm_storage_account diagnostics {
  name                         = "dev${var.location}diag${var.tags["suffix"]}"
  location                     = var.location
  resource_group_name          = var.resource_group_name
  account_kind                 = "StorageV2"
  account_tier                 = "Standard"
  account_replication_type     = "LRS"
  allow_nested_items_to_be_public = false
  default_to_oauth_authentication = true
  https_traffic_only_enabled   = true
  public_network_access_enabled = false
  shared_access_key_enabled    = false

  tags                         = var.tags
}
