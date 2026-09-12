---
name: dendritic-nix
description: Plan, review or carry out a dendritic Nix refactor of this fleet using feature-oriented flake-parts modules. Use for flake architecture, aspect composition, NixOS/Home Manager boundaries, shared values, module discovery or splitting growing features. Not for general Nix syntax or standalone package recipes.
---

# Dendritic Nix

## Purpose / authority

Organize each top-level module around **one concern across its applicable configurations**, not around a configuration class or a host import tree. Use the [upstream definition](https://github.com/mightyiam/dendritic) first; this guide and other repositories' skills are adaptations, not architectural authority. Revisit local guidance when researched upstream practice exposes a better boundary. Safety, real facts and explicit operation authorization still apply.

[Research and pins](../../../docs/research.md#dendritic-concern-ownership-refactor--2026-09-11) distinguish the upstream pattern from local choices. Dendritic itself does not mandate flake-parts, import-tree, a fleet schema, or a separately selectable module name for every file.

## Prerequisites

Read `../../../AGENTS.md`, `../../../README.md`, `../../../docs/adr/0001-dendritic-composition.md`, `../../../flake.nix`, `../../../modules/fleet.nix` and every affected concern/consumer. For Home Manager read `../../../modules/desktop.nix`; for tests read `../../../modules/validation.nix` and the feature's checks. Use `nix-research` for dependency-sensitive decisions.

## Design procedure

1. **Trace actual evaluation and consumers.** `flake.nix` passes the whole `modules/` tree to the pinned `import-tree` input; `modules/flake-parts.nix` imports `inputs.flake-parts.flakeModules.modules`, so every discovered `.nix` is a top-level module (`/_`-prefixed paths are excluded helpers). All those files are top-level modules, including facts and tests. A deferred definition is inert until imported into a matching-class consumer. `modules/fleet.nix` chooses the host's track, adds base and composes the named NixOS values plus the deferred host module; it must not know desktop/app internals.
2. **Choose the concern before the destination.** Keep a concern's NixOS/HM configuration, persistence, host facts and checks together, or in adjacent concern-specific files when large. `printing.nix` spans both classes, ThinkPad queue facts and tests. Do not collect unrelated services into `utilities`, mix policy into hardware facts, or grow a global test implementation file. File size alone is not the criterion.
3. **Compose deliberately, not mechanically.** Independently reused/selected capabilities need their own deferred values. Cohesive contributions may share a destination: the intentionally selected `desktop` bundle receives Hyprland, Noctalia, apps and peripherals. Sharing that destination does not make all those files one responsibility. Split by concern; do not add unused per-application enable flags or a capability for every filename. If another consumer needs a subset, extract the relevant values and explicitly wire both classes.
4. **Respect class and scope.** NixOS values live in `flake.modules.nixos`, HM values in `flake.modules.homeManager`; `fleet.hosts.<name>.module` is also deferred and NixOS-class-checked. Capture top-level `config.flake.modules` in a lexical binding before lower `config` shadows it. Lower functions receive their own `config`, `lib`, `pkgs`. Use a local `let` for within-file sharing, an existing/typed top-level option for a genuine cross-file need. Never use `inputs.self` for local aspect lookup or forward inputs/package sets through custom `specialArgs`/`extraSpecialArgs`.
5. **Let the integrating concern own its bridge.** `../../../modules/desktop.nix` imports native HM and composes `flake.modules.homeManager.desktop` via `home-manager.sharedModules`, using `useGlobalPkgs` and `useUserPackages`. Its import-time guard rejects other Nixpkgs tracks using native evaluator `modulesPath`, without config-dependent import recursion. Headless hosts never import HM. Preserve upstream's native `extraSpecialArgs.nixosConfig`, release checks and collision detection; no stable/standalone HM output is needed.
6. **Keep tooling and tests with their owner.** Native `devenv.nix` assembles the unstable developer toolbox/tasks; this explicit development entry-point exception is documented in [ADR 0010](../../../docs/adr/0010-native-devenv.md). Feature scripts/assets stay nearby; update all callers and repository-root calculations after moves. The small validation harness owns typed fixture assembly and independent output/track inventories, not feature assertions. Owners contribute `fleet.validation.fixtureModules`, `hostChecks`, `flake.validation` and `perSystem.checks`; fixture facts remain synthetic and capability-scoped.
7. **Preserve module identity.** Do not manually import discovered files again. Repeated lower-level import routes may need a stable `key` (see `../../../modules/ssh.nix`) to avoid duplicate list contributions. A refactor can change merge ordering and derivations: inspect generated results rather than assuming a move is behavior-free.

## Refactor workflow

1. Record the clean/dirty starting state, commit and locked pins without overwriting user work. Capture affected hosts' tracks, readiness/output eligibility, relevant generated settings/derivations, mounts, persistence and access policy using read-only local evaluation. Never collect secret values or contact targets as a baseline.
2. Read authoritative sources and reconcile the actual module graph before choosing boundaries. Preserve sound infrastructure; a justified whole-concern refactor need not be the smallest textual diff. Do not install a framework or rename a namespace merely to look compliant.
3. Move one concern at a time through one writer. Keep facts, policy, packages, review flags and pins unchanged unless a behavior change is explicitly requested. Update relative asset references, test paths, named consumers and guidance together.
4. Stage individually reviewed new files for Git-flake discovery. Compare values and generated outputs; investigate changed store paths, including list ordering and source-root references. Stop on unexpected package-source, security, storage, readiness or consumer changes. Preserve independent test oracles rather than deriving expectations from the production decision under test.
5. Follow [validate](../validate/SKILL.md): `devenv tasks run repo:fmt`, final `devenv tasks run repo:check-full`, and readiness/builds for affected commissioned hosts. Both tracks cover reusable infrastructure; supported-track and rejection checks cover desktop. Review the complete diff and report exact evidence and unresolved runtime acceptance. Targeted probes or read-only audits do not replace canonical checks.

## Local choices, not upstream requirements

- Production inputs stay in `flake.nix`; root `devenv.nix` is the sole approved development-only entry-point exception and is never discovered/imported into production. Discovery is the pinned `import-tree` input (`denful/import-tree`, formerly `vic/import-tree`): the flake root module is `(inputs.import-tree ./modules)` and `modules/flake-parts.nix` owns the flake-parts conventions. The pinned default excludes `/_`-prefixed paths and keeps `*.nix`-named entries in sorted depth-first order; configure no filters or builder API without a researched need.
- Host-local composition and storage live in `modules/hosts/<name>/{host,disko}.nix`, with Bastion data mounts in `data.nix`. This grouping does not create an import root: every file remains independently discovered at the top level. Shared storage capabilities/checks stay under `modules/storage/`.
- Discovery has exactly one dependency: the pinned `import-tree` callable, used bare. Prefer native module merging over hand-written registries that duplicate it; the small typed fleet/fixture interfaces exist for actual safety/reporting needs.
- Preserve required `system`/`track`, `fleetConfigurations`, readiness-filtered `nixosConfigurations` and ready-plus-enabled deployment outputs. Fixtures never become installation/deployment targets. `perSystem.pkgs` is not a source of normal host packages.

## Existing examples

| Concern | Example |
|---|---|
| Two classes, host facts, persistence and tests | `../../../modules/desktop/printing.nix` |
| Shared observed value used by runtime and test | `../../../modules/desktop/displays.nix` |
| Feature-owned fixture facts and negative tests | `../../../modules/access/checks.nix` |
| Matching-class integration | `../../../modules/desktop.nix` |
| Shared contribution without another host selection | `../../../modules/logging.nix` |

## Common failures / safety

A renamed omnibus is not a refactor; a new capability name per file is not the definition either. Watch for outer/inner scope confusion, unconsumed aspects, wrong-class imports, config-dependent import recursion, duplicated deferred modules, detached tests and fake fixture facts leaking into hosts. Fix the boundary, never suppress assertions. Architecture work authorizes no activation, secret access, enrollment, storage operation or change to real readiness/review evidence.
