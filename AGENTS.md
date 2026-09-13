# Agent instructions

This repository configures real machines and real storage. Read `README.md` and the matching [skill](.agents/skills/README.md) before editing. Skills hold the procedures; don't recreate them as `docs/` or explanatory code comments. Preserve shebangs, licenses and tool directives.

This file is the shared authority: Pi reads `AGENTS.md`, and root `CLAUDE.md` imports it for Claude Code. Canonical skills live in `.agents/skills/`, linked from `.claude/skills/`. Pi invokes `/skill:NAME`, Claude Code `/NAME`; read the file directly if discovery is unavailable. Run commands from the repository root.

Finding a skill is not authorization to run what it describes. Never add shell injection, tool preapproval, permission bypasses or hooks to make a harness work. Private settings, local memory and credentials stay out of tracked guidance.

## Non-negotiable safety

- Deployment, remote activation (including `--dry-activate`), installation, mounting, partitioning, formatting and data destruction each need explicit authorization for that operation in the current task. Local evaluation and builds authorize none of them.
- Never invent hardware, users, keys, endpoints, UUIDs, firmware, GPUs or NAS topology. Unknown facts stay typed nulls or blockers. Never set `ready`, `confirmed` or a `*Reviewed` flag, use `allowNoPasswordLogin`, or disable rollback just to make something pass.
- Bastion's OS disk is not its NAS data. No unknown disks, pools or shares, and no destructive migration. Verify backups, restore and device serials first.
- No plaintext secrets, password hashes or private keys in Git, Nix expressions or logs — only reviewed SOPS ciphertext and public recipients, per [secrets/README.md](secrets/README.md). A runtime path or public key proves neither decryption nor readiness. Nix trusted-user status and passwordless sudo are root-equivalent.

## Architecture

- `flake.nix` is the production entry point; root `devenv.nix` is the development-only exception and is never imported into production. Every other `.nix` file lives under `modules/` as a top-level flake-parts module, including tests and hardware facts. `modules/` is Nix only: executables and tests go in `scripts/<concern>/`, static data in `assets/<concern>/`.
- Capabilities are deferred, class-checked `flake.modules.nixos` / `flake.modules.homeManager` values, composed only in a matching evaluation. Per-host facts merge into `fleet.hosts.<name>.module`. No host import roots, no `common.nix`.
- Each host declares `system` and `track`. ThinkPad follows `nixpkgs-unstable`; servers follow the supported numbered stable branch. Generic code uses its own evaluation's `pkgs` and `lib` — no injected inputs, global overlays or importing both package sets.
- Track selection belongs in `modules/fleet.nix`, the independent track oracle in `modules/validation.nix`. `fleetConfigurations` evaluates everything; `nixosConfigurations` requires readiness; deploy outputs additionally require deployment intent.
- A concern owns its configuration, state, facts, scripts and checks together. Features contribute their own fixtures and checks; `modules/validation.nix` only assembles them. Fixtures never become real hosts or install targets, and their sentinel values never reach fleet facts.
- `devenv.nix` provides the toolbox, six scripts and exactly three tasks — `host:create`, `host:install`, `deploy:run` — uncached, null-default and independent of each other. Bodies live in `scripts/devenv/`. Its nixpkgs pin must match `flake.lock`.

## Workflow

1. Inspect the staged and unstaged diff. Research anything dependency-sensitive against upstream at the current pin before changing it.
2. Make the smallest coherent change using the existing typed boundaries. Leave facts, readiness, credentials and pins alone unless they are the task.
3. Run `bash scripts/secrets/check.sh` before staging encrypted files or evaluating tracked secrets. Stage only the reviewed new files — a Git flake ignores untracked ones. Never stage plaintext, private identities or unrelated work. Commit only when asked.
4. Validate per [devenv](.agents/skills/devenv/SKILL.md): the short documentation path, or formatting plus `bash scripts/devenv/preflight.sh` for anything substantive. Never run a live task as a test; `devenv test` is not a gate. Run the full sequence once on the final candidate, and always before deployment.
5. For each affected commissioned host, also run `devenv shell ready HOST` and `devenv shell build HOST`. These prove neither boot, credentials, networking, devices nor backups.
6. Review the whole diff and report exactly what passed, what failed and what is still unknown. A timeout or failure is not success.
