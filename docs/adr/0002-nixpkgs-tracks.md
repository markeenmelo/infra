# ADR 0002 — One package universe per host

- Status: accepted
- Date: 2026-09-09
- Extended by [ADR 0007](0007-thinkpad-desktop.md), then narrowed by [ADR 0008](0008-native-desktop-and-kernels.md): only the unstable desktop imports Home Manager, using its host's packages; servers retain stable Nixpkgs without HM.

## Context

Servers require predictable stable service changes; interactive machines require the explicitly requested `nixpkgs-unstable` track. A top-level module evaluator must not silently determine all target package sets.

## Decision

Keep independent `nixpkgs-stable` and `nixpkgs-unstable` inputs and locks. Stable names a researched, numbered supported NixOS branch. Each host **must** declare `track` and `system`. At the composition boundary, call the selected input's `lib.nixosSystem`; let NixOS instantiate its own packages.

Use stable library/developer tooling at the top level. Disko/impermanence modules consume the target evaluator's `pkgs`/`lib`. The deploy-rs overlay is scoped to the target's package set when constructing an activator, never installed globally into host overlays.

## Consequences

No global `pkgsStable`/`pkgsUnstable`, mixed-package overlays, cross-track defaults or package imports in generic features. A future package exception must be narrow, explicit and independently documented. Real API differences can use a localized option probe, as logging does.

Validation has an independent required-host mapping, actual-package-source comparison and locked-branch assertions. It catches metadata changes, evaluator wiring mistakes and input aliases. Updates can move one track without moving the other. Stable-dependent development tools change with stable; stateVersion never follows an input.

## Alternatives

A shared `perSystem.pkgs` for all hosts violates the split. Importing both trees into every host hides mixing and costs evaluation. Inferring tracks from roles or directory names makes intent less auditable.

See [research](../research.md), `flake.nix`, `modules/fleet.nix`, `modules/validation.nix`.
