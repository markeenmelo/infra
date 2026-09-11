# NixOS fleet

A small dendritic flake for four **already-installed** `x86_64-linux` hosts. This branch proposes a secure baseline plus a **new Hyprland/Noctalia desktop on ThinkPad**, not a reinstall. The other hosts remain headless. Read-only discovery and transition gates are in [docs/hosts.md](docs/hosts.md); new desktop defaults and acceptance are in [docs/desktop.md](docs/desktop.md).

**ThinkPad is commissioned and local-only. Its maintenance generation is deployed and booted, but limited runtime review exposed a cold-start output-policy race; the branch contains an unactivated fix and maintenance acceptance remains incomplete. Racknerd has a ready evaluation candidate, but remote deployment of racknerd, bastion and dino did not complete and is intentionally deferred to another branch/time; a reinstall of those three hosts is likely.** Only ready hosts enter `nixosConfigurations`; deploy outputs require readiness plus enabled deployment intent.

| Host | Baseline beyond SSH, access, disko existing mounts, tmpfs root and impermanence | Nixpkgs | Deploy-rs intent |
|---|---|---|---|
| `thinkpad` | Hyprland/Noctalia/Greeter, desktop-only HM, Ghostty/Zen and approved apps, fingerprint fallback, SOPS Wi-Fi, laptop power/thermald, reviewed Thunderbolt authorization; preserve LUKS/LVM/swap and `/home` | `nixpkgs-unstable` | local-only |
| `racknerd` | server hardening, nftables, persistent journal, SSH fail2ban, observed KVM/network configuration | numbered stable | `marcos@72.11.150.242`, after commissioning |
| `bastion` | server hardening, nftables, persistent journal; preserve existing ZFS `tank` legacy data mounts separately from OS persistence | numbered stable | `marcos@192.168.2.2`, after commissioning |
| `dino` | NetworkManager, laptop power management; preserve `/home`, `marcos`/`ian`, existing tmpfs root and zram | `nixpkgs-unstable` | `marcos@192.168.20.2`, after commissioning; may be offline |

All four target **Limine** (racknerd BIOS; others UEFI). Headless means no desktop, **not** removal of consoles/emergency recovery. Tailscale auth-key enrollment is enabled **only in ThinkPad's unactivated candidate**; the other three hosts remain disabled; see [the Tailscale procedure](docs/tailscale.md). The operator reports successful OpenTofu application of the policy allowing only ThinkPad → the other three hosts on TCP 22 and ICMP, denying all other tailnet peer access including family devices. DNS was excluded from the reviewed change; the operator subsequently confirmed no-drift verification, independent recovery access and checked protected backups. ThinkPad enrollment preparation now preserves its retained backing state after operator-reported control-plane node deletion; the operator has supplied the exact-tag SOPS auth key and confirmed a recoverable host-state backup. Runtime enrollment still needs separately authorized activation. Gaming applications/drivers beyond ordinary hardware support, reverse proxy, shares and other applications remain deferred. The Samsung display was later observed on `DP-3` with qualifying HDR metadata, but eGPU/GPU topology remains unverified and no NVIDIA driver is selected. The deployed maintenance boot exposed a startup race before the intended docked HDR/lid policy was applied; its fix still needs runtime acceptance. Requested application preferences are deliberately reused without copying private profiles or credentials. Dino's original stateVersion and EFI policy remain unknown, and its boot filesystem needs review.

Servers use a supported numbered stable NixOS branch. Laptops use **`nixpkgs-unstable`**, not `nixos-unstable`, for future interactive/gaming software; its different Hydra gating warrants validation before upgrades. There is no package-channel mixing. The explicit [stock 7.x kernel policy](docs/desktop.md#kernels-and-intel-driver) selects each track's latest locked kernel (7.2.4 on both tracks after the current refresh), with ZFS compatibility and major-version guards. Branch selections are in `flake.nix`; pins and dated API evidence are in [research](docs/research.md).

## Start here

Requires Nix with `nix-command` and `flakes`; developed with Nix 2.34.8.

```sh
nix develop --no-update-lock-file
just inventory
just check
just ready racknerd  # build-readiness candidate; remote deployment remains deferred
```

The locked development shell supplies official nixfmt/nixfmt-tree, statix, deadnix, just, jq, SOPS, age, yq, Git, OpenSSH, ShellCheck and source-matched deploy-rs. Entry performs no deployment, secret retrieval or disk action. **Stage intended new files before evaluation:** Git flakes ignore untracked files. Only reviewed encrypted SOPS files/public recipients may be staged; never plaintext credentials, private identities or unrelated work.

## Preservation, not provisioning

Each host composes `existing-storage`: disko `nodev` descriptions derive mounts for existing UUIDs or the existing LVM mapper. All disk/GPT/LVM-create/ZFS-create collections are closed; disko scripts and image/install-test outputs are rejected even after readiness. **`just disk-plan HOST` is unavailable for these installations.** This is a runtime mount description, not an installer layout.

- `/` becomes tmpfs on thinkpad/racknerd/bastion; dino already uses it. No old Btrfs root-reset/deletion script is retained. Existing root subvolumes are not erased.
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

Target policy: `marcos`, the explicitly selected existing public key, authenticated sudo with password fallback (ThinkPad additionally permits fingerprint), immutable users, locked root, no root/password SSH. **SOPS delivers password hashes from ciphertext before account creation** using `neededForUsers` and a dedicated persistent age identity. ThinkPad and Racknerd use their reviewed ciphertext bindings; Bastion and Dino retain null credential/identity blockers. No keys or passwords were generated or rotated during this preflight. An authorized operator-run ThinkPad audit privately verified SOPS decryption/MACs and existing password/PSK bindings; its filled campus file is now selected. All six ThinkPad commissioning reviews are recorded (private/read-only audits, operator-confirmed recovery and the chosen migration stance). ThinkPad's earlier [two-boot acceptance](docs/hosts.md#first-boot-acceptance-2026-09-10-utc) is recorded; the later maintenance candidate still needs separately authorized runtime acceptance. Bastion and Dino's reviews remain open; Racknerd's candidate reviews are recorded, but its remote deployment did not complete. Dino also retains `ian` without wheel rights. See [secret inventory and procedure](secrets/README.md), [partial ThinkPad preflight](docs/hosts.md#partial-commissioning-preflight-2026-09-10-utc) and [ADR 0006](docs/adr/0006-sops-password-delivery.md).

Racknerd has a **ready evaluation candidate**: an [authorized access bootstrap](docs/hosts.md#authorized-access-bootstrap-and-sops-preparation) provided marcos key login and password sudo, its dedicated SOPS identity delivers the reviewed password hash, and all six commissioning reviews are recorded with `trusted-user` closure transport. The operator reports that deployment of racknerd, bastion and dino did not complete; this branch does not retry it. Remote deployment is deferred to another branch/time, and reinstalling those three hosts is likely. Bastion still has **root-only SSH** and needs a separately authorized staged transition. Also verify networking without the existing VPN before removing it. [The transition checklist](docs/hosts.md#access-and-state-migration-checklist--no-execution-authorized) details these requirements.

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
- `modules/hardware/`, `modules/networking/`, `modules/access/`: observed facts and deliberate target choices.
- `modules/storage/existing.nix`, host storage/data modules: existing-installation mount/boot boundary.
- `modules/{headless,ssh,access,secrets,server,vps,workstation,laptop}.nix`: cohesive reusable features; `logging.nix` contributes to persistence.
- `modules/desktop/`: native Hyprland/Noctalia/Greeter, approved apps, fingerprint and private Wi-Fi; ThinkPad-only facts.
- `modules/kernel.nix`: explicit host-track latest stock 7.x policy, without suppressing ZFS compatibility failures.
- `modules/tailscale/`, `tofu/tailscale/`: review-gated client enrollment/persistence (ThinkPad candidate enabled) plus separate OpenTofu policy/MagicDNS management. `just tailscale-inventory` shows rollout blockers; `just tailnet` is an explicit operator workflow, never part of rebuild/check.
- `modules/deployment.nix`: metadata, SSH integration, target-track activation and upstream checks.
- `modules/{tooling,validation}.nix`: locked shell, source checks, both-track safety/composition fixtures.

Each host's explicit `track` selects exactly one input's `lib.nixosSystem` in `modules/fleet.nix`. NixOS instantiates its own `pkgs`; generic features use that evaluation's `pkgs`/`lib`. Home Manager is imported at that boundary only for the unstable desktop, using the host's packages; headless hosts have no HM integration. The `home-manager` and `zen-browser` inputs use default-branch URLs and follow unstable, with their revisions recorded only in `flake.lock`. Zen's recipe is still instantiated with the host's `pkgs`, not its upstream package outputs. Validation independently checks required tracks, actual package-source paths, locked branch names and Home Manager branch/follows policy. See [ADRs](docs/adr/0001-dendritic-composition.md).

## Validation and updates

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
