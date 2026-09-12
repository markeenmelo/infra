# NixOS fleet

A small dendritic flake for three **already-installed** `x86_64-linux` hosts: a secure baseline plus a Hyprland/Noctalia desktop on ThinkPad; the others stay headless. **[Current host status](docs/hosts.md#current-status) is the authoritative dated evidence for boot, credential, maintenance and deployment state.** Only ready hosts enter `nixosConfigurations`; deploy outputs additionally require enabled deployment intent.

| Host | Baseline beyond SSH, access, existing mounts, tmpfs root and impermanence | Nixpkgs | Deploy-rs intent |
|---|---|---|---|
| `thinkpad` | Hyprland/Noctalia/Greeter, desktop-only HM, Ghostty/Zen and approved apps, fingerprint fallback, SOPS Wi-Fi, laptop power/thermald, reviewed Thunderbolt authorization; preserve LUKS/LVM/swap and `/home` | `nixpkgs-unstable` | local-only |
| `racknerd` | server hardening, nftables, persistent journal, SSH fail2ban, observed KVM/network configuration | numbered stable | `marcos@72.11.150.242`, after commissioning |
| `bastion` | server hardening, nftables, persistent journal; preserve existing ZFS `tank` legacy data mounts separately from OS persistence | numbered stable | `marcos@192.168.2.2`, after commissioning |

All three target **Limine** (racknerd BIOS; others UEFI); headless means no desktop, not removal of consoles/emergency recovery. Servers use a supported numbered stable branch; the laptop uses `nixpkgs-unstable` (not `nixos-unstable`) with no package-channel mixing. The [stock 7.x kernel policy](docs/desktop.md#kernels-and-intel-driver) selects each track's latest locked kernel with ZFS compatibility guards. [Tailscale policy/enrollment](docs/tailscale.md) is separately review-gated. Gaming, reverse proxy, shares and other applications remain deferred. Pins and dated API evidence are in [research](docs/research.md).

## Start here

Requires Nix with `nix-command` and `flakes`; developed with Nix 2.34.8.

```sh
nix run --no-update-lock-file .#devenv -- shell
devenv tasks run repo:inventory
devenv tasks run repo:check        # fast inner gate (seconds)
devenv tasks run repo:check-full   # canonical gate before handoff or deployment
devenv shell ready racknerd  # expected refusal until identity/trust gates are resolved
```

Native **devenv** supplies the locked toolbox, language servers, SOPS/age and guarded deployment scripts ([development commands](docs/development.md)); it performs no deployment, secret retrieval or disk action. **Stage intended new files before evaluation** — Git flakes ignore untracked files — and stage only reviewed encrypted SOPS files/public recipients, never plaintext credentials or private identities.

## Preservation, not provisioning

Each host composes `existing-storage`: disko `nodev` descriptions derive mounts for existing UUIDs or the existing LVM mapper. All disk/GPT/LVM-create/ZFS-create collections are closed; disko scripts and image/install-test outputs are rejected even after readiness, so **`devenv shell disk-plan HOST` is unavailable for these installations**.

- `/` becomes tmpfs on all hosts; no root-reset/deletion script is retained and existing root subvolumes are not erased.
- Existing `/nix`, `/persist` and laptop `/home` remain durable, early-mounted filesystems; laptop `/home` is not also an impermanence bind.
- Thinkpad keeps its existing encryption, LVM and swap. Bastion's NVMe OS `/persist` is **not** its ZFS data; the observed `/srv` datasets stay outside disko, with no pools/datasets/properties created or upgraded.
- Persist scoped machine identity, SSH identities, NixOS allocation state, random seed, timers/time sync and feature-owned state. Server journals are bounded. Removing declarations does not erase backing data, and persistence is not backup.

The original fresh-install-only `os-disk` capability is retained with its destructive-boundary/ESP tests but composed by no host; its [installation runbook](docs/bootstrap.md#storage-and-installation) is not a migration procedure ([ADR 0005](docs/adr/0005-existing-headless-baseline.md)).

## Access and deployment

Target policy: `marcos`, the explicitly selected existing public key, authenticated sudo with password fallback (ThinkPad additionally permits fingerprint), immutable users, locked root, no root/password SSH. **SOPS delivers password hashes from ciphertext before account creation** via `neededForUsers` and a dedicated persistent age identity; Bastion remains blocked without its verified identity/recipient ([ADR 0006](docs/adr/0006-sops-password-delivery.md), [secret inventory](secrets/README.md)).

A temporary non-root access bootstrap is not declarative commissioning: follow [the transition checklist](docs/hosts.md#access-and-state-migration-checklist--no-execution-authorized). Only `ready && deployment.enable` hosts enter deploy-rs: root activates, a non-root account connects via SSH, and closure transport remains nullable until signing trust or explicit root-equivalent per-user Nix trust is provisioned. Rollback stays enabled.

After commissioning, **with separate deployment authorization**:

```sh
devenv shell ready racknerd
devenv shell build racknerd        # local build; no deployment
devenv shell deploy-host racknerd  # really activates remotely
```

`--dry-activate` also contacts targets. Rollback does not restore data, secrets, storage layouts or guarantee the next boot. See [operations and recovery](docs/operations.md#deployment-and-recovery).

## Architecture

`flake.nix` is the production Nix entry point: it pins inputs and passes the whole `modules/` tree to the pinned `import-tree` input for **one top-level flake-parts evaluation** (`/_`-prefixed paths are excluded non-auto-imported helpers). Root `devenv.nix` is the approved native development-only exception; all remaining Nix files, including hardware facts and tests, are top-level modules ([ADR 0010](docs/adr/0010-native-devenv.md)). Class-checked `flake.modules.nixos`/`homeManager` capabilities and deferred per-host `fleet.hosts.<name>.module` facts compose only in their matching evaluation; no flake inputs are forwarded via `specialArgs`.

- `modules/flake-parts.nix` — flake-parts conventions; `modules/fleet.nix` — host identity/track metadata and the evaluation boundary.
- `modules/machines/` — explicit capability compositions and deployment intent; `modules/hardware/` — observed hardware only.
- `modules/storage/existing.nix` and host storage modules — existing-installation mount/boot boundary.
- `modules/{headless,ssh,access,secrets,server,vps,workstation,laptop}.nix` — cohesive reusable features; `logging.nix` contributes to persistence.
- `modules/desktop.nix` + `modules/desktop/` — the desktop bundle, its HM bridge, compositor/greeter/apps/peripherals and their tests.
- `modules/kernel.nix` — per-track latest stock 7.x policy; `modules/tailscale/` + `tofu/tailscale/` — review-gated enrollment and OpenTofu policy.
- `modules/deployment.nix` — deploy metadata and upstream checks; `modules/tooling.nix` — unstable bootstrap CLI and source/lock checks.
- `devenv.nix` — native developer packages/tasks and guarded script entry points; `modules/validation.nix` — typed synthetic fixture assembly and independent inventories. Feature-owned `checks.nix` files, scripts and assets stay beside their owners.

Each host's explicit `track` selects exactly one input's `lib.nixosSystem`; NixOS instantiates its own `pkgs`. The desktop concern imports Home Manager only for its unstable bundle; headless hosts have no HM. `home-manager` and `zen-browser` use default-branch URLs following unstable, pinned only in `flake.lock`; Zen's recipe is instantiated with the host's `pkgs`. See [ADR 0001](docs/adr/0001-dendritic-composition.md) and [ADR 0002](docs/adr/0002-nixpkgs-tracks.md).

## Validation and updates

Documentation-only edits use [scoped whitespace/link/status checks](docs/validation.md#documentation-only-changes). For code/configuration/dependency changes and deployment preflight:

```sh
devenv tasks run repo:fmt
devenv tasks run repo:check-full
nix eval --json .#fleet | jq 'map_values({track,revision,ready,missing})'
devenv tasks run repo:revisions
```

`repo:check` is the fast inner gate (task contract, formatting, lint, ciphertext guard, fleet inventory); `repo:check-full` adds the evaluation oracle, ciphertext regressions and the full `nix flake check`. No target contact or activation occurs, and **evaluation fixtures are not tested installations** ([validation scope/results](docs/validation.md)).

Updates are separate, researched operations and never change stateVersion automatically; targeted updates must not move the other track:

```sh
nix flake update nixpkgs-stable   # OR: nixpkgs / full update
# After nixpkgs changes, synchronize devenv.lock as documented in docs/development.md.
devenv tasks run repo:check-full
```

Follow [input operations](docs/operations.md#input-updates), [AGENTS.md](AGENTS.md) and the [skill index](.agents/skills/README.md). Add only the capabilities the fleet actually needs; keep service state and mount requirements beside their owner.
