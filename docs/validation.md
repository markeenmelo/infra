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
| `validation.existingInstallations` | Both-track synthetic existing mounts, Limine EFI/BIOS and bootloader derivations, separate `/home` without duplicate binding, migration-review gating, closed destructive device collections, every public disko script/image/install-test alias rejected before and after approval, SSH/firewall/no-VPN/no-GUI policy, fail2ban persistence and laptop power/recovery |
| `validation.compositions` | Each exact shipped capability subset evaluated as a synthetic NixOS toplevel on that host's track; the combined fixture cannot mask a missing dependency |
| `checks.fleet-evaluation` | Forces the above and writes a context-free JSON report; does not build fixture NixOS systems |
| Upstream `deploy-schema` / `deploy-activate` | Real eligible deployment schema and activation files. Empty before commissioning; real closures may be built afterward |
| `stable-*` / `unstable-*` deploy smoke checks | Non-empty, tiny, source-matched activation payloads built/checked on both target package sets, never activated |
| GitHub Actions | Same canonical command on Linux; workflow is committed but a hosted run requires pushing to GitHub |

The independent track oracle deliberately repeats the four required track decisions. Changing a host's metadata alone must fail. Changing evaluator wiring to the other input must also fail even if reported metadata looks correct. A numbered stable input must not be silently replaced with an unstable branch alias.

## Expected bootstrap diagnostics

All four compositions retain `ready = false`. Existing hardware/storage/access facts are now populated from read-only discovery; see [host inventory](hosts.md). Boot/migration/network/user/provider/NAS review and deployment closure trust remain unresolved. Dino additionally has null original stateVersion and EFI NVRAM policy; thinkpad's privileged hardware review is pending. The `fleet` report shows them. `nixosConfigurations` and `deploy.nodes` initially have no entries; they are **not** fake buildable configurations or fake SSH endpoints.

- NixOS warns about its default stateVersion when inspecting an uncommissioned host. The explicit `fleet.installation.stateVersion` blocker prevents accepting that default for a real build.
- The original empty-scaffold NixOS access assertion is no longer expected on current hosts: the selected public key and runtime credential contract are supplied. Those runtime files have not been provisioned or verified. No NixOS access assertion is disabled. Other non-bootstrap failures remain errors.
- Nix warns about custom outputs such as `fleet`, `fleetConfigurations`, `deploymentPlan`, `validation`, `modules` and `deploy`. These are not standard Nix CLI schema names; custom outputs are explicitly evaluated by the check suite.
- `just ready HOST`, building an absent standard host output, or forcing an unapproved `fleetConfigurations.HOST.config.system.build.toplevel` must fail. This is the desired safety result.

## Original scaffold implementation (historical)

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

## Existing-host baseline implementation

Date: **2026-09-09**. Read-only local thinkpad and strict-key-checked SSH inventory ran on racknerd, bastion and dino. Stdout-only hardware scans wrote no files; unprivileged laptop scans failed to inspect Btrfs, while privileged remote scans emitted bind-mount/subvolume diagnostics. Dino's boot filesystem capacity/recovery fragments remain an explicit review concern, not a diagnosed/repaired filesystem. No private credential contents were read.

Initial source lint rejected repeated Nix attribute prefixes in three new/changed blocks; these were grouped and subsequent lint passed. Exploratory commands requiring jq were moved into the locked dev shell; local `getFlake` inspection required `--impure`, without updating inputs. The first ZFS property query used an invalid dataset selector and was corrected to `tank`, read-only.

Final executed checks:

- `nix develop --no-update-lock-file -c just fmt`: passed.
- `nix develop --no-update-lock-file -c just lint`: statix, deadnix and ShellCheck passed.
- `nix eval --no-update-lock-file --json .#validation`: passed, including real host components/policy, both-track existing-mount/Limine/password-file/security/persistence checks and retained fresh-install/ESP/deployment-access fixtures.
- `nix develop --no-update-lock-file -c just check`: full canonical suite passed, repeated after final code review. Upstream deploy checks/smokes were evaluated and satisfied from existing store results; changed source-quality and context-free fleet reports were built. No fixture NixOS toplevel or activation was run.
- `just ready HOST` and `just disk-plan HOST` on **all four hosts**: expected refusals, with the specific uncommissioned and existing-installation/no-provisioning messages checked. `nixosConfigurations` and `deploy.nodes` were both verified empty; deployment intent is enabled only for racknerd/bastion/dino, with marcos, interactive sudo and unresolved closure trust.
- No `just build HOST` was run: no real host is commissioned. This deliberately does not claim physical-system build/boot acceptance.
- Final code diff reviewed; all repository `.nix` files except `flake.nix` remain under `modules/`. No `flake.nix`/`flake.lock` changes, secret contents or commits. Intended new files staged for Git-flake discovery. `git diff --check` and staged whitespace checks passed; a local Node checker validated 40 repository-relative Markdown links/anchors across 22 Markdown files.

Only known custom-output warnings and dino's unset-stateVersion warning remain in canonical evaluation. Runtime password delivery, non-root server access, network without the old VPN/NetworkManager secret agent, boot capacity/firmware, pool-import policy, and backup/restore acceptance remain the explicit commissioning gates in [hosts.md](hosts.md).

## Not claimed / remaining acceptance

No real host is commissioned for this baseline yet. Fixtures' derivations were evaluated, not full NixOS systems built or booted. No disko script, install, mount, repair, VM boot, remote dry activation, deployment, reboot, backup restore or production mutation was executed. Authorized read-only host inventory did contact the targets.

Before real use, resolve [the existing-host transition gates](hosts.md), run `just check`, `just ready HOST`, `just build HOST` and complete separately authorized first-boot acceptance. `just disk-plan HOST` must refuse every current host even after readiness; provisioning requires a separate reviewed fresh-install design. Runtime credential existence, actual hardware/initrd compatibility, by-id correctness, data-disk separation, network/provider behavior, service migrations, SSH trust/elevation and recovery must be verified on real machines. Those cannot be proven by pure evaluation.
