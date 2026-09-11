---
name: add-feature
description: Add or extend a cohesive dendritic capability across NixOS, Home Manager, persistence, tooling and checks while keeping host package tracks isolated.
---

# Add a feature

## Purpose / when

Represent a cohesive capability reused by hosts or spanning configuration classes. A one-host hardware fact is usually a contribution to that host's deferred module, not a new generic layer.

## Prerequisites

Read `../../../AGENTS.md`, [dendritic-nix](../dendritic-nix/SKILL.md), `../../../modules/logging.nix`, `../../../modules/ssh.nix` and the affected host compositions. The architecture skill covers scaffolding, config scopes, safe splitting and refactor baselines. Use `nix-research` before choosing new module options or dependencies.

## Procedure

1. State one responsibility and identify consumers before choosing a file or deferred destination. Prefer a cohesive existing destination when consumers match; use separate values when independent selection/reuse is real. Logging contributes to persistence without another host import entry. Do not confuse sharing a destination with permission to combine unrelated concerns in one file.
2. Extend an existing concern or add a `.nix` file under `modules/` as a **top-level flake-parts module**. Define/merge `flake.modules.nixos.<capability>` and/or `flake.modules.homeManager.<capability>`, or contribute `fleet.hosts.<name>.module` for facts. Keep applicable classes beside each other, not in class-specific trees. Lower code stays inside deferred values; shared `let` bindings or typed top-level options replace custom argument forwarding.
3. For NixOS, select the name in `fleet.hosts.<name>.capabilities` or import a matching-class value through top-level `config.flake.modules`, not `inputs.self`. For Home Manager, use the concern-owned bridge in `modules/desktop.nix`: contributions to `flake.modules.homeManager.desktop` already reach `home-manager.sharedModules`; a separate HM capability needs an explicit HM import. Never put an HM value in the NixOS list, add HM to headless/stable hosts, or forward inputs/package sets through `specialArgs`/`extraSpecialArgs`.
4. Importing a capability should normally enable it. Add typed options for real choices or safety requirements, not reflexive enable toggles. Use clear assertions/blockers for invalid states. A lower module reachable through multiple composition routes may require a stable `key`, as SSH does, to deduplicate list contributions.
5. Keep the service, its persisted state/ownership, host-specific policy, scripts, checks and developer/output integration together or adjacent by concern. Do not put unrelated configuration into base/common/misc or hardware facts. Use the lower evaluation's `pkgs` and `lib` for ordinary packages; contribute developer tools through `perSystem.devPackages`, never from host package sets.
6. For a genuine stable/unstable API difference, inspect pinned options/source on **both** tracks. Prefer one localized option-availability branch (see logging). Explain when to remove it and record evidence in `docs/research.md`. Never solve compatibility by globally importing both package sets. A package exception needs a separate narrow, reviewed design.
7. Add owner-local assertions/tests, not feature implementations in the shared validation harness. Use `fleet.validation.fixtureModules.<capability>` for synthetic facts scoped to an actually selected capability; `hostChecks`, `flake.validation` and `perSystem.checks` retain the existing report/check interfaces. Deliberately update independent inventories when adding/removing a gate. Exercise reusable infrastructure on both tracks, restricted desktop on its supported track plus rejection cases. Fixtures never become real host outputs or commissioning facts.
8. Stage new files, `just fmt`, `just check`. Build affected commissioned hosts separately. Review persistence migration, runtime secrets, required mounts and recovery before any later activation.
9. Update README navigation, relevant ADR/research and procedures when the abstraction changes. Remove redundant code instead of adding compatibility layers without users.

## Commands

From repository root: `nix develop --no-update-lock-file`, `just fmt`, `just check`, `nix eval --json .#validation`. For a commissioned consumer: `just ready HOST`, `just build HOST`.

## Safety / completion

No new implicit credentials, root privilege, services, firewall exposure or data formatting. Completion means both-track checks pass, consumers opt in intentionally, generic code remains track-agnostic, and migration/runtime limitations are documented. Evaluation is not a boot or application test.

## Common failures

Wrong module class, an unconsumed HM capability, outer/inner `config` confusion, lower-module files accidentally discovered at the top level (including `_` paths), recursive config-dependent imports, duplicate anonymous deferred imports, stale upstream options and unrelated package-channel injection. Inspect the module graph and pinned API; do not disable checks to hide them.
