# ADR 0001 — Top-level dendritic composition

- Status: accepted
- Date: 2026-09-09

## Context

Three hosts need shared capabilities, independent facts and cross-cutting deployment/tooling concerns. A traditional host-import tree obscures these relationships. The upstream dendritic definition does not mandate flake-parts.

## Decision

Use flake-parts for the top-level Nixpkgs module evaluation and standard flake outputs. The initial small sorted `readDir` traversal is superseded by the import-tree amendment below; `flake.nix` remains the sole entry point. Every other Nix file is a top-level module, including future adapted hardware facts and tests.

Store class-checked NixOS capabilities in `flake.modules.nixos` (`deferredModule`). Use a typed `fleet.hosts` domain option with explicit identity/track/composition and a deferred per-host `module`. Concerns can contribute to the same value, as logging contributes to persistence. Do not forward inputs via `specialArgs` or add a general aspect framework.

## Concern-ownership amendment — 2026-09-11

The [upstream pattern](https://github.com/mightyiam/dendritic) requires feature-oriented top-level modules, not a particular importer or one separately selectable value per file. The existing evaluation/discovery foundation remains; the refactor addresses ownership rather than replacing the fleet safety interface.

- The deliberately selected `desktop` bundle replaces the compositor-named omnibus `hyprland` destination. Its integration module owns native HM imports, matching-class composition and supported-track rejection; the fleet evaluator knows no desktop name. Hyprland, Noctalia/greeter, fingerprint, shell, printing, files, controls and other apps remain separate concerns contributing to that shared destination. Extract independently selectable values when a real consumer needs a subset, not one switch per file in advance.
- Per-host deferred modules now carry the NixOS class as well as named capabilities. Hardware files retain observed hardware; timezone, laptop service policy, home-persistence selection and Tailscale credentials live with their owners. No reviewed value, device, credential or readiness fact changes.
- Feature-owned checks merge existing `validation` reports and public `checks`. The small typed validation harness only assembles synthetic capability-scoped fixtures and preserves independent report/check/track inventories. Tests are top-level modules, never raw NixOS fixture files or exported hosts. Feature owners contribute developer-shell packages; scripts live beside their owners.
- Shared display facts feed native HM settings and the tested runtime script from one local binding. Ordinary `let`, module merging and existing `perSystem` evaluation suffice; no new input or abstraction framework is introduced.

## Native import-tree amendment — 2026-09-11

At the user's request, use the upstream `mkFlake { inherit inputs; } (inputs.import-tree ./modules)` entry point and remove the hand-written traversal. Add only the dependency-free `denful/import-tree` input at the [researched pin](../research.md#native-import-tree-entry-point--2026-09-11); retain all existing inputs/pins and the explicit fleet/validation/deployment outputs.

`modules/flake/configuration.nix` owns flake-parts class registration and supported systems. The former tooling module moves to `modules/flake/development.nix`, grouping developer-shell, formatter and source-check outputs. Existing concern-oriented feature/host-fact paths need no wholesale restructuring; all Nix files are still top-level modules, not class-specific or conventional host import roots.

Use native sorted depth-first discovery and its `/_` exclusions; `default.nix` has no special import-root role. An independent source-quality inventory requires every repository module Nix file to be regular and selected, rejecting excluded or symlinked Nix modules rather than silently dropping them. Keep non-Nix assets beside their owner. No custom importer/filter framework, generated flake or extra configuration class is introduced.

## Consequences

File paths name features, not a host's import graph. Hardware facts must be wrapped rather than stored as raw generated lower-level modules. Multiple import routes need ordinary module deduplication; SSH has an explicit key. A custom host schema is justified by auditing/safety, not a general infrastructure framework.

Uncommissioned NixOS values live in `fleetConfigurations`; `fleet` reports their requirements. Only explicitly ready hosts enter standard build outputs. This preserves useful bootstrap checks without fake hardware. The ready flag does not suppress NixOS assertions.

## Alternatives

Raw `lib.evalModules` is valid dendritic architecture but would duplicate flake output plumbing. The original custom traversal was valid but is now replaced by the user's preferred standard import-tree integration; no larger framework is required. A conventional `hosts/common/profiles` tree does not meet this repository's design goal.

See [research](../research.md) and `modules/fleet.nix`.
