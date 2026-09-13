# Operations

Run infrastructure commands from the repository root inside native `devenv shell`; [bootstrap and command migration](development.md) cover the locked CLI. Documentation-only edits use [scoped whitespace/link/status/snippet validation](validation.md#documentation-only-changes), not fleet evaluation/builds. Consult the matching `.agents/skills/` procedure and [research ledger](research.md) before changing dependency-sensitive APIs.

## Input updates

Never substitute `system.stateVersion` for the current supported release. It is a state migration boundary, not an update knob.

1. Start with a reviewed clean working tree and save the current lock:
   ```sh
   before=$(mktemp)
   cp flake.lock "$before"
   ```
2. Research affected upstream changes. For stable, determine whether the current branch is still supported and review stable/security/service release notes. For unstable, inspect significant NixOS/module/driver changes since the locked revision, plus native devenv and OpenTofu/provider changes: desktop and developer tools share `nixpkgs`, and incompatible provider/version constraints intentionally fail the offline gate. For full updates, include unstable Home Manager, the pinned Zen recipe, disko, impermanence, sops-nix, deploy-rs and flake-parts issues. Desktop updates must review the actual target-packaged Hyprland/Noctalia APIs and new profile behavior, not legacy Noctalia Shell 4.x instructions. Home Manager, Zen and sops-nix are normal default-branch flakes pinned only in `flake.lock`; advance them with a scoped `nix flake update <input>` after research.
3. Choose **one** update scope:
   ```sh
   nix flake update nixpkgs-stable
   # OR
   nix flake update nixpkgs
   # OR
   nix flake update
   ```
4. Synchronize the native unstable lock as described in [development locks](development.md#locks-and-architecture) when `nixpkgs` changes. Run `devenv tasks run repo:check-full` for every scope (the fleet is small). Pay special attention to `racknerd`/`bastion` for stable and `thinkpad` for unstable. For commissioned targets build their system closures with `devenv shell build HOST`. No deployment is implied.
5. Review **every** changed lock node:
   ```sh
   jq -n --slurpfile old "$before" --slurpfile new flake.lock '
     ($old[0].nodes + $new[0].nodes | keys[]) as $k |
     select($old[0].nodes[$k].locked != $new[0].nodes[$k].locked) |
     {input: $k, before: $old[0].nodes[$k].locked, after: $new[0].nodes[$k].locked}'
   git diff -- flake.nix flake.lock
   ```
   Targeted updates must not move the other fleet track or unrelated dependency pins. A dependency following stable uses the new stable packages without changing its own source revision; report this too. Commit only the intended update and compatibility fixes with exact before/after revisions.

Inspect locked branch/revision/hash without evaluating a machine:

```sh
jq '.nodes as $n | ["nixpkgs-stable", "nixpkgs"][] as $i |
  {input:$i, original:$n[$n.root.inputs[$i]].original, locked:$n[$n.root.inputs[$i]].locked}' flake.lock
```

Only the unstable desktop uses Home Manager. The input is named `home-manager`, with URL `github:nix-community/home-manager`. Update it independently with `nix flake update home-manager`; validate the unstable desktop/actual ThinkPad configs and all both-track infrastructure checks. Updating unstable Nixpkgs changes HM's packages without moving HM's source revision; stable updates have no HM dependency.

Zen is a normal `zen-browser` flake input with URL `github:youwen5/zen-browser-flake` and an unstable follows link. Both Zen and Home Manager use default-branch URLs; exact revisions live only in `flake.lock`. A scoped Zen update uses `nix flake update zen-browser`, with review of its recipe/wrapper adapter and extension XPI pins. Continue passing the consuming host's `pkgs` into the recipe instead of importing upstream's separately instantiated package outputs. Validation checks input identity, flake status and follows policy, not a hardcoded Zen commit. Pi's extension set is declared directly in its managed `settings.packages` (pinned `npm:` specs, the hash-pinned `pi-review` store path and the RTK hook); update and test them together per [Pi package management](pi.md#package-management), without credentials or provider settings drift. Preserve HM file-collision checks and the isolated Noctalia profile. See [desktop ownership](desktop.md).

Every host uses its track's latest **stock 7.x** kernel. Check kernel EOL/release changes and Bastion's actual `kernelPackages.${boot.zfs.package.kernelModuleAttribute}` derivation. Never use the removed `.zfs` alias, allow broken packages, mix tracks or silently cross the major-version guard. Preserve recovery generations/ESP headroom and arrange boot/pool acceptance separately; a compatible derivation is not a tested boot.

A **stable release migration** changes the numbered stable Nixpkgs URL in `flake.nix` after fresh research, then updates that input; there is no stable HM URL to maintain. Do not automatically jump servers to a new release or bump their stateVersion. Update the dated research record and validate database/service compatibility and restores.

## ThinkPad Nix Helper (nh)

`modules/nh.nix` enables native NixOS `programs.nh` **only on ThinkPad**, using its own `pkgs.nh` (currently 4.4.2). `programs.nh.flake = "/home/marcos/projects/infra"` sets **`NH_FLAKE`** at this Nixpkgs pin. This is the observed checkout path, not a store copy or guessed server path. An explicit installable or `NH_OS_FLAKE` can override it; update the declaration if the checkout moves. Settings take effect during a separately authorized activation, not by editing this repository.

`programs.nh.clean.enable = false`: no nh cleanup service/timer, generation pruning, automatic input updates or rebuild aliases. Keep recovery generations and use the reviewed input-update procedure above. Home Manager is integrated into NixOS; there is no standalone output for `nh home`.

`devenv tasks run repo:check-full` remains canonical for substantive changes and deployment preflight; `devenv shell ready thinkpad` must still pass before a system build. [Current status](hosts.md#current-status) records exported hosts and acceptance. A build-only helper invocation is:

```sh
devenv tasks run repo:check-full
devenv shell ready thinkpad
nh os build --hostname thinkpad --no-update-lock-file
```

**Currently blocked:** the fresh-install branch has no commissioned ThinkPad output. Do not use this build/activation workflow over its running encrypted disk. After separate fresh commissioning, this selects the ThinkPad output. Outstanding maintenance/runtime acceptance is an operator requirement, not an additional enforced nh build gate. Do not bypass validation or input review with helper flags. `nh os switch`, `test`, `boot`, remote target/build options and `nh clean` require their own operation authorization. Smoke tests run only `nh --version` and `nh os build --help`, not rebuilds or activation.

## Deployment and recovery

### Current remote deployment status — 2026-09-13

Both servers have fresh-install/two-boot acceptance and enabled signed deployment outputs; the later minimal-server candidate is not activated. See [authoritative current status](hosts.md#current-status). ThinkPad remains unready/local-only and must not receive this fresh layout over its running encrypted installation. The reviewed servers expose disko plans, but **do not run disko or nixos-anywhere for this configuration update**.

The operator will deploy with deploy-rs themselves. It assumes reachable non-root SSH, working password sudo and existing closure trust. Validate host identity, access, space and console recovery before activation. No remote operation is performed by the local validation gate.

### Preflight

1. `devenv tasks run repo:check-full`; inspect `devenv tasks run repo:inventory` and `nix eval --json .#deploymentPlan | jq .`.
2. Use `bash modules/fleet/ready.sh HOST deploy` for deployment-specific readiness, or `devenv shell ready HOST` for build readiness. `devenv shell deploy-host HOST` performs the deploy-specific preflight automatically. The SSH user must be non-root with configured public keys; root is rejected to match the SSH root-login restriction. Keep the system activation `profileUser` as root and verify the chosen elevation path.
3. Confirm the reported revision/actual package source matches the independent host policy. Check a known-good generation and backup/restore status. The persistent SOPS identity, intended ciphertext/recipients and early-decryption path must be verified, alongside signing keys; pure checks cannot verify them. SOPS creates runtime password files during activation, not during builds. Follow the [secret procedure](../secrets/README.md).
4. Verify host-key fingerprint, reachability, free `/nix`/`/boot` space, admin login, sudo/doas policy and Nix closure trust. Do not put credentials in flake arguments, source files or shell history. For signed transport, securely set `LOCAL_KEY` to the existing signing-key path; the target must already trust its public key.
5. Keep an independent console and an existing SSH session open for sensitive changes. Consider `--dry-activate` only after authorization: it still contacts/copies to the target and is **not** a purely local check.

### Commands (these really deploy)

```sh
# First select Racknerd's existing private signer as LOCAL_KEY, off-target.
devenv shell deploy-host racknerd

# For Bastion's home-persistence removal, use the boot-only procedure below,
# not a live deploy-host switch.
```

`deploy .` means all **eligible** nodes, not every fleet identity. ThinkPad remains local-only. Deploy these servers **one at a time** with their distinct signers: one `LOCAL_KEY` does not satisfy both targets' public trust. Do not use `deploy-fleet` or `--targets` for this transition. An offline machine is not a reason to remove rollback safeguards.

deploy-rs builds from the locked input. Its default own checks may evaluate/build **all** eligible nodes even when a subset is selected; our `devenv tasks run repo:check-full` also covers the full fleet. This costs more once real machines are commissioned but does not contact them. `remoteBuild` moves the build to the target only when selected; review resources and trust before enabling it.

### Minimal-server transition — 2026-09-13

**Operator-run only; not an installation.** Review the exact candidate on the controller, retain console/old-generation recovery, and privately save anything wanted from Bastion's currently persisted home. Its old `/persist/home/marcos` is retained, not erased or securely deleted. Prefer **boot-only Bastion deployment followed by a planned reboot**: removing the live home bind underneath active shells/agents is unnecessary. Do not force-unmount it or run old acceptance helpers (they can reboot).

The MacBook is the operator-selected, reportedly prepared controller. This repository exports its toolbox/checks only for `x86_64-linux`, not Darwin. Run the canonical gate/readiness/builds in the existing Linux environment, or a separately prepared Linux builder/checkout controlled from the MacBook; keep the exact candidate/locks synchronized. Native macOS use of `deploy` requires the compatible locked deploy-rs CLI and a working `x86_64-linux` build route. `nix run .#devenv`/`.#deploy-rs` are not native Darwin outputs, and `--remote-build` is not an automatic workaround for these root-only-trust targets. No MacBook/builder was audited here; do not install a workspace on either minimal server or add trusted users to bypass this requirement.

Local preflight, inside the supported `devenv shell`:

```sh
devenv tasks run repo:fmt
devenv tasks run repo:check-full
bash modules/fleet/ready.sh bastion deploy
bash modules/fleet/ready.sh racknerd deploy
devenv shell build bastion
devenv shell build racknerd
```

The new candidate authorizes both reviewed administrator keys for `marcos` on every host: `SHA256:rU2P8TOXVjL3ymRg1OyxA0YgxKrp9PBKKD56FhXWu/I` and `SHA256:mZ36DV6PDIt0lmhfqrO9qKKxQSlmQ7iMiH1NNYWvDRI`. For these initial server deployments, the controller must still have the first key's private half: both running servers accept that historically installed key until activation. Do not assume the newly added second key can bootstrap its own deployment. Use independently verified **installed**, not installer, host keys. Do not accept a changed key just to deploy:

| Target | Installed ED25519 fingerprint | Required signer name |
|---|---|---|
| `marcos@192.168.2.2` | `SHA256:DiSj7jMXKQJchfzBDBBX8VsTSErDkDgLAdjsBPN3Ie4` | `bastion-deploy-20260912` |
| `marcos@72.11.150.242` | `SHA256:A0QspM00bMLwnPwevkEvB9q8TTfjS4ewlFWfN0ss0B0` | `racknerd-deploy-20260912` |

From that reviewed checkout/controller with the pinned `deploy` available, run in **Bash**. Prompts below request private-key **paths**, never key contents; sudo's password prompt belongs only in the private terminal. SSH uses the configured identity/known-host files, disables the agent/forwarding, and preserves liveness limits because `--ssh-opts` replaces node options:

```bash
set -euo pipefail
SSH_OPTIONS='-p 22 -o StrictHostKeyChecking=yes -o UpdateHostKeys=no -o IdentityAgent=none -o IdentitiesOnly=yes -o ForwardAgent=no -o ClearAllForwardings=yes -o ConnectTimeout=15 -o ServerAliveInterval=10 -o ServerAliveCountMax=3'
read -r -p 'Existing Bastion signing-key path: ' BASTION_SIGNER
test -f "$BASTION_SIGNER" && test -r "$BASTION_SIGNER" || exit 1
LOCAL_KEY="$BASTION_SIGNER" deploy .#bastion --boot --interactive --checksigs \
  --ssh-opts "$SSH_OPTIONS" -- --no-update-lock-file
```

Wait for successful deploy completion before the **separate planned reboot**. `--boot` updates the system profile/boot selection but does not remove the running home bind; its reachability confirmation cannot validate the next boot. When ready, use the existing private SSH/console session to run `sudo systemctl reboot`. Reconnect with the same strict pin; privately verify separate `marcos` logins using both reviewed private keys, then verify the intended `/run/current-system`, no failed units, `/home/marcos` on tmpfs with `marcos:users 0700`, working password sudo, retained identity/service binds and unchanged eight `tank` legacy mounts/health. If boot fails, use the previous Limine generation/console; do not repeat deployment blindly. Do not read secret contents or delete old backing data for acceptance.

After Bastion is accepted, deploy Racknerd separately (same Bash session/options), which removes the editor without changing its already-ephemeral home:

```bash
read -r -p 'Existing Racknerd signing-key path: ' RACKNERD_SIGNER
test -f "$RACKNERD_SIGNER" && test -r "$RACKNERD_SIGNER" || exit 1
LOCAL_KEY="$RACKNERD_SIGNER" deploy .#racknerd --interactive --checksigs \
  --ssh-opts "$SSH_OPTIONS" -- --no-update-lock-file
```

Privately verify separate `marcos` logins with both reviewed keys, then confirm the new generation, unchanged strict SSH/password sudo, no failed units and healthy network/firewall/fail2ban. Neither command changes keys, clears Nix generations, prunes `/persist`, deploys ThinkPad or authorizes its wipe. Old store generations may retain removed tools for rollback. No automatic/magic rollback override is needed.

### Rollback semantics

- `autoRollback = true`: return to the previous profile if activation fails.
- `magicRollback = true`: target rolls back if the client does not confirm post-activation reachability in time. Default confirmation is 60 seconds, activation 300 seconds, with SSH liveness limits.
- In a multi-target invocation, successful earlier profiles can also roll back if a later one fails. The verified override `--rollback-succeeded false` changes that policy; use only deliberately.
- None of these revert database migrations, `/persist`, user/NAS data, partition changes or secrets. None guarantee the next reboot succeeds.

When a host is unreachable, stop. Check power/network/rescue console and wait for pending rollback to settle. Do not retry blindly, disable magic rollback, delete known_hosts entries, or format disks. An SSH fingerprint change must be explained before accepting a new key.

**SSH-changing deployments:** prefer a two-stage migration keeping old and new access working until separately tested. Port/IP changes can cause the confirmation connection to fail and trigger rollback. If an access-breaking change is unavoidable, use a console and a planned maintenance window. Only with explicit authorization might an operator use:

```sh
deploy .#racknerd --magic-rollback false -- --no-update-lock-file
```

This disables the reachability safety mechanism; automatic activation-failure rollback is still on. `deploy .#racknerd --auto-rollback false` is a separate, usually inappropriate override. Neither belongs in repository defaults. Check the **locked** `deploy --help` before relying on flag syntax after updates. `--test` activates without setting boot defaults; `--boot` updates boot selection without a live switch, and therefore requires a reboot plan.

From a real target's console, a standard manual generation recovery is:

```sh
sudo nixos-rebuild switch --rollback
```

Or select the previous generation in its bootloader. Inspect the result before reconnecting/deploying again. Do not prune old generations automatically; maintain a deliberate retention policy and monitor disk space. If a service has migrated on-disk formats, restoring its data may be necessary even after reverting NixOS.

## Persistence, observability and backups

`devenv tasks run repo:inventory` lists declared persistent paths. New services must define ownership/mode and state requirements next to their configuration, ideally with a mount dependency so they cannot write into an ephemeral placeholder when their durable filesystem is missing. State outside declared paths is lost at reboot. State deliberately written directly into `/persist` remains even if not listed in the bind-mount inventory.

Neither minimal-server candidate persists an admin home. Bastion's accepted installed generation still does until the [boot-only transition](#minimal-server-transition--2026-09-13); removal leaves its private backing data on OS `/persist`. Administration/recovery belongs on the operator's MacBook or independent controller, not a new server role.

Servers retain a bounded journal; interactive hosts use volatile logs. No monitoring endpoint, exporter, application database, NAS share, unattended backup or automatic garbage collection is silently enabled. Racknerd's fail2ban database persists; Bastion retains monthly `tank` scrub and now declares standard native opt-in snapshots in its unactivated candidate. Review actual dataset properties, snapshot capacity/naming/pruning and recovery before activation; the service can select no datasets if none opt in. Neither scrub nor snapshots are an independent backup. Before production services, add separately reviewed backup/restore and observability features with runtime credentials and tested failure handling. A Btrfs subvolume and a persistent root policy are **not backups**. Removing an impermanence declaration leaves backing data; inspect it, do not automatically delete it.

Recommended future work, not implemented here: complete per-host SOPS identity/credential provisioning and acceptance, VPN access, ThinkPad's hardware-verified NVIDIA/Samsung HDR/VRR profile and desktop runtime acceptance, service-specific backups with restore exercises, and QEMU/real-hardware reboot tests. Thinkpad's existing LUKS encryption is preserved, not newly provisioned. Add only what the fleet actually needs.
