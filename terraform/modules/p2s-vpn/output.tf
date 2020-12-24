output cert_password {
  value       = random_string.cert_password.result
}

output client_cert_common_name {
  value       = local.client_cert_common_name
}

output client_cert_merged_pem {
  value       = <<-EOT
    ${tls_private_key.client_cert.private_key_pem}
    ${tls_locally_signed_cert.client_cert.cert_pem}
  EOT
}

output client_cert_private_pem {
  value       = tls_private_key.client_cert.private_key_pem
}

output client_cert_public_pem {
  value       = tls_locally_signed_cert.client_cert.cert_pem
}

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

output root_cert_merged_pem {
  value       = <<-EOT
    ${tls_private_key.root_cert.private_key_pem}
    ${tls_self_signed_cert.root_cert.cert_pem}
  EOT
}
output root_cert_private_pem {
  value       = tls_private_key.root_cert.private_key_pem
}

output root_cert_public_pem {
  value       = tls_self_signed_cert.root_cert.cert_pem
}
