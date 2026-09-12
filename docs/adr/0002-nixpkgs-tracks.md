# ADR 0002 — One package universe per host

- Status: accepted; developer/library track amended by [ADR 0010](0010-native-devenv.md), Home Manager scope narrowed by [ADR 0008](0008-native-desktop-and-kernels.md)
- Date: 2026-09-09

## Context

Servers need predictable stable service changes; the interactive machine needs `nixpkgs-unstable`. A top-level module evaluator must not silently determine target package sets.

## Decision

- Keep independent `nixpkgs` (naming `nixpkgs-unstable`) and `nixpkgs-stable` (a researched, numbered supported branch) inputs and locks. Every host declares explicit `track` and `system`; `modules/fleet.nix` calls the selected input's `lib.nixosSystem` and lets NixOS instantiate its own packages.
- Unstable library/developer tooling is used at the top level; flake-parts follows `nixpkgs`. This never selects packages for stable hosts. Generic features consume their own evaluation's `pkgs`/`lib`; a real API difference gets a localized option probe (as logging does), never cross-track package imports.
- The deploy-rs overlay is scoped to the target's package set when constructing an activator, never installed globally into host overlays.

## Consequences

- No `pkgsStable`/`pkgsUnstable`, mixed-package overlays, cross-track defaults or package imports in generic features. A future package exception must be narrow, explicit and independently documented.
- Validation independently checks required tracks, actual `pkgs.path` sources and locked branch names ([scope](../validation.md)); updates can move one track without the other.
- Development tools advance with unstable; `stateVersion` never follows an input.

## Alternatives

A shared `perSystem.pkgs` for all hosts, importing both trees into every host, or inferring tracks from roles/directory names all hide intent or cost evaluation.

See [research](../research.md), `flake.nix`, `modules/fleet.nix`, `modules/validation.nix`.
