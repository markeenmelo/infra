---
name: nix
description: "How this flake is organized (dendritic flake-parts + import-tree): where a module, host fact, fleet.* option, package pin, app, check or test goes, Nix merge and argument rules, package updates, and output-preserving refactors. Use before changing or adding any Nix, and when asking where something belongs."
---

# Nix

`flake.nix` holds only inputs and `flake-parts.lib.mkFlake` over `import-tree ./modules`. Every
file under `modules/` is a flake-parts module for one concern, and nothing Nix lives elsewhere.
Background: [dendritic pattern](https://github.com/mightyiam/dendritic),
[module semantics](https://nixos.org/manual/nixos/stable/#sec-writing-modules).

## Placement

| Contribution | Owner |
|---|---|
| Every host / role / service | `flake.modules.nixos.base` / `server`, `desktop` / `flake.modules.nixos.SERVICE` |
| Desktop user settings | `flake.modules.homeManager.cli` or `apps` when portable to darwin, else `homeManager.desktop` |
| nix-darwin base / role | `flake.modules.darwin.base` / `desktop`, in the same file as the NixOS counterpart |
| Host facts (system, addresses, keys, role flags) and imports | `modules/hosts/HOST/host.nix`, the only writer of `fleet.hosts.HOST` |
| Hardware, disko, networking, host-only data | `modules/hosts/HOST/` |
| Cross-concern facts | Typed `fleet.*` options beside their owner; never `specialArgs` or `_module.args` |
| Package expression or pin set | `NAME.pkg.nix`, not loaded as a module; other imported Nix is `_NAME.nix` |
| Apps, data, scripts, tests | Beside the feature they serve |
| Dev shell | `modules/dev-shell.nix`, plain `mkShell`; `nix fmt` through treefmt |

Rules:
- A concern sets every class it touches (`nixos`, `darwin`, `homeManager`) in one file; a
  directory is organization only. Extend an existing owner before adding a file.
- Import = enable. No `enable` option, no `mkIf cfg.enable`, no wrapper over an upstream option.
- A `fleet.*` option exists only when two consumers set it differently. It is typed and has no
  guessed default. A fact a service contributes for another host to read is set inside the
  service's module, so dropping the import drops the fact.
- Name a module for a role or a service a host runs, so `host.nix` lists what the host runs. A
  named module reads its own host as `hosts.${config.networking.hostName}`; other hosts through
  role flags, never by name.
- Ports, mounts, persisted paths and backup paths are declared beside the owning service.
- No helper library until a third copy of the code exists.

## Nix rules

**Arguments** — request only what you use; inner modules take their own `lib`/`pkgs`. Every host
follows the one `nixpkgs`. No overlays unless nixpkgs forces one, no `inputs.self` pass-through,
no mixed package sets. `with` only for capability imports.

**Merging** — let the module system merge; `//` is shallow. `mkDefault` for policy a host may
override; a non-obvious `mkForce` gets one sentence in the owning skill naming the attribute.
Extend an upstream default list at its priority: `mkDefault (mkAfter …)`.

**Inputs** — a new input empties transitive inputs it never uses (`inputs.X.follows = ""`).
Substituters go in `nix.settings`, never flake `nixConfig`.

**Apps** — every operator task is a flake app built with `writeShellApplication`; switch to
`writers.writePython3Bin` past ~100 lines or when it parses data. Only workflow YAML and `.envrc`
stay outside Nix.

**Checks** — a check that needs a host's `pkgs` sits under `flake.checks.${fleet.hosts.HOST.system}`;
one that needs only tools stays in `perSystem`. Prefer `runCommand` assertions on generated config
over `nixosTest`; one VM test covers the root rollback and Preservation. Assertions guard
independently contributed policy, never a value against the expression that produced it.

**Style** — `lib.getExe`, relative paths, `enableStrictShellChecks` on units whose scripts are this
repository's. Comments follow [CLAUDE.md](../../../CLAUDE.md).

## Package updates

`nix run .#update` moves `flake.lock` and every pin; the operator runs it. Never hand-edit
`flake.lock`: Nix resolves a locked input by `narHash` before `rev`, so a revision bump without
its hash keeps the old tree where cached and fails elsewhere; `nix flake update INPUT` instead.
Each pin keeps its own version literal so only that line is rewritten.

## Refactor check

A refactor must not change what the hosts build. The operator runs, from `HEAD` and the working
tree, and the two files must be identical:

```sh
nix eval --json .#nixosConfigurations --apply 'builtins.mapAttrs (_: h: h.config.system.build.toplevel.outPath)'
```

(`darwinConfigurations` likewise.) Write the output outside the checkout.
