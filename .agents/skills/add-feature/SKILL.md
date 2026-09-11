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

1. State one responsibility and identify consumers. Prefer extending a cohesive existing deferred value over proliferating names; logging contributes to persistence without another host import entry.
2. Extend an existing concern or add a `.nix` file under `modules/` as a **top-level flake-parts module**. Define/merge `flake.modules.nixos.<capability>` and/or `flake.modules.homeManager.<capability>`, or contribute `fleet.hosts.<name>.module` for facts. Keep applicable classes beside each other, not in class-specific trees. Lower code stays inside deferred values; shared `let` bindings or typed top-level options replace custom argument forwarding.
3. For NixOS, select the name in `fleet.hosts.<name>.capabilities` or import a matching-class value through top-level `config.flake.modules`, not `inputs.self`. For Home Manager, use the existing desktop bridge: contributions to `flake.modules.homeManager.hyprland` already reach `home-manager.sharedModules`; a separate HM capability needs an explicit HM import. Never put an HM value in the NixOS list, add HM to headless/stable hosts, or forward inputs/package sets through `specialArgs`/`extraSpecialArgs`.
4. Importing a capability should normally enable it. Add typed options for real choices or safety requirements, not reflexive enable toggles. Use clear assertions/blockers for invalid states. A lower module reachable through multiple composition routes may require a stable `key`, as SSH does, to deduplicate list contributions.
5. Keep the service, its persisted state/ownership, checks and developer/output integration together when they serve the same concern. Do not put unrelated configuration into base/common/misc. Use the lower evaluation's `pkgs` and `lib` for all ordinary packages.
6. For a genuine stable/unstable API difference, inspect pinned options/source on **both** tracks. Prefer one localized option-availability branch (see logging). Explain when to remove it and record evidence in `docs/research.md`. Never solve compatibility by globally importing both package sets. A package exception needs a separate narrow, reviewed design.
7. Add evaluation assertions/tests in the discovered validation module or a cohesive top-level test contribution. Exercise reusable infrastructure on both tracks; deliberately track-restricted native desktop APIs need supported-track checks and explicit rejection of unsupported composition. Include negative tests for safety constraints. Keep synthetic hardware strictly within evaluation fixtures, never real host outputs.
8. Stage new files, `just fmt`, `just check`. Build affected commissioned hosts separately. Review persistence migration, runtime secrets, required mounts and recovery before any later activation.
9. Update README navigation, relevant ADR/research and procedures when the abstraction changes. Remove redundant code instead of adding compatibility layers without users.

## Commands

From repository root: `nix develop --no-update-lock-file`, `just fmt`, `just check`, `nix eval --json .#validation`. For a commissioned consumer: `just ready HOST`, `just build HOST`.

## Safety / completion

No new implicit credentials, root privilege, services, firewall exposure or data formatting. Completion means both-track checks pass, consumers opt in intentionally, generic code remains track-agnostic, and migration/runtime limitations are documented. Evaluation is not a boot or application test.

## Common failures

Wrong module class, an unconsumed HM capability, outer/inner `config` confusion, lower-module files accidentally discovered at the top level (including `_` paths), recursive config-dependent imports, duplicate anonymous deferred imports, stale upstream options and unrelated package-channel injection. Inspect the module graph and pinned API; do not disable checks to hide them.
