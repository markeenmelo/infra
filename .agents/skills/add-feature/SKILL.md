---
name: add-feature
description: Add or extend a reusable dendritic capability across NixOS modules, persistence, tooling and checks while keeping host package tracks isolated.
---

# Add a feature

## Purpose / when

Represent a cohesive capability reused by hosts or spanning configuration classes. A one-host hardware fact is usually a contribution to that host's deferred module, not a new generic layer.

## Prerequisites

Read `../../../AGENTS.md`, `../../../docs/adr/0001-dendritic-composition.md`, `../../../modules/logging.nix`, `../../../modules/ssh.nix` and the affected host compositions. Use `nix-research` before choosing new module options or dependencies.

## Procedure

1. State one responsibility and identify consumers. Prefer extending a cohesive existing deferred value over proliferating names; logging contributes to persistence without another host import entry.
2. Add a `.nix` file under `modules/` as a **top-level flake-parts module**. Define/merge `flake.modules.nixos.<capability>` or contribute `fleet.hosts.<name>.module` for facts. Keep lower NixOS code inside those values, not in a conventional imported repository module file.
3. Compose by adding the capability name to appropriate `fleet.hosts.<name>.capabilities`, or import an existing deferred value by top-level `config` closure. Do not pass inputs/self/package sets through `specialArgs`.
4. Importing a capability should normally enable it. Add typed options for real choices or safety requirements, not reflexive enable toggles. Use clear assertions/blockers for invalid states. A lower module reachable through multiple composition routes may require a stable `key`, as SSH does, to deduplicate list contributions.
5. Keep the service, its persisted state/ownership, checks and developer/output integration together when they serve the same concern. Do not put unrelated configuration into base/common/misc. Use the lower evaluation's `pkgs` and `lib` for all ordinary packages.
6. For a genuine stable/unstable API difference, inspect pinned options/source on **both** tracks. Prefer one localized option-availability branch (see logging). Explain when to remove it and record evidence in `docs/research.md`. Never solve compatibility by globally importing both package sets. A package exception needs a separate narrow, reviewed design.
7. Add evaluation assertions/tests in the discovered validation module or a cohesive top-level test contribution. Exercise the capability on both tracks when reusable; include negative tests for safety constraints. Keep synthetic hardware strictly within evaluation fixtures, never real host outputs.
8. Stage new files, `just fmt`, `just check`. Build affected commissioned hosts separately. Review persistence migration, runtime secrets, required mounts and recovery before any later activation.
9. Update README navigation, relevant ADR/research and procedures when the abstraction changes. Remove redundant code instead of adding compatibility layers without users.

## Commands

From repository root: `nix develop --no-update-lock-file`, `just fmt`, `just check`, `nix eval --json .#validation`. For a commissioned consumer: `just ready HOST`, `just build HOST`.

## Safety / completion

No new implicit credentials, root privilege, services, firewall exposure or data formatting. Completion means both-track checks pass, consumers opt in intentionally, generic code remains track-agnostic, and migration/runtime limitations are documented. Evaluation is not a boot or application test.

## Common failures

Wrong module class, lower-module files accidentally discovered at the top level, recursive config-dependent imports, duplicate anonymous deferred imports, stale upstream options and unrelated package-channel injection. Inspect the module graph and pinned API; do not disable checks to hide them.
