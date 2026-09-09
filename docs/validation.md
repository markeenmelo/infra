# Validation scope and implementation record

## Canonical command

```sh
nix develop --no-update-lock-file -c just check
```

`just fmt` is the explicit formatting mutation. `just check` itself is non-destructive: no mounting, provisioning, installation, SSH connection or activation. Nix may fetch inputs/binaries and build store derivations. Stage intended new files first so a Git flake includes them.

## What is checked

| Check | Actual scope |
|---|---|
| Format / statix / deadnix / ShellCheck | Repository Nix formatting, syntax anti-patterns, unused bindings and Bash preflight |
| `validation.hosts` | All four actual compositions; typed options/assertions; forced package-path, `/etc` and initrd derivations; independent intended-track mapping; actual `pkgs.path` versus required input; locked branch policy |
| `validation.fixtures` | Synthetic combined capabilities evaluated with stable and unstable; UEFI and BIOS NixOS toplevel derivations; NixOS deploy activation and disko script derivations; tmpfs/early persistent mounts; unconfirmed/partition/missing-device rejection; ESP minimum/syntax rejection before direct disko-script derivation, accepted size boundaries, null-ESP blocker and BIOS without an ESP |
| `validation.fixtures.*.deploymentAccess` | Reuses the actual fleet host metadata type and deferred deployment module on both tracks; keyed non-root toplevel acceptance, root-with-key assertion/toplevel rejection, null commissioning blocker, unknown-account rejection, preserved SSH root-login denial and root activation default. No fixture deployment targets are exported |
| `validation.compositions` | Each exact shipped capability subset evaluated as a synthetic NixOS toplevel on that host's track; the combined fixture cannot mask a missing dependency |
| `checks.fleet-evaluation` | Forces the above and writes a context-free JSON report; does not build fixture NixOS systems |
| Upstream `deploy-schema` / `deploy-activate` | Real eligible deployment schema and activation files. Empty before commissioning; real closures may be built afterward |
| `stable-*` / `unstable-*` deploy smoke checks | Non-empty, tiny, source-matched activation payloads built/checked on both target package sets, never activated |
| GitHub Actions | Same canonical command on Linux; workflow is committed but a hosted run requires pushing to GitHub |

The independent track oracle deliberately repeats the four required track decisions. Changing a host's metadata alone must fail. Changing evaluator wiring to the other input must also fail even if reported metadata looks correct. A numbered stable input must not be silently replaced with an unstable branch alias.

## Expected bootstrap diagnostics

All four compositions start with `ready = false`, null disk/firmware/stateVersion/access data and unresolved human review requirements. The `fleet` report shows them. `nixosConfigurations` and `deploy.nodes` initially have no entries; they are **not** fake buildable configurations or fake SSH endpoints.

- NixOS warns about its default stateVersion when inspecting an uncommissioned host. The explicit `fleet.installation.stateVersion` blocker prevents accepting that default for a real build.
- NixOS's own “Neither the root account nor any wheel user has a password or SSH authorized key” assertion is expected until real access is supplied. It is not disabled. All other non-bootstrap assertion failures are errors in our evaluation check.
- Nix warns about custom outputs such as `fleet`, `fleetConfigurations`, `deploymentPlan`, `validation`, `modules` and `deploy`. These are not standard Nix CLI schema names; custom outputs are explicitly evaluated by the check suite.
- `just ready HOST`, building an absent standard host output, or forcing an unapproved `fleetConfigurations.HOST.config.system.build.toplevel` must fail. This is the desired safety result.

## Executed during implementation

Date: **2026-09-09**, local `x86_64-linux`, Nix **2.34.8**.

- `nix flake lock`: created the reproducible lock with independent stable/unstable pins.
- `nix develop --no-update-lock-file -c just fmt`: formatting applied.
- `nix develop --no-update-lock-file -c just lint`: statix, deadnix and ShellCheck passed.
- `nix eval --no-update-lock-file --json .#validation`: all host reports and both-track UEFI/BIOS, persistence, activation and disk-safety fixtures passed.
- `nix develop --no-update-lock-file -c just check`: full built check suite passed, including upstream schema/activation smoke checks. Source-matched deploy-rs executables built for both tracks; upstream Rust unit tests passed during builds.
- `just ready HOST` refused all four uncommissioned hosts; standard NixOS and deployment outputs were confirmed empty.
- One-off mutation tests in temporary copies: all **four** wrong-track edits rejected; wrong evaluator wiring rejected; unstable alias for stable rejected; premature readiness rejected; a lazy per-host missing-package error rejected. These tested `nix eval --no-update-lock-file --json path:<temporary-copy>#validation.hosts`; the corresponding invariants remain in the canonical check.
- A separate, clearly synthetic temporary commissioning fixture supplied test-only facts and enabled all four deployment targets. `nix flake check --no-build` evaluated all four standard NixOS/activation outputs; JSON from the actual node generator passed upstream `check-jsonschema`. It was **not** built, deployed or copied into the real host facts.
- Repository-local Markdown links and all eight skill frontmatter/required sections were checked. `git diff --check` and staged whitespace checks were run after final staging.

Failures encountered and fixed: module-option self-recursion when initially mapping over host definitions; nonexistent `boot.loader.enable`; duplicated GRUB devices already inferred by disko; duplicate SSH persistence from diamond composition; journald API removal on unstable. Final review also made UEFI NVRAM writes/fallback an explicit commissioning choice, added per-host component/subset evaluations, clarified the storage interface, removed a redundant architecture assertion, and preserved stable logging policy when other raw tuning lines are added. An initial full check attempt timed out after 600 seconds because derivation string contexts in an evaluation report pulled deep build dependencies. The report now deliberately discards **only metadata string context** after evaluation, and subsequent full checks pass. No timeout is counted as success.

## PR review regression validation

On **2026-09-09**, the deployment-access regression failed on the original implementation with `root deployment SSH user with a public key must fail readiness/toplevel evaluation`. After adding the explicit non-root assertion, both stable and unstable fixture reports passed under `nix eval --no-update-lock-file --json .#validation.fixtures --apply 'builtins.mapAttrs (_: fixture: fixture.deploymentAccess)'`. The fixtures reuse real deployment metadata/module wiring, but their facts and credentials are synthetic and no SSH connection or activation is performed.

## Not claimed / remaining acceptance

No physical host closure is buildable before its real facts are supplied. Fixtures' derivations were evaluated, not full NixOS systems built or booted. No disko script, install, mount, VM boot, remote dry activation, deployment, reboot, backup restore or sensitive production command was executed.

Before real use, run `just check`, `just ready HOST`, `just build HOST`, review `just disk-plan HOST` only when provisioning is intended, and complete [bootstrap first-boot acceptance](bootstrap.md#first-boot-acceptance). Runtime credential existence, actual hardware/initrd compatibility, by-id correctness, data-disk separation, network/provider behavior, service migrations, SSH trust/elevation and recovery must be verified on real machines. Those cannot be proven by pure evaluation.
