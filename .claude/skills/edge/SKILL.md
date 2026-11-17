---
name: edge
description: "The edge host: the Oracle Cloud Ampere A1 instance, its LUKS state partition with no TPM, the initrd that takes the passphrase over SSH on its public address, the unlock, wake and install apps for it, what it holds that the provider could read, how it boots, reaches the network and builds itself. Use before touching modules/hosts/edge or modules/unlock.nix, rebooting or reinstalling the instance, changing the unlock port or the initrd host key, or debugging a boot that never reaches the tailnet."
---

# Edge

[modules/hosts/edge/](../../../modules/hosts/edge/) is the instance the
[Oracle project](../opentofu/SKILL.md#oracle) creates: one Ampere A1 core on a virtio disk, UEFI,
`aarch64-linux`. It runs the `server` role with `telemetry` and nothing public yet; racknerd is
still the edge ([proxy skill](../proxy/SKILL.md)). Like asahi it builds its own closure on
deploy, which is nearly all substitution from cache.nixos.org.

The provider runs the hypervisor and can read the instance's memory, so no disk encryption hides
a running host from it. The design answer is that nothing worth reading lives here: the host
holds its SSH host key, its tailnet node key and the initrd host key, and each only reaches what
the tailnet policy grants the host. The encrypted state partition protects those at rest, in
snapshots and volume backups.

## Unlock

[unlock.nix](../../../modules/unlock.nix) is for a host whose state partition no TPM opens. Its
initrd brings the uplink up with the host's own networkd units and runs sshd on
`fleet.hosts.HOST.unlock.port`, the one SSH port the border admits
([opentofu skill](../opentofu/SKILL.md#oracle)); no host firewall exists at that point. It admits
the deploy account's keys with a pty and nothing else, and root's shell there is the passphrase
prompt, so a login can type the passphrase and do nothing more. The initrd waits without a
timeout, and sshd ends when the root is mounted, so the port answers only while the host is
locked.

The initrd host key is its own key under `/persist/etc/secrets/initrd`, never the host's: the
boot partition is not encrypted, so its private half is readable there, and whoever reads it can
impersonate the prompt and capture the passphrase. `unlock.hostKey` pins its public half for the
`unlock` app, which refuses any other key. A reboot the operator did not start (a crash,
provider maintenance) leaves the host down until someone unlocks it; nothing on the host can.

```sh
nix run .#unlock -- edge            # type the passphrase; the session closes when it is taken
nix run .#wake -- edge              # start a stopped instance through the Oracle API
```

## Boot and network

Limine installs to the removable-media path and leaves the EFI variables alone
([disko.nix](../../../modules/hosts/edge/disko.nix)), so a recreated instance boots the same
volume without firmware state. The uplink is matched by MAC address and takes DHCP; the host
resolves over DNS-over-TLS on its own, as racknerd does.

## Install

A new instance starts from the provider's stock image. `enroll` makes its identity first and
`install` takes that directory as ROOT ([deploy skill](../deploy/SKILL.md#install)); the border
admits the installer's port 22 only for that apply. disko asks for the passphrase on the
terminal, and the host then waits in its initrd for `unlock`. A reinstall of a live host goes
the usual way, carrying the identity off the old disk.

```sh
nix run .#tofu -- oracle apply -var install=true
nix run .#install -- edge ubuntu@ADDRESS IDENTITY
nix run .#unlock -- edge
nix run .#tofu -- oracle apply
```
