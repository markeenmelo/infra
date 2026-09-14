---
name: storage
description: Disk layouts, persistence and installation — disko OS-disk design, impermanence state decisions, and the operator-reviewed nixos-anywhere task. Use before any partitioning, formatting, mount, persistent-state or fresh-install change. Bastion NAS data is out of scope and protected.
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

## Private installer setup

The explicit `fleet:install` task in `devenv.nix` references `scripts/devenv/install.sh`. It accepts one fleet hostname, not a group. Use the locked x86_64-linux shell (`nix run --no-update-lock-file .#devenv -- shell`); never invoke an unmodified nixos-anywhere instead of the hardened package provided there.

For each host, configure a private OpenSSH alias `HOST-installer` with the console-verified live installer's `HostName` and port. The task uses root on the live installer, never root login to an installed fleet system. Keep this configuration and all credentials outside Git. No installer endpoint is inferred from the production deploy endpoint.

Prepare this runtime directory outside both the checkout and `/nix/store`:

```text
${XDG_DATA_HOME:-$HOME/.local/share}/infra/install/HOST/
├── identity                         (client key authorized on the live installer)
├── known_hosts                      (key verified against the provider console)
├── disko.sha256                     (only the reviewed script's 64-character digest)
└── extra-files/
    └── persist/
        ├── etc/
        │   ├── machine-id
        │   └── ssh/
        │       ├── ssh_host_ed25519_key
        │       └── ssh_host_ed25519_key.pub
        └── var/lib/sops-nix/key.txt  (required only for hosts selecting secrets)
```

Use an operator-owned `0700` directory and owner-only regular files/directories throughout (normally `0600` files, `0700` directories), with no symlinks. The resolved setup path may contain only letters, digits and `/._+-`, because upstream flattens SSH options into `NIX_SSHOPTS`. The client identity must be usable noninteractively; there is no agent or password fallback. Staging is not a backup: preserve independent recovery copies and correct remote ownership/modes. Nixos-anywhere copies these files as root while preserving modes. ThinkPad selects secrets and needs its reviewed age identity; neither server does. The wrapper never generates identities or decrypts anything, and file presence does not prove a key matches or decrypts.

The pinned nixos-anywhere 1.13.0 hardcodes disabled host-key checking before user flags; OpenSSH takes the first value. `devenv.nix` locally removes those defaults and changes ssh-copy-id's conflicting identity override, without changing pins. The task then enforces a private known-hosts file, strict/publickey-only/batch SSH, no agent or forwarding, and no host-key updates. Review these substitutions again whenever the upstream package changes.

## Installation

1. Finish the review above, confirm independent backups and console recovery, and verify the live installer's identity from the provider console.
2. Build the disko script **without executing it** and read every destroy, format and mount command in it. Any input or config change invalidates that review.

   ```sh
   nix build --no-update-lock-file -o result-disko-HOST \
     .#nixosConfigurations.HOST.config.system.build.diskoScript
   sha256sum result-disko-HOST
   ```
3. After reading the generated script, record only its digest in the private `disko.sha256` file. Confirm the tree is clean, committed and the revision is the one reviewed. With explicit installation authorization, invoke the task. Its local input, staging and digest checks do **not** replace the live-machine review; every item below remains yours to verify before and during the run:
   - the target is an idle live installer (`VARIANT_ID=installer`, overlay/tmpfs root) with exactly one unmounted disk matching `fleet.installation.osDevice`, held by no pool, swap, dm or kernel consumer;
   - the scanned SSH host key matches the fingerprint read from the provider console, pinned via a private `UserKnownHostsFile` with `StrictHostKeyChecking=yes`, publickey-only, no agent or forwarding;
   - staging files (`/persist/etc/machine-id`, the ed25519 host key pair, optionally the age identity) live outside the checkout and the store, owner-only;
   - the built disko script's SHA-256 still equals the one you reviewed.

   ```sh
   devenv tasks run fleet:install --input host=HOST
   ```

   The task validates the hostname against `fleet`, refuses a dirty tree or missing/unsafe staging, and builds the disko script and system from the same immutable local Git revision. It compares the script to the private review digest and passes those exact store outputs to the hardened installer with `--store-paths`, `--extra-files` and `--phases disko,install --build-on local`: **destructive install, no kexec, no reboot, no host-key copying**. It does not inspect live disk consumers, backups or installer state for you. Never use a successful evaluation/build as authorization.
4. Afterwards inspect mounts, identities and boot setup. First boot and reboot acceptance are separate authorizations.

Never run disko, a generated script, `mkfs`, `wipefs` or a partition tool directly. Rollback cannot recover repartitioned data.
