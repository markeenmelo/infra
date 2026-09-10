terraform {
  required_version = "~> 1.11.8"
  required_providers {
    tailscale = {
      source  = "tailscale/tailscale"
      version = "= 0.29.0"
    }
  }
}

# Authentication comes from narrowly scoped runtime provider environment
# variables; no OAuth/API secret is a Terraform variable or Nix input.
provider "tailscale" {
  tailnet = var.tailnet
}

variable "tailnet" {
  type        = string
  nullable    = false
  description = "Verified existing tailnet ID. Intentionally has no default."
  validation {
    condition     = length(trimspace(var.tailnet)) > 0 && var.tailnet != "-" && !can(regex("\\s", var.tailnet))
    error_message = "Supply the explicit tailnet ID; implicit credential-selected tailnets are forbidden."
  }
}

resource "tailscale_acl" "policy" {
  acl                        = file("${path.module}/policy.hujson")
  overwrite_existing_content = false
  reset_acl_on_destroy       = false
  lifecycle {
    prevent_destroy = true
  }
}

# Only MagicDNS is owned here. Existing global/split resolvers and search
# domains are deliberately untouched until their requirements are reviewed.
resource "tailscale_dns_preferences" "tailnet" {
  magic_dns = true
  lifecycle {
    prevent_destroy = true
  }
}
