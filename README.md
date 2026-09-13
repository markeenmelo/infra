# NixOS fleet

Dendritic NixOS configurations for three `x86_64-linux` machines: `thinkpad` (unstable track, Hyprland/Noctalia desktop), `racknerd` and `bastion` (stable track, headless). Each host's own facts, layout and readiness live in `modules/hosts/<name>/`.

## Layout

`flake.nix` hands the whole `modules/` tree to `import-tree`, so every file in it is a top-level flake-parts module — features, host facts and tests alike. `modules/` holds Nix only; executables and their tests live in `scripts/<concern>/`, static data in `assets/<concern>/`. Root `devenv.nix` is the one development-only entry point and is never imported into production.

Features own their NixOS and Home Manager contributions, persistence, host facts and checks together. Hosts choose a package track explicitly.

## Development

```sh
nix run --no-update-lock-file .#devenv -- shell
```

The shell provides the locked toolbox, the `ready`, `build`, `disk-plan`, `deploy`, `tailnet` and `tailnet-sops` scripts, and three explicitly invoked tasks: `host:create` (local scaffold), `host:install` (confirmed destructive nixos-anywhere installation) and `deploy:run` (guarded deployment). Entering the shell runs no checks, formatting, secret loading or deployment, and `devenv test` is not a validation gate.

Run `bash scripts/secrets/check.sh` before staging encrypted files or evaluating the flake — Nix copies tracked files into the public store. `bash scripts/devenv/preflight.sh` runs the full report-only check sequence.

## Where things are documented

[AGENTS.md](AGENTS.md) is the shared contract, [.agents/skills/](.agents/skills/README.md) holds the procedures, and [secrets/README.md](secrets/README.md) covers secret handling. Deployment policy — the dedicated `deploy` account, groups, remote builds and rollback — lives in `modules/deploy.nix`.

Checks and builds authorize no deployment, installation, disk operation or credential access. Persistence and rollback are not backups.
