---
name: devenv
description: Maintain the native locked toolbox and explicit scaffold, installation and deployment tasks without automatic operations, credential loading or production package mixing.
---

# Native development environment

Read `../../../AGENTS.md`, `../../../devenv.nix`, `../../../devenv.yaml`, both locks and [development details](references/development.md). [ADR 0010](../dendritic-nix/references/adr/0010-native-devenv.md) records the native entry-point exception and explicitly requested task amendment.

## Procedure

1. Check ciphertext before copying tracked inputs into the store, then bootstrap with `nix run --no-update-lock-file .#devenv -- shell`. Use the matching locked CLI. Commands run from the repository root; use `devenv shell -- bash -c 'COMMAND'` when passing shell flags so `-c` is not interpreted as the clean flag.
2. Retain unstable tools, `stdenvNoCC`, explicit Nix and exact OpenTofu/provider parity. No parallel devShell, production import, second package universe, application service or automatic package installation.
3. Exactly three repository tasks are now requested: `host:create`, `host:install` and `deploy:run`. They have null-default public inputs, no cache/status rules and no DAG/lifecycle edges. Source bodies live in `../../../scripts/devenv/`; feature helpers/tests live in concern-specific `scripts/` directories. Do not restore the old repo task graph, automatic formatter, hooks or test-entry gate. `devenv test` remains no validation gate.
4. Scaffolding only writes new untracked/unready files. Installation and deployment require exact confirmations, a clean reviewed commit and synchronous full local preflight before target contact. Installation is a separate destructive live-installer operation with device/identity/plan-hash checks; deployment uses the dedicated account and explicit ordered targets. Neither task may pull the other into its graph.
5. Keep `ready`, `build`, `disk-plan`, `deploy`, `tailnet` and `tailnet-sops` scripts. Deploy now uses the same guarded body as its task; no raw passthrough/override escape exists. Readiness/build/disk-plan remain local. Follow the corresponding storage/deploy/Tailscale skill before any live operation.
6. Preserve dotenv/SecretSpec disablement and private runtime state. Task inputs contain no passwords, private key contents or secret paths; installer key/staging paths are explicit runtime environment variables outside the checkout/store. No evaluation, shell entry or test decrypts secrets.
7. Research locked APIs before changes. Follow [validation](../validate/SKILL.md), including the actual native `DEVENV_TASK_FILE` contract, offline workflow regressions, native/flake pin parity and full flake checks. Shell entry alone proves none of these.

## Completion

Report exact tooling/task validation, lock scope and remaining runtime acceptance. No local check authorizes activation, installation, credential access, disk actions or live API operations; do not change local hooks or assistant settings as a side effect.
