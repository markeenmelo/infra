---
name: bastion
description: "The bastion host: UGREEN DXP4800 Plus hardware, LUKS state partition with TPM2 unlock and Limine Secure Boot, the hand-made ZFS pools and their declared mounts, snapshots, the kernel ZFS allows, LAN subnet routes, power and UPS, firmware settings. Use before touching modules/hosts/bastion, any ZFS pool or dataset, Secure Boot or TPM enrollment, or bastion's firmware."
---

# Bastion

[modules/hosts/bastion/](../../../modules/hosts/bastion/) is a UGREEN DXP4800 Plus (Pentium
Gold 8505, 64 GiB): the OS NVMe holds the boot and LUKS state partitions, and three ZFS pools
made by hand hold the data. Any partition, format, pool, dataset, unlock, enrollment or firmware
change needs [approval](../../../CLAUDE.md#autonomy); **never** touch `tank`, `apps` or
`scratch` beyond the mounts in [data.nix](../../../modules/hosts/bastion/data.nix).

## Pools

`tank` (Immich, Nextcloud, media), `apps` (`/srv`, PostgreSQL, nixflix state, the ThinkPad
backup) and `scratch` (Frigate, rebuildable) are encrypted with key files under `/persist/zfs`,
which the install carries and backups exclude; the password-manager copy beside the LUKS
passphrase is the only other one. Topology, quotas and key locations are not declared: the
operator pastes `zpool status` and `zfs get quota,keylocation`. The import units are not
restarted on a switch, which would unmount every dataset of the pool; mounts are `nofail`, so a
pool that fails to import leaves the host and SSH up. Sanoid snapshots only the datasets it
names, nonrecursively, and `tank` daily only so its disks can sleep.

ZFS lags the newest kernel, so [kernel.nix](../../../modules/kernel.nix) boots the newest
kernel series the ZFS module still supports; a nixpkgs bump moves it when ZFS catches up.

## Boot

The state partition is LUKS ([storage.nix](../../../modules/storage.nix), `fleet.encryptState`),
opened by a TPM2 token sealed to PCR 7 with the passphrase as fallback, and Limine is signed
with the sbctl keys in `/var/lib/sbctl`, enrolled with Microsoft's CA kept (`-m`) because
add-in option ROMs need it; PCR 7 then also matches under a Microsoft-signed loader that does
not measure what it boots, so a stolen box can unseal the key and, with it, the pool keys under
`/persist/zfs`; accepted over a TPM PIN. The NixOS installer is unsigned, so a reinstall turns Secure Boot off in the
firmware, installs with the carried keys, turns it back on, then re-seals a new LUKS header:

```sh
sudo systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=7 /dev/disk/by-partlabel/disk-os-state
```

## Network and power

It holds `192.168.2.2` on the homelab LAN and advertises the three LANs to the tailnet; it may
not open connections into the IoT and kids LANs, and forwards into them only from the tailnet.
The IT8613 watchdog (out-of-tree `it87`) is armed by systemd, so the firmware watchdog stays off;
the UPS hooks drop to the power-saver profile on battery and cut UPS output after the pools
unmount.

## Firmware

After a CMOS reset load the defaults (F9), then: C states on, package limit C10, C6DRAM off;
Power Loss and State After G3 on; Wake on LAN on, Deep S5 off; TPM (Intel PTT) on; firmware
watchdog off; serial, Wi-Fi, Bluetooth, eMMC, HD audio, ISH, THC and the AQC113 10G port off;
ASPM L1 with L1.1/L1.2 on every enabled root port, ClockReq on the CPU ports; Secure Boot mode
Custom, Reset To Setup Mode before enrolling keys. The bays sit on an ASM1164 that reports every
port external, hence the `ahci` parameters in
[hardware.nix](../../../modules/hosts/bastion/hardware.nix). Check idle package C8 and C10
counters grow in `/sys/kernel/debug/pmc_core/package_cstate_show`.
