# Validation scope and implementation record

## Canonical command

```sh
nix develop --no-update-lock-file -c just check
```

`just fmt` is the explicit formatting mutation. `just check` itself is non-destructive: no mounting, provisioning, installation, SSH connection or activation. Nix may fetch inputs/binaries and build store derivations. Stage intended new files first so a Git flake includes them.

## What is checked

| Check | Actual scope |
|---|---|
| `secret-check` / `checks.secret-files` | Host payload encryption shape, single-document/unique-key YAML and matching public recipient rules; seven malformed-input regressions in `checks.secret-files`; no decryption, key import or proof of valid MAC/hash/custody |
| Format / statix / deadnix / ShellCheck | Repository Nix formatting, syntax anti-patterns, unused bindings and Bash preflight |
| `validation.hosts` | All four actual compositions; typed options/assertions; forced package-path, `/etc`, kernel/initrd, Bastion ZFS-module and ThinkPad home-activation derivations; desktop isolation from headless hosts; independent intended-track mapping; actual `pkgs.path` versus required input; Nixpkgs/Home Manager/Zen branch/follows policy; ThinkPad-only native nh package/path and no cleanup units |
| `validation.fixtures` | Synthetic combined capabilities evaluated with stable and unstable; UEFI and BIOS NixOS toplevel derivations; NixOS deploy activation and disko script derivations; tmpfs/early persistent mounts; unconfirmed/partition/missing-device rejection; ESP minimum/syntax rejection before direct disko-script derivation, accepted size boundaries, null-ESP blocker and BIOS without an ESP |
| `validation.fixtures.*.deploymentAccess` | Reuses the actual fleet host metadata type and deferred deployment module on both tracks; keyed non-root toplevel acceptance, root-with-key assertion/toplevel rejection, null commissioning blocker, unknown-account rejection, preserved SSH root-login denial and root activation default. No fixture deployment targets are exported |
| `validation.existingInstallations` | Both-track synthetic existing mounts, Limine EFI/BIOS and bootloader derivations, separate `/home` without duplicate binding, migration-review gating, closed destructive device collections, every public disko script/image/install-test alias rejected before and after approval, SSH/firewall/no-VPN/no-GUI policy, fail2ban persistence and laptop power/recovery |
| `validation.compositions` | Each exact shipped capability subset evaluated as a synthetic NixOS toplevel on that host's track; the combined fixture cannot mask a missing dependency |
| `validation.sops` | Both-track early-user `.path`/root-only permissions, immutable users/password sudo, activation dependency on secret installation, direct early identity, no generation/implicit imports, target-package sourcing; null/undeclared passwords, null/unreviewed identity, late persistence, unsafe secret mode/path/timing, disabled validation, tmpfs or userborn and competing password source rejection |
| `stable-sops-users-manifest` / `unstable-sops-users-manifest` | Builds the pinned upstream installer and users manifest on each track; validates selected keys in shipped ciphertext without decrypting or installing secrets. Synthetic consumers have no matching identity |
| `validation.desktop` | Supported unstable-only native Hyprland/UWSM/HM fixture; package/session/profile/app policy, Noctalia Greeter, password-first fingerprint PAM, keyring hooks and autologin/unsafe-PAM/unreviewed-desktop rejection; activation/toplevel derivations. Real headless hosts must not import HM |
| `unstable-desktop-config` / `thinkpad-desktop-config` | Builds generated Hyprland/Noctalia/Ghostty configs and runs their native validators (Noctalia warnings fail); parses greeter/Herdr TOML and Zed/Pi JSON; builds/checks Zen wrapper/desktop entry, Nerd Font configuration/packaged families, nh help/version and targeted duplicate-autostart masks. No rebuild, graphical session/authentication/provider/GPU test |
| `validation.wifi` / `wifi-secret-environment` | Actual home profile/runtime permissions/ordering and campus template TLS/name policy; null credentials emit no campus profile and block commissioning. Synthetic offline real-envsubst/GLib round trips, permissions, malformed-value/unfilled-marker rejection and no partial output; no NM connection or real secret read |
| `thinkpad-wifi-manifest` | Native SOPS key-selection/shape check for actual declared Wi-Fi ciphertext, without decryption |
| `senecanet-template-manifest` | Evaluation-only campus template using the separate encrypted placeholder file; checks key selection/shape without decryption. Can pass against replacement markers; not usable credentials or a host/install target |
| `checks.fleet-evaluation` | Forces the above evaluations and writes a context-free JSON report; does not build fixture NixOS systems |
| Upstream `deploy-schema` / `deploy-activate` | Real eligible deployment schema and activation files. Empty before commissioning; real closures may be built afterward |
| `stable-*` / `unstable-*` deploy smoke checks | Non-empty, tiny, source-matched activation payloads built/checked on both target package sets, never activated |
| GitHub Actions | Same canonical command on Linux; workflow is committed but a hosted run requires pushing to GitHub |

The independent track oracle deliberately repeats the four required track decisions. Changing a host's metadata alone must fail. Changing evaluator wiring to the other input must also fail even if reported metadata looks correct. A numbered stable input must not be silently replaced with an unstable branch alias.

## Expected bootstrap diagnostics

All four compositions retain `ready = false`. Existing hardware/storage/access facts are now populated from read-only discovery; see [host inventory](hosts.md). Boot/migration/network/user/provider/NAS review and deployment closure trust remain unresolved. Dino additionally has null original stateVersion and EFI NVRAM policy; ThinkPad's privileged hardware, fingerprint/password/keyring/desktop review and campus identity/password provisioning are pending. NVIDIA/Samsung HDR/VRR acceptance remains a separate follow-up, not covered by the desktop review flag. The `fleet` report shows them. `nixosConfigurations` and `deploy.nodes` initially have no entries; they are **not** fake buildable configurations or fake SSH endpoints.

- NixOS warns about its default stateVersion when inspecting an uncommissioned host. The explicit `fleet.installation.stateVersion` blocker prevents accepting that default for a real build.
- The original empty-scaffold NixOS access assertion is no longer expected on current hosts: the selected public key remains supplied. SOPS ciphertext/binding is restored for ThinkPad; the other hosts have explicit null credential/identity blockers. No real identity review is acknowledged or decryption tested. No NixOS access assertion is disabled. Other non-bootstrap failures remain errors.
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

## SOPS integration — 2026-09-09

Reused sops-nix `fbf759290e0cb0a98dfc813a4eb7d53ad1dacb57` (narHash `sha256-gkSH8VUtCo6hnysNmb9DbTuDepH2t5pv+QWjP75xKAk=`); `nix flake lock` added only that node and its stable follows link. Every existing lock node/input was compared structurally to HEAD and remained unchanged. ThinkPad ciphertext was compared byte-for-byte with both the previous repository and the file referenced by its running users manifest; no decryption, generation, rotation or recipient expansion was performed. Read-only unit/identity metadata checks found no server SOPS unit/dedicated key at the prepared path; Dino returned `No route to host`, not a credential conclusion.

Incremental validation: formatting and statix/deadnix/ShellCheck passed after correcting the dev-shell package contribution and redundant parentheses. `just secret-check` passed. Both-track `validation.sops` passed. A first full evaluation timed out at 240 seconds; the complete retry passed in 5m33s with a longer limit. No timeout is counted as success.

Executed validation and review:

- `nix develop --no-update-lock-file -c just fmt` and full `just check`: passed, including all real host reports, both-track password/identity safety fixtures, **built** upstream users manifests, source/ciphertext checks and unchanged deploy-rs schema/activation smokes. The installer dependencies were already available in the store; manifest checks performed no decryption/installation. NixOS fixture systems were only evaluated, not built/booted.
- Adversarial ciphertext-guard tests initially revealed that multiple YAML documents and duplicate keys could hide an earlier plaintext value during JSON parsing. The guard now rejects both before accepting a document; `just secret-check-tests` retains seven regressions (plaintext, recipient mismatch, missing MAC, unsupported backend, invalid YAML, multiple documents, duplicate keys). All seven passed with diagnostic payloads withheld, as did the positive unchanged-file check and ShellCheck. The regressions also run in `checks.secret-files`. Its first sandboxed run found a read-only copied-store-file issue; the disposable test copy is now made writable, and the targeted `nix build --no-update-lock-file --no-link -L .#checks.x86_64-linux.secret-files` passed. Only temporary test data permissions changed, never repository ciphertext or host identities.
- `just ready HOST` and `just disk-plan HOST` refused all four hosts with their expected safety messages. Standard NixOS/deploy outputs remain empty and every real `identityReviewed` flag remains false. No real host build, credential provisioning, activation or reboot was performed.
- Code/docs/lock diff reviewed, ciphertext equality checked, and `git diff --check` / staged whitespace checks passed. Local Markdown checker verified **51** repository-relative links/anchors across 24 Markdown files. Intended new code/docs/ciphertext/public rules are staged for Git-flake discovery; no commit was made.

Only the documented custom-output warnings and Dino's unset-stateVersion warning remain. The missing per-host encrypted credentials, identity/decryption/access review and existing migration/boot/network/recovery requirements remain blockers, not passed runtime tests.

## Fresh ThinkPad desktop — 2026-09-09

Added only Home Manager stable `fd0956c99c41ae3c13a73a638f1f7e963aebc4ab` and unstable `14179aecea13dda28ec6655ad36602e827034558`, with matching follows links. Structural comparison against HEAD verified every pre-existing lock node/input unchanged. New desktop code/configuration was authored independently of prior desktop preferences; read-only sysfs/output/Bolt inventory supplied Intel/internal-panel facts, not NVIDIA/Samsung verification. The new Noctalia config/state/data profile directories were absent during metadata-only review; no existing user files were changed.

Incremental failures corrected: desktop fixtures initially compared unnormalized portal and systemd `ExecStart` values (the evaluated forms are a string and list respectively); native-parser review removed stale `misc.vfr`; statix rejected repeated `services` prefixes, which were grouped. An auxiliary review script found `python3` unavailable on the ambient PATH; the lock/path/link checks were rerun successfully with available Node. None of these failures was treated as success or bypassed with readiness/assertion suppression.

Executed checks:

- `nix develop --no-update-lock-file -c just fmt` and `nix develop --no-update-lock-file -c just lint`: passed.
- `nix eval --no-update-lock-file --json .#validation.desktop`: both tracks passed, including Home Manager activation/toplevel evaluation, package/session/profile policy and autologin/unreviewed-desktop rejection.
- `nix build --no-update-lock-file --no-link -L .#checks.x86_64-linux.thinkpad-desktop-config .#checks.x86_64-linux.stable-desktop-config .#checks.x86_64-linux.unstable-desktop-config`: passed with the actual Hyprland binaries and generated Noctalia config validation. These are **built config checks**, not desktop sessions or full system builds.
- `nix develop --no-update-lock-file -c just check`: full canonical suite passed, including all host reports, both-track fixtures, source/ciphertext guards, generated desktop configs, SOPS manifests and deploy schema/activation smokes. Unchanged checks were satisfied from the store; changed evaluation/source/ciphertext-guard outputs were built. Only documented custom-output/Dino stateVersion warnings and the expected dirty-tree notice remain.
- `just ready thinkpad`: expected refusal with the specific uncommissioned diagnostic. All four actual `ready` values remain false; standard NixOS configurations and deploy nodes were checked empty. No real host build was attempted because no host is commissioned.
- Code/docs/lock diff reviewed; all non-entry-point Nix files remain under `modules/`. Local Node checking passed for 67 repository-relative Markdown links/anchors across 26 files. `git diff --check` and staged whitespace checks passed. Intended new files were staged for Git-flake visibility; no commit was made.

No session, login/lock/PAM, sleep, screencast/audio, NVIDIA/eGPU, Samsung HDR/VRR, full-system boot, activation, deployment or storage action was tested or performed. These remain explicit target acceptance work, with `fleet.desktop.reviewed = false` and every existing commissioning/recovery gate preserved.

## Native desktop, Wi-Fi and kernel follow-up — 2026-09-09

[ADR 0008](adr/0008-native-desktop-and-kernels.md) supersedes the initial desktop's stable-HM/handwritten-config/greeter/app choices. Starting point: clean commit `1922ace`. Only stable Home Manager was removed and source-only Zen **3aadc420e763a8243aedd2ce925ae1dc13663ed9** added; all retained input nodes/revisions/follows are unchanged. Existing password/PSK ciphertext, recipient rules, storage, host readiness and deployment policy remain unchanged.

Executed:

- Locked-shell `just fmt`, `just lint`, targeted desktop/host evaluations and **full `nix develop --no-update-lock-file -c just check`**: passed. The final reviewed-code run includes native HM desktop/authentication/app policy, unsafe-PAM/autologin rejection, actual Wi-Fi manifest key selection, synthetic envsubst/GLib escaping/permissions/control-character/injection tests, generated Hyprland/Noctalia/Ghostty checks, other settings parsers, Zen wrapper/desktop entry and retained both-track infrastructure/SOPS/deploy fixtures. Unchanged outputs were reused from the store.
- Every real kernel/initrd derivation evaluates: **7.2.4 ThinkPad/Dino; 7.2.3 Racknerd/Bastion**. Bastion's actual **zfs_2_4 2.4.4 for 7.2.3** evaluates without allowing broken packages. No real kernel, module, initrd or host system was built/booted for acceptance.
- Generated greeter and sudo PAM reviewed: nonempty password first, bounded fingerprint fallback and final deny; graphical keyring token/session hooks present. Fingerprint PAM remains absent from console/SSH/other services. No PAM authentication/enrollment was executed.
- `just ready thinkpad`: correct uncommissioned refusal. All four readiness flags remain false and standard NixOS/deploy outputs are empty.
- Nix placement and **83 local Markdown links/anchors across 27 files** passed review. Staged/unstaged whitespace and exact lock/storage/ciphertext scope checks passed. Intended files are staged; no commit or activation.

Incremental failures were fixed rather than bypassed: HM normalizes the relocated XDG target with `.config/`; Pi's native file key uses full `configDir`; Noctalia's native field is `lockscreen`; Ghostty's validation subcommand rejects the general launcher's `--config-default-files` flag; the ZFS module selector is not the removed `.zfs` alias; GLib's shared library needs its library output, not default `bin`. Source review also corrected greetd's ineffective keyring toggle and masked the two packaged NM Applet/KDE Connect autostarts that would compete with the intended session owners, using native PAM/XDG mechanisms. Subsequent targeted and full canonical runs passed. Only documented custom-output/Dino stateVersion and dirty-tree warnings remain.

SenecaNET credentials are still absent, no incomplete campus profile is installed, and the typed-null provisioning blocker is intentional. Runtime password/fingerprint fallback, keyring/vault/provider behavior, service lifecycle, Wi-Fi/TLS rejection, Bluetooth/pairing, printing/scanning, suspend, GPUs and boot remain separately authorized acceptance work. Source/package support is not a tested installation.

## Input, placeholder, font and nh refinements — 2026-09-09

Starting point: clean `cee684a`. Rename HM/Zen inputs and their default-branch URL metadata; make Zen a normal flake following unstable while retaining host-pkgs recipe instantiation. Native `nix flake lock` and structural comparison confirm **every locked revision/narHash unchanged**, no new transitive package set, and all unrelated nodes/follows unchanged. Existing ThinkPad password/PSK ciphertext is untouched; only a separate encrypted campus-marker file and exact same-recipient rule are added. Its source selector remains null and no review/readiness flag changes.

Targeted formatting, statix/deadnix/ShellCheck, full validation evaluation and the five desktop/Wi-Fi check builds passed. They include actual packaged Nerd Font family inspection, ThinkPad nh help/version and native package/path/no-cleanup policy, both Wi-Fi manifests and fail-closed marker tests. An initial font assertion incorrectly expected Ghostty's scalar form; comparison now uses HM's normalized list and both desktop checks pass. No assertion or bootstrap gate was suppressed. One canonical attempt was interrupted during evaluation and is not counted as success; the subsequent full **`nix develop --no-update-lock-file -c just check` passed**, including all host/track/infrastructure/SOPS/deploy checks and the updated mixed valid/invalid credential test. Unchanged check outputs were reused. Only documented custom-output/Dino stateVersion and dirty-tree warnings remain.

`just ready thinkpad` refused with the expected uncommissioned diagnostic. All four hosts remain unready, the SenecaNET null blocker remains present, and `nixosConfigurations`/`deploy.nodes` are empty. **85 local Markdown links/anchors across 27 files** and placement of all **50 Nix files** passed; code/docs/lock/protected-scope and whitespace review passed. No real host build, nh rebuild/cleanup, private-key access, credential decryption, enrollment, activation, deployment or storage operation occurred. Real campus values and runtime acceptance remain outstanding.

## Not claimed / remaining acceptance

No real host is commissioned for this baseline yet. Fixtures' derivations were evaluated, not full NixOS systems built or booted. No disko script, install, mount, repair, VM boot, remote dry activation, deployment, reboot, backup restore or production mutation was executed. Authorized read-only host inventory did contact the targets.

Before real use, resolve [the existing-host transition gates](hosts.md), run `just check`, `just ready HOST`, `just build HOST` and complete separately authorized first-boot acceptance. `just disk-plan HOST` must refuse every current host even after readiness; provisioning requires a separate reviewed fresh-install design. Runtime credential existence, actual hardware/initrd compatibility, by-id correctness, data-disk separation, network/provider behavior, service migrations, SSH trust/elevation and recovery must be verified on real machines. Those cannot be proven by pure evaluation.
