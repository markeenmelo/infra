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

variable "fleet_hosts" {
  description = "Tailnet address per fleet host, from fleet.hosts.*.tailnetAddress; the tofu app sets it."
  type        = map(string)
}

variable "fleet_edge_ports" {
  description = "Bastion ports racknerd reaches for the public apps in fleet.web.apps; the tofu app sets it."
  type        = list(number)
}

variable "fleet_telemetry" {
  description = "Bastion ports each host pushes its telemetry to, from fleet.hosts.*.telemetry, null where a host pushes nothing; the tofu app sets it."
  type        = map(object({ metrics = number, logs = number }))
}

variable "fleet_routes" {
  description = "LAN subnets bastion routes for the tailnet, by name, from fleet.hosts.*.lan.routes; the tofu app sets it."
  type        = map(string)
}

variable "fleet_lan" {
  description = "LAN facts per wired fleet host, from fleet.hosts.*.lan; the tofu app sets it."
  type        = map(object({ gateway = string }))
}

variable "fleet_cache_port" {
  description = "Bastion port of the Harmonia cache, from fleet.cachePort; the tofu app sets it."
  type        = number
}

variable "fleet_home_backup_port" {
  description = "Bastion port of the ThinkPad's restic server, from fleet.homeBackupPort; the tofu app sets it."
  type        = number
}

variable "fleet_domain" {
  description = "The fleet's domain, from fleet.domain; the tofu app sets it."
  type        = string
}

locals {
  domain    = var.fleet_domain
  bastion   = var.fleet_hosts.bastion
  telemetry = { for host, ports in var.fleet_telemetry : host => [for port in values(ports) : port if port != null] if ports != null }
  # grafite is an admin device outside the fleet
  hosts = merge({
    grafite = "100.91.224.11"
  }, var.fleet_hosts)
  admin_clients = ["thinkpad", "asahi", "mac", "grafite"]
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
      "tag:ci"                = ["tag:infra-provisioner"]
    }
    groups = { "group:members" = ["naralidy.anjos@gmail.com", "markeenmelo@github"] }
    hosts  = local.hosts
    autoApprovers = {
      exitNode = ["tag:proton-exit"]
      routes   = { for lan in values(var.fleet_routes) : lan => ["tag:bastion"] }
    }
    grants = concat([for host, ports in local.telemetry : { src = [host], dst = ["bastion"], ip = [for port in ports : "tcp:${port}"] }], [
      { src = ["tag:admin-client"], dst = ["tag:server", "tag:admin-client"], ip = ["tcp:22"] },
      { src = ["racknerd"], dst = ["bastion"], ip = concat([for port in var.fleet_edge_ports : "tcp:${port}"], ["tcp:${var.fleet_cache_port}"]) },
      { src = ["thinkpad"], dst = ["bastion"], ip = ["tcp:${var.fleet_home_backup_port}"] },
      { src = concat(local.admin_clients, ["tag:ci"]), dst = ["bastion"], ip = ["tcp:${var.fleet_cache_port}"] },
      { src = concat(local.admin_clients, ["group:members"]), dst = ["bastion"], ip = ["tcp:443"] },
      { src = local.admin_clients, dst = [var.fleet_lan.bastion.gateway], ip = ["tcp:443"] },
      { src = local.admin_clients, dst = [var.fleet_routes.iot, var.fleet_routes.kids], ip = ["*"] },
      { src = ["tag:admin-client", "tag:server", "group:members"], dst = ["bastion"], ip = ["tcp:53", "udp:53"] },
      { src = ["tag:admin-client", "group:members"], dst = ["autogroup:internet"], ip = ["*"] },
    ])
    tests = concat([for host, ports in local.telemetry : { src = host, proto = "tcp", accept = [for port in ports : "bastion:${port}"], deny = [for port in setsubtract(flatten(values(local.telemetry)), ports) : "bastion:${port}"] }], [
      { src = "tag:admin-client", proto = "tcp", accept = ["tag:server:22"] },
      { src = "thinkpad", proto = "tcp", accept = ["bastion:${var.fleet_cache_port}"] },
      { src = "tag:server", proto = "tcp", deny = ["tag:server:22", "tag:admin-client:22"] },
      { src = "group:members", proto = "tcp", deny = ["tag:server:22"] },
      { src = "tag:ci", proto = "tcp", accept = ["bastion:${var.fleet_cache_port}"], deny = ["tag:server:22", "bastion:443", "tag:admin-client:22"] },
      { src = "racknerd", proto = "tcp", accept = ["bastion:9091"], deny = ["bastion:443"] },
    ])
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
