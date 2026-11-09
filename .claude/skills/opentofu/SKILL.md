---
name: opentofu
description: "OpenTofu projects under opentofu/ (Tailscale: tailnet policy, device tags, auth keys; Porkbun: the public DNS records), the tofu flake app, encrypted state, provider pins, plan and apply rules. Use before changing opentofu/ or modules/opentofu.nix, reviewing a plan the operator pasted, changing a public DNS record, or answering who can reach what on the tailnet."
---

# OpenTofu

[opentofu/PROJECT/](../../../opentofu/) is operator-only; no host reads it. The `tofu` app
([opentofu.nix](../../../modules/opentofu.nix)) runs any OpenTofu command inside a project with the
credentials from `secrets/PROJECT/operator.yaml`, plus `secrets/PROJECT/api.yaml` when the
project shares a credential with a host ([secrets skill](../secrets/SKILL.md)), and the
state at `$XDG_STATE_HOME/infra/PROJECT/terraform.tfstate`, encrypted with
`TF_VAR_state_passphrase` from the same file. State is never in Git; a lost state is recovery,
not a routine apply, and a moved `XDG_STATE_HOME` is a changed backend that needs an approved
`init -migrate-state`. The `opentofu` check only runs `tofu fmt`; validation needs the providers.

```sh
nix run .#tofu -- tailscale providers lock -platform=linux_amd64 -platform=darwin_arm64  # provider change
nix run .#tofu -- tailscale init                 # once per checkout, and after providers lock
nix run .#tofu -- tailscale plan                 # Claude reviews the pasted plan
nix run .#tofu -- tailscale apply                # operator only, after approval
```

Claude never runs `apply`, `import`, `state` commands or prints sensitive outputs; it prepares
the exact command and reviews the plan ([CLAUDE.md](../../../CLAUDE.md#autonomy)). Keep resource
addresses: rename with a `moved` block, adopt something that already exists with an `import`
block, and drop either after one apply. A resource with
`prevent_destroy` is removed by dropping the block, applying, then restoring it. Rotate the state
passphrase with a `fallback` key provider carrying the old one, apply, remove it.

## Tailscale

[main.tf](../../../opentofu/tailscale/main.tf) owns the whole tailnet: the policy as `jsonencode`
of a local (grants only; `tests` guard the SSH boundary and run on every apply), tailnet
settings, DNS (global resolver plus split DNS for the domain to bastion), tags on devices enrolled
without a key, and one auth key per host. Bastion's apps are reached through that split DNS and
its LAN proxy, so the tailnet defines no Tailscale services; that is why `group:members` reach
bastion on 443 and 53. Host addresses come from `fleet.hosts.*.tailnetAddress`, which the `tofu`
app passes as `TF_VAR_fleet_hosts`. The admin console is
read-only for all of these; `acls_externally_managed_on` says so.

- Auth keys recreate on apply once invalid; the [tailnet skill](../tailnet/SKILL.md) moves one
  into `secrets/hosts/HOST.yaml`.
- A host enrolled by key carries the key's tag; retagging it is a re-enrollment.
- Approval (`autoApprovers`) is not retroactive: apply a new route or exit node approver before
  deploying the host that advertises it.
- `tag:infra-provisioner` belongs to the OAuth client only.

## Porkbun

[main.tf](../../../opentofu/porkbun/main.tf) owns every record of the domain: one wildcard `A`
to the edge, since the edge aborts any hostname it does not publish and the wildcard
certificate names none ([proxy skill](../proxy/SKILL.md)), so publishing an app needs no DNS
change; the `CAA` set that confines issuance to Let's Encrypt, wildcard included, and forbids
S/MIME; and the null-mail set (null `MX` on the apex and on the wildcard, `-all` SPF, reject
DMARC covering subdomains, empty DKIM) that lets no one send as the domain or any name under it. The API keys in `secrets/porkbun/api.yaml` are the
edge's DNS-01 keys and are full-authority, so a plan already carries risk. A record that exists before its block is
adopted with an `import` block (`<record_id>_<domain>_<type>`, ids from the operator's
private listing), never duplicated.
