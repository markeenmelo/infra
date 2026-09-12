# Native devenv

## Start

```sh
nix run --no-update-lock-file .#devenv -- shell
```

This fetches/builds the **locked unstable CLI** and enters the native environment; it does not install a profile or activate a host. The ThinkPad desktop also includes `devenv` in Marcos's normal user profile: after activating that configuration, the CLI is available from any directory, including other projects. Use `devenv shell` in an existing devenv project, or `devenv init` to initialize a new one. Other machines can still use the bootstrap command above.

The shell uses `pkgs.stdenvNoCC`, retaining the previous `mkShellNoCC` behavior: no default C compiler toolchain in the developer shell. Nix system/package builds still get their own build dependencies. The Nix CLI is explicitly packaged, so checks/build commands also work under `--clean`. The [Nix recipe](https://devenv.sh/recipes/nix/#nix-patterns) does not justify adding a second package set, overlays or extra PATH hooks here.

Inside the environment:

```sh
devenv tasks list
devenv tasks run repo:fmt
devenv tasks run repo:check
```

`devenv test` runs the same canonical check. No application processes/services are configured. The first environment build requires network/cache access; subsequent entries use devenv's evaluation cache. **Safety tasks themselves are never cached.** A repository assertion matches the CLI to the locked package version; use the bootstrap command if another installed version differs. The devenv source URL is unversioned, with its exact revision in `devenv.lock`; native execution tests establish compatibility instead of relying on upstream's occasionally stale version marker.

When passing command flags, separate them from devenv's global flags:

```sh
devenv shell -- bash -c 'tofu version'
```

Without `--`, `bash -c` can be parsed as devenv's global `--clean`, silently dropping the intended command. For log-visible automation use `devenv --no-tui --verbose tasks run repo:check`; inspect task completion and the exit status, not just a quiet invocation.

## Commands replacing just

Run from the repository root. These tasks need no production credentials:

| Previous recipe | Native command |
|---|---|
| `just fmt` / `just format-check` | `devenv tasks run repo:fmt` / `repo:format-check` |
| `just lint` / `just evaluate` | `devenv tasks run repo:lint` / `repo:evaluate` |
| `just check` | **`devenv tasks run repo:check`** |
| `just inventory` / `just revisions` | `devenv tasks run repo:inventory` / `repo:revisions` |
| `just secret-check` / `just secret-check-tests` | `devenv tasks run repo:secret-check` / `repo:secret-check-tests` |
| `just tailscale-inventory` / `just tailscale-check` | `devenv tasks run repo:tailscale-inventory` / `repo:tailscale-check` |

In rows with two tasks, repeat the full `devenv tasks run` prefix. `repo:tooling-check` independently checks the native task graph, uncached gates, unstable lock and exact OpenTofu/provider package. Native dependency mode defaults to `before`; **never use `--mode single` for canonical validation**. Run individual task names, not the whole `repo` namespace: formatting and format-check should not run concurrently.

Argument-taking commands are scripts, usable inside the shell or through `devenv shell`:

| Previous recipe | Native command | Boundary |
|---|---|---|
| `just ready HOST` | `devenv shell ready HOST` | Local preflight only |
| `just build HOST` | `devenv shell build HOST` | Readiness, then local build |
| `just disk-plan HOST` | `devenv shell disk-plan HOST` | Refuses every current existing installation |
| `just deploy HOST` / `just deploy-fleet` | `devenv shell deploy-host HOST` / `devenv shell deploy-fleet` | Full check first; **real deployment**, separate authorization |
| `just tailnet OPERATION` | `devenv shell tailnet OPERATION` | Existing guarded operator workflow; API/state operations need authorization |

The `deploy` script invokes the flake's source-matched deploy-rs package; raw deploy remains operator-only. Keep `deploy-rs` and `sops-nix` in the production flake: the fleet needs their activation helpers and NixOS modules independently of devenv. The development environment only exposes the deploy CLI and SOPS/age binaries. No deploy, SOPS decryption, OpenTofu init/import/plan/apply or disk operation is a task dependency or shell hook. Historical validation records retain the old commands that actually ran; this table is their current equivalent. System-wide `just` available for unrelated projects is not removed or activated by this local migration.

## SOPS → OpenTofu

Use the existing [tailnet state, permissions, scopes and recovery procedure](tailscale.md#operator-setup-private-terminal-only). **Do not recreate existing state, rotate its passphrase or repeat imports.** The existing environment-input `tailnet` command remains available.

For SOPS delivery, the operator must separately prepare/review an encrypted YAML file containing **exactly** these keys:

- `TAILSCALE_OAUTH_CLIENT_ID`
- `TAILSCALE_OAUTH_CLIENT_SECRET`
- `TF_VAR_state_passphrase`

Values must be nonempty single-line strings; the passphrase must be the existing, independently recoverable value (at least 32 characters). Keep read-only and write clients in separately reviewed encrypted files. Use an operator identity, not a host identity or host password/Wi-Fi file. This migration supplies **no real operator ciphertext, identity or recipient rule**. Keep that file outside the checkout unless its exact public-recipient policy and structural checks are added in a separately reviewed change. Never put plaintext, `.env`, private keys or decrypted editor backups in Git/store inputs.

In a **private terminal**, enter a clean environment before providing the reviewed runtime paths:

```sh
devenv --clean shell -- bash --noprofile --norc
```

Set `TAILSCALE_STATE_DIR` to the existing reviewed private directory and, if needed, `SOPS_AGE_KEY_FILE` to the reviewed operator identity path. Neither path proves readiness. Once those are set and read-only API access is authorized:

```sh
tailnet-sops "$TAILSCALE_SOPS_FILE" verify
```

Set `TAILSCALE_SOPS_FILE` to your reviewed encrypted YAML path first. The adapter requires an explicit operation and refuses existing OAuth/passphrase exports and debug/tracing. It MAC-decrypts through native SOPS, accepts only the three allowed keys, and replaces itself with the **unchanged guarded wrapper**. Values remain subprocess memory/environment, not shell exports, command arguments, plaintext files or devenv task outputs. Do not call this through tasks, trace it, or launch an agent/editor from its credential-bearing child. Environment delivery is not protection against same-user/root inspection; recovery custody still matters.

`verify` preserves native status **0 = no changes, 2 = drift, 1 = error** without saving a plan. `plan`, `apply`, imports and init retain their existing explicit-operation guards; SOPS loading does not authorize any of them. No SOPS data-source provider is added, so OAuth credentials are not modeled as state resources. State/plans retain enforced encryption and the existing [emergency-state recovery](tailscale.md#emergency-state-recovery) exception.

## Additional repo integrations

- **OpenTofu editing:** native `languages.opentofu` supplies the exact checked offline provider wrapper and `tofu-ls`; no auto-init or live validation hook.
- **Nix/Bash editing:** `nixd`, `bash-language-server`, official nixfmt, statix, deadnix and ShellCheck are available to project-launched editors.
- **Existing tests:** Python helpers, Pi extension tests, desktop config tests, SOPS guards and offline Tailscale fixtures remain in the canonical flake checks; no new test framework or automatic npm install.
- **Optional Git hooks:** `devenv --profile hooks shell` installs local nixfmt/statix/deadnix/ShellCheck and ciphertext-recipient hooks. This is explicit opt-in and may replace a pre-existing pre-commit hook; inspect existing hooks first. Hooks are not full fleet validation. After leaving that profile the installed hook still exists until deliberately uninstalled with the hook runner.
- **Optional direnv:** with the locked CLI and direnv installed, review `.envrc` and run `direnv allow`. It invokes `devenv direnvrc`, not a downloaded script. No secrets are loaded into direnv's cached environment.

## Locks and architecture

[ADR 0010](adr/0010-native-devenv.md) records the native development entry-point exception. `devenv.nix` is not imported into the production flake. `modules/` retains its feature-owned top-level flake-parts modules, scripts, checks and independent track/readiness oracles. Host tracks and package-source revisions remain unchanged. The unstable flake input is now named `nixpkgs`; flake-parts follows it, and `nixpkgs-stable` remains explicit.

`flake.lock` owns production inputs and the unstable bootstrap CLI. `devenv.lock` owns native module/hooks sources and must contain the **same Nixpkgs node** as `flake.lock`'s `nixpkgs`. Both URLs select `nixpkgs-unstable`. After an authorized unstable update (`nix flake update nixpkgs`), synchronize that public lock node exactly (no package update is performed by this snippet):

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

Review the diff and run native formatting/canonical checks. If unstable changes the CLI or OpenTofu/provider version, research compatibility and rerun the native and offline checks. `devenv update devenv` updates the unversioned native source; `devenv update git-hooks` updates only development hooks; `devenv update` is broader and can advance Nixpkgs independently, so it is not a substitute for the [production update procedure](operations.md#input-updates). Do not accept lock drift, add Nix trusted-user access or enable another package universe to bypass a failure.
