terraform {
  required_providers {
    porkbun = {
      source  = "jianyuan/porkbun"
      version = "~> 0.3.4"
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

variable "fleet_domain" {
  description = "The fleet's domain, from fleet.domain; the tofu app sets it."
  type        = string
}

locals {
  domain = var.fleet_domain
  edge   = "72.11.150.242"
  records = {
    edge          = { subdomain = "*", type = "A", content = local.edge }
    caa-issue     = { subdomain = null, type = "CAA", content = "0 issue \"letsencrypt.org\"" }
    caa-issuewild = { subdomain = null, type = "CAA", content = "0 issuewild \"letsencrypt.org\"" }
    caa-issuemail = { subdomain = null, type = "CAA", content = "0 issuemail \";\"" }
    null-mx       = { subdomain = null, type = "MX", content = "." }
    null-mx-wild  = { subdomain = "*", type = "MX", content = "." }
    spf           = { subdomain = null, type = "TXT", content = "v=spf1 -all" }
    dmarc         = { subdomain = "_dmarc", type = "TXT", content = "v=DMARC1; p=reject; sp=reject; adkim=s; aspf=s" }
    dkim          = { subdomain = "*._domainkey", type = "TXT", content = "v=DKIM1; p=" }
  }
}

resource "porkbun_dns_record" "fleet" {
  for_each  = local.records
  domain    = local.domain
  subdomain = each.value.subdomain
  type      = each.value.type
  content   = each.value.content
  lifecycle {
    prevent_destroy = true
  }
}
