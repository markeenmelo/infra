# Agent instructions

This is infrastructure for real machines and valuable storage. Read `README.md` and the matching [.agents/skills/](.agents/skills/README.md) procedure before editing. Skills own operational guidance, architecture decisions, research and dated host evidence; do not recreate `docs/` or explanatory code comments. Preserve shebangs, licenses and tool directives.

## Non-negotiable safety

- No deployment, remote activation (including `--dry-activate`), installation, mount, partition, format, data destruction or generated disko execution without explicit authorization for that operation in the current task. Local evaluation/build checks authorize none of these.
- Never invent hardware, users/keys, endpoints, UUIDs, firmware, GPUs or NAS topology. Missing facts stay typed nulls/checklist blockers. Never set `ready`, `confirmed` or `*Reviewed` merely to pass validation, suppress assertions, use `allowNoPasswordLogin` or disable rollback to hide a broken setup.
- Bastion OS storage is **not** its NAS data. No unknown disks/pools/shares or destructive migration. Backups/restore and fresh device serial verification precede storage actions.
- No plaintext secrets/hashes/private keys in Git, Nix expressions, store inputs or logs. Only reviewed SOPS ciphertext/public recipients belong there; follow [secrets/README.md](secrets/README.md). Runtime paths/public keys do not prove decryption or readiness. Nix trusted-user and passwordless sudo privileges are root-equivalent.

## Architecture

- `flake.nix` is the production entry point. Root `devenv.nix` is the explicit development-only exception; never import it into production. All other `.nix` files live under `modules/` and are modules of the top-level flake-parts evaluation, including tests/adapted hardware. `modules/` contains only Nix files; executable sources/tests live in `scripts/<concern>/` and static data in `assets/<concern>/`. See [dendritic-nix](.agents/skills/dendritic-nix/SKILL.md) and its retained ADRs.
- Capabilities are deferred, class-checked `flake.modules.nixos` / `flake.modules.homeManager` values, composed only in their matching evaluation. Per-host facts merge into deferred `fleet.hosts.<name>.module`. No conventional host import roots, `common.nix` dumping ground or framework for this small fleet.
- Required explicit host metadata: `system`, `track`. ThinkPad uses `nixpkgs` on `nixpkgs-unstable`; servers use the supported numbered stable branch. Generic features consume their own lower `pkgs`/`lib`, without injected inputs, global overlays or importing both package sets.
- Production track selection belongs in `modules/fleet.nix`; independent required tracks in `modules/validation.nix`. Real API differences must be localized, researched and tested. `fleetConfigurations` evaluates all compositions; standard NixOS outputs require readiness, deploy outputs additionally require deployment intent.
- Each concern owns configuration, state, facts, scripts and checks across applicable classes. Contributions may deliberately share `desktop`; do not invent unused per-file capabilities. Desktop owns its HM bridge. Repeated lower imports may need a stable module `key` (SSH).
- Feature owners contribute capability-scoped synthetic fixture facts and checks. `modules/validation.nix` assembles fixtures and independent inventories, not feature test implementations. Fixtures never create real hosts or installer/deploy targets; never copy their device/key/review sentinels into fleet facts.
- Native devenv provides unstable developer tools; its Nixpkgs pin must match `flake.lock` and its OpenTofu/provider wrapper must match the checked package. **All repository-defined devenv tasks are removed; do not recreate them until requested.**

## Workflow

1. Inspect staged/unstaged changes. Research dependency-sensitive decisions with [nix-research](.agents/skills/nix-research/SKILL.md); record date, URL, pin and consequence in its research reference.
2. Make the smallest coherent change using existing typed boundaries. Keep facts, readiness, credentials and pins unchanged unless specifically in scope.
3. Stage only intended reviewed new files before Git-flake evaluation. Run the [manual ciphertext guard](.agents/skills/validate/references/ciphertext.md) before staging encrypted files/public rules or evaluating tracked secrets; never stage plaintext, private identities or unrelated work. Commit only when asked.
4. Follow [validate](.agents/skills/validate/SKILL.md): documentation-only whitespace/link/status/snippet checks, or manual formatting, static checks, ciphertext guard/regressions, lock/tool parity, fleet evaluation and full `nix flake check` for substantive changes. The removed task graph and `devenv test` are not gates. Run final full validation once for the coherent candidate; deployment preflight always needs it.
5. For each affected commissioned configuration/closure, also run `devenv shell ready HOST` and `devenv shell build HOST`. Prose-only follow-ups do not require rebuilding unchanged code. These checks prove neither boot, credentials, networking, devices nor backups.
6. Review the complete diff and report exactly what passed, failed or remains unknown. Applicable local checks must pass before handoff; a timeout/failure is not success. Keep procedures and dated evidence consistent without treating historical authorization as current permission.
