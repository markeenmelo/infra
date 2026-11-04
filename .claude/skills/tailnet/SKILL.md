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

Admin console → Settings → Keys → Generate auth key: single use, not ephemeral, pre-authorized,
tag `tag:server`, longest expiry. The key is consumed on the host's first boot and ignored once
the node is logged in, so it only matters at install time: an expired key in Git blocks nothing
until a reinstall, when the operator rotates it. The tailnet policy must own `tag:server` in
`tagOwners` and grant `tag:admin-client` to `tag:server:22`; the OpenTofu project owns that
policy once it lands here.

## Reinstall

Pass the preserved `/persist/var/lib/tailscale` to nixos-anywhere `--extra-files` with
`/persist/etc/ssh` and the node keeps its identity; otherwise it joins as a new node under the
same name and the old one is removed in the admin console. Never `tailscale logout` a live host.
