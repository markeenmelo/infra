# Agent instructions

This is infrastructure for real machines and valuable storage. Read `README.md`, the relevant ADR and the matching skill before editing. Pi supports the standard repository-local `.agents/skills/<name>/SKILL.md` layout (discovered after project trust); other agents may read those procedures directly. The [skill index](.agents/skills/README.md) lists them.

## Non-negotiable safety

- Do not deploy, remotely activate, install, mount, partition, format, destroy data or run generated disko scripts without explicit authorization for that operation in the current task. `--dry-activate` also contacts a target. `just check` is non-destructive.
- Never invent hardware facts, usernames/keys, network endpoints, UUIDs, firmware, GPUs or NAS topology. Incomplete values are typed nulls/checklist blockers, not plausible fake paths.
- Never set `ready`, `confirmed` or a `*Reviewed` flag just to pass validation. They record real review. Never suppress bootstrap/NixOS assertions, use `allowNoPasswordLogin`, or disable rollback to make a broken setup look usable.
- `bastion` OS storage is **not** its NAS data. No unknown data disks, pools, shares or destructive migration. Backups/restore and device serial verification precede any storage action.
- No plaintext secret contents/hashes or private keys in Git, Nix expressions, Nix store inputs or logs. Only reviewed SOPS ciphertext/public recipients belong in Git/store inputs; see `secrets/README.md`. Runtime paths/public keys do not prove decryption or credential readiness. Nix trusted-user and passwordless sudo access are root-equivalent.

## Architecture invariants

- `flake.nix` is the only Nix entry point. All other repository `.nix` files live under `modules/` and are modules of the **top-level flake-parts evaluation**, including tests and adapted hardware facts.
- Capabilities are deferred, class-checked `flake.modules.nixos` and `flake.modules.homeManager` values; compose each only in its matching evaluation. Per-host facts merge into `fleet.hosts.<name>.module` (also deferred). Paths name concerns; never add conventional host import roots, `common.nix` dumping grounds or a framework for this small fleet. Follow [dendritic-nix](.agents/skills/dendritic-nix/SKILL.md) for architecture and refactor work.
- Host `system` and `track` are required explicit metadata. `thinkpad` uses `nixpkgs-unstable`; `racknerd`/`bastion` use the supported numbered stable branch. Generic features use their own lower-level `pkgs`/`lib`, never arbitrary stable/unstable packages or injected flake inputs.
- Do not globally overlay or import both package sets. Input selection belongs in `modules/fleet.nix`; independently required tracks belong in `modules/validation.nix`. A legitimate API difference must be isolated, researched and tested (see logging).
- `fleetConfigurations` evaluates all compositions. Only explicitly ready hosts appear in `nixosConfigurations`; only ready + deployment-enabled hosts appear in deploy-rs. Preserve this bootstrap distinction.
- Module fixtures are explicitly synthetic evaluation-only data. Never copy their sentinel device/key/review flags into a fleet host. Do not expose their scripts as install/deploy targets.
- Each top-level module owns one concern across applicable classes, facts, state and checks. Contributions may share a deliberate destination (the `desktop` bundle); do not confuse that with an omnibus file or require unused per-file capabilities. The desktop concern owns its HM bridge, not the fleet evaluator. Repeated lower-level import paths may need a stable module `key` to prevent duplicated lists (SSH is the example).
- Feature owners contribute checks, capability-scoped synthetic fixture facts and developer tools. `modules/validation.nix` assembles fixtures and independent inventories, not feature test implementations. Keep independent track/rollout oracles independent from production choices; no fixture contribution may create a real host.

## Workflow

1. Research dependency-sensitive code using `nix-research`; record consequential findings in `docs/research.md` with date, URL, pin and consequence.
2. Make the smallest coherent change. Use existing typed abstractions; avoid unnecessary dependencies or package mixing.
3. Stage intended new files before evaluation: Git flakes ignore untracked files. Do not stage plaintext credentials, private identities or unrelated user work; run `just secret-check` before staging intended encrypted SOPS files. Do not make a Git commit unless asked.
4. Choose validation by the actual diff: **documentation-only** edits use [whitespace, link/status and changed-snippet checks](docs/validation.md#documentation-only-changes), not fleet evaluation/builds. For code, configuration, dependencies, tests or ciphertext changes, enter `nix develop --no-update-lock-file`; run `just fmt`, then **`just check`** once for the final coherent candidate. Deployment preflight still requires full checks.
5. When a commissioned host's configuration/closure is affected, also run `just ready HOST` and `just build HOST`; prose-only follow-ups do not require rebuilding it. These are not authorization to deploy. Pure checks do not verify devices, credentials, networking, hardware boot or backups.
6. Review the diff and report exactly what ran, what failed, and what remains unknown. Never call evaluation-only fixtures a tested installation. Document architectural changes and keep procedures in sync.

Current known expected bootstrap diagnostics are documented in `docs/validation.md`. Do not dismiss other warnings/errors as placeholders. The applicable validation path must pass before handoff; completed code still requires the canonical checks.
