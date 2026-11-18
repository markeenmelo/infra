---
name: edge
description: "The edge host: the Oracle Cloud Ampere A1 instance, its LUKS state partition with no TPM, the initrd that takes the passphrase over SSH on its public address, the unlock, wake and install apps for it, what it holds that the provider could read, how it boots, reaches the network and builds itself. Use before touching modules/hosts/edge or modules/unlock.nix, rebooting or reinstalling the instance, changing the unlock port or the initrd host key, or debugging a boot that never reaches the tailnet."
---

# Edge

[modules/hosts/edge/](../../../modules/hosts/edge/) is the instance the
[Oracle project](../opentofu/SKILL.md#oracle) creates: one Ampere A1 core on a virtio disk, UEFI,
`aarch64-linux`. It runs the `server` role with `telemetry`, and the public surface as a
passthrough that forwards TLS unread to bastion and enforces bastion's bans
([proxy skill](../proxy/SKILL.md)). Like asahi it builds its own closure on
deploy, which is nearly all substitution from cache.nixos.org.

The provider runs the hypervisor and can read the instance's memory, so no disk encryption hides
a running host from it. The design answer is that nothing worth reading lives here: the host
holds its SSH host key, its tailnet node key, the initrd host key and the key that reads ban
decisions, and each only reaches what the tailnet policy grants the host. What it can see of the
traffic it carries is what any network on the path sees: addresses, the server name in the TLS
handshake, sizes and timing. The encrypted state partition protects those at rest, in
snapshots and volume backups. Its key derivation is capped in
[disko.nix](../../../modules/hosts/edge/disko.nix): cryptsetup sizes it to the memory present at
format time, and the installer runs with more than the host does, so an uncapped volume could
ask the initrd for more memory than the host has. Once booted the host refuses to load further
kernel modules ([host.nix](../../../modules/hosts/edge/host.nix)), so root there cannot add one.

## Unlock

[unlock.nix](../../../modules/unlock.nix) is for a host whose state partition no TPM opens. Its
initrd brings the uplink up with the host's own networkd units and runs sshd on
`fleet.hosts.HOST.unlock.port`, the one SSH port the border admits
([opentofu skill](../opentofu/SKILL.md#oracle)); no host firewall exists at that point. It admits
the deploy account's keys with a pty and nothing else, and root's shell there is the passphrase
prompt, so a login can type the passphrase and do nothing more. The initrd waits without a
timeout and keeps asking after a wrong passphrase, however many, since a host that gave up could
only be reset from the provider's console. The prompt answers once and exits, so the session
closes the same way after a right passphrase and a wrong one: run `unlock` again, and it prompts
again if the host is still locked or finds nothing listening if it is not, since sshd ends when
the root is mounted.

The initrd host key is its own key under `/persist/etc/secrets/initrd`, never the host's: the
boot partition is not encrypted, so its private half is readable there, and whoever reads it can
impersonate the prompt and capture the passphrase. `unlock.hostKey` pins its public half for the
`unlock` app, which refuses any other key. A reboot the operator did not start (a crash,
provider maintenance) leaves the host down until someone unlocks it; nothing on the host can.
Bastion's `Host silent` alert is the signal for that
([monitoring skill](../monitoring/SKILL.md)).

Oracle goes on calling an instance running after the host powered itself off, as `shutdown`
does, so `wake` starts a stopped instance and resets a running one, and refuses the reset while
the host still answers on its public address or over the tailnet.

```sh
nix run .#unlock -- edge            # type the passphrase; rerun it to see whether the host still waits
nix run .#wake -- edge              # power the instance on through the Oracle API
```

## Boot and network

Limine installs to the removable-media path and leaves the EFI variables alone
([disko.nix](../../../modules/hosts/edge/disko.nix)), so the boot depends on no firmware state
the provider would have to keep. The uplink is the instance's one physical Ethernet link, matched
by type and by having no kind, which virtual links such as veth and bridges have, and not by MAC
address: a recreated instance gets a new address, and the initrd needs the network before anyone
can unlock it. It takes DHCP, and the host resolves over DNS-over-TLS on its own. A recreated instance also starts from a fresh stock volume, so it is installed
again.

## Install

A new instance starts from the provider's stock image. `enroll` makes its identity first and
`install` takes that directory as ROOT ([deploy skill](../deploy/SKILL.md#install)); the border
admits the installer's port 22, and the instance has the installer's memory, only for that
apply. disko asks for the passphrase on the terminal, and the host then waits in its initrd for
`unlock`. The apply that ends the install shrinks the instance again, which reboots it, so it is
unlocked a second time. For a new host `install` makes the installer boot itself
through the older kexec syscall: the stock image's kernel refuses the newer one for an image
this size with `Address not available`, which fits its Kexec HandOver being on by default, and
the installer's own fallback does not cover that error. A reinstall of a live host goes
the usual way, carrying the identity off the old disk. Bastion is deployed with a new host's
`telemetry` fact only after that host's first boot: the silence alerts fire for a sender that
has never sent.

```sh
nix run .#tofu -- oracle apply -var install=edge
nix run .#install -- edge ubuntu@ADDRESS IDENTITY
nix run .#unlock -- edge
nix run .#tofu -- oracle apply      # reboots edge at its running size
nix run .#unlock -- edge
rm -rf IDENTITY                     # only once edge answers on the tailnet
```
