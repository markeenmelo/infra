# ADR 0005 — Adopt existing installations without provisioning

- Status: accepted
- Date: 2026-09-09
- Amends ADR 0003 for the current fleet and ADR 0004's desktop deployment policy

## Context

Read-only discovery established that all four hosts already run NixOS with disko/impermanence and Limine. Their disks do not match the scaffold: named Btrfs subvolumes lack `@` prefixes; thinkpad has LUKS/LVM/swap; laptops have separate `/home`; bastion has a valuable, separate ZFS mirror. Applying the original fresh-disk layout would not be a safe migration. The user explicitly requests no wipe, headless scope, password sudo, no VPN yet, and remote deploy capability everywhere except thinkpad.

## Decision

Compose a cohesive `existing-storage` deferred capability instead of `os-disk` on all real hosts. Use the locked disko `nodev` API's explicit device/filesystem/mount options to derive existing runtime filesystems, with no destructive disk/LVM/MD/ZFS device collections. Configure existing LUKS unlocking/LVM activation/swap through ordinary NixOS options. Disable all public disko script/image/install-test outputs even after commissioning, because empty legacy scripts can still unmount `/mnt`. This is not a full provisioning layout.

Target tmpfs root without any deletion hook, preserving existing durable mounts, subvolumes and keys. Keep `/home` as a separate early mount when it already exists rather than duplicating it with impermanence. Keep bastion OS `/persist` on NVMe and its observed ZFS legacy `/srv` mounts outside disko, with no force import, new pool/datasets, properties, upgrades or shares. NAS import policy/restore remains a review gate.

Use Limine's common pinned API with observed EFI/BIOS policy, no force/editor and bounded generations. Retain recovery consoles; upstream `profiles/headless.nix` is inappropriate because it disables them. The old fresh-install capability remains separately available and tested but is not composed by the real fleet.

Configure `marcos` with the existing explicitly selected public key, runtime password-file contracts and password sudo. Preserve dino's existing `ian` UID/home without wheel. Servers need a separately authorized transition from their root-only SSH configuration; target root SSH stays disabled. Keep closure trust unresolved until explicitly provisioned, rather than silently granting root-equivalent Nix trust. Dino now opts into deploy-rs after commissioning; thinkpad remains excluded.

Headless scope includes SSH/firewall/time sync, scoped persistence, server hardening/logging and racknerd SSH banning, plus conservative laptop power management and thinkpad Thunderbolt authorization. No VPN, desktop, launchers, disconnected-eGPU driver, proxy or NAS application is enabled. Laptop graphics/gaming is a later feature, not an invented commissioning acknowledgement.

## Consequences

All real facts remain inspectable under `fleetConfigurations`, with `ready = false` until migration, credentials, network without VPN, hardware/boot and recovery review are complete. `just disk-plan` is not available for existing installations; a future reinstallation needs a separately researched and authorized design. Activation still changes boot files and can break access/state even without disko; it is not authorized by checks.

Both-track fixtures test Limine EFI/BIOS, existing UUID-backed mounts, separate `/home`, all provisioning-output rejection with and without readiness, migration gating and headless security. Existing fresh-install/ESP/deployment-access tests remain. No fixture flags/devices/keys become real commissioning data. Standard checks do not test boots, passwords, restored backups, pool imports or gaming.

Dated observations and exact unresolved items live in [host inventory](../hosts.md); API evidence is in [research](../research.md). Procedures distinguish existing-installation adoption from the older fresh-install runbook.
