---
name: deploy
description: "deploy-rs: how a host's committed configuration is activated over the tailnet with magic rollback, the deploy account and what it may run, the deploy checks, and the nixos-anywhere install app that carries a host's SSH and tailnet identity over. Use before touching modules/deploy.nix or modules/install.nix, the deploy account or sudo rules, and before preparing any deploy or install command."
---

# Deploy

[deploy.nix](../../../modules/deploy.nix) turns every `fleet.hosts` entry into a deploy-rs node
reached by its MagicDNS name as the `deploy` account. That account is root-equivalent: it is a
Nix trusted user so unsigned closures can be copied in, and sudo lets it run any store path's
`activate-rs` and remove the rollback canary. Its key is therefore the operator's root key on
every host, and CI gets its own. It is not in `wheel`, so `security.sudo.execWheelOnly` stays
off: it would make sudo unexecutable for it and break every deploy. IPv6 stays on host-wide for the
same reason: MagicDNS answers with each node's tailnet IPv6 address, and a peer that tries it first
against a host with IPv6 off waits out a connect timeout that can outlast the rollback confirm;
the uplinks refuse IPv6 per link instead. Magic rollback and auto rollback stay on: a profile
that breaks the SSH path reverts after the confirm timeout. `nix flake check` carries the
deploy-rs schema and activation checks per system.

A host that runs the builder ([builder.nix](../../../modules/builder.nix)), or has another
system than bastion, builds itself; every other host is built on the deploying machine, which
hands the build to bastion when it imports `remote-builds` (only the mac so far). The deploying
machine receives the whole closure back from bastion; deploy-rs then pushes it with
`--substitute-on-destination`, so the target fetches what bastion holds from its Harmonia cache.
Bastion trusts the admin clients' build keys, not the hosts it builds for: racknerd only reads
the cache, signed, so a compromised edge cannot write into bastion's store. A build key is a
trusted user on bastion and whatever it uploads is signed and served to racknerd; it sits on the
admin client beside the operator's key, which is already root on every host, so it widens nothing.
CI reads the cache too: [check.yml](../../../.github/workflows/check.yml) joins the tailnet as an
ephemeral `tag:ci` node, whose only grant is port 5005, fetches what bastion holds and leaves
before it builds, so tailnet minutes stay short and nothing built from PR code reaches bastion.
The tailnet policy decides who reaches 5005; bastion's firewall admits it from any tailnet peer.
What bastion built for another host stays until its store runs low on space: bastion collects
garbage only then, not weekly ([builder.nix](../../../modules/builder.nix)).

```sh
nix run .#deploy -- .#HOST          # after checks pass on the committed revision
nix run .#deploy -- .#HOST --boot   # set the boot default only, no activation
```

Claude prepares the command and asks first ([CLAUDE.md](../../../CLAUDE.md#autonomy)); a deploy
that changes SSH, firewall, Tailscale, users, sudo or this module is an access change. The first
activation of a host is a nixos-anywhere install, not a deploy. The installed generation has no
deploy-rs activation files, so the first deploy after an install cannot roll back to it: a failed
activation leaves the new configuration running with the profile pointing at the old generation,
until a deploy succeeds. Any failed unit fails the activation, so setup units stay idempotent and
do not fail on an outside service being down. A host without a tailnet
connection is unreachable to deploy-rs by design: recover through the provider or physical
console.

## Install

[install.nix](../../../modules/install.nix) wraps nixos-anywhere for a host booted into an
installer image with its old disk mounted read-only: it copies the host's `fleet.carry` paths
(the SSH host key, `/var/lib/tailscale`, and what the host adds, such as bastion's Secure Boot
keys and ZFS key files) out of the old persist tree into an `--extra-files` tree, both under
`/persist` and at their live paths, since the installer reads some of them (Limine signs with
`/var/lib/sbctl`) before Preservation exists; the root copy is gone on first boot. It then
unmounts the old disk, partitions with the host's disko layout and installs its configuration,
so the host keeps its SSH identity and its tailnet node, and sops-nix can decrypt on first boot.
A path that holds the only copy of a key goes in `fleet.carry` beside its owner, so no install
can forget it. Fleet hosts
admit no root login and no SSH off the tailnet ([ssh.nix](../../../modules/ssh.nix)), so a
reinstall always goes through the installer image, where root is the login. The disk is wiped;
it is an access change and needs the operator's approval.

```sh
ssh root@ADDRESS 'mkdir -p /mnt/old && mount -o ro /dev/DISK-PART /mnt/old'
nix run .#install -- HOST root@ADDRESS /mnt/old/persist
```

An encrypted old disk is opened first, with `cryptsetup open /dev/DISK-PART old` and
`/dev/mapper/old` as the mounted device; disko closes the mapping before it wipes the disk, and
asks for the new passphrase on the terminal.

ADDRESS is the host's public or LAN address, not its MagicDNS name, since the tailnet node is replaced
during the install. The installer presents its own host key, so `ssh-keygen -R ADDRESS` first
and accept the new one; the carried key returns with the installed system. From the mac the
closure builds on the target, inside the installer's memory-backed store. Rotate the host's auth key first ([tailnet skill](../tailnet/SKILL.md)) in
case the carried state is rejected; the key in the host file is only read when
`/var/lib/tailscale` holds no login.
