# ADR 0010 — Native devenv for local development

- Status: accepted; native CLI explicitly selected by the operator; gate layering, native treefmt and script consolidation amended by the [2026-09-12 amendment](#gate-layering-treefmt-and-consolidation-amendment--2026-09-12)
- Date: 2026-09-12
- Amends ADR 0001's single-entry-point rule, ADR 0002's library/tooling track and input names, and ADR 0009's developer-tooling procedure

## Decision

Use root `devenv.nix`, `devenv.yaml` and `devenv.lock` for the **native** CLI, replacing `mkShellNoCC`, `perSystem.devPackages` and `justfile`. This is a deliberate development-only exception: `flake.nix` remains the production entry point, all files under `modules/` remain top-level flake-parts modules, and no host imports devenv. Do not introduce another host evaluation, third package track or local-flake/self-lock bridge merely to share developer package declarations.

Native devenv assembles the small toolbox and task graph. Feature-owned operator scripts, packages and flake checks remain beside their owners. `nix run --no-update-lock-file .#devenv -- shell` bootstraps the CLI without an installation or a parallel devShell. The operator selected **unstable developer tools** and unversioned `github:cachix/devenv`; exact source revisions live in locks. Rename the production unstable input to default `nixpkgs`, with flake-parts, Home Manager and Zen following it; retain explicit `nixpkgs-stable` and host `stable`/`unstable` metadata. Keep native Nixpkgs locked to the same source as the flake's unstable tools. A repository assertion selects the locked CLI; native checks establish module/task compatibility and exact OpenTofu/provider wrapper parity. Every pre-existing production source revision/hash is preserved; only aliases/follows change. `deploy-rs` and `sops-nix` stay production inputs because their activation helpers and NixOS modules are consumed by the fleet; devenv exposes their command-line tools.

`repo:check` retains ciphertext-first evaluation, format/lint checks and full `nix flake check`, plus the native task/lock/tooling contract. Safety gates have no status/file-change caches. `devenv test` runs this same gate; it does not launch services. Argument-taking, interactive and credential-bearing operations are scripts rather than tasks, so task namespace expansion cannot deploy or operate OpenTofu. Preserve readiness, existing-installation disk-plan refusal, deploy rollback, tailnet binding, provider isolation, encryption and exact apply confirmation.

Use existing SOPS plus a small runtime-only JSON allowlist adapter for operator credentials. `tailnet-sops ENCRYPTED.yaml OPERATION` loads exactly the OAuth ID, OAuth secret and existing state passphrase into the guarded OpenTofu process. Never evaluate decrypted values, export them into the development shell, source decrypted shell text or put them in task output/cache files. No OpenTofu SOPS data source, SecretSpec evaluation-time loading, credential generation, new recipients or ciphertext migration is needed. Host SOPS delivery remains unchanged. Real credential preparation and all API/state operations remain separately authorized.

## Gate layering, treefmt and consolidation amendment — 2026-09-12

The single canonical gate split into two layers after long full-gate run times degraded the iteration experience. **`repo:check`** is now the fast inner gate — the native task/lock/tooling contract, one treefmt format check, report-only statix, the ciphertext guard and the whole-fleet inventory, completing in seconds. **`repo:check-full`** is the canonical gate for final candidates, deployment preflight and `devenv test`: it closes over every fast-gate dependency plus the full evaluation oracle (`repo:evaluate`), the ciphertext regression suite and `nix flake check -L`. The ciphertext-before-evaluation ordering, uncached safety gates and the no-deployment task boundary are unchanged and remain contract-pinned.

The native treefmt integration is adopted in the same idiom-alignment spirit as the discovery input: `devenv.yaml` pins `treefmt-nix` following `nixpkgs`, and one declaration formats Nix (nixfmt), removes dead bindings (deadnix), applies ShellCheck (including `.envrc`) and runs OpenTofu fmt. Report-only statix stays a separate `repo:lint` task because treefmt can only run statix's fixing mode. devenv's own `devenv:treefmt:run` task is detached from shell entry — formatting remains an explicitly invoked operation, and the task contract guards that detachment.

The repository-owned glue scripts were folded into the task graph they serve: the ciphertext guard and its eleven malformed-input regressions (formerly `modules/secrets/check-secrets.sh` and `test-secret-check.sh`) live once in `devenv.nix` and are shared by `repo:secret-check`, `repo:secret-check-tests` and the opt-in Git hook; the native task contract (formerly `modules/tooling/check-devenv.py`) is an inlined jq program in `repo:tooling-check`. `checks.secret-files` was removed; feature-owned flake checks, runtime assets, operator scripts and the independent inventories (eight reports, 22 built checks) remain beside their owners.

Finally, the evaluation oracle's rejection regressions force the `config.assertion` booleans instead of whole `system.build.toplevel` derivations, and the ESP-size loop evaluates one representative per rejection class at the applied option, keeping accepted boundary checks on real disko scripts. The NixOS toplevel throws exactly when an assertion is false, so every former rejection property is preserved while the oracle evaluation time roughly halves.

## Other integrations

The native OpenTofu language module provides the locked provider wrapper and `tofu-ls`. The shell also exposes the existing Python checks, Nix formatter/linters and Nix/Bash language servers. The optional `hooks` profile adds local git-hooks checks; ordinary shell entry installs no hooks. `.envrc` uses the installed CLI's native direnv integration, without downloading shell code. No application services, databases, containers or automatic npm installation are justified for this infrastructure repository.

## Consequences

Two lock files now exist intentionally. Unstable updates must synchronize their Nixpkgs node; native module/hook updates remain separate from production input updates. Unstable tooling advances OpenTofu/provider versions and the offline artifact checksum; existing live state has not been opened or migrated, and old saved plans require separate review/regeneration. No real readiness, hardware, storage, credential or deployment fact changes. Native shell/task execution and canonical flake checks are required; evaluation-only or mocked secret tests do not establish real decryption, installation or deployment.

See [development commands](../development.md), [pinned research](../research.md#native-devenv--2026-09-12) and [validation](../validation.md).
