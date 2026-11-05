---
name: deploy
description: "deploy-rs: how a host's committed configuration is activated over the tailnet with magic rollback, the deploy account and what it may run, the deploy checks, and the nixos-anywhere install app that carries a host's SSH and tailnet identity over. Use before touching modules/deploy.nix or modules/install.nix, the deploy account or sudo rules, and before preparing any deploy or install command."
---

# Deploy

[deploy.nix](../../../modules/deploy.nix) turns every `fleet.hosts` entry into a deploy-rs node
reached by its MagicDNS name as the `deploy` account. That account is root-equivalent: it is a
Nix trusted user so unsigned closures can be copied in, and sudo lets it run any store path's
`activate-rs` and remove the rollback canary. Its key is therefore the operator's root key on
every host, and CI gets its own. Magic rollback and auto rollback stay on: a profile
that breaks the SSH path reverts after the confirm timeout. `nix flake check` carries the
deploy-rs schema and activation checks per system.

```sh
nix run .#deploy -- .#HOST          # after checks pass on the committed revision
nix run .#deploy -- .#HOST --boot   # set the boot default only, no activation
```

Claude prepares the command and asks first ([CLAUDE.md](../../../CLAUDE.md#autonomy)); a deploy
that changes SSH, firewall, Tailscale, users, sudo or this module is an access change. The first
activation of a host is a nixos-anywhere install, not a deploy. A host without a tailnet
connection is unreachable to deploy-rs by design: recover through the provider or physical
console.

## Install

[install.nix](../../../modules/install.nix) wraps nixos-anywhere for a host booted into an
installer image with its old disk mounted read-only: it copies the SSH host key and
`/var/lib/tailscale` out of the old persist tree into an `--extra-files` tree, unmounts the old
disk, then partitions with the host's disko layout and installs its configuration, so the host
keeps its SSH identity and its tailnet node, and sops-nix can decrypt on first boot. Fleet hosts
admit no root login and no SSH off the tailnet ([ssh.nix](../../../modules/ssh.nix)), so a
reinstall always goes through the installer image, where root is the login. The disk is wiped;
it is an access change and needs the operator's approval.

```sh
ssh root@ADDRESS 'mkdir -p /mnt/old && mount -o ro /dev/DISK-PART /mnt/old'
nix run .#install -- HOST root@ADDRESS /mnt/old/persist
```

ADDRESS is the host's public address, not its MagicDNS name, since the tailnet node is replaced
during the install. The installer presents its own host key, so `ssh-keygen -R ADDRESS` first
and accept the new one; the carried key returns with the installed system. From the mac the
closure builds on the target, inside the installer's memory-backed store. Rotate the host's auth key first ([tailnet skill](../tailnet/SKILL.md)) in
case the carried state is rejected; the key in the host file is only read when
`/var/lib/tailscale` holds no login.
