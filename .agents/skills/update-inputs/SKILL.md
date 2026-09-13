---
name: update-inputs
description: Update stable, unstable or all flake inputs independently, research upstream changes, validate affected fleet hosts and report exact locked revision changes without unrelated upgrades.
---

# Update inputs

## Purpose / when

Perform a dependency update, security refresh or stable-release migration with explicit scope and an auditable lock diff.

## Prerequisites

Read `../../../AGENTS.md`, `../../../flake.nix`, `../../../flake.lock`, `../deploy/references/operations.md#input-updates`, and `../nix-research/references/research.md`. Start with a clean/reviewed working tree and known rollback commit. Enter `devenv shell`; see [bootstrap and lock synchronization](../devenv/references/development.md#locks-and-architecture). Invoke `nix-research` before choosing branch/API changes; upstream support status must be checked anew.

## Procedure

1. Agree on scope: stable, unstable, or full. `system.stateVersion` is never updated merely because inputs move. Save current pins without overwriting user work:
   ```sh
   before=$(mktemp)
   cp flake.lock "$before"
   jq '.nodes | map_values(.locked // null)' flake.lock devenv.lock
   ```
2. **Stable update:** inspect stable/security release notes and relevant long-running service changes. Confirm the current numbered branch remains supported. For a new stable release, deliberately change the stable Nixpkgs URL, then update that input; otherwise retain its URL. Headless servers do not import Home Manager; there is no stable HM input. For a refresh within the same release, run:
   ```sh
   nix flake update nixpkgs-stable
   ```
   Focus on `racknerd` and `bastion`, including storage/boot/service compatibility. Dependencies following stable also use the new packages; unstable and developer tooling must not move.
3. **Unstable update (alternative scope):** inspect notable NixOS/module, driver, kernel, desktop and gaming changes since the pin. Keep the required `nixpkgs-unstable` branch rather than silently switching to `nixos-unstable`. Run:
   ```sh
   nix flake update nixpkgs
   ```
   Focus on `thinkpad` and developer tooling; stable and unrelated dependency source pins must not move. Synchronize the native `devenv.lock` Nixpkgs node from the flake's `nixpkgs` node. Research native CLI/module and OpenTofu/provider compatibility, including [reviewed local-mirror checksum drift](../tailscale/references/tailscale.md#opentofu-ownership-and-private-local-state) even when provider versions stay fixed; unversioned devenv source updates use `devenv update devenv` and remain separate from production source updates.
4. **Full update (alternative scope):** research all significant inputs, especially disko destructive behavior, impermanence early boot, unstable Home Manager, the Zen flake/host-pkgs recipe and target-packaged Hyprland/Noctalia/Greeter APIs, flake-parts merging and deploy-rs activation/check API. Run `nix flake update`. Review upstream transitive-lock changes as well as direct inputs; do not casually alter follows relationships.
   An explicitly scoped Home Manager-only update uses `nix flake update home-manager`; a Zen-only update uses `nix flake update zen-browser`. Both are normal default-branch flakes with revisions pinned only in `flake.lock`. Preserve their unstable follows links and Zen's instantiation with the host's own `pkgs`, not upstream package outputs. Moving unstable Nixpkgs changes HM/Zen packages without moving those input source revisions. Run the unstable desktop/ThinkPad config checks plus all both-track infrastructure checks; research the Zen recipe/wrapper API and XPI pins. Pi's extension set lives in Pi's managed `settings.packages` (pinned `npm:` specs; no local store extensions); review and test it per [Pi package management](../desktop/references/pi.md#package-management) — no vendored manifest, npm hash or patch exists anymore.
5. Review each track's latest stock 7.x kernel, support/EOL and Bastion's actual OpenZFS kernel module. Preserve the major-7 gate and upstream compatibility failures; never allow broken modules or freeze an EOL branch to pass. For **every** scope, follow [manual validation](../validate/SKILL.md), including ciphertext checks before staging/evaluation, formatting, static/tool parity, both-track/all-host evaluation and full flake checks. Build affected commissioned hosts via `devenv shell build HOST`. Missing hardware prevents real system builds, not both-track fixture checks; report that distinction.
6. Review exact before/after locked values with the jq diff command below and `git diff -- flake.nix flake.lock`. Confirm no unrelated source revisions changed for a targeted update. If they did, investigate/revert only this task's changes; do not blindly recreate the whole lock.
7. For compatibility fixes, keep generic features track-agnostic or add one verified localized API branch. Never import another track's packages as a general escape hatch. Update `.agents/skills/nix-research/references/research.md` for architectural findings and ADRs if strategy changes.
8. Report every changed node/revision/hash and indirect follows effects, tests actually run, remaining runtime/migration risks and planned deployment order. Commit only when asked. Updates and checks do not authorize deployment or disk execution.

## Lock diff

After saving the original lock in `$before` as above:

```sh
: "${before:?Save the original lock first as described above}"
jq -n --slurpfile old "$before" --slurpfile new flake.lock '
  ($old[0].nodes + $new[0].nodes | keys[]) as $k |
  select($old[0].nodes[$k].locked != $new[0].nodes[$k].locked) |
  {input: $k, before: $old[0].nodes[$k].locked, after: $new[0].nodes[$k].locked}'
```

## Completion criteria

The chosen scope is preserved, the lock is reproducible, the full canonical check passes, affected ready hosts build or have an explicitly explained environment blocker, and exact revision changes are reported.

## Common failures / safety

Unsupported stable branch, release/docs mismatch, stale CLI aliases, lock refresh moving both tracks unintentionally, Git ignoring new files, stateVersion churn, changed service data formats, or unsafe disko follow/update assumptions. Stop on failed checks; do not call a partial update production-ready.
