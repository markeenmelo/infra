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
${XDG_DATA_HOME:-$HOME/.local/share}/infra/install/HOST/  (0700)
├── identity                         (0600; client key authorized on the live installer)
├── identity.pub                     (0600; preparation derives this from identity)
├── known_hosts                      (0600; key verified against the provider console)
├── disko.sha256                     (0600; only the reviewed script's 64-character digest)
└── extra-files/                     (0755)
    └── persist/                    (0755)
        ├── etc/                    (0755)
        │   ├── machine-id          (0444)
        │   └── ssh/                (0755)
        │       ├── ssh_host_ed25519_key      (0600)
        │       └── ssh_host_ed25519_key.pub  (0600)
        └── var/                    (0755; only needed for hosts selecting secrets)
            └── lib/                (0755)
                └── sops-nix/       (0700)
                    └── key.txt     (0600)
```

### Local preparation mode

On reinstalls, restore the intended machine-id and host keys from independent backups into this tree **before** using preparation. Missing files are treated as a request for new identities, not proof that the old machine had none. Preparation never rotates an existing identity or recovers one from the target.

```sh
devenv tasks run fleet:install --input host=racknerd --input prepare=true
```

`prepare=true` is a JSON boolean, not a string. This branch validates the host against the working-tree flake, creates missing directories with the modes above, and generates only missing client/installed-host ED25519 keys (without passphrases) and a random machine-id. It derives missing `.pub` files from existing private keys and checks existing key pairs without printing private material. It refuses invalid existing identities, orphaned public keys, unsafe permissions, symlinks and hard-linked files rather than overwriting identities or recursively changing modes. All creation is runtime-only, outside the checkout and store. It can run with a dirty tree; destructive installation still requires a clean committed revision.

The mode creates **empty** `0600` placeholders for missing `known_hosts` and `disko.sha256`. It reports these as **BLOCKED** with troubleshooting steps and returns nonzero; generated files are kept for the next run. It creates the age directory only for a host selecting secrets, but never generates an age identity: import the reviewed identity manually with the modes above.

After preparation it validates required files, including pre-existing ones: ownership/type/modes, SSH key pairs (including the installed host key's ED25519 type), machine-id, one ED25519 `known_hosts` entry, the digest's 64-character lowercase hexadecimal format, and any required native age identity's syntax. Age validation uses `age-keygen -y` with output suppressed, not SOPS decryption. Missing or malformed trust/digest/age files are reported together where possible; unsafe paths, permissions and invalid SSH/machine identities stop immediately. The first run normally fails until operator-supplied files are complete. Repeat the same `prepare=true` command after correcting the reported issues; existing identities are preserved.

A zero exit means **local installer-file checks passed**, not installation readiness. This is not a configuration checker: only the existing fleet-host and selected-secrets lookups use Nix; preparation does not add flake checks or builds, compare the digest to a generated script, inspect SSH configuration, test logins, decrypt secrets or contact the host. It cannot establish whether a correctly formatted pin belongs to the console-verified installer, whether an age recipient matches, or whether the disk and backups are safe.

To update trust/review files explicitly, supply either or both optional inputs, always with `prepare=true`:

```sh
devenv tasks run fleet:install --input host=racknerd --input prepare=true \
  --input knownHostsFile=/ABSOLUTE/PRIVATE/PATH/console-verified-known_hosts \
  --input reviewedDiskoSha256=REVIEWED_64_CHARACTER_SHA256
```

`knownHostsFile` must be an operator-owned local regular file outside the checkout/store, without symlinks or group/other write access. It must contain exactly one ED25519 **known_hosts entry**, including the installer hostname/IP (or `[host]:port` for a nondefault port), not just a bare public key. Read the live installer's public host key and fingerprint through the independently verified provider console and form that entry yourself. The mode checks file/key syntax and copies it atomically; it cannot verify your console comparison or infer the endpoint. It never scans the network, uses trust-on-first-use, edits SSH configuration or relaxes strict SSH checking. Repeating the command without this input preserves the current pin.

Only supply `reviewedDiskoSha256` after building and reading every command in the disko script as described below. Preparation validates the supplied or existing digest's format and records supplied updates atomically; it does not build a script or silently mark one reviewed. Installation still builds from the committed revision and checks equality. Without this input, the existing digest is preserved. Neither optional input is accepted in installation mode.

Authorize the generated `identity.pub` on the live installer through the verified console; preparation performs no key upload. Configure `HOST-installer` yourself. Existing credentials, backup custody, installer identity, disk state and eventual installed-system logins still need independent review. Preparation always exits before the installation branch: no SSH (including config resolution), disko execution, installation or reboot.

### Troubleshooting local preparation

The task prints a failing step plus `Troubleshoot:` guidance. For incomplete trust/digest/age files, resolve every `BLOCKED:` item and rerun preparation. Do not switch to installation to bypass a failure.

| Failure | Next steps |
|---|---|
| Error before `Running fleet:install` | The task has not started and cannot diagnose devenv itself. Use `nix run --no-update-lock-file .#devenv -- tasks run fleet:install --input host=HOST --input prepare=true`; pass `--no-tui` to devenv if terminal rendering hides the error. |
| Unsafe/missing path or incorrect modes | Inspect the exact path with `stat`. Keep the setup outside Git/store, owned by the operator, with the modes in the tree above. Correct individual reviewed paths only; no recursive chmod, automatic chown or symlink following. Check local free space/write access if file creation fails. |
| Invalid SSH key, mismatch or orphaned `.pub` | Restore the intended matching pair from independent backup. Do not remove a private key to force generation. Private keys must be usable noninteractively; installed host keys must be ED25519. Missing public files are derived automatically when the private key is valid. |
| Invalid machine-id | Restore the intended 32-character, nonzero lowercase hexadecimal ID and mode `0444`. Never replace a reinstall's identity just to pass validation. |
| Empty/invalid `known_hosts` | Read the live installer's public host key and fingerprint through the verified provider console. Form a full `hostname/IP ssh-ed25519 KEY` entry (or `[host]:port`), compare with `ssh-keygen -lf`, then edit the private file or import it using `knownHostsFile`. Strict SSH checking stays on; a network scan alone is not verification. |
| Empty/malformed `disko.sha256` | Follow the disko build-and-review steps below. Record only the reviewed 64-character lowercase digest, not the filename printed by `sha256sum`. A syntactically valid but stale digest is detected during installation, not preparation. |
| Missing/invalid age identity | Restore the reviewed identity from backup at the documented path/modes. Never print it, generate a replacement, or decrypt secrets just for validation. Correct recipient selection and real decryption remain separate checks. |

Keep the entire tree operator-owned inside the `0700` setup directory, with no symlinks, hard-linked files or group/other write access. All files except payload machine-id remain owner-only. The private outer directory protects the payload locally; the payload itself needs the target modes shown above. Nixos-anywhere copies it as root while preserving modes, and impermanence mirrors persistent directory modes into the running system. Recursive `chmod 700`/`600` on the payload can make `/etc` inaccessible and break D-Bus/networking. Machine-id must be readable by unprivileged system services; private keys must not be.

The resolved setup path may contain only letters, digits and `/._+-`, because upstream flattens SSH options into `NIX_SSHOPTS`. The client identity must be usable noninteractively; there is no agent or password fallback. Staging is not a backup: preserve independent recovery copies and correct remote ownership/modes. ThinkPad selects secrets and needs its reviewed age identity; neither server does. The installation branch rejects incorrect system-directory/machine-id modes; it never changes permissions, generates identities or decrypts anything. Only the explicit preparation branch creates missing identities and sets modes on its newly created files/directories. File presence does not prove a key decrypts selected secrets or provides usable access.

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
   - staging lives outside the checkout and the store in a private `0700` container; payload system directories are `0755`, machine-id is `0444`, and key files remain owner-only;
   - the built disko script's SHA-256 still equals the one you reviewed.

   ```sh
   devenv tasks run fleet:install --input host=HOST
   ```

   The task validates the hostname against `fleet`, refuses a dirty tree or missing/unsafe staging, and builds the disko script and system from the same immutable local Git revision. It compares the script to the private review digest and passes those exact store outputs to the hardened installer with `--store-paths`, `--extra-files` and `--phases disko,install --build-on local`: **destructive install, no kexec, no reboot, no host-key copying**. It does not inspect live disk consumers, backups or installer state for you. Never use a successful evaluation/build as authorization.
4. Afterwards inspect mounts, identities and boot setup, including persistent directory permissions and unprivileged machine-id readability. Private keys must remain inaccessible to unprivileged users. First boot and reboot acceptance are separate authorizations.

Never run disko, a generated script, `mkfs`, `wipefs` or a partition tool directly. Rollback cannot recover repartitioned data.
