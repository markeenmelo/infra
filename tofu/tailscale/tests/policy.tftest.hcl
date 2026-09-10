# Synthetic, offline provider. Never authenticates to a real tailnet.
mock_provider "tailscale" {}

variables {
  tailnet = "TEST-ONLY-NOT-A-TAILNET"
}

run "policy_and_dns" {
  command = plan
  assert {
    condition     = !tailscale_acl.policy.overwrite_existing_content && !tailscale_acl.policy.reset_acl_on_destroy
    error_message = "Policy adoption/reset protection must remain enabled."
  }
  assert {
    condition     = tailscale_dns_preferences.tailnet.magic_dns
    error_message = "MagicDNS should be managed without changing resolver configuration."
  }
  assert {
    condition     = length(jsondecode(tailscale_acl.policy.acl).grants) == 1 && length(jsondecode(tailscale_acl.policy.acl).acls) == 0 && length(jsondecode(tailscale_acl.policy.acl).ssh) == 0
    error_message = "The initial policy must have only the explicitly reviewed grant."
  }
}

run "reject_implicit_tailnet" {
  command = plan
  variables {
    tailnet = "-"
  }
  expect_failures = [var.tailnet]
}
