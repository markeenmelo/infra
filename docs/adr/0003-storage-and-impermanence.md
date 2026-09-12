# ADR 0003 — Explicit OS storage: tmpfs root, no NAS topology

- Status: accepted; fresh-install design retained and tested, but **composed by no current host** — [ADR 0005](0005-existing-headless-baseline.md) adopts existing installations instead
- Date: 2026-09-09

## Context

The original scaffold targeted fresh disks whose identifiers, firmware modes and data topology were unknown. Bastion holds valuable NAS data. Importing impermanence alone does not erase root, and current systemd initrd makes older scripted root-reset examples unsuitable.

## Decision

- One understandable `os-disk` capability: confirmed whole-disk by-id, GPT, deliberate UEFI/BIOS choice and NVRAM-write/fallback decision, explicitly sized ESP when needed, one Btrfs filesystem with `/nix` and `/persist` subvolumes (BIOS also keeps `/boot` there), and tmpfs `/` with a configurable 25% ceiling that disko also mounts during installation. Persistent and ephemeral mounts are `neededForBoot`.
- The ESP has a 512 MiB policy floor enforced during option evaluation, so direct disko-script derivations cannot bypass it. BIOS needs no ESP. The floor is not a capacity guarantee: actual kernel/initrd sizes and retained generations still require review.
- Btrfs shares capacity without guessing partition sizes; it introduces no RAID/snapshot machinery. No ZFS/LVM/LUKS stack, root-reset service or NAS data disk is inferred. Unused `lvm_vg`, `mdadm`, `zpool` and `bcachefs_filesystems` collections are forced empty so foreign contributions cannot generate destructive operations; both-track tests require an unchanged OS-only script derivation.
- Persist machine ID, random seed, NixOS allocation state, timer stamps, SSH identities where enabled, and feature-owned service state. Workstations deliberately keep `/home` and NetworkManager state; servers keep bounded journals. Add service state with its owning feature.
- A different layout is a separately reviewed capability. Shares and storage services are not pretended into existence; future services must require their real data mounts.

## Consequences

- No destructive command is automated; no host builds or deploys without its commissioning requirements. Backups, state migration and first-boot checks remain mandatory.
- Tmpfs can fill or consume memory; build downloads and large working data belong on durable storage. `/persist` contents are unencrypted under this baseline. Impermanence is neither backup nor secure deletion, and undeclared old backing data is not purged.
- Existing valuable data on the proposed OS disk makes this baseline inappropriate.

## Alternatives

Ext4 is simpler but needs an explicit capacity split for `/nix`/state or extra early bind setup. Btrfs snapshot root rollback avoids tmpfs memory pressure but adds boot ordering and deletion logic.

See [bootstrap](../bootstrap.md), [research](../research.md), `modules/storage/`.
