---
name: validate
description: Run the fleet canonical non-destructive formatting, static analysis, host and track evaluation, safety fixtures and deploy-rs checks before committing or deploying changes.
---

# Validate

## Purpose / when

Choose validation proportional to the actual diff; full canonical checks remain required for infrastructure code and deployment preflight. Distinguish source/evaluation correctness from actual machine commissioning and runtime acceptance.

## Prerequisites

Read `../../../AGENTS.md` and `../../../docs/validation.md`. For code/configuration checks also read `../../../devenv.nix` and [native CLI details](../../../docs/development.md), the fixture/inventory harness `../../../modules/validation.nix` and the affected concern's checks; these require Nix with flakes/nix-command, x86_64-linux, network or cached locked dependencies, and sufficient build resources. For changed APIs/tools use `nix-research` and update the research ledger if behavior has changed. For composition changes or structural refactors, use [dendritic-nix](../dendritic-nix/SKILL.md) to record the baseline and review discovery, classes, config scopes and consumer wiring before evaluation.

## Procedure

1. Inspect staged and unstaged status/diffs. For documentation-only edits, follow [whitespace, link/status and changed-snippet checks](../../../docs/validation.md#documentation-only-changes), report them and stop; no fleet check/build is required. For code, configuration, dependencies, tests, policy data or ciphertext changes, continue below. Ensure every `.nix` file except `flake.nix` and native `devenv.nix` is a top-level module under `modules/`. Stage intended new files (Git flakes ignore untracked files); do not stage unrelated changes, plaintext secrets or private identities. Run `devenv tasks run repo:secret-check` before staging intended SOPS ciphertext/public rules. Keep the lock unchanged unless updates are in scope.
2. Enter `devenv shell` (bootstrap: `nix run --no-update-lock-file .#devenv -- shell`). Run `devenv tasks run repo:fmt` to apply the official formatter; inspect formatting changes. Never run broad automatic dead-code/lint fixes without reviewing them.
3. Iterate with the fast inner gate `devenv tasks run repo:check` (seconds); run **`devenv tasks run repo:check-full`** once for the final coherent candidate (and for deployment preflight). [Canonical command and check inventory](../../../docs/validation.md#canonical-command) are maintained in `docs/validation.md`; native `devenv.nix` defines the dependency order; use the default `before` mode, never `--mode single`. Do not substitute targeted checks for this gate or run real `devenv shell tailnet` or `tailnet-sops` operations as validation.
4. Inspect reported missing facts and failed assertions. Uncommissioned hosts intentionally remain outside standard build/deploy outputs. Only explicit bootstrap/access blockers are expected; do not label new option errors, persistence duplicates, wrong tracks or invalid disks “placeholders”. A ready host must have no blockers/assertion failures.
5. For each commissioned host whose configuration/closure is affected, run `devenv shell ready HOST` and `devenv shell build HOST`. A later prose-only correction does not require rerunning unchanged builds. For an unready host, `devenv shell ready HOST` should refuse; inspect `.#fleetConfigurations.HOST.config` only for evaluation. No hardware fact may be fabricated to make a toplevel pass.
6. Current candidates are unready fresh per-host layouts; running systems are untouched. Cover all three layouts on both tracks, Limine UEFI/BIOS, early mounts, ThinkPad home/plain swap/no hibernation, fixed boot sizes and partition ordering. All public script/image aliases must reject unready/missing-review/invalid-device candidates and extra/redirected disks; non-OS destructive collections remain empty. Only synthetic approved fixtures may evaluate installer derivations. Real unready hosts must stay outside NixOS/deploy outputs; wrong tracks must fail the independent oracle. Never execute a generated script.
7. Inspect the final Git diff, lock changes, documentation/skill references and local canonical command. Feature reports/checks must still be forced through the independent inventories, not merely defined. Preserve the independent track oracle in `modules/validation.nix` and rollout oracle in `modules/tailscale/checks.nix`; test-only fixture contributions must not create a fleet host. For a structural refactor, compare the recorded baseline: relevant generated settings, exact consumers, package sources, persistence/access policy and readiness/output eligibility must remain unchanged unless explicitly in scope. Check moved asset paths, duplicated deferred imports and `_`-prefixed files, which this repository still auto-imports. Preserve native HM `nixosConfig` context while rejecting custom input/package forwarding. Avoid unsafe unknown-output suppression: custom outputs are explicitly checked, not magically understood by Nix.
8. Report exact commands/results. If unavailable due to network, cache, architecture, Nix version or build resources, record the precise remaining command and reason. Do not claim tests passed after a timeout/failure. Do not claim VM boot, physical boot, secret existence, SSH reachability, backup restore or deployment from evaluation-only tests.

## Safety

This procedure must not format, install, mount, activate remotely, reboot or deploy. Flake checks **build** activation scripts; they do not execute them. `deploy --dry-activate` is not a substitute for local validation.

## Completion criteria

The applicable validation path passes: documentation-only whitespace/link/status/snippet checks, or full formatting/lint/dead-code, host/track/safety evaluations and flake/deploy checks with affected real builds accounted for. Final diff and lock scope are reviewed. Any incomplete runtime/hardware work is explicitly separated from verified results.

## Common failures

Untracked modules, stale lock/API, wrong module class, duplicate deferred imports, assertions hidden by broad bootstrap exemptions, type-incorrect null substitutions, and accidentally retaining derivation string contexts in evaluation reports (which can turn an evaluation check into huge build dependencies). Fix the cause, not the safety policy.
