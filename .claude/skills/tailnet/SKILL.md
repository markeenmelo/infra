---
name: tailnet
description: "Tailscale on every host: how a host joins and stays joined, which traffic the tailnet admits (SSH), the auth key secret and the tag it needs, recovery after reinstall. Use before touching modules/tailscale.nix, tailscale0 firewall rules, or when a host must join or rejoin the tailnet."
---

# Tailnet

[tailscale.nix](../../../modules/tailscale.nix) joins every NixOS host with the auth key in
`secrets/hosts/HOST.yaml` (`tailscale-auth-key`, [secrets skill](../secrets/SKILL.md)) and
keeps `/var/lib/tailscale` under `/persist`, so a host authenticates once and survives reboots
and deploys. SSH is admitted only on the tailnet interface ([ssh.nix](../../../modules/ssh.nix)).

## Auth key

The [OpenTofu project](../opentofu/SKILL.md) mints one pre-authorized, tagged, single-use key per
host and recreates it on apply once expired. The operator moves it into the host file, never
through a terminal that echoes it:

```sh
nix run .#tofu -- tailscale output -json enrollment_keys | jq .racknerd |
  sops set --value-stdin secrets/hosts/racknerd.yaml '["tailscale-auth-key"]'
```

The key is consumed on the host's first boot and ignored once the node is logged in, so it only
matters at install time: an expired key in Git blocks nothing until a reinstall, when the operator
applies and copies again.

## Reinstall

Pass the preserved `/persist/var/lib/tailscale` to nixos-anywhere `--extra-files` with
`/persist/etc/ssh` and the node keeps its identity; otherwise it joins as a new node under the
same name and the old one is removed in the admin console. Never `tailscale logout` a live host.

## Proton exit nodes

[proton-exit.nix](../../../modules/proton-exit.nix) runs one more `tailscaled` per country on
bastion, each inside its own Proton WireGuard namespace, advertised as the exit node
`proton-COUNTRY`; the tailnet policy approves them by tag and admits the admin clients and
members to the internet through them. Each joins once with its own key, `proton-exit/COUNTRY-auth-key`,
moved like a host's from the `enrollment_keys` output, and keeps `/var/lib/tailscale-COUNTRY`
under `/persist`. [vpn-watch.nix](../../../modules/vpn-watch.nix) restarts a tunnel that fails or
whose handshake is older than five minutes, and starts its exit node again each time it comes up. Choosing
an exit node is done on the client; the desktop switcher arrives with the laptops.
