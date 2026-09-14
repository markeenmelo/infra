---
name: storage
description: Disk layouts, persistence and installation — disko OS-disk design, impermanence state decisions, and the manual nixos-anywhere install. Use before any partitioning, formatting, mount, persistent-state or fresh-install change. Bastion NAS data is out of scope and protected.
---

# Storage, persistence and installation

**Disko destroys data irreversibly.** Designing a layout is never permission to run one. Default to evaluation-only unless the current task explicitly authorizes the operation.

Read the host's `modules/hosts/<host>/disko.nix`, `modules/storage/persistence.nix` and `modules/storage/limine.nix`. `persistence.nix` owns the `fleet.installation.osDevice` option and its whole-disk validation, and puts disko, the tmpfs root, the empty-pool guards and the `/nix`/`/persist` `neededForBoot` flags into `base`; a host file declares only its disk.

## Layout

Each host declares its own layout in `modules/hosts/<host>/disko.nix` — still a top-level module, with no generic storage builder or old/new toggle. The shape is tmpfs `/`, a FAT boot partition, then Btrfs subvolumes for `/nix` and `/persist`; ThinkPad adds `/home` and plain swap. UEFI hosts use an `EF00` ESP; the BIOS host needs a 1 MiB `EF02` partition **first** on the disk. Limine is the bootloader, embedded on that same reviewed whole disk.

Identify the OS disk by a whole-disk `/dev/disk/by-id/` link and set it in `fleet.installation.osDevice`. Racknerd is the one researched exception: its VirtIO disk exposes no serial, so it uses a `by-path` PCI link confirmed by size. Partition suffixes are rejected everywhere. Verify against the real target with:

```sh
lsblk -o NAME,PATH,SIZE,TYPE,FSTYPE,MOUNTPOINTS,MODEL,SERIAL,UUID
```

Never invent a device path. **Bastion's `tank` members are not OS storage**: no extra disk declarations, pools, RAID, LUKS or shares enter disko.

## Persistence

Root is a tmpfs; only declared paths survive. Add state next to the feature that owns it via `environment.persistence."/persist".directories` or `.files`, setting owner, group and mode where the defaults are wrong.

- Every persistent *and* ephemeral filesystem needs `neededForBoot`. `/nix` must be a real mounted subvolume, never an impermanence binding.
- A durable `/home` is its own subvolume with `neededForBoot` in the host layout (ThinkPad), never an impermanence bind as well.
- Persist what has a reason: machine identity (`/etc/machine-id`, user/group allocation state), SSH host keys, service data with its ownership, and the SOPS age identity at `/persist/var/lib/sops-nix/`. Never persist `/run/secrets*`, `/etc` or `/var` wholesale.
- Audit with `nix eval --json .#fleet.HOST.persistence | jq .`. The report lists declarations only — direct `/persist` contents also survive, and removing a declaration deletes nothing.
- Plan migration *before* the reboot that needs it: back up, seed the backing paths with correct ownership, then boot.

## Installation

1. Finish the review above, confirm independent backups and console recovery, and verify the live installer's identity from the provider console.
2. Build the disko script **without executing it** and read every destroy, format and mount command in it. Any input or config change invalidates that review.

   ```sh
   nix build --no-update-lock-file -o result-disko-HOST \
     .#nixosConfigurations.HOST.config.system.build.diskoScript
   sha256sum result-disko-HOST
   ```
3. With explicit authorization, run `nixos-anywhere` by hand. The guarded installer that used to enforce all of this is gone; every item is now yours to verify before and during the run:
   - the target is an idle live installer (`VARIANT_ID=installer`, overlay/tmpfs root) with exactly one unmounted disk matching `fleet.installation.osDevice`, held by no pool, swap, dm or kernel consumer;
   - the scanned SSH host key matches the fingerprint read from the provider console, pinned via a private `UserKnownHostsFile` with `StrictHostKeyChecking=yes`, publickey-only, no agent or forwarding;
   - staging files (`/persist/etc/machine-id`, the ed25519 host key pair, optionally the age identity) live outside the checkout and the store, owner-only;
   - the built disko script's SHA-256 still equals the one you reviewed.

   Then invoke it with `--phases disko,install --build-on local` and nothing else: **destructive install, no kexec, no reboot, no host-key copying**.
4. Afterwards inspect mounts, identities and boot setup. First boot and reboot acceptance are separate authorizations.

Never run disko, a generated script, `mkfs`, `wipefs` or a partition tool directly. Rollback cannot recover repartitioned data.
