# Operations

Use the locked `x86_64-linux` development environment and matching skill. Tasks were removed on 2026-09-13 with no replacement runner. All local preflight is now the explicit [manual validation procedure](../../validate/SKILL.md); it authorizes no runtime operation.

## Input updates

Follow [update-inputs](../../update-inputs/SKILL.md) and [lock synchronization](../../devenv/references/development.md#locks-and-architecture). Choose stable, unstable or full scope deliberately; save the original lock and inspect every changed node. StateVersion is a migration boundary, never an update knob. Verify supported releases and actual locked module APIs through [nix-research](../../nix-research/SKILL.md).

Both tracks retain stock latest 7.x and Bastion's supported ZFS pair. Do not use removed kernel aliases, allow broken packages, mix tracks, prune recovery generations or automatically cross the major guard. A dependency update requires complete manual checks and affected commissioned-host builds, not activation.

## ThinkPad Nix Helper (nh)

`modules/nh.nix` enables native nh only on ThinkPad, with its own packages and observed `/home/marcos/projects/infra` checkout. At the recorded pin the module sets `NH_FLAKE`; explicit installables/`NH_OS_FLAKE` can override it. No automatic cleanup, updates or standalone HM output.

After complete validation and real readiness, `nh os build --hostname thinkpad --no-update-lock-file` is build-only. **Currently blocked:** the fresh ThinkPad candidate has no commissioned output; never activate it over the running encrypted disk. Switch/test/boot/remote/cleanup commands require their own authorization; help/version tests establish no rebuild or boot acceptance.

## Deployment and recovery

### Current remote deployment status — 2026-09-13

Both servers have accepted fresh installs/two boots with their older signed/interactive administration. The current candidate replaces that with `deploy`, remote builds and no server `marcos` account/password delivery. It is **unactivated**; [dated status](../../fleet-operations/references/hosts.md#current-status) remains authoritative. ThinkPad retains marcos and stays local-only/unready. Deployment uses deploy-rs, **not disko or nixos-anywhere**.

### Preflight

Follow [deploy](../SKILL.md). Before any contact, complete manual ciphertext, format, lint, lock/tool parity, fleet/evaluation and full flake checks; run deployment-specific readiness and real closure builds. Runtime identity/credential/backup acceptance must be independently verified. A raw deploy wrapper does none of this for you now.

Select an eligible host or explicit ordered group. `servers` means Racknerd then Bastion; `workstations` contains unready ThinkPad and must refuse rather than silently skip it. `deploy` is explicitly root-equivalent through Nix trust and passwordless activation/confirmation; wheel does not get blanket Nix trust or passwordless sudo. Its password is locked and its two authorized keys have `restrict`. No private signing-key access is needed for this new transport policy. Public configuration proves neither working installed login nor recovery.

Preserve the target's configured port and these reviewed whitespace-free deploy-rs `--ssh-opts` tokens: `-o BatchMode=yes -o StrictHostKeyChecking=yes -o UpdateHostKeys=no -o IdentityAgent=none -o IdentitiesOnly=yes -o ForwardAgent=no -o ClearAllForwardings=yes -o ConnectTimeout=15 -o ServerAliveInterval=10 -o ServerAliveCountMax=3`. Keep private identity/known-host paths in reviewed operator SSH configuration; the locked deploy-rs parser splits override strings on spaces. Never accept installer fingerprints as installed identity or delete known-host entries to make a connection work.

Use locked deploy-rs, `--checksigs` and `--no-update-lock-file`, without `--interactive`, after exact target/mode authorization. Keep automatic/magic rollback. `--boot` changes boot selection without a live switch; neither it nor magic confirmation proves a future boot. `sudo -n -u root` may run the store activate-rs executable and remove only its root-owned `/run/deploy-rs` canary. The general wheel password requirement remains in force.

Native `--groups servers` filters but does not implement repository order. Expand explicit `--targets .#racknerd .#bastion` for ordered activation; remote builds may overlap. `deploy .` is not a safe transition recipe. Upstream local checks may build all eligible closures even for a subset. Remote builds require working target Nix trust and reviewed RAM/store/build capacity; durable `/nix/var/nix/builds` avoids the small tmpfs root. This repository still exports controller tools only for Linux, not Darwin.

### Minimal-server transition — 2026-09-13

The operator chose their reportedly prepared MacBook/controller, then explicitly approved a dedicated root-equivalent `deploy` account on all hosts, removal of server marcos/home data/credentials, and **Racknerd before Bastion**. The earlier Bastion-first signed rollout below is superseded. Keep the exact candidate/locks synchronized with the prepared Linux checkout/builder; controller readiness is not independently tested here.

Before removing old access, independently verify console recovery, machine SSH/age identities and both private administrator keys. The running machines have not been shown to contain deploy; it cannot bootstrap itself. Use a separately reviewed console/staged-access transition to provision and test it while preserving old access, then apply the final account removal. Never point the new task at the old account or bypass its sudo/trust checks to force this transition.

For Bastion, retain boot-only selection and a separately authorized reboot rather than forcing the busy home bind off. Account/home-policy removal does **not** erase `/persist/home/marcos`, old credentials, acceptance files or generations. Although the operator authorized removal of server home data, this implementation performs no deletion and embeds no activation-time deletion. Any later cleanup must identify exact OS-backed paths, exclude tank and all mounts/symlinks, preserve machine/recovery identities, verify independent wanted-data recovery and occur after new-access/boot acceptance. Credential revocation/rotation is separate from deleting files; retained ciphertext and old generations still carry historical material.

Both running servers initially accept the first administrator key (`SHA256:rU2P8TOXVjL3ymRg1OyxA0YgxKrp9PBKKD56FhXWu/I`). The second (`SHA256:mZ36DV6PDIt0lmhfqrO9qKKxQSlmQ7iMiH1NNYWvDRI`) cannot bootstrap its own new allowlist entry; retain the first private half independently until activation/acceptance.

| Target | Installed ED25519 fingerprint | Required signer name |
|---|---|---|
| `marcos@192.168.2.2` | `SHA256:DiSj7jMXKQJchfzBDBBX8VsTSErDkDgLAdjsBPN3Ie4` | `bastion-deploy-20260912` |
| `marcos@72.11.150.242` | `SHA256:A0QspM00bMLwnPwevkEvB9q8TTfjS4ewlFWfN0ss0B0` | `racknerd-deploy-20260912` |

The table describes **installed old access**, not task targets; new targets use deploy at the same endpoints and fingerprints. Preserve the existing first key because neither a new account nor the second key can bootstrap its own access.

Complete the Racknerd transition and acceptance first. Verify separate deploy logins for both keys, locked password, Nix remote-store access, noninteractive activation rules, absent marcos/password delivery, private `/var/lib/deploy`, healthy units/network/firewall/fail2ban and unchanged identities. Then transition Bastion in boot-only mode and, after separate reboot authorization, verify the same plus all eight tank mounts/health and removal of its home bind. A group boot deployment only orders boot-selection updates; it does not wait for future reboot acceptance. No ThinkPad operation, pruning, secret reading or data cleanup is implied by deployment success.

### Rollback semantics

- Automatic rollback returns to the previous profile after activation failure.
- Magic rollback handles missing client reachability confirmation (default 60 seconds; activation 300 seconds). Keep SSH liveness limits and independent console access.
- Multi-target failure can roll back successful earlier profiles too; review the locked CLI before any separately approved override. Do not weaken defaults.
- Neither rollback restores databases, `/persist`, NAS/user data, disks or secrets, or guarantees a future boot. No blanket rollback-disable recipe is retained.

On failure, stop and wait for rollback. Inspect power/network/console rather than blindly retrying. Preserve old/new access during SSH-changing migrations. If authorized, recover from the console with a previous boot generation or `sudo nixos-rebuild switch --rollback`; service data may still need a separate restore. Keep recovery generations and monitor boot/store capacity.

## Persistence, observability and backups

Follow [impermanence](../../impermanence/SKILL.md). Direct `/persist` contents survive even outside the bind inventory; removing a declaration is not deletion. Every future data consumer needs ownership, migration planning and exact source/mount verification, not an existing directory on tmpfs.

Servers retain bounded persistent journals; Racknerd persists fail2ban state. Bastion keeps monthly tank-only scrub and native property-opt-in snapshots. Scheduled jobs, a mirror and snapshots are not independent backups; review properties, naming/holds, capacity, pruning and recovery before changing maintenance. No shares, monitoring endpoints, application databases, backup automation or garbage collection are implicitly enabled.
