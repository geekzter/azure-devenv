resource tls_private_key client_cert {
  algorithm                    = "RSA"
  rsa_bits                     = "2048"
}

resource local_file client_cert_private_pem_file {
  content                      = tls_private_key.client_cert.private_key_pem
  filename                     = "${local.certificates_directory}/client_cert.key"
}

resource tls_cert_request client_cert {
  key_algorithm                = tls_private_key.client_cert.algorithm
  private_key_pem              = tls_private_key.client_cert.private_key_pem
  subject {
    common_name                = local.client_cert_common_name
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
  filename                     = "${local.certificates_directory}/client_cert.pem"
}

resource local_file client_cert_merged {
  content                      = <<-EOT
    ${tls_private_key.client_cert.private_key_pem}
    ${tls_locally_signed_cert.client_cert.cert_pem}
  EOT
  filename                     = "${local.certificates_directory}/client_cert_merged.pem"
}