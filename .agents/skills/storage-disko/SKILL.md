---
name: storage-disko
description: Safely create or change the fleet OS-disk disko configuration with verified device identities, explicit destructive boundaries and special protection for bastion NAS data.
---

# Storage / disko

## Purpose / when

Review any disk-layout, boot-filesystem, device-assignment or provisioning change. **Disko can irreversibly destroy data.** Configuration work is not authorization to execute it.

## Prerequisites

Read `../../../AGENTS.md`, `../../../docs/hosts.md`, `../../../docs/reinstall.md`, `../../../docs/adr/0003-storage-and-impermanence.md`, and the matching `../../../modules/hosts/<name>/disko.nix`. Current candidates use fresh per-host layouts and are all unready; their public provisioning/script/image outputs are blocked. The running installations are untouched. `../../../docs/adr/0005-existing-headless-baseline.md` records the superseded adoption design, not retained modules. Obtain actual target inventory and verified recovery. Use `nix-research` for locked disko/script/boot APIs and both tracks.

## Procedure

1. Establish whether the task is evaluation-only, a proposed migration, or explicitly authorized provisioning. Default to evaluation-only. Fresh declarations do not authorize activation over old disks, nor do old-installation reviews approve new layouts. Keep public `_scripts`-derived outputs and image/install aliases blocked while unready or missing requirements; even an empty script can unmount /mnt. NAS mounts remain outside disko. Do not run disko, installers, mkfs, wipefs, partition tools or generated scripts.
2. On the target, request/read authorized **read-only** inventory: `lsblk -o NAME,PATH,SIZE,TYPE,FSTYPE,MOUNTPOINTS,MODEL,SERIAL,UUID`, `findmnt`, `/dev/disk/by-id/` links. Verify model/serial, whole-disk identity, current use and backups independently. Never invent a device path or use a fixture sentinel.
3. Separate OS disk, persistent host state and valuable data disks. For **bastion**, inspect its NAS inventory/restore plan and preferably physically isolate data drives before any later provisioning. If valuable data shares the candidate OS disk, reject this whole-disk baseline and design a migration.
4. Declare native partitions and firmware settings directly in `modules/hosts/<host>/disko.nix`, still a top-level flake-parts module; no generic storage builder, old/new toggle or conventional host import roots. Use nullable `fleet.installation.osDevice` and fresh `storageReviewed` in the existing installation metadata. Each layout owns its guards and imports upstream disko/shared Limine policy. BIOS requires FAT boot plus first 1 MiB EF02; UEFI uses an ESP. Test the chosen sizes and review actual boot headroom. All candidates remain unready/unreviewed; Racknerd's formatting identifier stays null pending a researched exception. Whole-disk by-id excludes partition suffixes.
5. Do not add NAS disks: extra disk declarations and redirected OS devices must reject every public script/image output. Do not add speculative pools, RAID, LUKS, shares or filesystem sizes. A different OS stack requires a small separately reviewed capability and tests, not weakening this boundary.
6. Design persistence and provisioning together: tmpfs root is mounted by disko; `/nix` and `/persist` must be persistent and early-mounted. Check firmware/bootloader behavior and avoid duplicate GRUB devices (disko derives them from EF02).
7. Stage files, `devenv tasks run repo:fmt`, `devenv tasks run repo:check-full`; inspect the host's `fleet` report and filesystem/device expressions. Once all commissioning prerequisites are real, `devenv shell disk-plan HOST` builds the script **without executing it**. Read every destroy/format/mount command and device reference in `result-disko-HOST`.
8. Check the generated plan against current target-local device identity again. Building it on an admin machine does not establish where it may run. Preserve/copy its entire Nix closure if needed. Changes to inputs/configuration invalidate earlier review.
9. Stop and report the reviewed plan and remaining prerequisites. Only a separate explicit authorization permits the installer-local destructive command in the bootstrap runbook, followed by mount inspection, secure state migration, installation and first-boot acceptance.

## Completion criteria

Only identified OS storage can be affected; data disks are excluded; both-track non-destructive checks pass; the exact generated plan is reviewed; migration/recovery requirements and execution authorization status are reported.

## Common failures / safety

Changed by-id resolution, selecting a partition instead of a disk, hidden NAS data on the OS disk, old UUIDs, double filesystem/GRUB definitions, unmounted `/nix`, stale generated scripts, or mistaking “format existing layout” for safe idempotence. Stop on any ambiguity. Rollback cannot recover repartitioned data.
