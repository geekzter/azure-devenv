
variable admin_object_id {
  default                      = null
}
variable admin_username {}
variable development_resource_group {
  default                      = "Development"
}

variable development_network {
  default                      = "Development-vnet"
}
variable devops_org {
  default                      = null

}
variable devops_pat {
  default                      = null
}
variable dns_zone_id {}
variable environment_variables {
  type                         = map
  default = {
    provisioner                = "terraform"
  }
} 
variable git_email {}
variable git_name {}
variable global_vnet_peering {
    type                       = bool
    default                    = true
}
variable linux_bootstrap {
    type                       = bool
    default                    = false
}
variable linux_os_offer {
  default                      = "UbuntuServer"
}
variable linux_os_publisher {
  default                      = "Canonical"
}
variable linux_os_sku {
  default                      = "18.04-LTS"
}
variable linux_os_version {
  default                      = "latest"
}
variable linux_vm_size {
  default                      = "Standard_D2s_v3"
}

variable locations {
  type                         = list
  default                      = ["westeurope"]
}
variable log_analytics_workspace_id {}

variable ssh_public_key {
  default                      = "~/.ssh/id_rsa.pub"
}

variable vpn_range {
  default                      = "192.168.0.0/24"
}

variable windows_sku_match {
  default                      = "-ent-g2"
}
variable windows_os_version {
  default                      = "latest"
}
variable windows_vm_size {
  default                      = "Standard_D4s_v3"
}
variable vm_domain {
  default                      = "dev.internal"
}
variable vm_subnet {
  default                      = "default"
}

# Certificate data
variable organization {
  default                      = "DevelopersInc"
}
variable root_cert_pem_file {
  default                      = "../certificates/root_cert.pem"
}
variable root_cert_cer_file {
  default                      = "../certificates/root_cert.cer"
}
variable root_cert_der_file {
  default                      = "../certificates/root_cert.der"
}
variable root_cert_private_pem_file {
  default                      = "../certificates/root_cert_private.pem"
}
variable root_cert_public_pem_file {
  default                      = "../certificates/root_cert_public.pem"
}
variable client_cert_pem_file {
  default                      = "../certificates/client_cert.pem"
}
variable client_cert_p12_file {
  default                      = "../certificates/client_cert.p12"
}
variable client_cert_public_pem_file {
  default                      = "../certificates/client_cert_public.pem"
}
variable client_cert_private_pem_file {
  default                      = "../certificates/client_cert_private.pem"
}