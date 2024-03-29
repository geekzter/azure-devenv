variable dns_ip_addresses {
  default                      = []
  type                         = list
}
variable location {
  description                  = "The location/region where the virtual network is created. Changing this forces a new resource to be created."
}
variable log_analytics_workspace_id {}
variable organization {
  default                      = "geekzter"
}
variable resource_group_id {
  description                  = "The id of the resource group"
}
variable subnet_range {
    description                = "The subnet range for the VPN GW subnet"
}
variable tags {
  description                  = "A map of the tags to use for the resources that are deployed"
  type                         = map
} 
variable virtual_network_id {
    description                = "The id of the Virtual Network to connect the VPN to"
}
variable vpn_range {
    description                = "The client subnet range for VPN"
}