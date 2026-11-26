# Tailnet

[tailscale.nix](../../../modules/tailscale.nix) joins every NixOS host with the auth key in
`secrets/hosts/HOST.yaml` (`tailscale-auth-key`, [secrets.md](secrets.md)) and
keeps `/var/lib/tailscale` under `/persist`, so a host authenticates once and survives reboots
and deploys. SSH is admitted only on the tailnet interface ([ssh.nix](../../../modules/ssh.nix)).

## Auth key

The [OpenTofu project](../opentofu/SKILL.md) mints one pre-authorized, tagged, single-use key per
host and recreates it on apply once expired. The operator moves it into the host file, never
through a terminal that echoes it:

```sh
nix run .#tofu -- tailscale output -json enrollment_keys | jq .HOST |
  sops set --value-stdin secrets/hosts/HOST.yaml '["tailscale-auth-key"]'
```

The key is spent by `enroll` for a new host ([deploy.md](deploy.md#install)), or on
the first boot of a host whose `/var/lib/tailscale` holds no login, and ignored once the node is logged in, so it only
matters at install time: an expired key in Git blocks nothing until a reinstall, when the operator
applies and copies again.

## Reinstall

The `install` app carries `/persist/var/lib/tailscale` with `/persist/etc/ssh` (both in
`fleet.carry`, [deploy.md](deploy.md#install)), so the node keeps its identity; otherwise it joins as a new node under the
same name and the old one is removed in the admin console. Never `tailscale logout` a live host.

## VPN exit nodes

[vpn-exit.nix](../../../modules/vpn-exit.nix) runs one more `tailscaled` per country on
bastion, each inside its own Private Internet Access namespace (the PIA account and per-start
keys as for the arr apps, [services: arr](../services/arr.md)), advertised as the exit node
`vpn-COUNTRY` (`vpn-ca`, `vpn-us`, `vpn-br`; regions in `countries`) and tagged `tag:vpn-exit`; the tailnet policy approves them by tag
and admits the admin clients and members to the internet through them. Each joins once with its
own key, `vpn-exit/COUNTRY-auth-key`,
moved like a host's from the `enrollment_keys` output, and keeps `/var/lib/tailscale-COUNTRY`
under `/persist`. Each node's direct peer traffic, the marked UDP from its own tailscaled port, goes around PIA:
`pvCOUNTRY-bypass` routes it over the namespace's bridge and bastion masquerades it, so clients
reach the nodes directly and see bastion's public address as their endpoint; the `vpn-exit`
nftables table lets it reach public addresses only, never the LAN, the tailnet or another
namespace. Control, DERP and the DNS tailscaled forwards for exit clients stay in the tunnel. [vpn-watch.nix](../../../modules/vpn-watch.nix) restarts a tunnel that fails or
whose handshake is older than five minutes, and starts its exit node again each time it comes up. Choosing
an exit node is done on the client: the desktops go back to `vpn-ca` at every boot and after every auto-connect run, a re-login included (`tailscale-exit-node`, [desktop.nix](../../../modules/desktop.nix), wanted by `tailscaled-set`, tried for five minutes and otherwise leaving the exit node as it was; activation starts it on the deploy that adds it but never waits for it, and a later deploy leaves it alone; the unit fails if the node named `vpn-ca` is offline, so a stale node holding the name shows in `systemctl --failed`), and the bar's tailnet panel picks another or none until then; with bastion or the tunnel down, the internet is down on them until another is picked. Their local subnet stays off the tunnel
(`--exit-node-allow-lan-access`, [desktop.nix](../../../modules/desktop.nix)), since an exit node
never reaches a LAN; on an untrusted network that subnet sees the laptop's local traffic. On the Linux laptops `marcos`
is the Tailscale operator ([noctalia.nix](../../../modules/noctalia.nix)), an accepted risk: every
process of `marcos`, the Noctalia plugins included, holds the whole LocalAPI (`up`, `down`, `set`,
`serve`, `logout`) without a password, so a bump of those plugins needs their code read, not just
the hash. Every host's auto-connect `tailscale up` carries `--reset`
([desktop.nix](../../../modules/desktop.nix), [server.nix](../../../modules/server.nix)), since `up` refuses stored non-default settings it is
not given again; `tailscaled-set` re-applies the declared ones after it, on every run of the auto-connect unit
([tailscale.nix](../../../modules/tailscale.nix)), since upstream starts it only with `tailscaled`.
