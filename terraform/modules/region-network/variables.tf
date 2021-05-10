variable address_space {
    description                = "The IP range for the VNet"
}
variable deploy_bastion {
    type                       = bool
}
variable location {
  description                  = "The location/region where the virtual network is created. Changing this forces a new resource to be created."
}
variable log_analytics_workspace_id {
    default                    = null
}
variable private_dns_zone_name {}
variable resource_group_name {
  description                  = "The name of the resource group"
}
variable tags {
  description                  = "A map of the tags to use for the resources that are deployed"
  type                         = map
} 

