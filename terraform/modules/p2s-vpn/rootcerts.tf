resource tls_private_key root_cert {
  algorithm                    = "RSA"
  rsa_bits                     = "2048"
}

resource local_file root_cert_private_pem_file {
  content                      = tls_private_key.root_cert.private_key_pem
  filename                     = "${local.certificates_directory}/root_cert.key"
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
    common_name                = local.root_cert_common_name
    organization               = var.organization
  }
  validity_period_hours        = 8766 # 1 year
}

resource local_file root_cert_public_pem_file {
  content                      = tls_self_signed_cert.root_cert.cert_pem
  filename                     = "${local.certificates_directory}/root_cert.pem"
}

resource local_file root_cert_merged {
  content                      = <<-EOT
    ${tls_private_key.root_cert.private_key_pem}
    ${tls_self_signed_cert.root_cert.cert_pem}
  EOT
  filename                     = "${local.certificates_directory}/root_cert_merged.pem"
}
