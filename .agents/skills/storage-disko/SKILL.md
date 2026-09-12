---
name: storage-disko
description: Safely create or change the fleet OS-disk disko configuration with verified device identities, explicit destructive boundaries and special protection for bastion NAS data.
---

# Storage / disko

## Purpose / when

Review any disk-layout, boot-filesystem, device-assignment or provisioning change. **Disko can irreversibly destroy data.** Configuration work is not authorization to execute it.

## Prerequisites

Read `../../../AGENTS.md`, `../../../docs/hosts.md`, `../../../docs/adr/0005-existing-headless-baseline.md`, and `../../../modules/storage/existing.nix` first. All current hosts use existing-storage mount descriptions: **no provisioning/script/image outputs, even after commissioning**. For a separately requested fresh installation also read `../../../docs/bootstrap.md#storage-and-installation`, `../../../docs/adr/0003-storage-and-impermanence.md`, and `../../../modules/storage/os-disk.nix`. Obtain actual target inventory and a verified backup/restore plan. Use `nix-research` to verify the locked disko module, generated script API, bootloader interaction and both Nixpkgs tracks before dependency-sensitive edits.

## Procedure

1. Establish whether the task is evaluation-only, a proposed migration, or explicitly authorized provisioning. Default to evaluation-only. Existing installations retain UUID-backed disko nodev mounts, existing LUKS/LVM unlocking and swap, and separate laptop /home; never replace them with the fresh-disk scaffold just to obtain scripts. Existing-storage closes destructive device collections and rejects every pinned `_scripts`-derived public output and installer/image aliases; recheck this localized upstream API on updates. NAS mounts remain outside disko. The remaining provisioning steps apply only to a separately reviewed fresh-install capability. Do not run disko, an install command, mkfs, wipefs, partition tools or generated scripts.
2. On the target, request/read authorized **read-only** inventory: `lsblk -o NAME,PATH,SIZE,TYPE,FSTYPE,MOUNTPOINTS,MODEL,SERIAL,UUID`, `findmnt`, `/dev/disk/by-id/` links. Verify model/serial, whole-disk identity, current use and backups independently. Never invent a device path or use a fixture sentinel.
3. Separate OS disk, persistent host state and valuable data disks. For **bastion**, inspect its NAS inventory/restore plan and preferably physically isolate data drives before any later provisioning. If valuable data shares the candidate OS disk, reject this whole-disk baseline and design a migration.
4. Supply verified facts through a top-level storage module contributing to `fleet.hosts.<name>.module`. The baseline takes `fleet.osDisk.device`, `bootMode`, UEFI `espSize`/`efiCanTouchVariables` and explicit `confirmed`. ESP sizes use positive whole `M`/`G` values (MiB/GiB) with a 512 MiB floor (`512M`); review actual kernel/initrd sizes, retained generations and headroom rather than treating the floor as sufficient capacity. An undersized value fails option evaluation, while null remains a UEFI commissioning blocker. BIOS needs no ESP. Do not set confirmed before a real layout/device review. Partition suffixes are rejected; by-id naming is required until a researched alternative capability exists.
5. Do not add NAS disks to the closed `disko.devices.disk` list. Do not add speculative pools, RAID, LUKS, shares or filesystem sizes. A different OS stack requires a small separately reviewed capability and tests, not weakening this boundary.
6. Design persistence and provisioning together: tmpfs root is mounted by disko; `/nix` and `/persist` must be persistent and early-mounted. Check firmware/bootloader behavior and avoid duplicate GRUB devices (disko derives them from EF02).
7. Stage files, `devenv tasks run repo:fmt`, `devenv tasks run repo:check`; inspect the host's `fleet` report and filesystem/device expressions. Once all commissioning prerequisites are real, `devenv shell disk-plan HOST` builds the script **without executing it**. Read every destroy/format/mount command and device reference in `result-disko-HOST`.
8. Check the generated plan against current target-local device identity again. Building it on an admin machine does not establish where it may run. Preserve/copy its entire Nix closure if needed. Changes to inputs/configuration invalidate earlier review.
9. Stop and report the reviewed plan and remaining prerequisites. Only a separate explicit authorization permits the installer-local destructive command in the bootstrap runbook, followed by mount inspection, secure state migration, installation and first-boot acceptance.

## Completion criteria

Only identified OS storage can be affected; data disks are excluded; both-track non-destructive checks pass; the exact generated plan is reviewed; migration/recovery requirements and execution authorization status are reported.

## Common failures / safety

Changed by-id resolution, selecting a partition instead of a disk, hidden NAS data on the OS disk, old UUIDs, double filesystem/GRUB definitions, unmounted `/nix`, stale generated scripts, or mistaking “format existing layout” for safe idempotence. Stop on any ambiguity. Rollback cannot recover repartitioned data.
