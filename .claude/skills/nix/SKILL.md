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
| Operator user settings | `flake.modules.homeManager.base` on every workstation; `homeManager.desktop` for the Linux desktop; mac-only ones in the darwin module's `home-manager.users` |
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

## New service checklist

Answer each before the module is done; a reviewer will ask otherwise.

- State and logs: which paths it writes, which of them go under `/persist` and with what
  owner and mode, which are deliberately lost on reboot. A user that owns data on a pool gets a
  pinned uid and gid, since a reinstall reallocates dynamic ids.
- Dependencies: what it needs at boot and at runtime (network, DNS, tailnet, another host, a
  secret), ordered with `after`/`wants`, and what happens when each is down. No single upstream
  for anything a certificate or a deploy needs.
- Secrets: how each reaches the unit (`LoadCredential`, `*File`, environment file), that it
  restarts the reader, and where it could leak (logs, query strings, argv, store).
- Reloads: how the upstream NixOS module applies a config change (reload or restart) and that
  nothing in the config disables it.
- Exposure: ports opened, on which interface, and what admits or denies traffic. A local port
  that answers without authentication gets a `fleet.loopbackGuards` entry
  ([loopback-guards.nix](../../../modules/loopback-guards.nix)).

## Nix rules

**Arguments** — request only what you use; inner modules take their own `lib`/`pkgs`. Every host
follows the one `nixpkgs`. No overlays unless nixpkgs forces one, no `inputs.self` pass-through,
no mixed package sets. `with` only for capability imports.

**Merging** — let the module system merge; `//` is shallow and skips priorities, so it appears
nowhere in Nix here: config shared between classes or hosts is a module both import, and a value
built from several parts is `lib.mkMerge [ … ]` (inside module config) or `lib.listToAttrs`.
`mkDefault` for policy a host may override; a non-obvious `mkForce` gets one sentence in the owning skill naming the attribute.
Extend an upstream default list at its priority: `mkDefault (mkAfter …)`.

**Inputs** — a new input empties transitive inputs it never uses (`inputs.X.follows = ""`).
Substituters go in `nix.settings`, never flake `nixConfig`.

**Apps** — every operator task is a flake app built with `writeShellApplication`; switch to
`writers.writePython3Bin` past ~100 lines or when it parses data. Only workflow YAML, `.envrc` and
the `justfile` stay outside Nix; a recipe only names a flake app or a Nix or nh command, with no
logic beyond picking the platform's switch.

**Checks** — a check that needs a host's `pkgs` sits under `flake.checks.${fleet.hosts.HOST.system}`;
one that needs only tools stays in `perSystem`. A check made for every NixOS host that runs a
service goes through [_host-checks.nix](../../../modules/_host-checks.nix) (name, enabled predicate, derivation). Prefer `runCommand` assertions on generated config
over `nixosTest`; one VM test, `storage` in [storage.nix](../../../modules/storage.nix), installs
the disk layout with disko's test library, reboots, and asserts the root subvolume was recreated
while preserved paths and the machine id survived; it needs KVM, which the linux CI job enables.
[check.yml](../../../.github/workflows/check.yml) evaluates every system and builds the x86_64
ones (`linux`) and the mac (`darwin`, on a macOS runner) on each PR push and on `main`. Assertions guard
independently contributed policy, never a value against the expression that produced it.

**Language** — `let`, never `rec`; `inherit` over repetition; conditional config through
`mkIf`, `lib.optional`, `lib.optionals` and `lib.optionalString`, not `if` around whole attrsets.
A value computed from another option reads `config`, never a copy. Store paths come from
interpolating a derivation, never a literal `/nix/store` path or `builtins.currentSystem`; no
`--impure`, `getEnv` or import-from-derivation in anything a check or app evaluates.

**Options** — every declared option has a type and a description, camelCase except when it names
a package attribute; `enum` and `submodule` over `attrs`, `anything` or `raw`, so values are
checked and the type extends across files. No `mkEnableOption` (import = enable).

**Style** — `lib.getExe`, relative paths, `enableStrictShellChecks` on units whose scripts are this
repository's. Comments follow [CLAUDE.md](../../../CLAUDE.md).

## Package updates

Renovate ([renovate.json](../../../renovate.json)) opens the update PRs for `flake.lock`, the
SHA-pinned actions and the OpenTofu providers. The review bots skip PRs opened by bots
([review.yml](../../../.github/workflows/review.yml)), so the operator reviews these by hand,
above all action and `flake.lock` moves, which change what runs with secrets and on every host.
Every other pin goes through the `update-pins` app ([pins.nix](../../../modules/pins.nix)), which
`just update` runs after `nix flake update`: nix-update bumps each `NAME.pkg.nix` in `pins` with
its hashes (the Claude Code plugins only through `update-plugin`, darwin skill), and [update-pins.sh](../../../modules/update-pins.sh) bumps what nix-update cannot see
(Caddy plugin versions, Grafana dashboard revisions, the CrowdSec hub commit). A source the fleet
fetches is a `NAME.pkg.nix` added to `pins`, not a `flake = false` input, which a rev in its URL
freezes. Never hand-edit `flake.lock`: Nix
resolves a locked input by `narHash` before `rev`, so a revision bump without its hash keeps the
old tree where cached and fails elsewhere; `nix flake update INPUT` instead. Each pin keeps its
own version literal so only that line is rewritten.

[vulnix.yml](../../../.github/workflows/vulnix.yml) builds each x86_64 host weekly and matches
its runtime closure against NIST's CVEs, listing the matches in the run summary; the run fails
while an unwhitelisted match scores CVSS 9 or higher; a match NIST has not scored yet counts as
10, so a fresh one fails until it is scored or whitelisted. vulnix matches by name and version, so most matches are
another project with the same name or a CVE nixpkgs already patches. A confirmed false positive
or an accepted risk goes in [vulnix.toml](../../../vulnix.toml) as a section per package with
`cve`, `comment` and an `until` date, so it comes back for review; a real one is fixed by the
update that carries the patch.

## Refactor check

A refactor must not change what the hosts build. The operator runs, from `HEAD` and the working
tree, and the two files must be identical:

```sh
nix eval --json .#nixosConfigurations --apply 'builtins.mapAttrs (_: h: h.config.system.build.toplevel.outPath)'
```

(`darwinConfigurations` likewise.) Write the output outside the checkout.
