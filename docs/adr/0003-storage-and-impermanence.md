# ADR 0003 — Explicit OS storage: tmpfs root, no NAS topology

- Status: accepted; amended 2026-09-12 for per-host fresh candidates, superseding [ADR 0005](0005-existing-headless-baseline.md) for this branch only. All candidates began unready; subsequent host review, installation and boot acceptance are recorded in [current status](../hosts.md#current-status).
- Date: 2026-09-09

## Context

The original scaffold targeted fresh disks whose identifiers, firmware modes and data topology were unknown. Bastion holds valuable NAS data. Importing impermanence alone does not erase root, and current systemd initrd makes older scripted root-reset examples unsuitable.

## Decision

- Each host composes its single `modules/hosts/<host>/disko.nix`, a top-level flake-parts module exporting that host's plain NixOS layout. Delete `os-disk.nix`, `existing.nix` and old per-host UUID mount files; no replacement generic storage module, compatibility interface or old/new toggle. Each file directly imports upstream disko and the shared Limine boot policy, and owns its small provisioning-output guard.
- Nullable `fleet.installation.osDevice` and fresh `storageReviewed` belong to the existing installation metadata, not a layout-building API. All fresh candidates begin unready, including previously commissioned ThinkPad; new approvals require actual fresh review. Old-installation boot/migration approvals remain historical evidence, not fresh review. Racknerd's separately approved no-serial exception uses the real canonical PCI by-path attachment identity; Bastion/ThinkPad still require by-id. The base type rejects partition suffixes and each layout gates its own identifier policy. A PCI path is topology, not a unique disk serial: reverify VM, attachment, capacity and current use before every install. Null still blocks scripts.
- GPT with explicitly sized FAT `/boot`, plain Btrfs `nix` and `persist` subvolumes, and tmpfs `/` with the existing configurable 25% ceiling. ThinkPad additionally declares `home` and an 8 GiB plain swap partition, with no hibernation or LVM. Persistent and ephemeral mounts are `neededForBoot`.
- Both firmware modes use Limine and FAT `/boot`: UEFI uses an ESP; BIOS adds a first 1 MiB EF02 embedding partition. Boot sizes are explicit native disko values: 2 GiB on servers, 4 GiB on ThinkPad, covered by independent layout fixture assertions. There is no generic size option/minimum parser. Actual kernel/initrd sizes and retained generations still require review before approval.
- Btrfs shares remaining capacity without a `/nix` versus state split; it introduces no RAID/snapshot machinery. No ZFS/LVM/LUKS stack, root-reset service or NAS data disk is inferred. Unused `lvm_vg`, `mdadm`, `zpool` and `bcachefs_filesystems` collections are forced empty. Additional disks and redirected OS devices reject public scripts/images; pending identity/confirmation/firmware facts reject even empty scripts that could unmount `/mnt`. Both-track tests cover the actual three proposed layouts, not a second test-only layout.
- Persist machine ID, random seed, NixOS allocation state, timer stamps, SSH identities where enabled, and feature-owned service state. Workstations deliberately keep `/home` and NetworkManager state; servers keep bounded journals, not admin homes. The 2026-09-13 candidate removes Bastion's temporary `/home/marcos` bind because administration moves to the operator's MacBook. Apply that change with an operator-controlled boot-only deployment/reboot, not a forced live unmount; retain old `/persist/home/marcos` data until separately reviewed cleanup. No disk layout, identity/service persistence or NAS mount change is involved. Add service state with its owning feature.
- A different layout is a separately reviewed capability. Shares and storage services are not pretended into existence; future services must require their real data mounts.

## Consequences

- No destructive command is automated; no host builds or deploys without its commissioning requirements. Backups, state migration and first-boot checks remain mandatory.
- Tmpfs can fill or consume memory; build downloads and large working data belong on durable storage. `/persist` contents are unencrypted under this baseline. Impermanence is neither backup nor secure deletion, and undeclared old backing data is not purged.
- Existing valuable data on the proposed OS disk makes this baseline inappropriate.

## Alternatives

Ext4 is simpler but needs an explicit capacity split for `/nix`/state or extra early bind setup. Btrfs snapshot root rollback avoids tmpfs memory pressure but adds boot ordering and deletion logic.

See [bootstrap](../bootstrap.md), [research](../research.md), `modules/hosts/` and shared `modules/storage/`.
