# NixOS fleet

Dendritic NixOS configurations for three `x86_64-linux` machines.

| Host | Track | Candidate |
|---|---|---|
| `thinkpad` | `nixpkgs-unstable` | Hyprland/Noctalia desktop; fresh reinstall remains unready and local-only |
| `racknerd` | Numbered stable | Minimal headless VPS; signed deployment enabled after commissioning |
| `bastion` | Numbered stable | Minimal headless NAS controller; existing `tank` stays separate from OS storage |

[Current host evidence](.agents/skills/fleet-operations/references/hosts.md#current-status) distinguishes accepted boots from unactivated candidates. Never activate ThinkPad's fresh plain layout over its running encrypted installation.

## Development

```sh
nix run --no-update-lock-file .#devenv -- shell
```

`devenv.nix` supplies the locked toolbox and existing operator scripts. **Repository tasks have been removed; replacements are deferred.** Shell entry performs no repository checks, formatting, secret loading or deployment. `devenv test` is not a validation gate.

Use the [validation skill](.agents/skills/validate/SKILL.md) for manual local checks and [devenv skill](.agents/skills/devenv/SKILL.md) for shell/lock details. Check ciphertext before staging or evaluating the flake: Nix copies tracked inputs into its public store.

## Architecture and procedures

`flake.nix` discovers the Nix-only `modules/` tree in one top-level flake-parts evaluation. Executable sources/tests live in `scripts/`, static data in `assets/`, grouped by concern. Features own their class-checked NixOS/Home Manager contributions, facts and tests; hosts explicitly choose one package track. Native `devenv.nix` is the sole development-only entry-point exception.

Operational guidance, architecture decisions, research and dated evidence live under [.agents/skills/](.agents/skills/README.md), not `docs/` or code comments. Start with [AGENTS.md](AGENTS.md), the matching skill and [secret handling](secrets/README.md).

Checks/builds authorize no deployment, installation, disk operation or credential access. Persistence and rollback are not backups.
