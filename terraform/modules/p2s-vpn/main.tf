data azurerm_client_config current {}

locals {
  certificates_directory       = "${path.root}/../data/${terraform.workspace}/certificates"
  tenant_url                   = "https://login.microsoftonline.com/${data.azurerm_client_config.current.tenant_id}/"
  issuer_url                   = "https://sts.windows.net/${data.azurerm_client_config.current.tenant_id}/"
  resource_group_name          = element(split("/",var.resource_group_id),length(split("/",var.resource_group_id))-1)
  virtual_network_name         = element(split("/",var.virtual_network_id),length(split("/",var.virtual_network_id))-1)
}

resource random_string cert_password {
  length                       = 8
  upper                        = false
  lower                        = true
  number                       = false
  special                      = false
}

resource random_string vpn_domain_name_label {
  length                       = 16
  upper                        = false
  lower                        = true
  number                       = false
  special                      = false
}

locals {
  cert_password                = random_string.cert_password.result
}

resource azurerm_subnet vpn_subnet {
  name                         = "GatewaySubnet"
  resource_group_name          = local.resource_group_name
  virtual_network_name         = local.virtual_network_name
  address_prefixes             = [var.subnet_range]
}

resource azurerm_public_ip vpn_pip {
  name                         = "${local.resource_group_name}-vpn-pip"
  location                     = var.location
  resource_group_name          = local.resource_group_name

  allocation_method            = "Static"
  sku                          = "Standard"
  domain_name_label            = random_string.vpn_domain_name_label.result

  tags                         = var.tags
  
}

resource azurerm_virtual_network_gateway vpn_gw {
  name                         = "${local.resource_group_name}-vpn"
  resource_group_name          = local.resource_group_name
  location                     = var.location

  type                         = "Vpn"
  vpn_type                     = "RouteBased"

  active_active                = false
  enable_bgp                   = false
  generation                   = "Generation2"
  sku                          = "VpnGw2"

  ip_configuration {
    name                       = "vnetGatewayConfig"
    public_ip_address_id       = azurerm_public_ip.vpn_pip.id
    private_ip_address_allocation = "Dynamic"
    subnet_id                  = azurerm_subnet.vpn_subnet.id
  }

  vpn_client_configuration {
    address_space              = [var.vpn_range]
    root_certificate {
      name                     = "${var.organization}-terraform-tls"
      # public_cert_data         = data.local_file.root_cert_der_file.content_base64
      public_cert_data         = base64encode(tls_self_signed_cert.root_cert.cert_pem)
    }
    vpn_client_protocols       = [
                                  "IkeV2",
                                  "OpenVPN"
                                 ]
  }

  tags                         = var.tags
}
