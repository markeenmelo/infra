---
name: devenv
description: The development shell, its scripts and tasks, the local validation sequence, and flake input updates. Use to run checks, validate a change before handoff, enter or maintain the toolbox, or update nixpkgs and other inputs.
---

# Toolbox, checks and updates

Enter the shell from the repository root:

```sh
nix run --no-update-lock-file .#devenv -- shell
```

`devenv.nix` is the one development-only entry point; it is never imported into production. It supplies unstable tooling, `stdenvNoCC`, Nix, SOPS/age, nixos-anywhere and the exact packaged OpenTofu/provider wrapper. Pass shell flags as `devenv shell -- bash -c 'COMMAND'`, otherwise `-c` is parsed as devenv's own clean flag. Shell entry runs no checks, formatting, secret loading or deployment.

Scripts: `ready HOST`, `build HOST`, `disk-plan HOST` (all local), `deploy`, `tailnet`, `tailnet-sops`. Tasks: `host:create`, `host:install`, `deploy:run` — uncached, null-default inputs, no dependency edges, never invoked by shell entry. `devenv test` is not a validation gate. Script bodies live in `scripts/devenv/`.

## Validating a change

**Before staging ciphertext or evaluating the flake**, run the ciphertext guard — Nix copies tracked files into the public store, and a later check cannot undo that:

```sh
bash scripts/secrets/check.sh
```

Stage only the new files you reviewed; a Git flake ignores untracked ones. Then apply formatting and inspect what it changed:

```sh
treefmt
tofu fmt -recursive tofu
```

Then run the whole report-only sequence:

```sh
bash scripts/devenv/preflight.sh
```

It re-runs the ciphertext guard and its regressions, the native task contract, `treefmt --ci`, `tofu fmt -check`, `statix`, `deadnix`, `shellcheck`, the guidance check, lock and tool parity, the fleet and validation reports, and `nix flake check`. It changes no files and contacts nothing. For each affected commissioned host also run `devenv shell ready HOST` and `devenv shell build HOST`; ThinkPad is unready and must refuse.

Documentation-only changes need `git diff --check`, working links and claims, and a syntax check of any changed snippet — no fleet build.

Report the exact commands and results. A timeout or failure is not a pass, and none of this proves boot, credentials, networking or backups.

## Updating inputs

Research the upstream change at the current pin before editing anything dependency-sensitive: read the project's own manual and the module source at the locked revision, and confirm a stable branch is still supported rather than assuming from the calendar.

Pick one scope and keep it: `nix flake update nixpkgs-stable` (servers, currently `nixos-26.05`), `nix flake update nixpkgs` (ThinkPad and tooling, which must stay on `nixpkgs-unstable`), or a full `nix flake update`. Save `flake.lock` first and diff every changed node afterwards; a targeted update must not move unrelated revisions.

After an unstable update, copy `flake.lock`'s `nixpkgs` node into `devenv.lock` so the toolbox matches — `scripts/devenv/preflight.sh` enforces that parity. `devenv update devenv` is a separate native-source update.

`system.stateVersion` is a migration boundary, never an update knob. Run the full sequence above plus builds for affected hosts, and report exactly which revisions moved. An update authorizes no deployment.
