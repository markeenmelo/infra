terraform {
  required_version = "= 1.12.6"
  required_providers {
    tailscale = {
      source  = "tailscale/tailscale"
      version = "= 0.29.2"
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
  type      = string
  sensitive = true
  validation {
    condition     = length(var.state_passphrase) >= 16
    error_message = "The independently backed-up state passphrase must be at least 16 characters."
  }
}

provider "tailscale" {
  base_url = "https://api.tailscale.com"
}

import {
  to = tailscale_acl.fleet
  id = "acl"
}
resource "tailscale_acl" "fleet" {
  acl                        = file("${path.module}/../../assets/tailscale/policy.hujson")
  overwrite_existing_content = false
  reset_acl_on_destroy       = false
}

import {
  to = tailscale_tailnet_settings.fleet
  id = "tailnet_settings"
}
resource "tailscale_tailnet_settings" "fleet" {
  acls_externally_managed_on                  = true
  devices_approval_on                         = true
  devices_auto_updates_on                     = false
  devices_key_duration_days                   = 180
  users_approval_on                           = false
  users_role_allowed_to_join_external_tailnet = "admin"
  regional_routing_on                         = false
  posture_identity_collection_on              = false
  depends_on                                  = [tailscale_acl.fleet]
}

import {
  to = tailscale_dns_preferences.fleet
  id = "dns_preferences"
}
resource "tailscale_dns_preferences" "fleet" {
  magic_dns  = true
  depends_on = [tailscale_acl.fleet]
}

import {
  to = tailscale_dns_search_paths.fleet
  id = "dns_search_paths"
}
resource "tailscale_dns_search_paths" "fleet" {
  search_paths = []
  depends_on   = [tailscale_acl.fleet]
}

import {
  to = tailscale_device_tags.grafite
  id = "nV2TinpBxq11CNTRL"
}
resource "tailscale_device_tags" "grafite" {
  device_id  = "nV2TinpBxq11CNTRL"
  tags       = ["tag:admin-client"]
  depends_on = [tailscale_acl.fleet]
  lifecycle {
    prevent_destroy = true
  }
}

resource "tailscale_tailnet_key" "enrollment" {
  for_each = {
    thinkpad = "tag:admin-client"
    racknerd = "tag:server"
    bastion  = "tag:server"
  }
  description         = each.key
  tags                = [each.value]
  preauthorized       = true
  ephemeral           = false
  reusable            = false
  expiry              = 86400
  recreate_if_invalid = "never"
  depends_on          = [tailscale_acl.fleet, tailscale_tailnet_settings.fleet]
}

output "enrollment_keys" {
  value     = { for host, key in tailscale_tailnet_key.enrollment : host => key.key }
  sensitive = true
}
