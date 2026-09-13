---
name: devenv
description: Maintain the native development toolbox and synchronized locks without adding repository tasks, automatic operations or production package mixing.
---

# Native development environment

Read `../../../AGENTS.md`, `../../../devenv.nix`, `../../../devenv.yaml`, both locks and [development details](references/development.md). The native entry-point exception is retained in [ADR 0010](../dendritic-nix/references/adr/0010-native-devenv.md).

## Procedure

1. Bootstrap with `nix run --no-update-lock-file .#devenv -- shell`, or use the matching locked `devenv shell`. Commands run from the repository root. Use `devenv shell -- bash -c 'COMMAND'` when passing shell flags; without `--`, `-c` can be mistaken for devenv's clean flag.
2. Keep the toolbox on unstable, `stdenvNoCC`, and explicit `pkgs.nix` for clean-shell use. No parallel devShell, production import, second package universe, application service or automatic dependency installation.
3. Repository-defined tasks, the live deployment task, task contract, task-dependent fleet wrapper, `enterTest` gate and optional hooks profile were removed on 2026-09-13. **Do not replace them yet.** Native devenv lifecycle tasks may still appear; they are not repository checks. The treefmt integration was removed because it registers an automatic formatting task.
4. Existing `ready`, `build`, `disk-plan`, `deploy`, `tailnet` and `tailnet-sops` scripts remain. They are not task replacements. Readiness/build/plan construction are local; raw `deploy` is not a guarded full preflight. Use the matching deployment/storage/Tailscale skill before operator commands.
5. Keep dotenv/SecretSpec disabled; never load credentials into Nix, shell entry, direnv caches or test output. Runtime SOPS delivery belongs only to the explicit guarded child process.
6. Preserve exact native/flake unstable-lock and OpenTofu/provider wrapper parity. Research API changes at the pin, then use [manual validation](../validate/SKILL.md). Shell entry and `devenv test` do not establish a passing gate.

## Safety / completion

No local shell/check operation authorizes credentials, live API access, remote activation or disks. Report shell/tool compatibility, lock scope and actual checks; do not invent replacement tasks or silently install/uninstall local hooks.
