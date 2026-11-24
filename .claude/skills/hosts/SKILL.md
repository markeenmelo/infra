---
name: hosts
description: "Each host's hardware, disks, boot and recovery: bastion (UGREEN NAS, LUKS with TPM2, Limine Secure Boot, the hand-made ZFS pools and declared mounts, snapshots, subnet routes, UPS, firmware), edge (Oracle Cloud Ampere instance, LUKS without TPM unlocked over SSH in the initrd, the unlock, wake and install apps) and thinkpad (LUKS with TPM2 and PIN, Secure Boot, remote builds, home backups, reinstall). Use before touching modules/hosts/, modules/unlock.nix or modules/wake.nix, any ZFS pool or dataset, Secure Boot or TPM enrollment, firmware, or rebooting, unlocking or reinstalling a host."
---

# Hosts

Read the file for the host you touch; each holds what its `modules/hosts/HOST/` files cannot say.
The host table and where each builds are in [README.md](../../../README.md#hosts).

| File | Host | Modules |
|---|---|---|
| [bastion.md](bastion.md) | Home server: NAS hardware, ZFS pools, TPM2 unlock, UPS | `modules/hosts/bastion/` |
| [edge.md](edge.md) | Oracle Cloud instance: initrd SSH unlock, wake, install | `modules/hosts/edge/`, `unlock.nix`, `wake.nix` |
| [thinkpad.md](thinkpad.md) | Operator laptop: disk, unlock, boot, home backups | `modules/hosts/thinkpad/` |

What runs on a host lives elsewhere: bastion's apps in the [services skill](../services/SKILL.md),
its MicroVMs in the [guests skill](../guests/SKILL.md), the laptop's desktop role in the
[desktop skill](../desktop/SKILL.md), deploys and installs in the
[deploy skill](../deploy/SKILL.md).
