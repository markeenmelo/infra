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

Both servers have accepted fresh installs/two boots and signed deployment outputs. The later minimal-server/two-administrator-key candidate remains unactivated; [dated status](../../fleet-operations/references/hosts.md#current-status) is authoritative. This update uses deploy-rs, **not disko or nixos-anywhere**. ThinkPad remains local-only and unready.

### Preflight

Follow [deploy](../SKILL.md). Before any contact, complete manual ciphertext, format, lint, lock/tool parity, fleet/evaluation and full flake checks; run deployment-specific readiness and real closure builds. Runtime identity/credential/backup acceptance must be independently verified. A raw deploy wrapper does none of this for you now.

Use exactly one eligible host and its own existing signer. Privately compare the public key derived from `LOCAL_KEY` with the target's declared trust, and verify signed transport, interactive sudo and independent recovery. A key path or public configuration alone proves neither custody nor working credentials. No password/private-key content in arguments, Git, Nix or logs.

Preserve the target's configured port and these reviewed whitespace-free deploy-rs `--ssh-opts` tokens: `-o StrictHostKeyChecking=yes -o UpdateHostKeys=no -o IdentityAgent=none -o IdentitiesOnly=yes -o ForwardAgent=no -o ClearAllForwardings=yes -o ConnectTimeout=15 -o ServerAliveInterval=10 -o ServerAliveCountMax=3`. Keep private identity/known-host paths in reviewed operator SSH configuration; the locked deploy-rs parser splits override strings on spaces. Never accept installer fingerprints as installed identity or delete known-host entries to make a connection work.

Use locked deploy-rs, `--interactive`, `--checksigs` and `--no-update-lock-file` after exact target/mode authorization in a private foreground terminal. Upstream CLI defaults would otherwise pass `--no-check-sigs` during copy. Keep all rollback checks. `--boot` updates boot selection without a live switch; `--test` activates without setting boot defaults; neither guarantees the next boot.

`deploy .` selects all eligible nodes, not every host. It is inappropriate for the current transition with distinct signers. Upstream local checks may evaluate/build all eligible nodes even for a selected subset; this is not target contact. `remoteBuild` needs explicit resource/trust review, not an assumption that a MacBook can build Linux automatically.

### Minimal-server transition — 2026-09-13

The operator chose their reportedly prepared MacBook/controller rather than a Bastion workspace. This repository exports tooling/checks only for `x86_64-linux`, not Darwin. Keep the exact reviewed candidate/locks synchronized with the prepared Linux checkout/builder and compatible locked deploy-rs CLI. `--remote-build` does not automatically solve root-only-trust targets; do not install a server workspace or grant trusted-user privileges as a workaround. Controller readiness has not been independently tested here.

Privately preserve anything wanted from Bastion's old home before deployment. Removing the home bind does **not** erase `/persist/home/marcos`, credentials, old acceptance artifacts or Nix generations. Use boot-only Bastion deployment, then a separately planned reboot; do not unmount the busy home, run old rebooting acceptance helpers or delete backing data.

Both running servers initially accept the first administrator key (`SHA256:rU2P8TOXVjL3ymRg1OyxA0YgxKrp9PBKKD56FhXWu/I`). The second (`SHA256:mZ36DV6PDIt0lmhfqrO9qKKxQSlmQ7iMiH1NNYWvDRI`) cannot bootstrap its own new allowlist entry; retain the first private half independently until activation/acceptance.

| Target | Installed ED25519 fingerprint | Required signer name |
|---|---|---|
| `marcos@192.168.2.2` | `SHA256:DiSj7jMXKQJchfzBDBBX8VsTSErDkDgLAdjsBPN3Ie4` | `bastion-deploy-20260912` |
| `marcos@72.11.150.242` | `SHA256:A0QspM00bMLwnPwevkEvB9q8TTfjS4ewlFWfN0ss0B0` | `racknerd-deploy-20260912` |

After successful boot-only deployment and the authorized reboot, reconnect with the same strict pin. Privately test separate logins using both reviewed keys, intended generation, no failed units, password sudo, unchanged identities/scoped binds, private `marcos:users 0700` tmpfs home and all eight exact tank mounts/health. Keep previous Limine/console recovery; do not read secret contents or delete backing data for acceptance.

Only after Bastion acceptance, deploy Racknerd separately in switch mode. Its home is already ephemeral; verify both administrator logins, new generation, strict SSH/password sudo, no failed units and healthy network/firewall/fail2ban. No ThinkPad operation, credential rotation, pruning or storage action is implied.

### Rollback semantics

- Automatic rollback returns to the previous profile after activation failure.
- Magic rollback handles missing client reachability confirmation (default 60 seconds; activation 300 seconds). Keep SSH liveness limits and independent console access.
- Multi-target failure can roll back successful earlier profiles too; review the locked CLI before any separately approved override. Do not weaken defaults.
- Neither rollback restores databases, `/persist`, NAS/user data, disks or secrets, or guarantees a future boot. No blanket rollback-disable recipe is retained.

On failure, stop and wait for rollback. Inspect power/network/console rather than blindly retrying. Preserve old/new access during SSH-changing migrations. If authorized, recover from the console with a previous boot generation or `sudo nixos-rebuild switch --rollback`; service data may still need a separate restore. Keep recovery generations and monitor boot/store capacity.

## Persistence, observability and backups

Follow [impermanence](../../impermanence/SKILL.md). Direct `/persist` contents survive even outside the bind inventory; removing a declaration is not deletion. Every future data consumer needs ownership, migration planning and exact source/mount verification, not an existing directory on tmpfs.

Servers retain bounded persistent journals; Racknerd persists fail2ban state. Bastion keeps monthly tank-only scrub and native property-opt-in snapshots. Scheduled jobs, a mirror and snapshots are not independent backups; review properties, naming/holds, capacity, pruning and recovery before changing maintenance. No shares, monitoring endpoints, application databases, backup automation or garbage collection are implicitly enabled.
