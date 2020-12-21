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

resource tls_private_key root_cert {
  algorithm                    = "RSA"
  rsa_bits                     = "2048"
}

resource local_file root_cert_private_pem_file {
  content                      = tls_private_key.root_cert.private_key_pem
  filename                     = "${local.certificates_directory}/root_cert_private.pem"
}

resource tls_self_signed_cert root_cert {
  allowed_uses                 = [
                                "cert_signing",
                                "client_auth",
                                "digital_signature",
                                "key_encipherment",
                                "server_auth",
  ]
  early_renewal_hours          = 200
  is_ca_certificate            = true
  key_algorithm                = tls_private_key.root_cert.algorithm
  private_key_pem              = tls_private_key.root_cert.private_key_pem
  subject {
    common_name                = "P2SRootCert"
    organization               = var.organization
  }
  validity_period_hours        = 8766 # 1 year
}

resource local_file root_cert_public_pem_file {
  content                      = tls_self_signed_cert.root_cert.cert_pem
  filename                     = "${local.certificates_directory}/root_cert_public.pem"
}

resource null_resource root_cert_files {
  provisioner local-exec {
    command                    = "openssl x509 -in '${local_file.root_cert_public_pem_file.filename}' -outform der > '${local.certificates_directory}/root_cert.der'"
  }  
}
resource local_file root_cert_files {
  content                      = <<-EOT
    ${tls_private_key.root_cert.private_key_pem}
    ${tls_self_signed_cert.root_cert.cert_pem}
  EOT
  filename                     = "${local.certificates_directory}/root_cert.pem"
}

resource tls_private_key client_cert {
  algorithm                    = "RSA"
  rsa_bits                     = "2048"
}

resource local_file client_cert_private_pem_file {
  content                      = tls_private_key.client_cert.private_key_pem
  filename                     = "${local.certificates_directory}/client_cert_private.pem"
}

resource tls_cert_request client_cert {
  key_algorithm                = tls_private_key.client_cert.algorithm
  private_key_pem              = tls_private_key.client_cert.private_key_pem
  subject {
    common_name                = "P2SChildCert"
    organization               = var.organization
  }
}

resource tls_locally_signed_cert client_cert {
  allowed_uses                 = [
                                "key_encipherment",
                                "digital_signature",
                                "server_auth",
                                "client_auth",
  ]
  ca_cert_pem                  = tls_self_signed_cert.root_cert.cert_pem
  ca_key_algorithm             = tls_private_key.client_cert.algorithm
  ca_private_key_pem           = tls_private_key.client_cert.private_key_pem
  cert_request_pem             = tls_cert_request.client_cert.cert_request_pem
  is_ca_certificate            = true
  validity_period_hours        = 43800
}

resource local_file client_cert_public_pem_file {
  content                      = tls_locally_signed_cert.client_cert.cert_pem
  filename                     = "${local.certificates_directory}/client_cert_public.pem"
}

resource null_resource client_cert_files {
  provisioner local-exec {
    command                    = "openssl pkcs12 -in '${local_file.client_cert_public_pem_file.filename}' -inkey '${local_file.client_cert_private_pem_file.filename}' -certfile '${local_file.root_cert_public_pem_file.filename}' -out '${local.certificates_directory}/client_cert.p12' -export -password 'pass:${local.cert_password}'"
  }  
}

resource local_file client_cert_files {
  content                      = <<-EOT
    ${tls_private_key.client_cert.private_key_pem}
    ${tls_locally_signed_cert.client_cert.cert_pem}
  EOT
  filename                     = "${local.certificates_directory}/client_cert.pem"
}

data local_file root_cert_der_file {
  filename                     = "${local.certificates_directory}/root_cert.der"

  depends_on                   = [null_resource.root_cert_files]
}

resource local_file root_cert_cer_file {
  content                      = data.local_file.root_cert_der_file.content_base64
  filename                     = "${local.certificates_directory}/root_cert.cer"
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
      public_cert_data         = data.local_file.root_cert_der_file.content_base64
    }
    vpn_client_protocols       = [
                                  "IkeV2",
                                  "OpenVPN"
                                 ]
  }

  tags                         = var.tags
}
