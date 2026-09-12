# ADR 0005 — Adopt existing installations without provisioning

- Status: accepted; amends [ADR 0003](0003-storage-and-impermanence.md) and [ADR 0004](0004-deployment-and-readiness.md); password delivery superseded by [ADR 0006](0006-sops-password-delivery.md), desktop scope extended by [ADR 0007](0007-thinkpad-desktop.md), VPN deferral amended by [ADR 0009](0009-tailscale-and-opentofu.md)
- Date: 2026-09-09

**2026-09-12 amendment:** the operator explicitly selected direct fresh per-host layouts now, rather than retaining old/new abstractions. [ADR 0003](0003-storage-and-impermanence.md) supersedes the storage implementation on this branch: `existing.nix`/`os-disk.nix` and old mount files are deleted. All fresh candidates initially remained unready; the subsequent [Bastion-only authorized preflight](../hosts.md#bastion-live-installer-preflight--2026-09-12) resumes validation and records its new reviews separately from boot acceptance. The decisions below document the prior adoption baseline and running-installation history; they do not authorize wiping or prove a fresh installation.

## Context

All three hosts already run NixOS with disko/impermanence and Limine, and their disks do not match the fresh-disk scaffold: unprefixed Btrfs subvolume names, ThinkPad LUKS/LVM/swap with a separate `/home`, and a valuable separate ZFS mirror on bastion. Applying the original layout would not be a safe migration. The user explicitly requested no wipe, a headless baseline, password sudo, no VPN yet, and remote deploy capability everywhere except ThinkPad.

## Decision

- Compose a cohesive `existing-storage` deferred capability on all real hosts instead of `os-disk`: disko `nodev` mount descriptions for existing devices/filesystems with no destructive disk/LVM/MD/ZFS device collections. Existing LUKS unlocking, LVM activation and swap are ordinary NixOS options. All public disko script/image/install-test outputs stay disabled **even after readiness**, because empty legacy scripts can still unmount `/mnt`.
- Target tmpfs root with no deletion hook; existing durable mounts, subvolumes and keys are preserved. `/home` stays a separate early mount rather than an impermanence bind. Bastion's OS `/persist` stays on NVMe; its observed ZFS legacy `/srv` mounts stay outside disko with no force import, pool/dataset/property changes or upgrades — NAS import policy and restore remain review gates.
- Limine with its common pinned API, observed EFI/BIOS policy, no force/editor and bounded generations. Recovery consoles are retained; upstream `profiles/headless.nix` is inappropriate because it disables them. The old fresh-install capability remains separately available and tested but uncomposed.
- `marcos` with the existing explicitly selected public key and authenticated sudo with password fallback; SOPS delivers password hashes ([ADR 0006](0006-sops-password-delivery.md)). Target root SSH stays disabled; servers need a separately authorized staged transition from root-only SSH. Closure trust stays unresolved until explicitly provisioned rather than silently granting root-equivalent Nix trust. Servers opt into deploy-rs after commissioning; ThinkPad stays local-only.
- Headless scope: SSH/firewall/time sync, scoped persistence, server hardening/logging, racknerd SSH banning, conservative laptop power management and ThinkPad Thunderbolt authorization. Desktop and VPN were initially deferred; [ADR 0007](0007-thinkpad-desktop.md) adds ThinkPad's desktop and [ADR 0009](0009-tailscale-and-opentofu.md) enables only its reviewed, unactivated Tailscale candidate while server rollouts stay disabled. eGPU drivers, proxy and NAS applications remain deferred, not invented commissioning acknowledgements.

## Consequences

- Real facts stay inspectable under `fleetConfigurations` with `ready = false` until migration, credentials, network, hardware/boot and recovery review complete. `devenv shell disk-plan HOST` refuses existing installations; reinstallation needs its own separately researched and authorized design.
- Activation still changes boot files and can break access/state; canonical checks authorize nothing ([validation scope](../validation.md)).
- Dated observations and exact unresolved items live in [hosts.md](../hosts.md); API evidence in [research](../research.md).
