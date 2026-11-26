---
name: opentofu
description: "OpenTofu projects under opentofu/ (Tailscale: tailnet policy, device tags, auth keys; Porkbun: the public DNS records; UniFi: VLANs, Wi-Fi, fixed addresses, the LAN firewall, gateway settings; Oracle: the cloud network, its border firewall, the instances and their reserved addresses), the tofu and unifi-settings flake apps, encrypted state, provider pins, plan and apply rules. Use before changing opentofu/ or modules/opentofu.nix, reviewing a plan the operator pasted, changing a public DNS record, adding a LAN device or firewall rule, adding or resizing a cloud instance or opening a port at its border, or answering who can reach what on the tailnet or the LAN."
---

# OpenTofu

[opentofu/PROJECT/](../../../opentofu/) is operator-only; no host reads it. The `tofu` app
([opentofu.nix](../../../modules/opentofu.nix)) runs any OpenTofu command inside a project with the
credentials from `secrets/PROJECT/operator.yaml`, plus `secrets/PROJECT/api.yaml` when the
project shares a credential with a host ([operating: secrets](../operating/secrets.md)), and the
state in schema `PROJECT` of the `tofu` database on bastion's PostgreSQL, which only the
operator laptops reach over the tailnet, locked per run and encrypted with
`TF_VAR_state_passphrase` from the same file. State is never in Git; a lost state is recovery,
not a routine apply: adopt the live objects with `import` blocks, plan until nothing is created,
apply, then drop the blocks. The tailscale project's own state sits behind the grant that
project applies, and bastion's sshd forwards no ports, so a policy that loses the operator
laptops' grant to the state port is repaired in the admin console (lifting
`acls_externally_managed_on` first if it blocks the edit), then planned and applied again. The
`format` check runs `tofu fmt` over the projects ([nix skill](../nix/SKILL.md)); validation needs the providers, so
[check.yml](../../../.github/workflows/check.yml) runs `tofu validate` on each project.

```sh
nix run .#tofu -- tailscale providers lock -platform=linux_amd64 -platform=linux_arm64  # provider change
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
settings, DNS (global resolver, which a client using an exit node leaves for the exit node's own resolver, plus split DNS for the domain to bastion), tags on devices enrolled
without a key, and one auth key per host. Bastion's apps are reached through that split DNS and
its LAN proxy, so the tailnet defines no Tailscale services; that is why `group:members` reach
bastion on 443 and 53. Host addresses come from `fleet.hosts.*.tailnetAddress`, which the `tofu`
app passes as `TF_VAR_fleet_hosts`; the two bastion ports the
edge reaches come the same way as `fleet_public_port` and `fleet_bans_port`
([proxy skill](../proxy/SKILL.md)), and each host's
`fleet.hosts.HOST.telemetry` ports as `TF_VAR_fleet_telemetry`, and the cache port,
the operator laptops, the state database's port, the routed LAN subnets and the gateway as `fleet_cache_port`,
`fleet_operators`, `fleet_state_port`, `fleet_routes` and `fleet_lan`, so a new log
sender or a moved port needs only a plan and an apply. Every project reads the domain
from `fleet.domain` as `TF_VAR_fleet_domain`. The admin console is
read-only for all of these; `acls_externally_managed_on` says so.

- `grafite` is the operator's phone, an admin client outside the fleet.
- `tag:kid` is inspiron, Ian's laptop on the Kids VLAN; its grants and their tests in `main.tf`
  hold what it reaches.
- Auth keys recreate on apply once invalid; [operating: tailnet](../operating/tailnet.md) moves one
  into `secrets/hosts/HOST.yaml`.
- A host enrolled by key carries the key's tag; retagging it is a re-enrollment.
- Approval (`autoApprovers`) is not retroactive: apply a new route or exit node approver before
  deploying the host that advertises it.
- `tag:infra-provisioner` belongs to the OAuth client only.
- CI joins as `tag:ci` through a federated identity that accepts GitHub's OIDC token from
  `check.yml` on `main` in this repository, so no secret is stored. Only pushes to `main` join:
  a pull request would otherwise run its own edits to `check.yml` and its
  bumped inputs' evaluation on the tailnet, so pull requests fetch from cache.nixos.org only. Agents merge into `dev`, whose
  push run never joins; `main` takes only the operator's merge of `dev`, and
  [CODEOWNERS](../../../.github/CODEOWNERS) holds workflows, the flake's inputs and pins, and this project for the
  operator's review on the way. Any other Nix that reaches `main` is still evaluated on that run, which the policy lets reach bastion's cache port
  and nothing else. Like the OAuth client, it is a trust credential made in the admin console, since the OAuth
  client lacks the scope to create one: issuer GitHub, subject
  `repo:markeenmelo@8158196/infra@1445093287:*` (GitHub puts the owner's and repository's ids in
  the subject, so a renamed or recreated repository of the same name does not match), claim
  `job_workflow_ref` = `markeenmelo/infra/.github/workflows/check.yml@refs/heads/main`, scope `auth_keys`, tag
  `tag:ci`. Its client id and audience are not secret and go to the repository
  variables `TS_CI_CLIENT_ID` and `TS_CI_AUDIENCE` with `gh variable set`.

## Porkbun

[main.tf](../../../opentofu/porkbun/main.tf) owns every record of the domain: one wildcard `A`
to the edge (`fleet.hosts.*.publicAddress`, passed as `fleet_edge_address`), since the edge aborts any hostname it does not publish and the wildcard
certificate names none ([proxy skill](../proxy/SKILL.md)), so publishing an app needs no DNS
change; the `CAA` set that confines issuance to Let's Encrypt, wildcard included, and to DNS-01,
so holding the address the names point at, as the edge's provider does, gets no certificate, and forbids
S/MIME; and the null-mail set (null `MX` on the apex and on the wildcard, `-all` SPF, reject
DMARC covering subdomains, empty DKIM) that lets no one send as the domain or any name under it. The API keys in `secrets/porkbun/api.yaml` are
bastion's DNS-01 keys and are full-authority, so a plan already carries risk. A record that exists before its block is
adopted with an `import` block (`<record_id>_<domain>_<type>`, ids from the operator's
private listing), never duplicated.

## Oracle

[main.tf](../../../opentofu/oracle/main.tf) owns the Oracle Cloud tenancy, all of it in the root
compartment of the home region, the only place Always Free resources exist: one network with a
public subnet, its border firewall, and one Ampere A1 instance per row of `local.instances`, each
behind a reserved address that a recreated instance keeps and `addresses` outputs for
`fleet.hosts.HOST.publicAddress`. The rows share the Always Free A1 and block volume allowances
([Always Free Resources](https://docs.oracle.com/en-us/iaas/Content/FreeTier/resourceref.htm));
Oracle changes those without notice, so read that page before adding or growing a row, and move
`local.free` with it. The credentials in `secrets/oracle/operator.yaml` are an API signing key
with its user's authority over the tenancy.

The account is Pay As You Go, so use past the allowance is billed instead of refused. The `free`
quota refuses it first: every compute shape but A1 and the Always Free micro, A1 and block
storage beyond `local.free`, and both anywhere but the home region, where nothing is free.
Oracle's quota reference omits names a tenancy has (the regional A1 ones), and a name the
blanket `zero` leaves unset refuses every launch, so after changing a statement read the result
back with `oci limits resource-availability get`. It names only those two services; outbound data and every other
service are caught after the fact by the `spend` budget, which Oracle evaluates once a day and
which mails `alert_email` on any spend at all. A paid resource is a deliberate edit of the quota.

The border is the network's default security list, taken over so Oracle's own rule admitting
port 22 is gone. It admits the web ports, `fleet_unlock_ports` for a host that takes its disk
passphrase over SSH from the initrd, where no host firewall runs yet, Tailscale's port
(`fleet_tailscale_port`) so traffic to bastion connects directly instead of through a relay, and
no ICMP at all, so the host finds the path MTU by probing ([host.nix](../../../modules/hosts/edge/host.nix)). Port 22 opens only with `-var install=NAME`, for the
stock image and the nixos-anywhere installer. The same flag raises that one instance to
`local.installer_memory`, the only size the installer, which runs from memory, has been through
an install at; whether the edge's running size would do is untested. A resize reboots an
instance, which is why the flag names one: any other instance keeps running. The apply after the
install, without the flag, closes the port and shrinks the instance, which reboots it. A
precondition refuses a plan whose instances, at those sizes, exceed `local.free`.

An instance launches from the newest Ubuntu image, which admits the deploy account's keys
(`fleet_deploy_keys`), and ignores later images and later keys, since the install replaces both
and the provider would otherwise reimage the boot volume for a new image and replace the instance
for a new key. A1 capacity runs
out: an apply that fails with `Out of host capacity` has created the network and is applied again
later. Oracle may reclaim an instance it deems idle; the next apply recreates it behind the same
address, and the host is installed again.

## UniFi

[main.tf](../../../opentofu/unifi/main.tf) owns the gateway's LAN side: the VLANs, Wi-Fi networks,
fixed client addresses, the LAN wildcard record that points the domain at bastion, IPS and
controller settings, remote syslog to bastion ([services: monitoring](../services/monitoring.md)) and
the firewall. Bastion's LAN address, MAC, gateway and syslog port come from `fleet.hosts.*.lan`
as `fleet_lan`. Plan and apply from the LAN or through bastion's subnet route to the gateway;
apply a network or Wi-Fi change from a wired client, since it can cut the route mid-apply.

**Who reaches what.** Each VLAN is its own firewall zone. The controller lets a custom zone out
to the gateway and the internet and keeps it from the other zones, so `local.policies` lists
only the exceptions, one row each: `from` and `to` zones, optional `from_ips`, `to_ips`,
`protocol`, one `port` or a `ports` group, `block`, and a `schedule` (the Kids' bedtime block). An allow towards another VLAN gets its
return policy from the controller; one towards the gateway or the internet must not ask for it,
and an ICMP policy is IPv4 only, both of which the resource derives. `local.orders` lists the
zone pairs where order decides, first match first. A client's flags in `local.clients` put it in
a role the rows use: `admin` (reaches the gateway's own HTTPS), `cloud` (IoT allowed to the
internet), `shared` (IoT that Home and the tailnet reach), `player` (IoT that reaches bastion's
HTTPS). Tailnet clients routed through bastion arrive as bastion's address, so the
"Bastion-routed" rows decide what they reach, behind the tailnet grants.

Kids resolve through the gateway like every other VLAN, so they get the LAN wildcard record and
reach bastion directly instead of through the edge. Filtering is the gateway's content filter
(Family) applied to the Kids network in the controller UI, which the provider cannot write, and
a Kids row blocks every external resolver on 53 and 853. A Kids device set to DoH on 443 is not
filtered: an accepted gap. After an apply that touches the Kids network, check in the UI that the
filter still lists it.

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
- `dhcp_dns` stays unset: any value turns DHCP DNS on.

Settings no provider writes (DoH resolvers, the country block, UPnP and the NAT helpers off, the
weekly controller backup) live in [settings.json](../../../opentofu/unifi/settings.json), keyed
by the controller's setting name. `nix run .#unifi-settings -- check` exits 1 and lists the
drift; `apply`, which needs the same approval as an OpenTofu apply, merges the file into each
setting and leaves every other field alone.
