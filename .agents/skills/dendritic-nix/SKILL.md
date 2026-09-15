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
- `modules/fleet.nix` evaluates each host: it picks nixpkgs by `track`, then composes `base` with the host module. Hosts pick features with `module.imports = with config.flake.modules.nixos; [ … ]`. Keep names few — `base` (every host), `desktop`, `laptop`, `server`, `vps` — and merge a new feature into one of them before inventing another; host-only configuration merges straight into `fleet.hosts.<name>.module`.
- Home Manager reaches a host only through `modules/desktop.nix`, which imports the HM NixOS module and feeds `flake.modules.homeManager.desktop` into `home-manager.sharedModules` with `useGlobalPkgs` and `useUserPackages`. `sharedModules` does not create users: `modules/hosts/thinkpad/host.nix` explicitly enrolls Marcos, independently of feature-specific Home Manager settings. Headless hosts never import HM.

## Rules that bite

1. Top-level `config` and a lower module's `config` are different scopes. Bind `config.flake.modules` in a `let` before the deferred function shadows it.
2. Never resolve local values through `inputs.self`, and never forward packages or inputs via `specialArgs`/`extraSpecialArgs`.
3. Importing a capability should enable it. Add an option only for a real choice or a safety gate.
4. A lower module reachable by two import routes needs a stable `key` so list contributions deduplicate. Prefer merging into `base` so there is only one route.
5. Use the lower evaluation's own `pkgs` and `lib`. Developer tools belong in `devenv.nix`, never in a host package set, and never import both tracks. A real stable/unstable API difference gets one localized branch (`modules/logging.nix`).
6. `modules/` is Nix only: static data lives in `assets/<concern>/`. An executable a host needs is built in Nix (`pkgs.writeShellApplication` and friends) inside the module that owns it. The only standalone exceptions are the development task implementations `scripts/devenv/install.sh`, `scripts/devenv/deploy.sh` and `scripts/devenv/tailnet.sh`, referenced by `devenv.nix` and never imported into production. Native operator HCL lives under `opentofu/tailscale/` and `opentofu/porkbun/`; their separate operator credentials and encrypted local backends are never NixOS inputs. Follow [tailscale](../tailscale/SKILL.md) and [reverse-proxy](../reverse-proxy/SKILL.md) for the separate plan/apply boundaries. Porkbun uses explicit native commands, not a fourth task/script.

## Adding a feature

Name the single responsibility and its consumers first, then extend the cohesive existing file or add one under `modules/`. Keep the service, its persisted state and host policy together. Nothing verifies a feature: there are no fixtures, no `fleet.validation`/`flake.validation` and no `perSystem.checks`. Ordinary NixOS `assertions` inside a module are the only mechanism left, and they now run only when a host is actually evaluated.

## Adding a host

1. Create `modules/hosts/<name>/{host,hardware,disko}.nix` by hand, with nothing filled in. Leave them untracked until the facts are real — a Git flake ignores untracked files, so nothing evaluates meanwhile. Copy the shape from an existing host, never its values.
2. `host.nix` defines `fleet.hosts.<name>` with required `system` and `track` plus `module.imports` of the named values it needs. Choose the track deliberately; a role or directory never implies one.
3. Adapt an actual hardware scan; never borrow another machine's UUIDs, devices or keys. The exact destructive candidate, backups and recovery need explicit acceptance before any install.
4. Follow [storage](../storage/SKILL.md) for the layout and persistence, then add deployment facts to `modules/deploy.nix`.
5. Run `nix fmt`, `nix flake check --no-update-lock-file -L` and read `nix eval --json .#fleet.<name>`.

Unknown facts stay typed nulls, never invented values. Evaluation proves no installation readiness. The install task checks local inputs and the reviewed script digest; the storage skill's live-machine review and explicit authorization remain mandatory.
