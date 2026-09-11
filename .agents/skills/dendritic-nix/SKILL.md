---
name: dendritic-nix
description: Plan, review or carry out a dendritic Nix refactor of this fleet using feature-oriented flake-parts modules. Use for flake architecture, aspect composition, NixOS/Home Manager boundaries, shared values, module discovery or splitting growing features. Not for general Nix syntax or standalone package recipes.
---

# Dendritic Nix

## Purpose / when

Keep one top-level module system and organize by responsibility, not configuration class. Use this architectural guide with `add-feature` or `add-host`; it does not replace their implementation and safety procedures.

This is a repository-specific adaptation of the reviewed `sebnow/configs` skill, not an upstream scaffold installation. [Source, pin and deliberate differences](../../../docs/research.md#dendritic-skill-alignment--2026-09-11) are recorded separately.

## Prerequisites

Read `../../../AGENTS.md`, `../../../docs/adr/0001-dendritic-composition.md`, `../../../flake.nix`, `../../../modules/fleet.nix` and the affected feature/consumers. For Home Manager, also read `../../../modules/desktop/hyprland.nix` and `../../../docs/adr/0008-native-desktop-and-kernels.md`. Use `nix-research` before relying on new upstream options or dependencies.

## Procedure

1. **Trace the evaluation boundary.** `flake.nix` already imports `inputs.flake-parts.flakeModules.modules` and discovers `modules/`. That extra supplies class-checked deferred values; do not add a second scaffold or registration. `modules/fleet.nix` already selects the host track and constructs configurations through the typed `fleet.hosts` schema.
2. **Choose the concern, then its classes.** Each repository `.nix` file except `flake.nix` is a top-level flake-parts module under `modules/`. Keep a feature's NixOS and Home Manager contributions together when both apply: `flake.modules.nixos.<capability>` and `flake.modules.homeManager.<capability>`. Extend existing cohesive values rather than naming every file as a new capability. Host-specific facts contribute to `fleet.hosts.<name>.module`. Do not split the same concern into `nixos/` and `home-manager/` trees.
3. **Share values at the right level.** Use a lexical `let` within a file; reuse or declare a typed top-level option for a genuine cross-file shared value. Top-level `config` is flake-parts configuration, not NixOS or Home Manager configuration. Lower deferred values can be functions receiving their own `config`, `lib` and `pkgs`; capture outer values before shadowing `config`, or name the lower arguments `nixosArgs`/`hmArgs`. Never inject inputs/self/package sets through `specialArgs` or `extraSpecialArgs`, nor use `inputs.self` to reference local aspects; use top-level `config.flake.modules`.
4. **Wire the actual consumer.** Defining a deferred module does not enable it. NixOS consumers select names through `fleet.hosts.<name>.capabilities`, or import matching-class values through a top-level closure. Home Manager values belong in HM imports, not the NixOS capability list. The existing desktop bridge imports `config.flake.modules.homeManager.hyprland` through `home-manager.sharedModules`; contributions to that value need no extra host entry. A genuinely separate HM capability needs explicit matching-class composition for the intended users. Keep imports independent of the lower configuration being constructed; condition option definitions instead.
5. **Split by sub-concern, not module class.** A growing feature can have several independently discovered top-level files contributing to the same deferred value, as `modules/desktop/` does. Do not manually import those files again or introduce a raw lower-level repository module. Preserve relative asset references when moving files. Trace every import route before changing module identity; a deferred module reached through multiple routes may need a stable `key`, as in `modules/ssh.nix`, to prevent duplicated lists.

## Refactor workflow

1. **Separate structure from behavior.** Identify the concern, affected consumers and intended file/module boundary. A refactor preserves policy unless a behavior change is explicitly in scope. Do not combine moves with input updates, new applications, changed defaults or commissioning decisions.
2. **Record the baseline.** Review staged/unstaged changes and record the starting commit and pins without overwriting user work. Capture affected hosts' track/readiness/output eligibility, relevant evaluated settings and generated configuration or derivation identities. Include persistence/mount and access policy when touched. Use read-only local evaluation, never secret contents or target contact, to obtain comparison evidence.
3. **Move one concern at a time.** Preserve the deferred capability interface and intended consumers while moving or splitting top-level contributions. Update relative asset references and test paths together. Trace all import routes, lexical closures and stable module keys; a rename must not silently duplicate state declarations or disconnect a feature. Do not introduce a generic abstraction solely to make the tree uniform.
4. **Compare before expanding scope.** Run targeted evaluation/checks for the changed composition and compare the baseline values and relevant generated configuration. Investigate changed derivations; a path move can affect source inputs, so neither ignore differences nor promise every store path remains identical. Stop on unexpected package-source, access, persistence, readiness or output-eligibility changes. Test reusable infrastructure on both tracks and desktop behavior only on its supported track.
5. **Finish a coherent candidate.** Review the complete diff, update affected navigation/procedures and follow `validate` for final canonical checks plus affected commissioned-host readiness/builds. Each independently handed-off refactor candidate needs its applicable checks; targeted intermediate probes do not replace them. Keep activation, deployment and runtime acceptance separately authorized.

## Repository-specific boundaries

- The local traversal imports every regular `.nix` file under `modules/`, including `_`-prefixed paths and `default.nix`; neither naming convention disables a file. It ignores non-Nix assets and does not follow symlinks. Do not copy the reference's `_lang`/`_experiments.nix` exclusion pattern or ban existing JSON/script/assets beside their owning concern.
- Keep `flake.nix` as inputs plus top-level setup/discovery. Its existing traversal is the auto-import equivalent; no `import-tree`, `flake-file`, framework or generated flake is needed. Do not replace it with manual per-feature imports.
- Preserve `fleet.hosts`, required `system`/`track`, `fleetConfigurations` and readiness/deployment filtering. The reference's `configurations.nixos` schema and unconditional toplevel-check example are not replacements for commissioning gates.
- Home Manager is nested in the unstable-only `hyprland` composition and uses the host's packages. Do not add standalone HM/Darwin outputs, stable HM or another package set just to mirror an example. `perSystem.pkgs` is for that output evaluation, not a source of ordinary host packages.
- The ban on custom argument forwarding does not remove upstream Home Manager's native `extraSpecialArgs.nixosConfig` context. Preserve that integration and its regression assertion; do not force all extra arguments empty.

## Existing examples

| Task | Reuse |
|---|---|
| Extend desktop terminal/shell settings | `../../../modules/desktop/terminal.nix` contributes to the existing HM `hyprland` value |
| Keep system integration and user configuration together | `../../../modules/desktop/bitwarden.nix` contributes to both classes in one file |
| Add another contribution without a new host entry | `../../../modules/logging.nix` extends NixOS `persistence` |
| Diagnose a feature with no effect | Trace `../../../modules/machines/thinkpad.nix` through `../../../modules/fleet.nix` and the desktop HM bridge |

## Validation / completion

Follow [validate](../validate/SKILL.md) for the actual diff. Architecture/code changes require canonical checks and affected commissioned-host readiness/builds; editing this guide alone uses documentation-only checks. Inspect exact consumer compositions, class boundaries, package sources and duplicate imports; retain both-track infrastructure and supported-track desktop coverage. Report runtime acceptance separately.

## Common failures / safety

Missing modules extra, outer/inner `config` confusion, an unconsumed aspect, HM imported as NixOS, config-dependent import recursion, duplicate deferred imports, or assuming `_` hides a file. Fix the boundary instead of bypassing assertions. No architectural refactor authorizes activation, secret access, storage operations or changing real review/readiness facts.
