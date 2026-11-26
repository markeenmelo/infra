---
name: hosts
description: "Each host's hardware, disks, boot and recovery: bastion (UGREEN NAS, LUKS with TPM2, Limine Secure Boot, the hand-made ZFS pools and declared mounts, snapshots, subnet routes, UPS, firmware), edge (Oracle Cloud Ampere instance, LUKS without TPM unlocked over SSH in the initrd, the unlock, wake and install apps), thinkpad (LUKS with TPM2 and PIN, Secure Boot, remote builds, reinstall) and beast (gaming desktop, LUKS with TPM2, Secure Boot, the games drive outside disko). Use before touching modules/hosts/, modules/{unlock,wake,fwupd,secure-boot}.nix, any ZFS pool or dataset, Secure Boot or TPM enrollment, firmware, or rebooting, unlocking or reinstalling a host."
---

# Hosts

Read the file for the host you touch; each holds what its `modules/hosts/HOST/` files cannot say.
The host table and where each builds are in [README.md](../../../README.md#hosts).

| File | Host | Modules |
|---|---|---|
| [bastion.md](bastion.md) | Home server: NAS hardware, ZFS pools, TPM2 unlock, UPS | `modules/hosts/bastion/` |
| [edge.md](edge.md) | Oracle Cloud instance: initrd SSH unlock, wake, install | `modules/hosts/edge/`, `unlock.nix` |
| [thinkpad.md](thinkpad.md) | Operator laptop: disk, unlock, boot | `modules/hosts/thinkpad/` |
| [beast.md](beast.md) | Gaming desktop: disks, the games drive, unlock, install | `modules/hosts/beast/` |
| [inspiron.md](inspiron.md) | Ian's Minecraft laptop: plain storage, kiosk session, Kids network | `modules/hosts/inspiron/`, `kiosk.nix` |

Each host names its disk layout in `host.nix` ([storage.nix](../../../modules/storage.nix)):
`storage`, a btrfs root rolled back at every boot with state preserved under `/persist`, or
`plain-storage`, an ext4 root on the same LUKS partition that keeps everything and runs no
Preservation. A `plain-storage` host keeps its identity at the live paths only, which sops-nix
and unlock read ([secrets.nix](../../../modules/secrets.nix)); the install stages nothing under
`/persist` for it, and its reinstall takes the mounted ext4 root itself as ROOT, where the
`fleet.carry` paths resolve to the live files.

[fwupd.nix](../../../modules/fwupd.nix) runs fwupd on bastion, thinkpad and beast, not edge, whose firmware is
Oracle's. Bastion, thinkpad and beast boot Limine with their own Secure Boot keys (the `secure-boot` module, [secure-boot.nix](../../../modules/secure-boot.nix): signing on, sbctl, `/var/lib/sbctl` preserved and carried), so nixpkgs' Limine module signs fwupd's EFI
app with the sbctl keys (`fwupd-efi.service`) and has capsule updates boot it without shim, which
none of them has. A capsule update reflashes the firmware, after which the TPM may not unseal and LUKS asks for the passphrase; re-seal as in the host's file.

`wake.nix` powers on bastion and beast by Wake-on-LAN, from home only, and edge through the Oracle API; the
command is in [operating: deploy](../operating/deploy.md).

What runs on a host lives elsewhere: bastion's apps in the [services skill](../services/SKILL.md),
its MicroVMs in the [guests skill](../guests/SKILL.md), the laptop's desktop role in the
[desktop skill](../desktop/SKILL.md), deploys and installs in the
[operating: deploy](../operating/deploy.md).
