output cert_password {
  value       = random_string.cert_password.result
}

output client_cert {
  value       = tls_locally_signed_cert.client_cert.cert_pem
}

output client_cert_common_name {
  value       = local.client_cert_common_name
}

output client_cert_pem_file {
  value       = abspath(local_file.client_cert_files.filename)
}

output client_key {
  value       = tls_private_key.client_cert.private_key_pem
}

# output root_cert_cer {
#   value       = data.local_file.root_cert_der_file.content_base64
# }

output gateway_id {
  value       = azurerm_virtual_network_gateway.vpn_gw.id
}

output gateway_fqdn {
  value       = azurerm_public_ip.vpn_pip.fqdn
}

output gateway_ip {
  value       = azurerm_public_ip.vpn_pip.ip_address
}

output root_cert_common_name {
  value       = local.root_cert_common_name
}

output root_cert_public_pem_file {
  value       = abspath(local_file.root_cert_public_pem_file.filename)
}