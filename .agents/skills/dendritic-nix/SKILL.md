---
name: dendritic-nix
description: Fleet architecture and composition — where a capability, host fact or test belongs, how NixOS and Home Manager values are kept apart, and how to add a feature or a host. Use for flake structure, refactors, module boundaries and new fleet members.
---

# Architecture

`flake.nix` is the only production entry point. It hands `modules/` to `import-tree`, so **every `.nix` file under `modules/` is a top-level flake-parts module**; paths beginning with `_` are excluded helpers. There are no host import roots and no `common.nix`. `modules/hosts/<name>/` groups files for humans, not for evaluation.

One file owns one concern across every class it touches: NixOS config, Home Manager config, host facts, persistence and its own checks. `modules/desktop/printing.nix` is the worked example.

The pattern is [dendritic](https://github.com/mightyiam/dendritic): one feature per file, lower configurations merged as deferred option values. Flake-parts, import-tree and this repo's `fleet` schema are local choices, not part of the pattern.

## Composition

- `flake.modules.nixos.<name>` and `flake.modules.homeManager.<name>` hold deferred, class-checked configuration. They do nothing until a matching-class consumer imports them.
- `fleet.hosts.<name>.module` carries host facts; it is deferred and NixOS-class-checked, and independent features merge into it.
- `modules/fleet.nix` evaluates each host: it picks nixpkgs by `track`, then composes `base`, the host module and the named capabilities.
- Home Manager reaches a host only through `modules/desktop.nix`, which imports the HM NixOS module and feeds `flake.modules.homeManager.desktop` into `home-manager.sharedModules` with `useGlobalPkgs` and `useUserPackages`. Headless hosts never import HM.

## Rules that bite

1. Top-level `config` and a lower module's `config` are different scopes. Bind `config.flake.modules` in a `let` before the deferred function shadows it.
2. Never resolve local values through `inputs.self`, and never forward packages or inputs via `specialArgs`/`extraSpecialArgs`.
3. Importing a capability should enable it. Add an option only for a real choice or a safety gate.
4. A lower module reachable by two import routes needs a stable `key` so list contributions deduplicate — see `modules/ssh.nix`.
5. Use the lower evaluation's own `pkgs` and `lib`. Developer tools belong in `devenv.nix`, never in a host package set, and never import both tracks. A real stable/unstable API difference gets one localized branch (`modules/logging.nix`).
6. `modules/` is Nix only: executables and tests live in `scripts/<concern>/`, static data in `assets/<concern>/`.

## Adding a feature

Name the single responsibility and its consumers first, then extend the cohesive existing file or add one under `modules/`. Keep the service, its persisted state, host policy and checks together. Features own their checks through `fleet.validation.fixtureModules`, `hostChecks`, `flake.validation` and `perSystem.checks`; `modules/validation.nix` only assembles fixtures and independent oracles. Fixture facts are synthetic — never copy a sentinel device or key into a real host.

## Adding a host

1. `devenv tasks run host:create` scaffolds untracked `modules/hosts/<name>/{host,hardware,disko}.nix` with nothing filled in. It never stages, evaluates or installs.
2. `host.nix` defines `fleet.hosts.<name>` with required `system` and `track` plus its `capabilities`. Choose the track deliberately; a role or directory never implies one.
3. Mirror that choice in the independent `expectedTracks` oracle in `modules/validation.nix`.
4. Keep `ready = false` until the facts are real. Adapt an actual hardware scan; never borrow another machine's UUIDs, devices or keys.
5. Follow [storage](../storage/SKILL.md) for the layout and persistence, then add deployment facts to `modules/deploy.nix`.
6. Validate per [devenv](../devenv/SKILL.md) and read `nix eval --json .#fleet.<name>`.

Unknown facts stay as blockers in `fleet.bootstrap.missing`. Never flip `ready`, `storageReviewed` or `identityReviewed` to make an evaluation pass.
