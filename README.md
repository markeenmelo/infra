# NixOS fleet

Dendritic NixOS configurations for three `x86_64-linux` machines.

| Host | Track | Candidate |
|---|---|---|
| `thinkpad` | `nixpkgs-unstable` | Hyprland/Noctalia desktop; fresh reinstall remains unready and local-only |
| `racknerd` | Numbered stable | Minimal headless VPS; dedicated-account remote deployment candidate |
| `bastion` | Numbered stable | Minimal headless NAS controller; existing `tank` stays separate from OS storage |

[Current host evidence](.agents/skills/fleet-operations/references/hosts.md#current-status) distinguishes accepted boots from unactivated candidates. Never activate ThinkPad's fresh plain layout over its running encrypted installation.

## Development

```sh
nix run --no-update-lock-file .#devenv -- shell
```

`devenv.nix` supplies the locked toolbox, scripts and three explicitly invoked tasks: **`host:create`** (unready local scaffold), **`host:install`** (separately confirmed destructive nixos-anywhere installation), and **`deploy:run`** (guarded host/group deployment). See [task inputs and safety boundaries](.agents/skills/devenv/references/development.md#operator-tasks). They are uncached and have no lifecycle/dependency edges. Shell entry performs no repository checks, formatting, secret loading or deployment. `devenv test` is not a validation gate.

For a guided OS reinstall from a live USB, use `devenv shell -- install bastion` on the locked Linux controller. It prompts for missing information, handles JSON/temporary manifests internally and asks for explicit erasure confirmation after plan review; all checks remain mandatory. See the [Bastion prerequisites](.agents/skills/storage-disko/references/reinstall.md#bastion-operator-reinstall--2026-09-13). This is destructive installation, not a smoke test; no automatic reboot.

Use the [validation skill](.agents/skills/validate/SKILL.md) for manual local checks and [devenv skill](.agents/skills/devenv/SKILL.md) for shell/lock details. Check ciphertext before staging or evaluating the flake: Nix copies tracked inputs into its public store.

## Architecture and procedures

`flake.nix` discovers the Nix-only `modules/` tree in one top-level flake-parts evaluation. Executable sources/tests live in `scripts/`, static data in `assets/`, grouped by concern. Features own their class-checked NixOS/Home Manager contributions, facts and tests; hosts explicitly choose one package track. Native `devenv.nix` is the sole development-only entry-point exception.

Operational guidance, architecture decisions, research and dated evidence live under [.agents/skills/](.agents/skills/README.md), not `docs/` or code comments. Start with [AGENTS.md](AGENTS.md), the matching skill and [secret handling](secrets/README.md). Pi reads the canonical skills directly; Claude Code imports the same instructions through `CLAUDE.md` and discovers linked `.claude/skills/` entries. No duplicate guidance or agent installation is required.

Deployment policy lives in `modules/deploy.nix`: restricted `deploy` SSH account on all hosts, explicit root-equivalent Nix/activation privileges, remote builds, automatic/magic rollback, and servers ordered Racknerd before Bastion. The account transition is unactivated; see the [deployment procedure](.agents/skills/deploy/SKILL.md).

Checks/builds authorize no deployment, installation, disk operation or credential access. Persistence and rollback are not backups.
