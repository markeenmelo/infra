---
name: opentofu
description: "OpenTofu projects under opentofu/ (Tailscale: tailnet policy, services, device tags, auth keys), the tofu flake app, encrypted state, provider pins, plan and apply rules. Use before changing opentofu/ or modules/opentofu.nix, reviewing a plan the operator pasted, or answering who can reach what on the tailnet."
---

# OpenTofu

[opentofu/PROJECT/](../../../opentofu/) is operator-only; no host reads it. The `tofu` app
([opentofu.nix](../../../modules/opentofu.nix)) runs any OpenTofu command inside a project with the
credentials from `secrets/PROJECT/operator.yaml` ([secrets skill](../secrets/SKILL.md)) and the
state at `$XDG_STATE_HOME/infra/PROJECT/terraform.tfstate`, encrypted with
`TF_VAR_state_passphrase` from the same file. State is never in Git; a lost state is recovery,
not a routine apply. The `opentofu` check only runs `tofu fmt`; validation needs the providers.

```sh
nix run .#tofu -- tailscale init                 # once per checkout, and after a provider change
nix run .#tofu -- tailscale plan                 # Claude reviews the pasted plan
nix run .#tofu -- tailscale apply                # operator only, after approval
nix run .#tofu -- tailscale providers lock -platform=linux_amd64 -platform=darwin_arm64
```

Claude never runs `apply`, `import`, `state` commands or prints sensitive outputs; it prepares
the exact command and reviews the plan ([CLAUDE.md](../../../CLAUDE.md#autonomy)). Keep resource
addresses: rename with a `moved` block and drop it after one apply. A resource with
`prevent_destroy` is removed by dropping the block, applying, then restoring it. Rotate the state
passphrase with a `fallback` key provider carrying the old one, apply, remove it.

## Tailscale

[main.tf](../../../opentofu/tailscale/main.tf) owns the whole tailnet: the policy as `jsonencode`
of a local (grants only; `tests` guard the SSH boundary and run on every apply), tailnet
settings, DNS (global resolver plus split DNS for the domain to bastion), the services bastion
hosts, tags on devices enrolled without a key, and one auth key per host. The admin console is
read-only for all of these; `acls_externally_managed_on` says so.

- Auth keys recreate on apply once invalid; the [tailnet skill](../tailnet/SKILL.md) moves one
  into `secrets/hosts/HOST.yaml`.
- A host enrolled by key carries the key's tag; retagging it is a re-enrollment.
- Approval (`autoApprovers`) is not retroactive: apply a new route or service approver before
  deploying the host that advertises it.
- `tag:infra-provisioner` belongs to the OAuth client only.
