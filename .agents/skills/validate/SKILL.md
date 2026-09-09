---
name: validate
description: Run the fleet canonical non-destructive formatting, static analysis, host and track evaluation, safety fixtures and deploy-rs checks before committing or deploying changes.
---

# Validate

## Purpose / when

Canonical pre-commit/pre-deployment procedure for infrastructure edits. Distinguish source/evaluation correctness from actual machine commissioning and runtime acceptance.

## Prerequisites

Read `../../../AGENTS.md`, `../../../justfile`, `../../../modules/validation.nix`, and `../../../docs/validation.md`. Need Nix with flakes/nix-command, x86_64-linux for the current check set, network or cached locked dependencies, and sufficient build resources. For changed APIs/tools use `nix-research` and update the research ledger if behavior has changed.

## Procedure

1. Inspect `git status --short`/diff. Ensure every non-entry-point `.nix` file is a top-level module under `modules/`. Stage intended new files (Git flakes ignore untracked files); do not stage unrelated changes, plaintext secrets or private identities. Run `just secret-check` before staging intended SOPS ciphertext/public rules. Keep the lock unchanged unless updates are in scope.
2. Enter `nix develop --no-update-lock-file`. Run `just fmt` to apply the official formatter; inspect formatting changes. Never run broad automatic dead-code/lint fixes without reviewing them.
3. Run **`just check`**, whose order is:
   - `just secret-check`: encrypted host payload shape and exact recipient-rule matching, without decryption or printing values. This does not establish a valid MAC/hash or identity custody.
   - `treefmt --ci`: formatting check.
   - `statix check .`, `deadnix --fail .`, `shellcheck scripts/*.sh`: syntax/dead-code/shell checks.
   - `nix eval --no-update-lock-file --json .#validation`: every real composition report and package/`/etc`/initrd derivation, independent host-track mapping, actual package-source and locked-branch assertions, exact capability-subset fixtures, both-track existing-installation Limine/migration/provisioning-output rejection and headless security/power checks, plus the separate fresh-install UEFI/BIOS and negative disk/ESP tests. SOPS fixtures additionally check both-track early password ordering, target-package sourcing and missing/unsafe credential/identity rejection. Desktop fixtures check track-matched Home Manager, single-session shell ownership, fresh profile isolation, authenticated login and desktop-review gating; actual ThinkPad home activation is also evaluated.
   - `nix flake check --no-update-lock-file -L`: standard output evaluation and built check derivations, including malformed-ciphertext guard regressions, built SOPS users manifests (parsing/key selection only, never decryption), native generated Hyprland/Noctalia config validation on both tracks and ThinkPad (no compositor session), upstream deployment schema/activation checks and both-track non-empty smoke payloads.
4. Inspect reported missing facts and failed assertions. Uncommissioned hosts intentionally remain outside standard build/deploy outputs. Only explicit bootstrap/access blockers are expected; do not label new option errors, persistence duplicates, wrong tracks or invalid disks “placeholders”. A ready host must have no blockers/assertion failures.
5. For each affected commissioned host, run `just ready HOST` and `just build HOST`. For an unready host, `just ready HOST` should refuse; inspect `.#fleetConfigurations.HOST.config` only for evaluation. No hardware fact may be fabricated to make a toplevel pass.
6. For current existing installations, all public disko script/image/install-test outputs must remain rejected even after synthetic commissioning; no disk/LVM-create/MD/ZFS-create nodes may appear. Validate preserved separate `/home`, Limine EFI/BIOS and migration-review gating. For fresh-install storage/readiness/deployment changes, exercise negative cases: unconfirmed/partition/missing device must not yield a destructive disk configuration; an unready host must not enter `nixosConfigurations`/`deploy.nodes`; wrong track metadata/wiring must fail the independent oracle. Never execute generated scripts to test a guard.
7. Inspect the final Git diff, lock changes, documentation/skill references and CI command. Avoid unsafe unknown-output suppression: custom outputs are explicitly checked, not magically understood by Nix.
8. Report exact commands/results. If unavailable due to network, cache, architecture, Nix version or build resources, record the precise remaining command and reason. Do not claim tests passed after a timeout/failure. Do not claim VM boot, physical boot, secret existence, SSH reachability, backup restore or deployment from evaluation-only tests.

## Safety

This procedure must not format, install, mount, activate remotely, reboot or deploy. Flake checks **build** activation scripts; they do not execute them. `deploy --dry-activate` is not a substitute for local validation.

## Completion criteria

Formatting/lint/dead-code, all host/track/safety evaluations and flake/deploy checks pass; affected real builds are accounted for; final diff and lock scope are reviewed. Any incomplete runtime/hardware work is explicitly separated from verified results.

## Common failures

Untracked modules, stale lock/API, wrong module class, duplicate deferred imports, assertions hidden by broad bootstrap exemptions, type-incorrect null substitutions, and accidentally retaining derivation string contexts in evaluation reports (which can turn an evaluation check into huge build dependencies). Fix the cause, not the safety policy.
