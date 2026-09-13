# Native devenv

## Start

From the repository root:

```sh
nix run --no-update-lock-file .#devenv -- shell
```

The shell supplies the locked unstable CLI/toolbox, no default compiler (`stdenvNoCC`), explicit Nix, Nix/Bash language servers, Python, SOPS/age and the exact checked OpenTofu/provider wrapper plus `tofu-ls`. No host imports this development environment. ThinkPad's desktop also packages devenv for other projects.

**2026-09-13 task amendment:** after the earlier task removal, the operator explicitly requested three independent tasks: `host:create`, `host:install` and `deploy:run`. No repo validation DAG, automatic formatter, hooks profile or `enterTest` gate returns. All task inputs default to null; no cache/status or lifecycle/dependency edges. Shell entry never invokes them, and `devenv test` remains no validation gate. `pkgs.nixfmt-tree` supplies the explicit Nix-only formatter. The toolbox adds Nixpkgs-pinned nixos-anywhere 1.13.0, not an unpinned `nix run github:...` installer.

Use `devenv shell -- bash -c 'COMMAND'` for shell flags: without the separator, `-c` can be parsed as devenv's global clean flag. Check actual output/exit status, not merely a quiet successful shell entry.

## Existing scripts

Bodies live in `scripts/devenv/`; `devenv.nix` registers them with `builtins.readFile`. Keep future devenv helpers there, not inline or under `modules/`.

| Command | Boundary |
|---|---|
| `devenv shell ready HOST` | Local commissioning checks only |
| `devenv shell build HOST` | Readiness then local system build |
| `devenv shell disk-plan HOST` | Local guarded script construction, never execution |
| `devenv shell -- install HOST` | Guided destructive reinstall; prompts, plan review and shared full preflight; no reboot |
| `devenv shell -- deploy TARGET MODE "DEPLOY TARGET MODE"` | Same guarded preflight/confirmation body as deploy:run, no raw overrides |
| `devenv shell tailnet OPERATION` | Guarded operator workflow; live API/state actions need authorization |
| `devenv shell tailnet-sops ENCRYPTED.yaml OPERATION` | Explicit private runtime credential delivery into that workflow |

Follow [validation](../../validate/SKILL.md), including ciphertext inspection **before** staging/evaluation. Deployment/installation explicitly run `bash scripts/devenv/preflight.sh` synchronously; it performs report-only formatting/static checks, native task contract, ciphertext/regressions, tool/lock parity and serialized fleet/full-flake validation. It never formats files or contacts targets. Readiness/build/disk-plan still require the operator's pre-store guard. Use the matching [deployment](../../deploy/SKILL.md), [storage](../../storage-disko/SKILL.md) or [Tailscale](../../tailscale/SKILL.md) procedure.

`.envrc` uses the installed CLI's `devenv direnvrc`, not downloaded shell code. Review before `direnv allow`. Never load secrets into its cached environment. Existing local hooks installed by the deleted opt-in profile may remain on an operator machine; inspect them and request separate removal if needed, rather than modifying `.git/hooks` automatically.

## Operator tasks

Run from the locked shell. Inputs are public operation requests, not Nix configuration or proof of acceptance. Unknown/missing inputs and wrong confirmation phrases fail closed. Live tasks require a clean reviewed commit; no task stages files, changes readiness, logs credential values, disables rollback or deletes homes as deployment cleanup.

### Scaffold only

```sh
: "${new_host:?Choose a new lowercase host name}"
devenv tasks run host:create --input-json "$(jq -cn --arg name "$new_host" \
  '{name:$name,system:"x86_64-linux",track:"stable",group:"servers"}')"
```

Choose track and group deliberately; the example selects stable/server. This creates only `modules/hosts/NAME/{host,hardware,disko}.nix`, refuses overwrites, leaves all facts/reviews unresolved and blocks every disk-script alias. Workstation scaffolds start headless until desktop policy is explicitly reviewed. No evaluation or Git staging occurs. Before staging, complete hardware/OS layout/keys/state, add deployment facts to `modules/deploy.nix`, and deliberately extend independent track/host/composition oracles. The incomplete scaffold is not yet a passing fleet addition and may not be installed.

### Deployment

```sh
devenv tasks run deploy:run --input target=servers --input mode=boot \
  --input 'confirm=DEPLOY servers boot'
```

This is a live-operation example, **not a command to run without current authorization**. Targets may be one commissioned host or `servers`/`workstations`. All members must be eligible before any contact. Server activation is ordered Racknerd then Bastion via explicit targets; upstream remote builds may overlap, and a later failure may roll back earlier successful activations. ThinkPad remains blocked. Bastion's current `bootOnly` metadata refuses switch mode. The first account/home transition still requires [staged old access or console](../../deploy/references/operations.md#minimal-server-transition--2026-09-13); the task cannot create its own missing login. Native deploy-rs Nix flags follow its final `--`; no arbitrary override passthrough is accepted.

### Separate destructive installation

**Normal interactive command:**

```sh
devenv shell -- install bastion
```

The foreground-only guide looks up the host's configured OS device and age policy, prompts for verified live-USB/recovery information, creates a private temporary host-bound manifest and opens the built disk plan for review. You do not write JSON, export variables or copy hashes. Private file paths are entered without echo; no key/password contents are requested. Use independently verified recovery records for the preserved machine ID/SSH fingerprint, not values inferred from an unreviewed staging bundle. Staging preparation, backups and physical/console verification remain necessary; the guide does not mount/recover disks or generate/decrypt identities.

After plan/recovery acknowledgement, it shows the exact scope and requires `ERASE HOST`. Only then does it compose the existing full target/device/identity confirmation and call `scripts/devenv/host-install.sh`, with full preflight and every existing guard retained. Enter at either approval or Ctrl-C cancels before handoff; interruption after handoff requires inspection before retrying. A changed/dirty candidate refuses. The guide never runs on shell entry and adds no task/DAG edge. `install` reserves exactly one host-like argument; normal GNU `install` options/file-copy invocations forward to the pinned coreutils executable rather than recursing into the guide.

See the [Bastion guided procedure](../../storage-disko/references/reinstall.md#bastion-operator-reinstall--2026-09-13). The following explicit-input interface is retained for deliberate automation, **not required by the guide**.

#### Advanced task interface

First complete [storage review](../../storage-disko/SKILL.md), independent backups/restore, live-installer console identity and exact OS-device review. `disk-plan HOST` builds without executing and prints the script SHA-256; read the entire plan before supplying `planHash`. Any changed hash requires renewed review.

Prepare a private owned `0700` staging directory **outside the checkout/store**, containing only `persist/etc/machine-id`, `persist/etc/ssh/ssh_host_ed25519_key` and its `.pub`. Add `persist/var/lib/sops-nix/key.txt` **only for a host with selected SOPS secrets**; current servers require no age key and reject it in staging. Private files must be owned and inaccessible to group/others (normally `0600`); no symlinks/group-writable entries. These are independently verified installed identities with off-host recovery, not live-USB identities. Do not generate/rotate/decrypt them implicitly. Set only runtime paths `FLEET_INSTALL_EXTRA_FILES`, `FLEET_INSTALL_IDENTITY` and `FLEET_INSTALL_MANIFEST`; no path/content goes in Nix or task inputs.

The manifest is a separate owned `0600` JSON file outside the staging tree, checkout and store. Its exact fields are `host` (selected fleet name), `machineId` (reviewed nonzero 32-character lowercase hex ID), `sshHostFingerprint` (installed ED25519 `SHA256:` fingerprint) and `ageRecipient` (JSON `null` for secret-free servers; otherwise the installed dedicated age public recipient). Obtain these bindings from independently verified, host-labelled recovery records—not by blessing whichever staging directory was supplied. The helper compares the staged machine ID, derives the SSH public key from its private half and checks the staged public file/fingerprint, and, when needed, derives the age recipient without printing private material. After full preflight it reads the selected host's typed SOPS metadata; the manifest's null/public age recipient must match it, and nonstandard staged identity paths refuse. Before any target contact it snapshots staging and the manifest into a private temporary directory, rechecks that snapshot against both host and evaluated age policy, and installs only that snapshot. This catches mixed-up host bundles; it does not establish the provenance or recovery quality of the operator-reviewed manifest.

```sh
: "${FLEET_INSTALL_EXTRA_FILES:?Set the reviewed private staging directory}"
: "${FLEET_INSTALL_IDENTITY:?Set the reviewed private installer SSH identity path}"
: "${FLEET_INSTALL_MANIFEST:?Set the independently reviewed host-bound manifest path}"
: "${host:?}" "${installer:?root@reviewed-IPv4-or-DNS-endpoint}" "${port:?}"
: "${device:?Reviewed whole OS disk}" "${identity:?Exact serial; Racknerd PCI only: size:BYTES}"
: "${fingerprint:?Console-verified installer ED25519 SHA256 fingerprint}" "${plan_hash:?Reviewed disko script SHA-256}"
export FLEET_INSTALL_EXTRA_FILES FLEET_INSTALL_IDENTITY FLEET_INSTALL_MANIFEST
devenv tasks run host:install --input-json "$(jq -cn \
  --arg host "$host" --arg target "$installer" --argjson port "$port" \
  --arg device "$device" --arg identity "$identity" --arg fingerprint "$fingerprint" \
  --arg planHash "$plan_hash" --arg confirm "ERASE $host $installer $device $identity" \
  '{host:$host,target:$target,port:$port,device:$device,identity:$identity,fingerprint:$fingerprint,planHash:$planHash,confirm:$confirm}')"
```

The confirmation acknowledges the exact target/disk/identity, reviewed plan, backup and recovery prerequisites; it does not prove them. The task runs full local preflight, compares the commissioned disk and plan hash, pins a scanned ED25519 key against the console-provided fingerprint, and then requires root on a RAM/overlay NixOS live installer with no `/mnt` mounts, imported ZFS pools or active swap. Every enumerated disk/partition must have a readable, empty kernel `holders` directory; missing or failed inventory queries refuse. Fresh lsblk must identify one unmounted whole disk matching the serial, or Racknerd's explicitly reviewed PCI/size exception, with only plain disk/partition node types: unmounted dm-crypt/LVM/RAID/multipath consumers also refuse. These read-only checks are not an exclusive device lock; keep the installer idle and never activate consumers during installation. The task does not close mappings, stop arrays, disable swap, export pools or unmount anything to bypass a refusal.

Nixos-anywhere 1.13.0 hardcodes unsafe SSH defaults before its option flags. The runtime SSH shim **prepends** strict/batch/key-only settings and the pinned private known-host file for every underlying SSH call; ordinary `--ssh-option StrictHostKeyChecking=yes` cannot safely override the upstream first-value behavior. The tool copies the selected installer login key into its private temporary directory and may ensure that key is authorized in the live installer; it does not generate installed host identities here. It receives prebuilt store paths, `--build-on local` and exactly `--phases disko,install`: **destructive OS partitioning/install, no kexec, no reboot, no automatic host-key copying**. Inspect mounts/identities/boot setup afterward; boot and two-boot acceptance require separate authorization. Task success is not a tested installation.

## SOPS → OpenTofu

Use the [private state, scopes and recovery procedure](../../tailscale/references/tailscale.md#operator-setup-private-terminal-only). Do not recreate existing state, rotate its passphrase or repeat completed imports.

The separately reviewed operator YAML must contain exactly:

- `TAILSCALE_OAUTH_CLIENT_ID`
- `TAILSCALE_OAUTH_CLIENT_SECRET`
- `TF_VAR_state_passphrase`

Values must be nonempty single-line strings; use the existing independently recoverable passphrase (at least 32 characters). Keep read-only/write clients in separate reviewed ciphertext files, outside the checkout unless separately reviewed recipient rules/structural validation are added. Use an operator identity, never a host password/Wi-Fi file. No real operator ciphertext or identity is supplied here.

In a private terminal, before providing runtime paths:

```sh
devenv --clean shell -- bash --noprofile --norc
```

Set `TAILSCALE_STATE_DIR` to the existing reviewed private directory, `TAILSCALE_SOPS_FILE` to the reviewed ciphertext path and, if needed, `SOPS_AGE_KEY_FILE` to the operator identity path. A path proves no readiness. Only after read-only API authorization:

```sh
tailnet-sops "$TAILSCALE_SOPS_FILE" verify
```

The adapter refuses inherited credential exports/debugging, MAC-decrypts through native SOPS with captured sanitized diagnostics, parses JSON as data, accepts exactly the three keys and replaces itself with the guarded wrapper. Values stay child memory/environment, not shell exports, argv, plaintext files or cached output. No sourced decrypted shell text or OpenTofu SOPS data source. Same-user/root inspection remains possible; do not launch an agent/editor from the credential-bearing child.

`verify` preserves 0=no changes, 2=drift, 1=error without saving a plan. Init/import/plan/apply still require their own operation review; credential loading authorizes none of them. Preserve the encrypted [emergency-state fallback](../../tailscale/references/tailscale.md#emergency-state-recovery).

## Locks and architecture

[ADR 0010](../../dendritic-nix/references/adr/0010-native-devenv.md) retains the development-only exception. Production inputs and unstable bootstrap packages belong to `flake.lock`; native sources belong to `devenv.lock`. Both Nixpkgs nodes must match exactly. Never change host tracks or grant Nix trust to bypass a tooling failure.

After an authorized unstable input update, synchronize only the public native Nixpkgs node:

```sh
python3 - <<'PY'
import json
from pathlib import Path
path = Path('devenv.lock')
lock = json.loads(path.read_text())
lock['nodes']['nixpkgs'] = json.loads(Path('flake.lock').read_text())['nodes']['nixpkgs']
path.write_text(json.dumps(lock, indent=2) + '\n')
PY
```

Research CLI/module and OpenTofu/provider compatibility; review every lock delta and run manual checks. `devenv update devenv` is a scoped native-source update; `devenv update` is broader and may advance Nixpkgs independently. The git-hooks input remains an upstream module dependency, not an enabled local hooks profile. Keep production deploy-rs/sops-nix inputs: host activation and secret-delivery modules consume them independently of development tooling.
