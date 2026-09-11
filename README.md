# NixOS fleet

A small dendritic flake for three **already-installed** `x86_64-linux` hosts. This branch proposes a secure baseline plus a **new Hyprland/Noctalia desktop on ThinkPad**, not a reinstall. The other hosts remain headless. Read-only discovery and transition gates are in [docs/hosts.md](docs/hosts.md); new desktop defaults and acceptance are in [docs/desktop.md](docs/desktop.md).

**Read [current host status](docs/hosts.md#current-status) for dated boot, credential, maintenance and deferred-deployment evidence.** Only ready hosts enter `nixosConfigurations`; deploy outputs require readiness plus enabled deployment intent.

| Host | Baseline beyond SSH, access, disko existing mounts, tmpfs root and impermanence | Nixpkgs | Deploy-rs intent |
|---|---|---|---|
| `thinkpad` | Hyprland/Noctalia/Greeter, desktop-only HM, Ghostty/Zen and approved apps, fingerprint fallback, SOPS Wi-Fi, laptop power/thermald, reviewed Thunderbolt authorization; preserve LUKS/LVM/swap and `/home` | `nixpkgs-unstable` | local-only |
| `racknerd` | server hardening, nftables, persistent journal, SSH fail2ban, observed KVM/network configuration | numbered stable | `marcos@72.11.150.242`, after commissioning |
| `bastion` | server hardening, nftables, persistent journal; preserve existing ZFS `tank` legacy data mounts separately from OS persistence | numbered stable | `marcos@192.168.2.2`, after commissioning |

All three target **Limine** (racknerd BIOS; others UEFI). Headless means no desktop, **not** removal of consoles/emergency recovery. [Tailscale policy/enrollment](docs/tailscale.md) is separately review-gated; policy maintenance is not host enrollment or traffic acceptance. Gaming applications/drivers beyond ordinary hardware support, reverse proxy, shares and other applications remain deferred. Requested application preferences are deliberately reused without copying private profiles or credentials. Hardware unknowns and remaining display/campus/application acceptance stay explicit in [current status](docs/hosts.md#current-status).

Servers use a supported numbered stable NixOS branch. The laptop uses **`nixpkgs-unstable`**, not `nixos-unstable`, for future interactive/gaming software; its different Hydra gating warrants validation before upgrades. There is no package-channel mixing. The explicit [stock 7.x kernel policy](docs/desktop.md#kernels-and-intel-driver) selects each track's latest locked kernel (7.2.4 on both tracks after the current refresh), with ZFS compatibility and major-version guards. Branch selections are in `flake.nix`; pins and dated API evidence are in [research](docs/research.md).

## Start here

Requires Nix with `nix-command` and `flakes`; developed with Nix 2.34.8.

```sh
nix develop --no-update-lock-file
just inventory
just check
just ready racknerd  # expected refusal until identity/trust gates are resolved
```

The locked development shell supplies official nixfmt/nixfmt-tree, statix, deadnix, just, jq, SOPS, age, yq, Git, OpenSSH, ShellCheck and source-matched deploy-rs. Entry performs no deployment, secret retrieval or disk action. **Stage intended new files before evaluation:** Git flakes ignore untracked files. Only reviewed encrypted SOPS files/public recipients may be staged; never plaintext credentials, private identities or unrelated work.

## Preservation, not provisioning

Each host composes `existing-storage`: disko `nodev` descriptions derive mounts for existing UUIDs or the existing LVM mapper. All disk/GPT/LVM-create/ZFS-create collections are closed; disko scripts and image/install-test outputs are rejected even after readiness. **`just disk-plan HOST` is unavailable for these installations.** This is a runtime mount description, not an installer layout.

- `/` becomes tmpfs on thinkpad/racknerd/bastion. No old Btrfs root-reset/deletion script is retained. Existing root subvolumes are not erased.
- Existing `/nix`, `/persist` and laptop `/home` remain durable, early-mounted filesystems. Laptop `/home` is **not** also an impermanence bind.
- Thinkpad's existing encryption, LVM and swap remain. No plaintext secrets or private identities enter the Nix store.
- Bastion's NVMe OS `/persist` is **not** its ZFS data. The observed `/srv` datasets stay outside disko. No pools/datasets/properties are created or upgraded; import policy and restore require review.
- Persist scoped machine identity, SSH identities, NixOS allocation state, random seed, timers/time sync and feature-owned state. Server journals are bounded; workstation `/home` deliberately preserves user data. Removing declarations does not erase backing data. Persistence and mirroring are not backups.

```sh
nix eval --json .#fleet.bastion.filesystems | jq .
nix eval --json .#fleet.thinkpad.persistence | jq .
```

The original **fresh-install-only** `os-disk` capability is retained with its destructive-boundary/ESP tests, but no current host composes it. Its [installation runbook](docs/bootstrap.md#storage-and-installation) is not a migration procedure. See [ADR 0005](docs/adr/0005-existing-headless-baseline.md).

## Access and deployment

Target policy: `marcos`, the explicitly selected existing public key, authenticated sudo with password fallback (ThinkPad additionally permits fingerprint), immutable users, locked root, no root/password SSH. **SOPS delivers password hashes from ciphertext before account creation** using `neededForUsers` and a dedicated persistent age identity. Null credentials or unreviewed identities remain commissioning blockers, not plausible runtime paths. See [secret inventory and procedure](secrets/README.md), [ADR 0006](docs/adr/0006-sops-password-delivery.md) and [current credential/access evidence](docs/hosts.md#current-status).

A temporary non-root access bootstrap is not declarative commissioning. Follow [the transition checklist](docs/hosts.md#access-and-state-migration-checklist--no-execution-authorized), with independent recovery and verified non-VPN routing before removing an old service. Reinstallation requires a separately reviewed fresh-install design; validation never authorizes it.

Only `ready && deployment.enable` hosts enter deploy-rs. Root activates the system; a non-root account connects via SSH. Closure transport remains nullable until signing trust or explicit root-equivalent per-user Nix trust is chosen and provisioned. No blanket wheel trust or passwordless sudo. Automatic and magic rollback remain enabled.

After commissioning, **with separate deployment authorization**:

```sh
just ready racknerd
just build racknerd       # local build; no deployment
just deploy racknerd      # really activates remotely
# Approved subset, after each target's preflight:
deploy --targets .#racknerd .#bastion -- --no-update-lock-file
```

`--dry-activate` also contacts/copies to targets. Rollback does not restore data, secrets, storage layouts or guarantee the next boot. See [operations and recovery](docs/operations.md#deployment-and-recovery).

## Architecture

`flake.nix` is the sole Nix entry point. Its sorted discovery imports every `.nix` under `modules/` into **one top-level flake-parts evaluation**; no symlinks are followed. All other repository Nix files, including hardware facts and tests, are top-level modules.

Class-checked `flake.modules.nixos.<capability>`, `flake.modules.homeManager.<capability>` and per-host `fleet.hosts.<name>.module` are deferred values. Concerns may contribute to the same value; paths organize concerns, not host import roots. No flake inputs are injected through `specialArgs`. SSH has a stable module key to deduplicate diamond imports.

- `modules/fleet.nix`: required identity/architecture/track, evaluation boundary, inventory.
- `modules/machines/`: explicit capability compositions and deployment intent.
- `modules/hardware/`: observed hardware only; networking, access, locale and laptop policy live in their own concerns.
- `modules/storage/existing.nix`, host storage/data modules: existing-installation mount/boot boundary.
- `modules/{headless,ssh,access,secrets,server,vps,workstation,laptop}.nix`: cohesive reusable features; `logging.nix` contributes to persistence.
- `modules/desktop.nix`: concern-owned native HM bridge and `desktop` bundle. `modules/desktop/` separates compositor, greeter, apps, peripherals, display facts and their tests; applicable NixOS/HM/host contributions stay together.
- `modules/kernel.nix`: explicit host-track latest stock 7.x policy, without suppressing ZFS compatibility failures.
- `modules/tailscale/`, `tofu/tailscale/`: review-gated client enrollment/persistence (ThinkPad candidate enabled) plus separate OpenTofu policy/MagicDNS management. `just tailscale-inventory` shows rollout blockers; `just tailnet` is an explicit operator workflow, never part of rebuild/check.
- `modules/deployment.nix`: metadata, SSH integration, target-track activation and upstream checks.
- `modules/tooling.nix`: locked shell assembly and source checks; features contribute their own developer tools.
- `modules/validation.nix`: typed synthetic fixture assembly and independent report/check/track inventories. Feature-owned `checks.nix` files and small inline checks retain the public reports and safety regressions. Scripts/assets stay beside their owner, not in a separate scripts tree.

Each host's explicit `track` selects exactly one input's `lib.nixosSystem` in `modules/fleet.nix`. NixOS instantiates its own `pkgs`; generic features use that evaluation's `pkgs`/`lib`. The desktop concern, not the fleet evaluator, imports Home Manager only for its unstable bundle, using the host's packages; headless hosts have no HM integration. The `home-manager` and `zen-browser` inputs use default-branch URLs and follow unstable, with their revisions recorded only in `flake.lock`. Zen's recipe is still instantiated with the host's `pkgs`, not its upstream package outputs. Validation independently checks required tracks, actual package-source paths, locked branch names and Home Manager branch/follows policy. See [ADRs](docs/adr/0001-dendritic-composition.md).

## Validation and updates

Documentation-only edits use [whitespace, link/status and changed-snippet validation](docs/validation.md#documentation-only-changes), not fleet builds. For code/configuration/dependency changes and deployment preflight:

```sh
just fmt
just check
nix eval --json .#fleet | jq 'map_values({track,revision,ready,missing})'
just revisions
```

`just check` first checks encrypted payload shape/public recipients without decryption, then runs formatting, statix, deadnix, ShellCheck, every real host report and package/`/etc`/initrd derivation, independent track checks, both-track synthetic infrastructure/storage/security/SOPS fixtures, unstable-only desktop fixtures, built SOPS manifests, native generated desktop-config and offline Wi-Fi checks and upstream deploy schema/activation smoke checks. No target contact or activation occurs. **Evaluation fixtures are not tested installations.** Actual host toplevel builds remain gated. [Validation scope/results](docs/validation.md) distinguishes evaluation, builds and runtime acceptance.

Updates are separate, researched operations and never change stateVersion automatically:

```sh
nix flake update nixpkgs-stable
# OR: nix flake update nixpkgs-unstable
# OR: nix flake update
just check
```

Targeted updates must not move the other track. Follow [input operations](docs/operations.md#input-updates), [AGENTS.md](AGENTS.md) and the [skill index](.agents/skills/README.md). Add only the capabilities the fleet actually needs; keep service state and mount requirements beside their owner.
