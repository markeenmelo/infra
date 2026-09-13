---
name: storage
description: Disk layouts, persistence and installation — disko OS-disk design, impermanence state decisions, and the guarded nixos-anywhere install. Use before any partitioning, formatting, mount, persistent-state or fresh-install change. Bastion NAS data is out of scope and protected.
---

# Storage, persistence and installation

**Disko destroys data irreversibly.** Designing a layout is never permission to run one. Default to evaluation-only unless the current task explicitly authorizes the operation.

Read the host's `modules/hosts/<host>/disko.nix`, `modules/storage/persistence.nix` and `modules/storage/limine.nix`.

## Layout

Each host declares its own layout in `modules/hosts/<host>/disko.nix` — still a top-level module, with no generic storage builder or old/new toggle. The shape is tmpfs `/`, a FAT boot partition, then Btrfs subvolumes for `/nix` and `/persist`; ThinkPad adds `/home` and plain swap. UEFI hosts use an `EF00` ESP; the BIOS host needs a 1 MiB `EF02` partition **first** on the disk. Limine is the bootloader, embedded on that same reviewed whole disk.

Identify the OS disk by a whole-disk `/dev/disk/by-id/` link and set it in `fleet.installation.osDevice`. Racknerd is the one researched exception: its VirtIO disk exposes no serial, so it uses a `by-path` PCI link confirmed by size. Partition suffixes are rejected everywhere. Verify against the real target with:

```sh
lsblk -o NAME,PATH,SIZE,TYPE,FSTYPE,MOUNTPOINTS,MODEL,SERIAL,UUID
```

Never invent a device path or reuse a fixture sentinel. **Bastion's `tank` members are not OS storage**: no extra disk declarations, pools, RAID, LUKS or shares enter disko, and every public disk-script alias must refuse a redirected or extra device.

## Persistence

Root is a tmpfs; only declared paths survive. Add state next to the feature that owns it via `environment.persistence."/persist".directories` or `.files`, setting owner, group and mode where the defaults are wrong.

- Every persistent *and* ephemeral filesystem needs `neededForBoot`. `/nix` must be a real mounted subvolume, never an impermanence binding.
- Workstations use `fleet.workstation.homePersistence` — `"filesystem"` for a separately mounted home, `"bind"` for an impermanence bind. Never both.
- Persist what has a reason: machine identity (`/etc/machine-id`, user/group allocation state), SSH host keys, service data with its ownership, and the SOPS age identity at `/persist/var/lib/sops-nix/`. Never persist `/run/secrets*`, `/etc` or `/var` wholesale.
- Audit with `nix eval --json .#fleet.HOST.persistence | jq .`. The report lists declarations only — direct `/persist` contents also survive, and removing a declaration deletes nothing.
- Plan migration *before* the reboot that needs it: back up, seed the backing paths with correct ownership, then boot.

## Installation

1. Finish the review above, confirm independent backups and console recovery, and verify the live installer's identity from the provider console.
2. `devenv shell disk-plan HOST` builds the disko script **without executing it** and prints its SHA-256. Read every destroy, format and mount command in `result-disko-HOST`; any input or config change invalidates that review.
3. With explicit authorization, `devenv tasks run host:install`. Its exact inputs, staging layout and `FLEET_INSTALL_*` runtime paths are enforced in `scripts/devenv/host-install.sh` — read that file rather than a summary. It runs full local preflight, pins the scanned host key against the console fingerprint, re-checks the target is an idle live installer with one unmounted matching disk, and then runs nixos-anywhere with `--phases disko,install --build-on local`: **destructive install, no kexec, no reboot, no host-key copying**.
4. Afterwards inspect mounts, identities and boot setup. First boot and reboot acceptance are separate authorizations.

Never run disko, a generated script, `mkfs`, `wipefs` or a partition tool directly. Rollback cannot recover repartitioned data.
