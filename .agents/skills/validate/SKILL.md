---
name: validate
description: Run manual non-destructive formatting, ciphertext, static, fleet and flake validation after task removal; distinguish local checks from real host acceptance.
---

# Validate

Read `../../../AGENTS.md`, the actual staged/unstaged diff, [check scope and historical evidence](references/validation.md), `../../../modules/validation.nix` and affected feature checks. Repository devenv tasks were removed on 2026-09-13; **do not recreate them or use `devenv test` as a gate**.

## Documentation-only changes

1. Run `git diff --check` and `git diff --cached --check`; review intended changes and lock/status scope.
2. Check local Markdown links/anchors, skill frontmatter and claims against [dated host status](../fleet-operations/references/hosts.md#current-status). Historical evidence is not current authorization.
3. Check changed snippets without executing operations: `bash -n`/ShellCheck for complete shell blocks, strict JSON parsing, isolated Nix parse/option-shape checks as applicable. No deployment, disk, secret or live-service command is a documentation test.
4. Report results. Prose-only changes need no fleet check/build.

## Code, configuration, dependency, test or ciphertext changes

Run from the repository root in `devenv shell` (bootstrap: `nix run --no-update-lock-file .#devenv -- shell`). Tools/checks support `x86_64-linux`. For refactors first capture the baseline per [dendritic-nix](../dendritic-nix/SKILL.md).

1. **Before staging ciphertext or evaluating the flake**, run the [manual ciphertext guard](references/ciphertext.md) in the current shell. It checks ambiguous YAML, encrypted payload shape and exact public recipients without decryption or value output. Review other intended new files for secrets and stage only those files: Git flakes ignore untracked inputs. Never stage identities/plaintext/unrelated work.
2. Apply the existing formatters explicitly, inspect changes, then run report-only static checks. The shell's `treefmt` is now the packaged **Nix-only** wrapper, not the removed multi-language integration:

   ```sh
   treefmt
   tofu fmt -recursive tofu
   treefmt --ci
   tofu fmt -check -recursive tofu
   statix check .
   deadnix --fail .
   find modules -name '*.sh' -print0 | xargs -0 shellcheck .envrc
   ```

   Do not run unreviewed broad automatic lint/dead-code fixes.
3. Verify tooling without updating inputs, after the ciphertext guard:

   ```sh
   jq -e --slurpfile flake flake.lock \
     '.nodes.nixpkgs.locked == $flake[0].nodes.nixpkgs.locked' devenv.lock >/dev/null
   jq -e '.nodes.devenv.original == {owner: "cachix", repo: "devenv", type: "github"}' devenv.lock >/dev/null
   packaged=$(nix eval --no-update-lock-file --raw .#packages.x86_64-linux.tailscale-tofu)
   test "$(readlink -f "$(command -v tofu)")" = "$packaged/bin/tofu"
   ```

   Inspect native shell/task inventory after development changes: no repository/deployment/treefmt tasks, no local hook installation, no credential loading. Native lifecycle tasks can remain. Do not grant trust or add another package set to repair a failure.
4. Run the malformed-input regression block in [ciphertext checks](references/ciphertext.md#regressions), then serialize the local fleet/evaluation/full-flake commands; do not race Nix's eval-cache database:

   ```sh
   nix eval --no-update-lock-file --json .#fleet | jq 'map_values({track,revision,ready,missing,failedAssertions})'
   nix eval --no-update-lock-file --json .#validation | jq '{hosts,fixtures,compositions,storageLayouts,sops,desktop,wifi,tailscale}'
   nix flake check --no-update-lock-file -L
   ```

   Run the full sequence once for the final coherent candidate and before deployment; targeted tests are only iteration. Use `set -euo pipefail` for automation so pipeline failures cannot be hidden. No replacement task runner is provided.
5. Inspect real blockers/assertions. Only documented bootstrap/client-setting/custom-output/deprecated-alias diagnostics are expected. Do not suppress new option, track, disk, persistence or credential failures. Both-track fixtures remain synthetic; all public disko aliases reject unready/missing-review/extra/redirected-device cases. Only native disk scripts have positive fixture expectations; VM/image variants may correctly refuse under real access/device guards. Never execute a generated script.
6. For affected commissioned closures, run `devenv shell ready HOST` and `devenv shell build HOST`. ThinkPad's unready candidate must refuse; inspect only `fleetConfigurations` for its evaluation. No false facts/reviews to get a build.
7. Compare refactor baselines: host facts/track/readiness/output sets, packages, access, mounts and persistence. Inspect expected derivation changes from immutable script/comment paths. Preserve the independent track/rollout/check inventories, native HM `nixosConfig` and stable SSH module key. `/_` paths are excluded helpers, not discovered modules.
8. Review the full diff, locks, skill references and source placement. Report exact commands, exits, corrected failures and remaining unknowns; a timeout or failed run is not success. Do not claim real boot, credential validity, network reachability, backup restore, installation or deployment from pure fixtures.

## Completion

The applicable manual path passes, affected ready-host builds are accounted for and no unauthorized operation occurred. If blocked by resources/network/platform, report the precise uncompleted command and reason; do not call an incomplete candidate validated.
