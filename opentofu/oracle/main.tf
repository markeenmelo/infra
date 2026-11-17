terraform {
  required_version = ">= 1.10"
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 9.13.0"
    }
  }
  backend "pg" {}
  encryption {
    key_provider "pbkdf2" "operator" {
      passphrase = var.state_passphrase
    }
    method "aes_gcm" "operator" {
      keys = key_provider.pbkdf2.operator
    }
    state {
      method   = method.aes_gcm.operator
      enforced = true
    }
    plan {
      method   = method.aes_gcm.operator
      enforced = true
    }
  }
}

variable "state_passphrase" {
  description = "Passphrase the state and plan encryption key is derived from."
  type        = string
  sensitive   = true
}

variable "tenancy_ocid" {
  description = "OCID of the tenancy, whose root compartment holds every resource."
  type        = string
}

variable "user_ocid" {
  description = "OCID of the user the API signing key belongs to."
  type        = string
}

variable "fingerprint" {
  description = "Fingerprint of the API signing key."
  type        = string
}

variable "private_key" {
  description = "The API signing key, PEM."
  type        = string
  sensitive   = true
}

variable "region" {
  description = "The tenancy's home region, the only one where Always Free resources exist."
  type        = string
}

variable "fleet_deploy_keys" {
  description = "Public keys of the deploy account, one per line, from users.users.deploy; the tofu app sets it."
  type        = string
}

variable "fleet_tailscale_port" {
  description = "UDP port Tailscale takes direct connections on, from services.tailscale.port; the tofu app sets it."
  type        = number
}

variable "install" {
  description = "Whether the border admits SSH on port 22, where the stock image and the nixos-anywhere installer listen; true only for the apply before an install."
  type        = bool
  default     = false
}

provider "oci" {
  tenancy_ocid = var.tenancy_ocid
  user_ocid    = var.user_ocid
  fingerprint  = var.fingerprint
  private_key  = var.private_key
  region       = var.region
}

locals {
  instances = {
    edge = { ocpus = 1, memory = 2 }
  }
  shape                = "VM.Standard.A1.Flex"
  boot_volume          = 50
  network              = "10.80.0.0/24"
  anywhere             = "0.0.0.0/0"
  unlock_port          = 22022
  tcp_ports            = concat([80, 443, local.unlock_port], var.install ? [22] : [])
  protocol             = { icmp = "1", tcp = "6", udp = "17" }
  fragmentation_needed = { type = 3, code = 4 }
}

data "oci_identity_availability_domains" "home" {
  compartment_id = var.tenancy_ocid
}

data "oci_core_images" "installer" {
  compartment_id           = var.tenancy_ocid
  operating_system         = "Canonical Ubuntu"
  operating_system_version = "24.04"
  shape                    = local.shape
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

resource "oci_core_vcn" "fleet" {
  compartment_id = var.tenancy_ocid
  display_name   = "fleet"
  cidr_blocks    = [local.network]
}

resource "oci_core_internet_gateway" "fleet" {
  compartment_id = var.tenancy_ocid
  vcn_id         = oci_core_vcn.fleet.id
  display_name   = "fleet"
}

resource "oci_core_default_route_table" "fleet" {
  manage_default_resource_id = oci_core_vcn.fleet.default_route_table_id
  route_rules {
    destination       = local.anywhere
    network_entity_id = oci_core_internet_gateway.fleet.id
  }
}

# shortcut: one security list admits the edge's ports to every instance in the subnet, move them to a network security group per instance when a second instance must not get them
resource "oci_core_default_security_list" "fleet" {
  manage_default_resource_id = oci_core_vcn.fleet.default_security_list_id
  egress_security_rules {
    destination = local.anywhere
    protocol    = "all"
  }
  dynamic "ingress_security_rules" {
    for_each = local.tcp_ports
    content {
      source   = local.anywhere
      protocol = local.protocol.tcp
      tcp_options {
        min = ingress_security_rules.value
        max = ingress_security_rules.value
      }
    }
  }
  ingress_security_rules {
    source   = local.anywhere
    protocol = local.protocol.udp
    udp_options {
      min = var.fleet_tailscale_port
      max = var.fleet_tailscale_port
    }
  }
  ingress_security_rules {
    source   = local.anywhere
    protocol = local.protocol.icmp
    icmp_options {
      type = local.fragmentation_needed.type
      code = local.fragmentation_needed.code
    }
  }
}

resource "oci_core_subnet" "fleet" {
  compartment_id = var.tenancy_ocid
  vcn_id         = oci_core_vcn.fleet.id
  display_name   = "fleet"
  cidr_block     = local.network
}

resource "oci_core_instance" "fleet" {
  for_each            = local.instances
  compartment_id      = var.tenancy_ocid
  availability_domain = data.oci_identity_availability_domains.home.availability_domains[0].name
  display_name        = each.key
  shape               = local.shape
  shape_config {
    ocpus         = each.value.ocpus
    memory_in_gbs = each.value.memory
  }
  source_details {
    source_type             = "image"
    source_id               = data.oci_core_images.installer.images[0].id
    boot_volume_size_in_gbs = local.boot_volume
  }
  create_vnic_details {
    subnet_id        = oci_core_subnet.fleet.id
    assign_public_ip = false
  }
  metadata = {
    ssh_authorized_keys = var.fleet_deploy_keys
  }
  lifecycle {
    prevent_destroy = true
    ignore_changes  = [source_details]
  }
}

data "oci_core_private_ips" "fleet" {
  for_each   = oci_core_instance.fleet
  subnet_id  = oci_core_subnet.fleet.id
  ip_address = each.value.private_ip
}

resource "oci_core_public_ip" "fleet" {
  for_each       = data.oci_core_private_ips.fleet
  compartment_id = var.tenancy_ocid
  display_name   = each.key
  lifetime       = "RESERVED"
  private_ip_id  = each.value.private_ips[0].id
  lifecycle {
    prevent_destroy = true
  }
}

output "addresses" {
  description = "Each instance's reserved public IPv4 address, which goes in fleet.hosts.HOST.publicAddress."
  value       = { for name, address in oci_core_public_ip.fleet : name => address.ip_address }
}
