---
name: dendritic-nix
description: Fleet architecture and composition — where a capability or host fact belongs, how NixOS and Home Manager values are kept apart, and how to add a feature or a host. Use for flake structure, refactors, module boundaries and new fleet members.
---

# Architecture

`flake.nix` is the only production entry point. It hands `modules/` to `import-tree`, so **every `.nix` file under `modules/` is a top-level flake-parts module**; paths beginning with `_` are excluded helpers. There are no host import roots and no `common.nix`. `modules/hosts/<name>/` groups files for humans, not for evaluation.

One file owns one concern across every class it touches: NixOS config, Home Manager config, host facts and persistence. `modules/desktop/printing.nix` is the worked example.

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
6. `modules/` is Nix only: static data lives in `assets/<concern>/`. There is no `scripts/` tree — an executable a host needs is built in Nix (`pkgs.writeShellApplication` and friends) inside the module that owns it.

## Adding a feature

Name the single responsibility and its consumers first, then extend the cohesive existing file or add one under `modules/`. Keep the service, its persisted state and host policy together. Nothing verifies a feature: there are no fixtures, no `fleet.validation`/`flake.validation` and no `perSystem.checks`. Ordinary NixOS `assertions` inside a module are the only mechanism left, and they now run only when a host is actually evaluated.

## Adding a host

1. Create `modules/hosts/<name>/{host,hardware,disko}.nix` by hand, with nothing filled in and `fleet.hosts.<name>.module.fleet.installation.approved = false`. Leave them untracked until the facts are real — a Git flake ignores untracked files, so nothing evaluates or installs meanwhile. Copy the shape from an existing host, never its values.
2. `host.nix` defines `fleet.hosts.<name>` with required `system` and `track` plus its `capabilities`. Choose the track deliberately; a role or directory never implies one.
3. Keep installation approval false until the exact destructive candidate, backups and recovery are accepted. Adapt an actual hardware scan; never borrow another machine's UUIDs, devices or keys.
4. Follow [storage](../storage/SKILL.md) for the layout and persistence, then add deployment facts to `modules/deploy.nix`.
5. Run `nix fmt`, `nix flake check --no-update-lock-file -L` and read `nix eval --json .#fleet.<name>`.

Unknown facts stay as blockers in `fleet.bootstrap.missing`. They never fail a system build; together with `fleet.installation.approved`, they only make the host's public disko aliases refuse. Never set installation approval or `identityReviewed` to make anything pass.
