# ADR 0003 — Explicit OS storage, tmpfs root, no NAS topology

- Status: accepted
- Date: 2026-09-09
- Scope update: [ADR 0005](0005-existing-headless-baseline.md) adopts existing installations. This original fresh-disk design remains separately tested but is **not composed by any current host**.

## Context

No disk identifiers, firmware modes or data topology are known. Bastion holds valuable NAS data. Importing impermanence alone does not erase root. Current systemd initrd makes older scripted root-reset examples unsuitable.

## Decision

Offer one understandable OS baseline: confirmed whole-disk by-id, GPT, deliberate UEFI/BIOS and UEFI NVRAM-write/fallback choices, explicitly sized ESP when needed, one Btrfs filesystem with `/nix` and `/persist` subvolumes. BIOS additionally keeps `/boot` there. Use tmpfs `/` with a configurable 25% ceiling; disko mounts it during installation as well as deriving runtime filesystems. Mark persistent and ephemeral mounts `neededForBoot`.

Btrfs is used to share capacity without guessing partition sizes, not to introduce RAID/snapshot machinery. No ZFS/LVM/LUKS stack, root-reset service or NAS data disk is inferred. A different layout is a separately reviewed capability. Confirmation/type checks and the closed OS disk list make the destructive boundary explicit. The ESP has a 512 MiB policy floor (`512M`, with `M`/`G` in MiB/GiB), enforced during option evaluation so direct disko-script derivations cannot bypass it. There is no automatic size or capacity guarantee: actual kernel/initrd sizes and retained generations still require review; BIOS needs no ESP.

Persist machine ID, random seed, NixOS allocation state, timer stamps, SSH identities where enabled, and scoped service state. Workstations deliberately keep `/home` and NetworkManager state; servers retain bounded journal history. Add service state with its owning feature.

## Consequences

No destructive command is automated. No host can build/deploy without its commissioning requirements. Backups, state migration and first-boot checks remain mandatory. Tmpfs can fill or consume memory; build downloads/large working data belong on durable storage. `/persist` contents are unencrypted unless the operator replaces the baseline before installing. Impermanence is neither backup nor secure deletion, and undeclared old backing data is not purged.

NAS disks are not part of this layout. Shares and storage services are not pretended into existence; future services must require their real data mounts. Existing valuable data on the proposed OS disk makes this baseline inappropriate.

## Alternatives

Ext4 is a good simple filesystem but either needs an explicit capacity split for `/nix`/state or additional early bind-directory setup. Btrfs snapshot root rollback avoids tmpfs memory pressure but adds boot ordering and deletion logic. The small tmpfs/subvolume design is easier to audit initially.

See [bootstrap](../bootstrap.md), [research](../research.md), `modules/storage/`.
