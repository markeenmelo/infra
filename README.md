# NixOS fleet

Dendritic NixOS configurations for three `x86_64-linux` machines: `thinkpad` (unstable track, Hyprland/Noctalia desktop), `racknerd` and `bastion` (stable track, headless). Each host's own facts and layout live in `modules/hosts/<name>/`.

## Layout

`flake.nix` hands the whole `modules/` tree to `import-tree`, so every file in it is a top-level flake-parts module — features and host facts alike. `modules/` holds Nix only; static data lives in `assets/<concern>/`. Root `devenv.nix` is the one development-only entry point and is never imported into production.

Features own their NixOS and Home Manager contributions, persistence and host facts together. Hosts choose a package track explicitly.

## Development

```sh
nix run --no-update-lock-file .#devenv -- shell
```

The shell provides the locked toolbox and nothing else — Nix, SOPS/age, nixos-anywhere, deploy-rs's inputs and the formatters. It defines no scripts, tasks or hooks; entering it runs no checks, formatting, secret loading or deployment.

Inspect and build with the flake directly:

```sh
nix fmt
nix flake check --no-update-lock-file -L
nix eval --no-update-lock-file --json .#fleet | jq 'map_values({track,osDisk})'
nix build --no-update-lock-file --no-link .#nixosConfigurations.HOST.config.system.build.toplevel
```

`nix flake check` builds no checks; it only evaluates the flake's outputs. Nothing in this repository verifies SOPS ciphertext shape or recipients, module layout, deployment-account policy or generated desktop configuration — review those by hand. Nix copies tracked files into the public store, so read any encrypted file before staging it.

## Where things are documented

[AGENTS.md](AGENTS.md) is the shared contract, [.agents/skills/](.agents/skills/README.md) holds the procedures, and [secrets/README.md](secrets/README.md) covers secret handling. Deployment policy — the dedicated `deploy` account, remote builds and rollback for racknerd and bastion — lives in `modules/deploy.nix`.

Evaluation and builds authorize no deployment, installation, disk operation or credential access. Persistence and rollback are not backups.
