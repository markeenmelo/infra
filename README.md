# NixOS fleet

A small, dendritic flake for four `x86_64-linux` machines. **This is a safe commissioning scaffold, not an install image. No real disk, network, GPU, account, or provider facts have been fabricated.**

| Host | Composition (in addition to base, OS disk, persistence, access) | Primary Nixpkgs | Deployment policy |
|---|---|---|---|
| `thinkpad` | workstation, laptop, administration | `nixpkgs-unstable` | opt-in; may be offline |
| `racknerd` | server, VPS | `nixpkgs-stable` | enabled after commissioning |
| `bastion` | server, NAS | `nixpkgs-stable` | enabled after commissioning |
| `dino` | workstation, gaming | `nixpkgs-unstable` | opt-in; may be offline |

Servers use a numbered, supported stable NixOS branch for conservative service upgrades. Interactive systems use **`nixpkgs-unstable`**, not `nixos-unstable`, for newer desktop/driver/gaming packages. This channel has different Hydra gating from the NixOS channel; validate before upgrading. Kernels come from each track's defaults; selecting a newer kernel remains an explicit hardware decision. No package-channel mixing is provided.

The stable branch researched at implementation time and source evidence are recorded in [docs/research.md](docs/research.md). The current repository branch selections live in `flake.nix`, not an evergreen release number here.

## Start here

Requires Nix with `nix-command` and `flakes` enabled; developed with Nix 2.34.8. The documented targeted update syntax needs Nix 2.19 or newer.

```sh
nix develop --no-update-lock-file
just inventory
just check
just ready thinkpad    # deliberately fails until commissioning is complete
```

The development shell uses stable Nixpkgs: official `nixfmt`/`nixfmt-tree`, maintained Nixpkgs `statix`, `deadnix`, `just`, `jq`, Git, OpenSSH, ShellCheck, and the locked deploy-rs source. Nix itself must already be available. No automatic hooks, channel updates, secret downloads, deployments, or disk actions occur on shell entry.

**Initially `nixosConfigurations` and `deploy.nodes` are empty.** All four *real compositions* are evaluated under `fleetConfigurations`. `fleet` provides a JSON-safe report with revisions, missing facts, persistence and failed assertions. Setting `fleet.hosts.<name>.ready = true` publishes that host as a normal NixOS configuration; unresolved requirements still fail its build. This avoids both fake buildable hardware and a permanently broken bootstrap `nix flake check`.

Follow [docs/bootstrap.md](docs/bootstrap.md) to commission a host. Never mark a checklist acknowledgement true without doing the work.

## Architecture and navigation

`flake.nix` is the only Nix entry point. Its small, sorted discovery expression imports every `.nix` file under `modules/` into **one top-level flake-parts/Nixpkgs module evaluation**. No symlinks are followed. All other repository Nix files must live there and be top-level modules, including tests and future hardware facts.

- `modules/fleet.nix`: typed identity/composition metadata, host evaluation and inventory.
- `modules/machines/`: identities with explicit track, architecture and named capabilities; **not** NixOS import roots.
- `modules/{workstation,laptop,gaming,server,vps,access,ssh,administration}.nix`: cohesive capabilities.
- `modules/storage/`: OS destructive boundary, ephemeral root/persistence, NAS review boundary.
- `modules/logging.nix`: contributes logging to the *same* deferred persistence value; localized journald API compatibility.
- `modules/deployment.nix`: deployment metadata, SSH integration, target-track activation, upstream deploy checks and CLI package.
- `modules/{tooling,validation}.nix`: shell, source checks and both-track evaluation/safety fixtures.
- `docs/`: commissioning, operating procedures, research and [ADRs](docs/adr/).
- `.agents/skills/`: standard, repository-local procedural agent skills.

`flake.modules.nixos.<capability>` is a class-checked **`deferredModule`** value. Features can contribute to the same value; evaluation happens only when a host composes it. `fleet.hosts.<name>.module` is another deferred value, allowing storage assignments, hardware, user choices and deployment concerns to be supplied independently. Paths name concerns; moving a file within `modules/` does not change its meaning. Nothing passes flake inputs through `specialArgs`.

### Which revision evaluates a host?

`modules/fleet.nix` maps required metadata `track = "stable" | "unstable"` to exactly one input and calls **that input's** `lib.nixosSystem`. NixOS creates its own `pkgs`; the development shell's package set is never injected. `validation.nix` independently checks the required host-to-track mapping, the actual `pkgs.path`, and locked branch names.

```sh
nix eval --json .#fleet.thinkpad | jq '{input,revision,nixpkgsPath,nixosVersion}'
nix eval --json .#fleet | jq 'map_values({track,revision})'
nix flake metadata
just revisions
```

## Updating inputs

Start with a clean, reviewed Git state. Read relevant release notes/issues first. Lock updates do **not** change `system.stateVersion`.

```sh
nix flake update nixpkgs-stable    # server track only
nix flake update nixpkgs-unstable  # interactive track only
nix flake update                  # all inputs
just check
git diff -- flake.lock
```

Stable updates within the existing branch do not advance to the next release. At stable-release migration time, research the currently supported branch, change **only** the stable URL, and review service migrations before updating its lock. `follows` consumers also move when their parent input moves: stable developer tools are intentionally affected by stable updates. Neither targeted update changes the other fleet track. See [operations](docs/operations.md#input-updates) for exact revision diffs and independent-update precautions.

## Validation and builds

```sh
just fmt       # modifies Nix formatting
just check     # canonical non-destructive pre-commit/CI/pre-deployment command
just build thinkpad  # after real facts + readiness approval
```

`just check` runs formatter check, static/dead-code analysis, ShellCheck, all host reports and independent track assertions, then `nix flake check`. Checks force real per-host package, `/etc` and initrd derivations; evaluate each exact capability composition and combined UEFI/BIOS fixtures; evaluate NixOS toplevels/deploy activators on both tracks; test disk rejection; and build upstream deploy schema/activation smoke checks. Fixtures are synthetic evaluation data, **never real fleet hardware**. Their NixOS systems are not built or booted by the normal checks. Actual deployment activation checks build full closures once hosts are enabled.

Expected bootstrap diagnostics: NixOS warns that unset `stateVersion` defaults to its release, and `fleet.failedAssertions` includes commissioning/access blockers. Such defaults are **not accepted for deployment**. Custom flake outputs produce benign “unknown flake output” warnings; their contents are explicitly validated by our checks. [Validation scope/results](docs/validation.md) distinguishes evaluation from runtime testing.

The GitHub workflow runs the same command on Linux without deployment credentials or deployment steps. **Stage new files with `git add` before evaluating**: Git flakes ignore untracked files even though local linters can see them.

## Deployment

Only `ready && deployment.enable` hosts enter `deploy.nodes`. Addresses/users are nullable placeholders, not invented DNS names. Desktops are deliberately excluded until explicitly opted in.

```sh
just ready racknerd
just deploy racknerd
# Subset (after just check and readiness checks):
deploy --targets .#racknerd .#bastion -- --no-update-lock-file
just deploy-fleet  # all currently eligible nodes, not all inventory entries
```

SSH port/user, activation user, sudo/doas, interactive sudo, timeouts, connection flags, remote builds and closure trust are host metadata. The system profile must activate as root; SSH login defaults to a supplied non-root admin with keys. No blanket `@wheel` Nix trust is granted. Choose root-equivalent `deployment.transport = "trusted-user"` or provision signing trust for `"signed"` explicitly.

Both automatic and magic rollback remain enabled. Never use rollback-disabling flags to “fix” an unreachable machine. [Operations](docs/operations.md#deployment-and-recovery) covers offline hosts, SSH-changing deployments, subset rollback, signing, and console recovery. Deploy-rs does not install an OS or manage data rollback.

## Disk provisioning and impermanence

**Disko can irreversibly erase disks. Nothing in `just check` runs it.** `just disk-plan HOST` only builds a script for inspection, after readiness preflight.

The optional baseline uses one confirmed **whole OS disk by-id**, GPT, an explicitly selected UEFI/BIOS boot mode, and Btrfs subvolumes for `/nix` and `/persist` (plus `/boot` for BIOS). UEFI requires an explicitly sized ESP and a reviewed `efiCanTouchVariables` choice: permit NVRAM writes, or verify firmware fallback boot. Btrfs is used only to share capacity without guessing a Nix/state partition split; there is no RAID, snapshot-rollback hook, LVM, ZFS, encryption or NAS formatting. Root is tmpfs with a configurable 25% memory ceiling, mounted by disko during installation and recreated on every boot. Root, `/nix` and `/persist` are `neededForBoot` with systemd initrd.

**For `bastion`, this layout owns only the OS disk. NAS data topology, mounts, shares and backup jobs are intentionally absent.** The OS disk list is closed with `mkForce`; extra ordinary disk definitions would be discarded, not provisioned. Do not extend it with valuable data disks. A different OS layout needs a separately reviewed capability. Read [the storage runbook](docs/bootstrap.md#storage-and-installation) before even preparing a destructive command.

Audit what survives:

```sh
nix eval --json .#fleet.bastion.persistence | jq .
```

Baseline: `/nix` (separate subvolume), machine ID, random seed, NixOS identity allocation state and systemd timer stamps. SSH adds its explicit host-key files. Servers add a bounded persistent journal; workstations persist `/home` and NetworkManager state. **Keeping all of `/home` is a deliberate user-data policy, not minimal application persistence.** `/persist` itself is durable; the inventory lists declared bind/symlink paths, not arbitrary files an operator has placed there. Removed declarations do not erase old backing data. Persistence is not a backup or encryption.

Add persisted state next to the service that owns it, for example in a new top-level feature:

```nix
{
  flake.modules.nixos.my-service = {
    environment.persistence."/persist".directories = [
      { directory = "/var/lib/my-service"; user = "my-service"; group = "my-service"; mode = "0700"; }
    ];
  };
}
```

This fragment also needs the real service/account definitions. Compose `my-service` on its hosts; evaluate both tracks and review first-install migration. Do not persist `/etc` or `/var` wholesale. Runtime secrets live outside the repository/Nix store; see [the secrets boundary](docs/bootstrap.md#access-and-secrets).

## Growing the fleet

**Add a host:** create a top-level module defining `fleet.hosts.<name>` with required architecture, explicit track and capability names. Supply independently reviewed fact modules, storage, persistence and deployment metadata. Add it to the independent track oracle in `modules/validation.nix`; do not copy another machine's hardware. Keep it unready until commissioning is complete.

**Add a capability:** create a discovered top-level module contributing a deferred NixOS value (or merge into a cohesive existing value). Use the lower-level `pkgs`/`lib`, not a direct input reference. A genuinely version-dependent API belongs in one documented compatibility branch, preferably probing available options as logging does. A module imported through multiple routes may need an explicit deduplication `key` (see SSH).

See `AGENTS.md` and the [agent skill index](.agents/skills/README.md) for step-by-step procedures.
