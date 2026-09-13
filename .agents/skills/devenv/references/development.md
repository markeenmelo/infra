# Native devenv

## Start

From the repository root:

```sh
nix run --no-update-lock-file .#devenv -- shell
```

The shell supplies the locked unstable CLI/toolbox, no default compiler (`stdenvNoCC`), explicit Nix, Nix/Bash language servers, Python, SOPS/age and the exact checked OpenTofu/provider wrapper plus `tofu-ls`. No host imports this development environment. ThinkPad's desktop also packages devenv for other projects.

**2026-09-13: all repository tasks removed; replacements deferred.** No repository task graph, task contract, live deployment task, fleet-deploy wrapper, optional hooks profile or `enterTest` gate remains. Native devenv lifecycle tasks are implementation details, not validation. `devenv test` no longer runs repository checks. The treefmt integration and its direct lock input were removed because enabling it automatically registers a shell-entry task; `pkgs.nixfmt-tree` still supplies a Nix-only `treefmt` wrapper.

Use `devenv shell -- bash -c 'COMMAND'` for shell flags: without the separator, `-c` can be parsed as devenv's global clean flag. Check actual output/exit status, not merely a quiet successful shell entry.

## Existing scripts

| Command | Boundary |
|---|---|
| `devenv shell ready HOST` | Local commissioning checks only |
| `devenv shell build HOST` | Readiness then local system build |
| `devenv shell disk-plan HOST` | Local guarded script construction, never execution |
| `devenv shell deploy ...` | Raw locked deploy-rs; **no automatic full preflight** |
| `devenv shell tailnet OPERATION` | Guarded operator workflow; live API/state actions need authorization |
| `devenv shell tailnet-sops ENCRYPTED.yaml OPERATION` | Explicit private runtime credential delivery into that workflow |

These scripts predate task removal; none is a replacement task. Follow [manual validation](../../validate/SKILL.md), including ciphertext inspection **before** staging/evaluation. Then use the matching [deployment](../../deploy/SKILL.md), [storage](../../storage-disko/SKILL.md) or [Tailscale](../../tailscale/SKILL.md) procedure. Shell/build scripts do not supply the removed task graph's automatic ciphertext checks.

`.envrc` uses the installed CLI's `devenv direnvrc`, not downloaded shell code. Review before `direnv allow`. Never load secrets into its cached environment. Existing local hooks installed by the deleted opt-in profile may remain on an operator machine; inspect them and request separate removal if needed, rather than modifying `.git/hooks` automatically.

## SOPS → OpenTofu

Use the [private state, scopes and recovery procedure](../../tailscale/references/tailscale.md#operator-setup-private-terminal-only). Do not recreate existing state, rotate its passphrase or repeat completed imports.

The separately reviewed operator YAML must contain exactly:

- `TAILSCALE_OAUTH_CLIENT_ID`
- `TAILSCALE_OAUTH_CLIENT_SECRET`
- `TF_VAR_state_passphrase`

Values must be nonempty single-line strings; use the existing independently recoverable passphrase (at least 32 characters). Keep read-only/write clients in separate reviewed ciphertext files, outside the checkout unless separately reviewed recipient rules/structural validation are added. Use an operator identity, never a host password/Wi-Fi file. No real operator ciphertext or identity is supplied here.

In a private terminal, before providing runtime paths:

```sh
devenv --clean shell -- bash --noprofile --norc
```

Set `TAILSCALE_STATE_DIR` to the existing reviewed private directory, `TAILSCALE_SOPS_FILE` to the reviewed ciphertext path and, if needed, `SOPS_AGE_KEY_FILE` to the operator identity path. A path proves no readiness. Only after read-only API authorization:

```sh
tailnet-sops "$TAILSCALE_SOPS_FILE" verify
```

The adapter refuses inherited credential exports/debugging, MAC-decrypts through native SOPS with captured sanitized diagnostics, parses JSON as data, accepts exactly the three keys and replaces itself with the guarded wrapper. Values stay child memory/environment, not shell exports, argv, plaintext files or cached output. No sourced decrypted shell text or OpenTofu SOPS data source. Same-user/root inspection remains possible; do not launch an agent/editor from the credential-bearing child.

`verify` preserves 0=no changes, 2=drift, 1=error without saving a plan. Init/import/plan/apply still require their own operation review; credential loading authorizes none of them. Preserve the encrypted [emergency-state fallback](../../tailscale/references/tailscale.md#emergency-state-recovery).

## Locks and architecture

[ADR 0010](../../dendritic-nix/references/adr/0010-native-devenv.md) retains the development-only exception. Production inputs and unstable bootstrap packages belong to `flake.lock`; native sources belong to `devenv.lock`. Both Nixpkgs nodes must match exactly. Never change host tracks or grant Nix trust to bypass a tooling failure.

After an authorized unstable input update, synchronize only the public native Nixpkgs node:

```sh
python3 - <<'PY'
import json
from pathlib import Path
path = Path('devenv.lock')
lock = json.loads(path.read_text())
lock['nodes']['nixpkgs'] = json.loads(Path('flake.lock').read_text())['nodes']['nixpkgs']
path.write_text(json.dumps(lock, indent=2) + '\n')
PY
```

Research CLI/module and OpenTofu/provider compatibility; review every lock delta and run manual checks. `devenv update devenv` is a scoped native-source update; `devenv update` is broader and may advance Nixpkgs independently. The git-hooks input remains an upstream module dependency, not an enabled local hooks profile. Keep production deploy-rs/sops-nix inputs: host activation and secret-delivery modules consume them independently of development tooling.
