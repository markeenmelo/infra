# ADR 0001 — Dendritic flake-parts composition

- Status: accepted (concern ownership and import-tree discovery folded in)
- Date: 2026-09-09

## Context

Three hosts need shared capabilities, independent facts and cross-cutting deployment/tooling concerns. A conventional host-import tree (`hosts/<name>/`, `common/` profiles) obscures those relationships. The upstream dendritic pattern does not mandate a particular importer.

## Decision

- `flake.nix` is the production entry point. It pins the `import-tree` input ([denful/import-tree](https://github.com/denful/import-tree); pin and behavior evidence in [research](../research.md)) and passes the whole `modules/` tree as the root module of **one top-level flake-parts evaluation**. Discovery is deterministic sorted depth-first; `/_`-prefixed files are deliberately excluded non-auto-imported helpers. `modules/flake-parts.nix` owns the flake-parts conventions (flakeModules import, systems).
- Root `devenv.nix` is the approved native development-only exception ([ADR 0010](0010-native-devenv.md)), never imported by production. Every other Nix file — including adapted hardware facts and tests — is a top-level module.
- NixOS/Home Manager capabilities are class-checked `deferredModule` values under `flake.modules.nixos` / `flake.modules.homeManager`; per-host facts merge into a deferred `fleet.hosts.<name>.module`. Concerns may contribute to the same value (logging contributes to persistence). Paths organize concerns, not host import roots. No `specialArgs` input forwarding; no additional discovery or aspect framework.
- Host-local composition/storage files are grouped under `modules/hosts/<name>/` (`host.nix`, `disko.nix`, and Bastion `data.nix`), as selected 2026-09-12. This is organizational only: every file remains a top-level module, with no host entry point, `default.nix` or manual import chain. Shared storage capabilities/checks remain under `modules/storage/`.
- Modules are feature-oriented and own their checks, scripts and assets beside their implementations. The typed validation harness (`modules/validation.nix`) only assembles synthetic capability-scoped fixtures and independent report/check/track inventories. Extract an independently selectable value only when a real consumer needs a subset — not one switch per file in advance.
- The deliberately selected `desktop` bundle (originally named `hyprland`) is the shared destination for compositor, greeter, shell, apps and peripherals; its integration module owns the Home Manager bridge, matching-class composition and supported-track rejection ([ADR 0008](0008-native-desktop-and-kernels.md)). The fleet evaluator knows no desktop name. Shared agent policy is now independently consumed by Bastion's native NixOS `agents` capability and ThinkPad's HM desktop contribution (`modules/agents.nix`); public native user-tmpfiles links do not introduce HM on headless/stable hosts.
- Uncommissioned NixOS values live in `fleetConfigurations`; `fleet` reports their requirements. Only explicitly `ready` hosts enter standard build outputs. The ready flag never suppresses NixOS assertions.

## Consequences

- File paths name features, not a host's import graph. Hardware facts are wrapped/adapted into deferred values, never stored as raw generated modules.
- Multiple import routes to one module need ordinary deduplication; SSH carries a stable module `key`.
- The custom host schema is justified by auditing/safety needs, not as a general infrastructure framework.

## Alternatives

Raw `lib.evalModules` is valid dendritic architecture but duplicates flake output plumbing. A conventional `hosts/common/profiles` tree does not meet this repository's design goal. A hand-written `readDir` traversal worked but was replaced by the upstream import-tree idiom for deliberate alignment, with behavior-neutral effect.

See [research](../research.md) and `modules/fleet.nix`.
