---
name: opentofu
description: "OpenTofu projects under opentofu/ (Tailscale: tailnet policy, device tags, auth keys; Porkbun: the public DNS records; UniFi: VLANs, Wi-Fi, fixed addresses, the LAN firewall, gateway settings), the tofu and unifi-settings flake apps, encrypted state, provider pins, plan and apply rules. Use before changing opentofu/ or modules/opentofu.nix, reviewing a plan the operator pasted, changing a public DNS record, adding a LAN device or firewall rule, or answering who can reach what on the tailnet or the LAN."
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
- CI joins as `tag:ci` through a federated identity that accepts GitHub's OIDC token from
  `check.yml` in this repository, so no secret is stored; GitHub gives no OIDC token to a fork's
  PR. Like the OAuth client, it is a trust credential made in the admin console, since the OAuth
  client lacks the scope to create one: issuer GitHub, subject
  `repo:markeenmelo@8158196/infra@1445093287:*` (GitHub puts the owner's and repository's ids in
  the subject, so a renamed or recreated repository of the same name does not match), claim
  `job_workflow_ref` = `markeenmelo/infra/.github/workflows/check.yml@*`, scope `auth_keys`, tag
  `tag:ci`. Its client id and audience are not secret and go to the repository
  variables `TS_CI_CLIENT_ID` and `TS_CI_AUDIENCE` with `gh variable set`.

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

## UniFi

[main.tf](../../../opentofu/unifi/main.tf) owns the gateway's LAN side: the VLANs, Wi-Fi networks,
fixed client addresses, the LAN wildcard record that points the domain at bastion, IPS and
controller settings, remote syslog to bastion ([monitoring skill](../monitoring/SKILL.md)) and
the firewall. Bastion's LAN address, MAC, gateway and syslog port come from `fleet.hosts.*.lan`
as `fleet_lan`. Plan and apply from the LAN or through bastion's subnet route to the gateway;
apply a network or Wi-Fi change from a wired client, since it can cut the route mid-apply.

**Who reaches what.** Each VLAN is its own firewall zone. The controller lets a custom zone out
to the gateway and the internet and keeps it from the other zones, so `local.policies` lists
only the exceptions, one row each: `from` and `to` zones, optional `from_ips`, `to_ips`,
`protocol`, one `port` or a `ports` group, and `block`. An allow towards another VLAN gets its
return policy from the controller; one towards the gateway or the internet must not ask for it,
and an ICMP policy is IPv4 only, both of which the resource derives. `local.orders` lists the
zone pairs where order decides, first match first. A client's flags in `local.clients` put it in
a role the rows use: `admin` (reaches the gateway's own HTTPS), `cloud` (IoT allowed to the
internet), `shared` (IoT that Home and the tailnet reach), `player` (IoT that reaches bastion's
HTTPS). Tailnet clients routed through bastion arrive as bastion's address, so the
"Bastion-routed" rows decide what they reach, behind the tailnet grants.

**Provider limits** (filipowm/unifi):
- The WAN, ad blocking and per-network mDNS stay in the controller UI: the provider rewrites a
  whole network from its schema, which drops the WAN's PPPoE VLAN tag, discards the ad-blocking
  networks, and fails in-place updates of `multicast_dns` and the Default network's IPv6 flags.
- A policy takes one `port`; several ports go through a port group, since a comma list reads
  back as null.
- `unifi_setting_ips` takes only the categories the Network UI lists; others are dropped and the
  apply fails as inconsistent.
- A fixed client's `mac` forces replacement, which forgets the client in the controller. Its
  `note` is left to the controller UI: the provider cannot clear one, so an unset note would
  show as a change on every plan.
- `dhcp_dns` stays unset except on Kids: any value turns DHCP DNS on.

Settings no provider writes (DoH resolvers, the country block, UPnP and the NAT helpers off, the
weekly controller backup) live in [settings.json](../../../opentofu/unifi/settings.json), keyed
by the controller's setting name. `nix run .#unifi-settings -- check` exits 1 and lists the
drift; `apply`, which needs the same approval as an OpenTofu apply, merges the file into each
setting and leaves every other field alone.
