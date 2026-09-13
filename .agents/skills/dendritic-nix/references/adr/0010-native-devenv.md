# ADR 0010 — Native devenv for local development

- Status: accepted; task removal supersedes the former task-graph/live-task amendments
- Date: 2026-09-12; amended 2026-09-13

## Decision

Root `devenv.nix`, `devenv.yaml` and `devenv.lock` provide the native development CLI. This is the sole development-only exception to the production `flake.nix`/top-level `modules/` architecture. No host imports devenv, parallel devShell, local-self-lock bridge or third package track is introduced.

Developer tools use unstable and the unversioned `github:cachix/devenv` source, with revisions in locks. Native Nixpkgs must match the flake's unstable node, and native OpenTofu/provider selection must match the checked flake package. The CLI assertion enforces the selected package version; actual native execution establishes module compatibility. `stdenvNoCC` and explicit Nix support a clean shell without a default C compiler.

**2026-09-13 operator decision:** remove every repository-defined devenv task without replacing it yet. Remove the live deployment task, task inventory/graph contract, dependent fleet-deployment wrapper, test-entry gate, optional hook profile and native treefmt integration (which registers its own automatic task). Keep the toolbox and pre-existing independent scripts. Native devenv lifecycle tasks are not repository validation. `devenv test` is no longer a gate; [manual validation](../../../validate/SKILL.md) documents the interim checks, not a replacement runner.

No evaluation/shell/direnv secret loading, automatic formatting, deployment, enrollment, provider initialization or npm installation. Runtime operator SOPS delivery stays an explicit three-key JSON allowlist adapter into the existing guarded OpenTofu process. Credentials remain child-only runtime values; no additional secret provider or state resource is needed.

## Consequences

- Two locks remain intentionally. Remove only the now-unused direct treefmt input/node; preserve all retained revisions and the upstream git-hooks/transitive treefmt dependencies.
- Feature checks/scripts stay beside their owners. Ciphertext review before Git staging/flake evaluation, lock/tool parity and full local flake validation remain required manually; there is no task graph enforcing their order.
- Raw deploy-rs exposes no replacement preflight/confirmation wrapper. Operators must follow the [deployment skill](../../../deploy/SKILL.md), preserve signer verification, strict SSH, signatures, interactive sudo and rollback, and obtain current operation authorization.
- Existing locally installed hooks are operator state; deleting their profile does not uninstall them. No host facts, readiness, storage, credentials or runtime acceptance change.

See [development details](../../../devenv/references/development.md), [research](../../../nix-research/references/research.md) and [validation](../../../validate/SKILL.md).
