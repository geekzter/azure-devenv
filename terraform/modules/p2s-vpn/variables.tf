variable resource_group_id {
  description                  = "The id of the resource group"
}
variable location {
  description                  = "The location/region where the virtual network is created. Changing this forces a new resource to be created."
}
variable organization {
  default                      = "geekzter"
}
variable tags {
  description                  = "A map of the tags to use for the resources that are deployed"
  type                         = map
} 

variable dns_ip_address {
  default                      = []
  type                         = list
}

variable root_cert_pem_file {}
variable root_cert_cer_file {}
variable root_cert_der_file {}
variable root_cert_public_pem_file {}
variable root_cert_private_pem_file {}
variable client_cert_pem_file {}
variable client_cert_p12_file {}
variable client_cert_public_pem_file {}
variable client_cert_private_pem_file {}

variable subnet_range {
    description                = "The subnet range for the VPN GW subnet"
}
variable vpn_range {
    description                = "The client subnet range for VPN"
}

variable virtual_network_id {
    description                = "The id of the Virtual Network to connect the VPN to"
}