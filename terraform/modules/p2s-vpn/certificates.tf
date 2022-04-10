resource tls_private_key root_cert {
  algorithm                    = "RSA"
  rsa_bits                     = "2048"
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

resource tls_private_key client_cert {
  algorithm                    = "RSA"
  rsa_bits                     = "2048"
}

resource tls_cert_request client_cert {
  key_algorithm                = tls_private_key.client_cert.algorithm
  private_key_pem              = tls_private_key.client_cert.private_key_pem
  subject {
    common_name                = local.client_cert_common_name
    organization               = var.organization
  }
}

# BUG: In tls provider 3.2/3.3
#      error creating certificate: x509: provided PrivateKey doesn't match parent's PublicKey
#      Problem inferring key algorithm?
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