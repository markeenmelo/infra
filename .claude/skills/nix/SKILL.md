---
name: nix
description: "How this flake is organized (dendritic flake-parts + import-tree): where a module, host fact, fleet.* option, package pin, app, check or test goes, Nix merge and argument rules, package updates, and output-preserving refactors. Use before changing or adding any Nix, and when asking where something belongs."
---

# Nix

`flake.nix` holds only `flake-parts.lib.mkFlake` over `import-tree ./modules`, with the inputs
[tack](https://docs.manic.systems/tack) pins in [pins.toml](../../../.tack/pins.toml) and locks in
`.tack/pins.lock.json`. Every file under `modules/` is a flake-parts module for one concern, and
nothing Nix lives elsewhere but tack's generated resolver, `.tack/default.nix`, which the
`tack-resolver` check in [pins.nix](../../../modules/pins.nix) holds to the tack pin's own.
[flake-parts.nix](../../../modules/flake-parts.nix) lists the systems and loads the flake module
that makes `flake.modules.*` exist. [base.nix](../../../modules/base.nix) is what a host gets
before any role.
Background: [dendritic pattern](https://github.com/mightyiam/dendritic),
[module semantics](https://nixos.org/manual/nixos/stable/#sec-writing-modules).

## Placement

| Contribution | Owner |
|---|---|
| Every host / role / service | `flake.modules.nixos.base` / `server`, `desktop` / `flake.modules.nixos.SERVICE` |
| Operator user settings | `flake.modules.homeManager.base` on every workstation; `homeManager.desktop` for the Linux desktop |
| Host facts (system, addresses, keys, role flags) and imports | `modules/hosts/HOST/host.nix`; the files of `modules/hosts/HOST/` are the only writers of `fleet.hosts.HOST` |
| Hardware, disko, networking, host-only data | `modules/hosts/HOST/` |
| Cross-concern facts | Typed `fleet.*` options beside their owner; never `specialArgs` or `_module.args` |
| Package expression or pin set | `NAME.pkg.nix`, not loaded as a module; other imported Nix is `_NAME.nix` |
| Apps, data, scripts, tests | Beside the feature they serve |
| Dev shell | `modules/dev-shell.nix`, plain `mkShellNoCC`; `nix fmt` through treefmt |

Rules:
- A concern sets every class it touches (`nixos`, `homeManager`) in one file; a
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

**Inputs** — an input is a tack pin; a new one lists the transitive inputs it never uses in
`omit_inputs`. Since the flake itself declares no inputs, flake-parts' `inputs'` and `self.inputs`
are empty: read `inputs`.
Substituters go in `nix.settings`, never flake `nixConfig`. Every host trusts, after bastion's
cache and cache.nixos.org, the caches the pins' upstreams publish
([base.nix](../../../modules/base.nix)): numtide's for llm-agents, nix-community's, microvm's and
tack's. A cache serves a pin only where it keeps its own nixpkgs; a pin that follows ours rarely hits it.

**Apps** — every operator task is a flake app built with `writeShellApplication`; switch to
`writers.writePython3Bin` past ~100 lines or when it parses data. Only workflow YAML, `.envrc` and
the `justfile` stay outside Nix; a recipe only names a flake app or a Nix or nh command, with no
logic beyond picking the platform's switch.

**Checks** — a check that needs a host's `pkgs` sits under `flake.checks.${fleet.hosts.HOST.system}`;
one that needs only tools stays in `perSystem`. A check made for every NixOS host that runs a
service goes through [_host-checks.nix](../../../modules/_host-checks.nix) (name, enabled predicate, derivation). Prefer `runCommand` assertions on generated config
over `nixosTest`; the VM tests, `storage` in [storage.nix](../../../modules/storage.nix) (`storage-perlless` for the
edge), need KVM, which the linux CI job enables. The `apps` check builds
every flake app, which is what runs shellcheck on them, and `format` fails on unformatted Nix, OpenTofu, Luau, shell, TOML, JSON, YAML or
`justfile` ([dev-shell.nix](../../../modules/dev-shell.nix)), leaving out `secrets/`. `links` fails on a relative Markdown link whose target is missing.
What CI builds when is in [README.md](../../../README.md#ci) and [check.yml](../../../.github/workflows/check.yml), which builds every check when the base does not evaluate. A check whose derivation matches the base's is
not rebuilt: a pull request into `main` builds what differs from `main`, and a push to `main` builds everything.
A pull request into any other branch only evaluates and builds the cheap `format`, `secrets` and `links` checks. Assertions guard
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

`just update` is the only updater: it runs `tack update`, which moves a pin with a `tag` template
to its newest matching release tag and every other pin to its branch head (on a host with the
GitHub token, tack authenticates with it: [secrets](../operating/secrets.md)), then the `update-pins`
app ([pins.nix](../../../modules/pins.nix)). nix-update bumps each `NAME.pkg.nix` in `pins` with its
hashes, and [update-pins.sh](../../../modules/update-pins.sh) bumps what nix-update cannot see
(Caddy plugin versions, Grafana dashboard revisions, the CrowdSec hub commit, tack's resolver after a tack bump, each OpenTofu
provider's constraint and lock, the SHA-pinned actions through pinact). The operator reads the
diff before committing, above all action, `pins.lock.json` and plugin moves: actions run with secrets,
the inputs on every host, the Noctalia plugins as `marcos` with the Tailscale operator, and the
Claude Code plugins as `marcos` in the agent guest ([guests: agents](../guests/agents.md));
a provider move needs a `tofu plan` with no changes. Updates take the newest release
at once, with no release-age cool-down: that read is the only gate. A source tree the fleet
fetches from a Git forge is a `type = "fetch"` pin, left at the default `fetch_mode`, whose eval
fetch gives the same store path as `fetchFromGitHub`; a package built from it is a `NAME.pkg.nix`
that takes `src` from `inputs`. Only what a pin cannot lock stays in `pins` for nix-update: a
build with its own dependency hash, a sparse checkout, a release asset. Never hand-edit
`pins.lock.json`: the resolver fetches a locked input by `narHash`, so a revision bump without its
hash keeps the old tree where cached and fails elsewhere; `nix run .#tack -- update PIN` instead. Each pin keeps its
own version literal so only that line is rewritten.

[vulnix.yml](../../../.github/workflows/vulnix.yml) scans each host's runtime closure on a runner
of its architecture (`ubuntu-24.04-arm` for edge) weekly against NIST's CVEs; the workflow says what fails a run. vulnix matches by name and version, so most matches are
another project with the same name or a CVE nixpkgs already patches. A confirmed false positive
or an accepted risk goes in [vulnix.toml](../../../vulnix.toml) as a section per package with
`cve`, `comment` and an `until` date, so it comes back for review; a real one is fixed by the
update that carries the patch.

## Refactor check

A refactor must not change what the hosts build. Run this at the base and on the branch; the two
outputs must be identical:

```sh
nix eval --json .#nixosConfigurations --apply 'builtins.mapAttrs (_: h: h.config.system.build.toplevel.outPath)'
```

Write the output outside the checkout.
