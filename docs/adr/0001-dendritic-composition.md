# ADR 0001 — Top-level dendritic composition

- Status: accepted; development entry-point exception and tooling ownership amended by [ADR 0010](0010-native-devenv.md); discovery moved to the pinned import-tree input by the [2026-09-12 amendment](#discovery-input-amendment--2026-09-12)
- Date: 2026-09-09

## Context

Three hosts need shared capabilities, independent facts and cross-cutting deployment/tooling concerns. A traditional host-import tree obscures these relationships. The upstream dendritic definition does not mandate flake-parts.

## Decision

Use flake-parts for the top-level Nixpkgs module evaluation and standard flake outputs. A small sorted `readDir` traversal discovers all Nix files under `modules/`; `flake.nix` is the production entry point. Root `devenv.nix` is the approved native development-only exception, never imported here. Every other Nix file is a top-level module, including future adapted hardware facts and tests.

Store class-checked NixOS capabilities in `flake.modules.nixos` (`deferredModule`). Use a typed `fleet.hosts` domain option with explicit identity/track/composition and a deferred per-host `module`. Concerns can contribute to the same value, as logging contributes to persistence. Do not forward inputs via `specialArgs` or add a new discovery/aspect framework.

## Concern-ownership amendment — 2026-09-11

The [upstream pattern](https://github.com/mightyiam/dendritic) requires feature-oriented top-level modules, not a particular importer or one separately selectable value per file. The existing evaluation/discovery foundation remains; the refactor addresses ownership rather than replacing the fleet safety interface.

- The deliberately selected `desktop` bundle replaces the compositor-named omnibus `hyprland` destination. Its integration module owns native HM imports, matching-class composition and supported-track rejection; the fleet evaluator knows no desktop name. Hyprland, Noctalia/greeter, fingerprint, shell, printing, files, controls and other apps remain separate concerns contributing to that shared destination. Extract independently selectable values when a real consumer needs a subset, not one switch per file in advance.
- Per-host deferred modules now carry the NixOS class as well as named capabilities. Hardware files retain observed hardware; timezone, laptop service policy, home-persistence selection and Tailscale credentials live with their owners. No reviewed value, device, credential or readiness fact changes.
- Feature-owned checks merge existing `validation` reports and public `checks`. The small typed validation harness only assembles synthetic capability-scoped fixtures and preserves independent report/check/track inventories. Tests are top-level modules, never raw NixOS fixture files or exported hosts. Scripts live beside their owners; the later native devenv migration assembles developer packages/tasks separately, without changing feature-owned checks.
- Shared display facts feed native HM settings and the tested runtime script from one local binding. Ordinary `let`, module merging and existing `perSystem` evaluation suffice; no new input or abstraction framework is introduced.

## Discovery-input amendment — 2026-09-12

The operator chose the upstream discovery idiom. `flake.nix` pins the `import-tree` input ([denful/import-tree](https://github.com/denful/import-tree), formerly published as `vic/import-tree`; researched at `eb1b52eaecc57f7c136d07ae8a93e724dfecac46` in [research](../research.md#import-tree-discovery-input--2026-09-12)) and its root module is the tree itself: `mkFlake { inherit inputs; } (inputs.import-tree ./modules)`. `modules/flake-parts.nix` — an ordinary discovered module — owns the flake-parts conventions (`flakeModules.modules` import and `systems`). The hand-written `readDir` traversal is removed.

Source-verified behavior preserves deterministic sorted depth-first discovery. The only deltas are the upstream default excluding `/_`-prefixed helper paths — from now on underscore-prefixed files are deliberately not auto-imported — and including `*.nix`-named non-directory entries; neither exists in the tree today. All fleet inputs stay declared in `flake.nix`; no fleet interface, host composition, readiness or track decision changes. This supersedes the Alternatives note that declined import-tree: it remains unnecessary for correctness and is adopted as deliberate idiom alignment.

## Consequences

File paths name features, not a host's import graph. Hardware facts must be wrapped rather than stored as raw generated lower-level modules. Multiple import routes need ordinary module deduplication; SSH has an explicit key. A custom host schema is justified by auditing/safety, not a general infrastructure framework.

Uncommissioned NixOS values live in `fleetConfigurations`; `fleet` reports their requirements. Only explicitly ready hosts enter standard build outputs. This preserves useful bootstrap checks without fake hardware. The ready flag does not suppress NixOS assertions.

## Alternatives

Raw `lib.evalModules` is valid dendritic architecture but would duplicate flake output plumbing. import-tree was initially declined as unnecessary for a small deterministic traversal; the [2026-09-12 amendment](#discovery-input-amendment--2026-09-12) later adopted it as idiom alignment with behavior-neutral effect. A conventional `hosts/common/profiles` tree does not meet this repository's design goal.

See [research](../research.md) and `modules/fleet.nix`.
