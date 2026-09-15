terraform {
  required_version = "= 1.12.6"
  required_providers {
    porkbun = {
      source  = "jianyuan/porkbun"
      version = "= 0.3.2"
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
    error_message = "Use an independently recoverable Porkbun state passphrase of at least 16 characters, separate from tailnet custody."
  }
}

variable "domain" {
  type    = string
  default = null
  validation {
    condition     = var.domain == null ? true : can(regex("^[a-z0-9][a-z0-9.-]*\\.[a-z]{2,}$", var.domain))
    error_message = "Supply the verified domain, not a URL or wildcard."
  }
}

variable "records" {
  type = map(object({
    subdomain = optional(string)
    type      = string
    content   = string
    ttl       = optional(number)
    priority  = optional(number)
    record_id = optional(string)
  }))
  default = {}
  validation {
    condition = alltrue([for record in values(var.records) :
      contains(["A", "AAAA", "CNAME", "ALIAS", "MX", "TXT", "NS", "SRV", "TLSA", "CAA", "HTTPS", "SVCB"], record.type) &&
      length(record.content) > 0 &&
      (record.subdomain == null ? true : !strcontains(lower(record.subdomain), "_acme-challenge") && !strcontains(record.subdomain, "*"))
    ])
    error_message = "Only reviewed persistent DNS records are permitted; no wildcard or ACME challenge ownership."
  }
}

provider "porkbun" {}

import {
  for_each = { for name, record in var.records : name => record if record.record_id != null }
  to       = porkbun_dns_record.selected[each.key]
  id       = "${each.value.record_id}_${var.domain}_${each.value.type}"
}

resource "porkbun_dns_record" "selected" {
  for_each  = var.records
  domain    = var.domain
  subdomain = each.value.subdomain
  type      = each.value.type
  content   = each.value.content
  ttl       = each.value.ttl
  priority  = each.value.priority
  lifecycle {
    prevent_destroy = true
    precondition {
      condition     = var.domain != null
      error_message = "DNS management is blocked until the real domain and existing record inventory are reviewed."
    }
  }
}
