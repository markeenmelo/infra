---
name: validate
description: Run the fleet canonical non-destructive formatting, static analysis, host and track evaluation, safety fixtures and deploy-rs checks before committing or deploying changes.
---

# Validate

## Purpose / when

Choose validation proportional to the actual diff; full canonical checks remain required for infrastructure code and deployment preflight. Distinguish source/evaluation correctness from actual machine commissioning and runtime acceptance.

## Prerequisites

Read `../../../AGENTS.md` and `../../../docs/validation.md`. For code/configuration checks also read `../../../justfile` and `../../../modules/validation.nix`; these require Nix with flakes/nix-command, x86_64-linux, network or cached locked dependencies, and sufficient build resources. For changed APIs/tools use `nix-research` and update the research ledger if behavior has changed.

## Procedure

1. Inspect staged and unstaged status/diffs. For documentation-only edits, follow [whitespace, link/status and changed-snippet checks](../../../docs/validation.md#documentation-only-changes), report them and stop; no fleet check/build is required. For code, configuration, dependencies, tests, policy data or ciphertext changes, continue below. Ensure every non-entry-point `.nix` file is a top-level module under `modules/`. Stage intended new files (Git flakes ignore untracked files); do not stage unrelated changes, plaintext secrets or private identities. Run `just secret-check` before staging intended SOPS ciphertext/public rules. Keep the lock unchanged unless updates are in scope.
2. Enter `nix develop --no-update-lock-file`. Run `just fmt` to apply the official formatter; inspect formatting changes. Never run broad automatic dead-code/lint fixes without reviewing them.
3. Run **`just check`** once for the final coherent candidate (and for deployment preflight), whose order is:
   - `just secret-check`: encrypted host payload shape and exact recipient-rule matching, without decryption or printing values. This does not establish a valid MAC/hash or identity custody.
   - `treefmt --ci`: formatting check.
   - `statix check .`, `deadnix --fail .`, `shellcheck scripts/*.sh`: syntax/dead-code/shell checks.
   - `nix eval --no-update-lock-file --json .#validation`: every real composition report and package/`/etc`/initrd derivation, independent host-track mapping, actual package-source and locked-branch assertions, exact capability-subset fixtures, both-track existing-installation Limine/migration/provisioning-output rejection and headless security/power checks, plus the separate fresh-install UEFI/BIOS and negative disk/ESP tests. SOPS fixtures additionally check both-track early password ordering, target-package sourcing and missing/unsafe credential/identity rejection. Desktop fixtures are deliberately unstable-only and check native Home Manager, greeter/password-first PAM/locking policy, keyring hooks, app ownership, fresh profile isolation and commissioning gates; actual ThinkPad home activation is also evaluated. Headless hosts must not import HM. ThinkPad's native printer provisioning must have no boot dependency/timer/restart-on-rebuild and must retain persistent CUPS queues/PPDs. All real kernel/initrd and Bastion ZFS-module derivations are forced with own-track/latest-stock/major-7 checks. Wi-Fi checks preserve TLS/name validation, runtime secrets and absent-campus-credential blocking. Home Manager/Zen must remain default-branch flakes with the intended follows links; nh must be ThinkPad-only with its known checkout, own package and no cleanup unit/timer.
   - `nix flake check --no-update-lock-file -L`: standard output evaluation and built check derivations, including malformed-ciphertext guard regressions, built SOPS users manifests (parsing/key selection only, never decryption), native generated Hyprland/Noctalia/Ghostty checks on unstable and ThinkPad, other settings parsers, Zen wrapper/desktop-entry build, Nerd Font configuration/family inspection, nh help/version and duplicate-autostart masks (no app session), isolated output-policy CLI regressions (virtual outputs, lid/hotplug/reload, fail-fast command/JSON/EDID/IO handling) and native manual printer provisioning with mocked success/offline failures, offline Wi-Fi escaping/permissions/rejection tests (including encrypted-template markers), the actual ThinkPad Wi-Fi ciphertext manifest and separate campus-template manifest (not valid credentials), upstream deployment schema/activation checks and both-track non-empty smoke payloads.
   - Tailscale additionally checks the independent real-host rollout oracle (ThinkPad candidate only), both-track synthetic preserve/auth-key composition and unsafe-review/tag/secret/override rejection, actual CLI flag support, mocked reconciliation/operator-wrapper guards (including non-saving verification, native exit-status propagation and retained-plan preservation), exact default-deny policy regressions, OpenTofu schema/mock plans and temporary local-only state/plan encryption with no-change/drift exit-code and retained-file checks. `terraform_data` is the only synthetic apply; no real provider/host is contacted. `just tailscale-inventory` reports feature blockers separately from OS readiness. Real `just tailnet` operations are never validation dependencies.
4. Inspect reported missing facts and failed assertions. Uncommissioned hosts intentionally remain outside standard build/deploy outputs. Only explicit bootstrap/access blockers are expected; do not label new option errors, persistence duplicates, wrong tracks or invalid disks “placeholders”. A ready host must have no blockers/assertion failures.
5. For each commissioned host whose configuration/closure is affected, run `just ready HOST` and `just build HOST`. A later prose-only correction does not require rerunning unchanged builds. For an unready host, `just ready HOST` should refuse; inspect `.#fleetConfigurations.HOST.config` only for evaluation. No hardware fact may be fabricated to make a toplevel pass.
6. For current existing installations, all public disko script/image/install-test outputs must remain rejected even after synthetic commissioning; no disk/LVM-create/MD/ZFS-create/bcachefs nodes may appear. Validate preserved separate `/home`, Limine EFI/BIOS and migration-review gating. For fresh-install storage/readiness/deployment changes, exercise negative cases: unconfirmed/partition/missing device must not yield a destructive disk configuration; an unready host must not enter `nixosConfigurations`/`deploy.nodes`; wrong track metadata/wiring must fail the independent oracle. Never execute generated scripts to test a guard.
7. Inspect the final Git diff, lock changes, documentation/skill references and local canonical command. Avoid unsafe unknown-output suppression: custom outputs are explicitly checked, not magically understood by Nix.
8. Report exact commands/results. If unavailable due to network, cache, architecture, Nix version or build resources, record the precise remaining command and reason. Do not claim tests passed after a timeout/failure. Do not claim VM boot, physical boot, secret existence, SSH reachability, backup restore or deployment from evaluation-only tests.

## Safety

This procedure must not format, install, mount, activate remotely, reboot or deploy. Flake checks **build** activation scripts; they do not execute them. `deploy --dry-activate` is not a substitute for local validation.

## Completion criteria

The applicable validation path passes: documentation-only whitespace/link/status/snippet checks, or full formatting/lint/dead-code, host/track/safety evaluations and flake/deploy checks with affected real builds accounted for. Final diff and lock scope are reviewed. Any incomplete runtime/hardware work is explicitly separated from verified results.

## Common failures

Untracked modules, stale lock/API, wrong module class, duplicate deferred imports, assertions hidden by broad bootstrap exemptions, type-incorrect null substitutions, and accidentally retaining derivation string contexts in evaluation reports (which can turn an evaluation check into huge build dependencies). Fix the cause, not the safety policy.
