# Agent instructions

This repository configures real machines and real storage. Read `README.md` and the matching [skill](.agents/skills/README.md) before editing. Skills hold the procedures; don't recreate them as `docs/` or explanatory code comments.

This file is the shared authority: Pi reads `AGENTS.md`, and root `CLAUDE.md` imports it for Claude Code. Canonical skills live in `.agents/skills/`, linked from `.claude/skills/`. Pi invokes `/skill:NAME`, Claude Code `/NAME`; read the file directly if discovery is unavailable. Run commands from the repository root.

Finding a skill is not authorization to run what it describes. Never add shell injection, tool preapproval, permission bypasses or hooks to make a harness work. Private settings, local memory and credentials stay out of tracked guidance.

## Non-negotiable safety

- Deployment, remote activation (including `--dry-activate`), installation, mounting, partitioning, formatting and data destruction each need explicit authorization for that operation in the current task. Local evaluation and builds authorize none of them.
- Never invent hardware, users, keys, endpoints, UUIDs, firmware, GPUs or NAS topology. Unknown facts stay typed nulls or blockers. Never use `allowNoPasswordLogin` or disable rollback just to make something pass.
- Bastion's OS disk is not its NAS data. No unknown disks, pools or shares, and no destructive migration. Verify backups, restore and device serials first.
- No plaintext secrets, password hashes or private keys in Git, Nix expressions or logs — only reviewed SOPS ciphertext and public recipients, per [secrets/README.md](secrets/README.md). A runtime path or public key proves neither decryption nor readiness. Nix trusted-user status and passwordless sudo are root-equivalent.

## Architecture

- `flake.nix` is the production entry point; root `devenv.nix` is the development-only exception and is never imported into production. Every other `.nix` file lives under `modules/` as a top-level flake-parts module, including hardware facts. `modules/` is Nix only: static data goes in `assets/<concern>/`. There is no `scripts/` tree and no test suite — the repository is declarative configuration and nothing else.
- Capabilities are deferred, class-checked `flake.modules.nixos` / `flake.modules.homeManager` values, composed only in a matching evaluation. Per-host facts merge into `fleet.hosts.<name>.module`. No host import roots, no `common.nix`.
- Each host declares `system` and `track`. ThinkPad follows `nixpkgs-unstable`; servers follow the supported numbered stable branch. Generic code uses its own evaluation's `pkgs` and `lib` — no injected inputs, global overlays or importing both package sets.
- Track selection belongs in `modules/fleet.nix`. `fleetConfigurations` and `nixosConfigurations` always evaluate every host; deploy nodes require only `deployment.enable`.
- A concern owns its configuration, state and facts together. Nothing in the repository verifies them: there are no fixtures, no `fleet.validation`, no `flake.validation` report and no `perSystem.checks`.
- `devenv.nix` provides the locked toolbox and nothing else — no scripts, no tasks, no hooks. Its nixpkgs pin must match `flake.lock`.

## Workflow

1. Inspect the staged and unstaged diff. Research anything dependency-sensitive against upstream at the current pin before changing it.
2. Make the smallest coherent change using the existing typed boundaries. Leave facts, credentials and pins alone unless they are the task.
3. Read every encrypted file you touch before staging it — no automated ciphertext guard exists any more. Confirm by eye that each value is an `ENC[AES256_GCM,...]` payload and that the recipients match the matching `.sops.yaml` creation rule exactly. Stage only the reviewed new files — a Git flake ignores untracked ones. Never stage plaintext, private identities or unrelated work. Commit only when asked.
4. Validate per [devenv](.agents/skills/README.md): documentation-only changes need `git diff --check` and working links; anything substantive needs `nix fmt` and `nix flake check`. `nix flake check` now builds no checks — it only evaluates the flake outputs, so it proves evaluation and nothing more.
5. For each affected host run `nix eval --no-update-lock-file --json .#fleet.HOST` and `nix build --no-update-lock-file --no-link .#nixosConfigurations.HOST.config.system.build.toplevel`. These prove neither boot, credentials, networking, devices nor backups, and no longer prove policy either.
6. Review the whole diff and report exactly what passed, what failed and what is still unknown. A timeout or failure is not success.
