terraform {
  required_version = "~> 1.12.6"
  required_providers {
    tailscale = {
      source  = "tailscale/tailscale"
      version = "= 0.29.2"
    }
  }
}

locals {
  # Public operator-supplied identity, not proof of API access or live review.
  tailnet = jsondecode(file("${path.module}/tailnet.json")).id
}

# Authentication comes from narrowly scoped runtime provider environment
# variables; no OAuth/API secret is a Terraform variable or Nix input.
provider "tailscale" {
  tailnet = local.tailnet
}

variable "tailnet" {
  type        = string
  default     = null
  description = "Optional confirmation of the checked-in tailnet ID, never a way to select another tailnet."
  validation {
    condition     = var.tailnet == null || var.tailnet == local.tailnet
    error_message = "The confirmation must match tailnet.json; retargeting requires a reviewed configuration change."
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
