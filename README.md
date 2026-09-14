# NixOS fleet

Dendritic NixOS configurations for three `x86_64-linux` machines: `thinkpad` (unstable track, Hyprland/Noctalia desktop), `racknerd` and `bastion` (stable track, headless). Each host's own facts and layout live in `modules/hosts/<name>/`.

## Layout

`flake.nix` hands the whole `modules/` tree to `import-tree`, so every file in it is a top-level flake-parts module — features and host facts alike. `modules/` holds Nix only; static data lives in `assets/<concern>/`. Root `devenv.nix` is the one development-only entry point and is never imported into production.

Features own their NixOS and Home Manager contributions, persistence and host facts together. Hosts choose a package track explicitly.

## Development

```sh
nix run --no-update-lock-file .#devenv -- shell
```

The shell provides the locked toolbox — Nix, SOPS/age, a locally hardened pinned nixos-anywhere, deploy-rs's inputs and the formatters — plus two explicitly invoked tasks backed by `scripts/devenv/`. Entering it runs no fleet checks, formatting, secret loading, installation or deployment. The shell supports x86_64-linux only.

Prepare and validate local installer files explicitly (generates missing identities, preserves existing ones, never contacts the host):

```sh
devenv tasks run fleet:install --input host=racknerd --input prepare=true
```

Missing or invalid required files return nonzero with troubleshooting steps; generated files are kept for the next run. Supply `installerHost` and a console-verified `installerHostKey` to also generate private SSH configuration and `known_hosts` (optional integer `installerPort`, default 22). Your personal SSH configuration is untouched; no network scanning or trust-on-first-use is performed.

After local checks pass, preparation can explicitly upload the generated client public key using existing verified live-installer root access: add `--input authorizeKey=true --input bootstrapIdentityFile=/ABSOLUTE/PRIVATE/KEY`. This contacts the host and modifies only live-installer SSH authorization; it requires separate authorization and never starts installation. Without `authorizeKey=true`, preparation stays local.

These checks are not Nix configuration validation or installation readiness: console trust, disk/backup safety, disko review/digest equality and decryption remain operator responsibilities. See the [storage skill](.agents/skills/storage/SKILL.md) for all inputs, troubleshooting and identity preservation on reinstalls.

After completing the [installation](.agents/skills/storage/SKILL.md) or [deployment](.agents/skills/deploy/SKILL.md) prerequisites:

```sh
devenv tasks run fleet:install --input host=thinkpad
devenv tasks run fleet:deploy --input target=racknerd
devenv tasks run fleet:deploy --input target=servers
devenv tasks run fleet:deploy --input target=servers --input boot=true
```

Installation accepts any fleet host and requires private installer setup. Deployment accepts `racknerd`, `bastion`, or `servers` (Racknerd then Bastion); ThinkPad is install-only. Normal deployment switches without rebooting. `boot=true` stages and then requests a reboot for each successful target; it requires the reboot sudo permission to have been commissioned first. These commands change real machines and need separate explicit authorization.

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
