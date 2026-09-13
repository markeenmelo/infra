# ADR 0010 — Native devenv for local development

- Status: accepted; explicit operator tasks supersede the interim task-removal policy
- Date: 2026-09-12; amended 2026-09-13

## Decision

Root `devenv.nix`, `devenv.yaml` and `devenv.lock` are the sole development-only exception to the production `flake.nix`/top-level Nix-only `modules/` architecture. No production import, parallel devShell, self-lock bridge or third package track.

Tools use unstable and the unversioned upstream devenv source, pinned by locks. Native Nixpkgs matches production's unstable node exactly; OpenTofu/provider wrappers match the checked package. Preserve the CLI-version assertion, `stdenvNoCC`, explicit Nix and no evaluation-time secrets.

After removing the previous task graph, the operator explicitly requested three independent tasks:

- `host:create`: new untracked/unready host/hardware/disko scaffold, no overwrite, real facts or staging.
- `host:install`: exact public target/device/identity/plan-hash confirmation, reviewed private runtime staging, full local preflight, pinned live-installer SSH and fresh unmounted whole-device checks; prebuilt closures and only disko/install phases.
- `deploy:run`: exact host/group/mode confirmation, full local preflight/readiness/builds, installed dedicated-account access/trust checks, explicit ordered targets and retained automatic/magic rollback.

Bodies are read from `scripts/devenv/`; helpers/checks remain with their script concern. Inputs default to null, contain no credentials/private paths and reject unknown fields. No cache/status rules or DAG/lifecycle edges exist, so selecting a namespace or `--mode all` cannot silently couple installation, deployment and scaffolding. Invalid inputs still refuse each selected task. `devenv test` remains no repository gate.

The operator additionally selected `devenv shell -- install HOST` as the friendly interactive interface. Its script-backed Python guide uses a foreground terminal, prompts for unresolved verified facts/recovery paths, creates a private temporary manifest, opens the local disk plan and captures its hash internally. After the displayed scope and explicit `ERASE HOST` approval, it supplies the existing full-scope input to the same `host-install.sh` backend; no fourth task, skip flag, alternate transport or lifecycle operation is added. Normal coreutils install invocations forward to the pinned binary because `install` is also a standard file utility. Private paths remain child environment only; no new private input/configuration/profile is persisted.

The synchronous report-only `scripts/devenv/preflight.sh` is invoked explicitly by live workflows, not as an automatic repository task graph. The actual generated native task JSON is checked separately from production, which must never import devenv. Source-quality runs isolated workflow and ciphertext regressions; mocks never become real targets or installers.

## Consequences

No automatic formatting, hooks, secret loading, provider initialization, npm installation, deployment or enrollment on shell entry. Keep explicit formatter/scripts and the runtime SOPS → OpenTofu adapter. Private installer key/staging paths enter only the operator child environment; native transport copies them outside the Nix store without logging contents. Installation is intentionally separate from deployment and never performs kexec/reboot or copies installer host identities automatically.

Before any Nix bootstrap/evaluation, inspect ciphertext: a later check cannot undo a store copy. Full checks cannot prove device ownership, credentials, backups, remote builds or boot acceptance. Installed access-changing migrations need console/staged access, and Bastion remains boot-only until its transition is accepted. No task automatically deletes homes, identities, credentials or generations. Existing local hooks/settings remain operator state.

See [task usage](../../../devenv/references/development.md#operator-tasks), [deployment policy](0004-deployment-and-readiness.md), [research](../../../nix-research/references/research.md) and [validation](../../../validate/SKILL.md).
