# NixOS fleet

A small dendritic flake preparing **fresh reinstalls** of three `x86_64-linux` hosts: a secure baseline plus a Hyprland/Noctalia desktop on ThinkPad; the others stay headless. Candidate readiness is distinct from installed-system acceptance; do not activate fresh disk layouts over existing installations. **[Current host status](docs/hosts.md#current-status) is the authoritative dated evidence for boot, credential, maintenance and deployment state.** Only ready hosts enter `nixosConfigurations`; deploy outputs additionally require enabled deployment intent.

| Host | Candidate beyond SSH, access, plain Btrfs, tmpfs root and impermanence | Nixpkgs | Deploy-rs intent |
|---|---|---|---|
| `thinkpad` | Hyprland/Noctalia/Greeter, desktop-only HM, Ghostty/Zen and approved apps, fingerprint fallback, SOPS Wi-Fi, laptop power/thermald, reviewed Thunderbolt authorization; separate `/home`, 8 GiB plain swap, no LUKS/LVM/hibernation | `nixpkgs-unstable` | local-only |
| `racknerd` | server hardening, nftables, persistent journal, SSH fail2ban, observed KVM/network configuration | numbered stable | `marcos@72.11.150.242`, after commissioning |
| `bastion` | server hardening, nftables, persistent journal; preserve ZFS `tank` legacy mounts separately from OS persistence; monthly scrub and native opt-in snapshots | numbered stable | `marcos@192.168.2.2`, after commissioning |

All three target **Limine** (racknerd BIOS; others UEFI); headless means no desktop, not removal of consoles/emergency recovery. Servers use a supported numbered stable branch; the laptop uses `nixpkgs-unstable` (not `nixos-unstable`) with no package-channel mixing. The [stock 7.x kernel policy](docs/desktop.md#kernels-and-intel-driver) selects each track's latest locked kernel with ZFS compatibility guards. [Tailscale policy/enrollment](docs/tailscale.md) is separately review-gated. Gaming, reverse proxy, shares and other applications remain deferred. Pins and dated API evidence are in [research](docs/research.md).

## Start here

Requires Nix with `nix-command` and `flakes`; developed with Nix 2.34.8.

```sh
nix run --no-update-lock-file .#devenv -- shell
devenv tasks run repo:inventory
devenv tasks run repo:check        # fast inner gate (seconds)
devenv tasks run repo:check-full   # canonical gate before handoff or deployment
devenv shell ready racknerd  # local commissioning checks; never installation/activation
```

Native **devenv** supplies the locked toolbox, language servers, SOPS/age, guarded operator scripts and the explicit live single-host deploy task ([development commands](docs/development.md)); shell entry and `repo:*` tasks perform no deployment, secret retrieval or disk action. **Stage intended new files before evaluation** — Git flakes ignore untracked files — and stage only reviewed encrypted SOPS files/public recipients, never plaintext credentials or private identities.

## Fresh candidates and execution boundaries

Each host composes its single `modules/hosts/<host>/disko.nix`: native disko partitions, firmware policy and local provisioning guards. The old `os-disk.nix`, `existing.nix`, old UUID mount files and their interfaces are removed, not renamed or retained as an old/new framework.

- Order: **Bastion → Racknerd → ThinkPad**. Both servers have accepted two boots. The operator selected their already-prepared **MacBook**, not Bastion, to administer the final ThinkPad reinstall; retain independent credentials/recovery outside ThinkPad before its separate wipe authorization.
- GPT, FAT `/boot`, plain Btrfs `nix`/`persist`, tmpfs `/`; ThinkPad adds `home` and 8 GiB swap. BIOS Racknerd has a first 1 MiB EF02 partition. No LUKS/LVM or old UUIDs in the candidate.
- Readiness and storage review gate standard NixOS/deploy targets and real disko scripts. Both servers now have fresh pre-install reviews; ThinkPad remains unready. Racknerd's approved no-serial exception uses its real PCI by-path attachment, with mandatory VM/topology/size checks. Bastion/ThinkPad still require by-id. Old-installation reviews do not commission freshly formatted storage.
- Bastion's NVMe `/persist` is **not** `tank`; its legacy `/srv` mounts remain outside disko and unchanged. No NAS pool/dataset creation, conversion or migration is authorized.
- Preserve scoped identity and service state through impermanence. Both server candidates are editor-free minimal baselines, without agents/development workspaces or persistent admin homes. Bastion's installed home bind remains until the operator applies the [boot-only transition](docs/operations.md#minimal-server-transition--2026-09-13); old backing data is not deleted. Persistence is not backup.

[Reinstall preparation](docs/reinstall.md) and the [manual installation runbook](docs/bootstrap.md#storage-and-installation) retain recovery and explicit execution boundaries. The historical adoption policy is [ADR 0005](docs/adr/0005-existing-headless-baseline.md); the current fresh design is [ADR 0003](docs/adr/0003-storage-and-impermanence.md). Bastion's NVMe installation and two boots are accepted. Racknerd's separately authorized single-disk installation, private credential/sudo checks and two-boot persistence acceptance also passed. [Dated status](docs/hosts.md#current-status) records progress and exact boundaries. ThinkPad operations and deploy-rs activation remain unauthorized.

## Access and deployment

Target policy: `marcos`, both explicitly reviewed administrator public keys (`SHA256:rU2P8TOXVjL3ymRg1OyxA0YgxKrp9PBKKD56FhXWu/I` and `SHA256:mZ36DV6PDIt0lmhfqrO9qKKxQSlmQ7iMiH1NNYWvDRI`), authenticated sudo with password fallback (ThinkPad additionally permits fingerprint), immutable users, locked root, no root/password SSH. **SOPS delivers password hashes from ciphertext before account creation** via `neededForUsers` and a dedicated persistent age identity; Bastion now has a separately verified identity/recipient, private-terminal credential checks and two-boot persistence acceptance ([ADR 0006](docs/adr/0006-sops-password-delivery.md), [secret inventory](secrets/README.md)).

A temporary non-root access bootstrap is not declarative commissioning: follow [the transition checklist](docs/hosts.md#access-and-state-migration-checklist--no-execution-authorized). Only `ready && deployment.enable` hosts enter deploy-rs: root activates, a non-root account connects via SSH, and closure transport remains nullable until signing trust or explicit root-equivalent per-user Nix trust is provisioned. Rollback stays enabled.

After commissioning, **with separate deployment authorization**:

```sh
devenv shell ready racknerd
devenv shell build racknerd        # local build; no deployment
# LIVE: exact public confirmation + that host's LOCAL_KEY are required.
LOCAL_KEY=/private/path/to/racknerd-signing-key \
  devenv --no-tui tasks run deploy:host --show-output \
  --input host=racknerd --input mode=switch \
  --input confirm=deploy:racknerd:switch
```

`--dry-activate` also contacts targets. Rollback does not restore data, secrets, storage layouts or guarantee the next boot. See [operations and recovery](docs/operations.md#deployment-and-recovery).

## Architecture

`flake.nix` is the production Nix entry point: it pins inputs and passes the whole `modules/` tree to the pinned `import-tree` input for **one top-level flake-parts evaluation** (`/_`-prefixed paths are excluded non-auto-imported helpers). Root `devenv.nix` is the approved native development-only exception; all remaining Nix files, including hardware facts and tests, are top-level modules ([ADR 0010](docs/adr/0010-native-devenv.md)). Class-checked `flake.modules.nixos`/`homeManager` capabilities and deferred per-host `fleet.hosts.<name>.module` facts compose only in their matching evaluation; no flake inputs are forwarded via `specialArgs`.

- `modules/flake-parts.nix` — flake-parts conventions; `modules/fleet.nix` — host identity/track metadata and the evaluation boundary.
- `modules/hosts/<host>/host.nix` — explicit composition/deployment intent; adjacent `disko.nix` owns its fresh OS layout. Bastion's `data.nix` owns legacy tank mounts and scrub/snapshot policy, outside disko. Every file remains independently discovered at the top level: no `default.nix` or host import chain.
- `modules/storage/` — shared Limine, persistence, NAS review and storage checks; `modules/hardware/` — observed hardware only.
- `modules/{headless,ssh,access,secrets,server,vps,workstation,laptop}.nix` — cohesive reusable features; `logging.nix` contributes to persistence.
- `modules/desktop.nix` + `modules/desktop/` — the desktop bundle, its HM bridge, compositor/greeter/apps/peripherals and their tests.
- `modules/kernel.nix` — per-track latest stock 7.x policy; `modules/tailscale/` + `tofu/tailscale/` — review-gated enrollment and OpenTofu policy.
- `modules/deployment.nix` — deploy metadata and upstream checks; `modules/tooling.nix` — unstable bootstrap CLI and source/lock checks.
- `devenv.nix` — native developer packages/tasks, including the disconnected live single-host deployment task, and guarded script entry points; `modules/validation.nix` — typed synthetic fixture assembly and independent inventories. Feature-owned `checks.nix` files, scripts and assets stay beside their owners.

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
