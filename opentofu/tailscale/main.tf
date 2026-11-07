terraform {
  required_providers {
    tailscale = {
      source  = "tailscale/tailscale"
      version = "~> 0.29.3"
    }
  }
  backend "local" {}
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

# shortcut: addresses and hosts are literals, feed them from fleet facts when bastion lands
locals {
  domain  = "marcosmelo.dev"
  bastion = "100.105.158.109"
  hosts = {
    bastion  = local.bastion
    racknerd = "100.96.133.3"
    thinkpad = "100.119.79.113"
    asahi    = "100.122.51.97"
    mac      = "100.74.75.110"
    grafite  = "100.91.224.11"
  }
  admin_clients = ["thinkpad", "asahi", "mac", "grafite"]
  lans          = ["192.168.2.0/24", "192.168.4.0/24", "192.168.20.0/24"]
  enrollment = {
    thinkpad  = ["tag:admin-client"]
    asahi     = ["tag:admin-client"]
    mac       = ["tag:admin-client"]
    racknerd  = ["tag:server"]
    bastion   = ["tag:server", "tag:bastion"]
    proton-ca = ["tag:proton-exit"]
    proton-us = ["tag:proton-exit"]
    proton-br = ["tag:proton-exit"]
  }
  tagged = {
    bastion = { id = "nRazrRf2yE11CNTRL", tags = ["tag:server", "tag:bastion"] }
    grafite = { id = "na2EEFHL1i11CNTRL", tags = ["tag:admin-client"] }
  }

  policy = {
    tagOwners = {
      "tag:infra-provisioner" = ["autogroup:admin"]
      "tag:admin-client"      = ["tag:infra-provisioner"]
      "tag:server"            = ["tag:infra-provisioner"]
      "tag:bastion"           = ["tag:infra-provisioner"]
      "tag:proton-exit"       = ["tag:infra-provisioner"]
    }
    groups = { "group:members" = ["naralidy.anjos@gmail.com", "markeenmelo@github"] }
    hosts  = local.hosts
    autoApprovers = {
      exitNode = ["tag:proton-exit"]
      routes   = { for lan in local.lans : lan => ["tag:bastion"] }
    }
    grants = [
      { src = ["tag:admin-client"], dst = ["tag:server", "tag:admin-client"], ip = ["tcp:22"] },
      { src = ["racknerd"], dst = ["bastion"], ip = ["tcp:9091", "tcp:8096", "tcp:2283", "tcp:8123", "tcp:9095", "tcp:3102", "tcp:9200"] },
      { src = ["bastion"], dst = ["racknerd"], ip = ["tcp:8000"] },
      { src = ["thinkpad"], dst = ["bastion"], ip = ["tcp:3103", "tcp:9097", "tcp:8010"] },
      { src = ["asahi"], dst = ["bastion"], ip = ["tcp:3104", "tcp:9098"] },
      { src = ["mac"], dst = ["bastion"], ip = ["tcp:3105", "tcp:9099"] },
      { src = concat(local.admin_clients, ["group:members"]), dst = ["bastion"], ip = ["tcp:443"] },
      { src = local.admin_clients, dst = ["192.168.2.1"], ip = ["tcp:443"] },
      { src = local.admin_clients, dst = ["192.168.4.0/24", "192.168.20.0/24"], ip = ["*"] },
      { src = ["tag:admin-client", "tag:server", "group:members"], dst = ["bastion"], ip = ["tcp:53", "udp:53"] },
      { src = ["tag:admin-client", "group:members"], dst = ["autogroup:internet"], ip = ["*"] },
    ]
    tests = [
      { src = "tag:admin-client", proto = "tcp", accept = ["tag:server:22"] },
      { src = "tag:server", proto = "tcp", deny = ["tag:server:22", "tag:admin-client:22"] },
      { src = "group:members", proto = "tcp", deny = ["tag:server:22"] },
    ]
  }
}

resource "tailscale_acl" "fleet" {
  acl = jsonencode(local.policy)
}

resource "tailscale_tailnet_settings" "fleet" {
  acls_externally_managed_on                  = true
  acls_external_link                          = "https://github.com/markeenmelo/infra/blob/main/opentofu/tailscale/main.tf"
  devices_approval_on                         = true
  devices_auto_updates_on                     = false
  devices_key_duration_days                   = 180
  users_approval_on                           = true
  users_role_allowed_to_join_external_tailnet = "admin"
  regional_routing_on                         = false
  posture_identity_collection_on              = false
  depends_on                                  = [tailscale_acl.fleet]
}

resource "tailscale_dns_configuration" "fleet" {
  override_local_dns = true
  nameservers {
    address            = "194.242.2.3"
    use_with_exit_node = true
  }
  split_dns {
    domain = local.domain
    nameservers {
      address            = local.bastion
      use_with_exit_node = true
    }
  }
  depends_on = [tailscale_acl.fleet]
}

resource "tailscale_device_tags" "fleet" {
  for_each   = local.tagged
  device_id  = each.value.id
  tags       = each.value.tags
  depends_on = [tailscale_acl.fleet]
  lifecycle {
    prevent_destroy = true
  }
}

resource "tailscale_tailnet_key" "enrollment" {
  for_each            = local.enrollment
  description         = each.key
  tags                = each.value
  preauthorized       = true
  expiry              = 7776000
  recreate_if_invalid = "always"
  depends_on          = [tailscale_acl.fleet, tailscale_tailnet_settings.fleet]
}

output "enrollment_keys" {
  description = "Pre-authorized auth key per host; the tailnet skill says how one reaches secrets/hosts/HOST.yaml."
  value       = { for host, key in tailscale_tailnet_key.enrollment : host => key.key }
  sensitive   = true
}
