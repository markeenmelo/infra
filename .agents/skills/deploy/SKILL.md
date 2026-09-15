---
name: deploy
description: Deploy commissioned hosts with deploy-rs (racknerd, then bastion) through the dedicated deploy account, remote builds and rollback. Use for activation, pre-deployment review and recovery after a failed rollout.
---

# Deploy

Policy lives in `modules/deploy.nix`. The explicit `fleet:deploy` devenv task references `scripts/devenv/deploy.sh`; it validates inputs and a clean tree, then calls the pinned deploy-rs. It does not prove commissioning or readiness. Reading this authorizes no remote contact: deployment and reboot each need explicit authorization for the exact targets and mode in the current task.

## Before contact

1. Confirm the exact targets and mode. Both servers now permit normal switching; Bastion's access/home transition was accepted by the operator. Default deployment activates now without rebooting. Task input `boot=true` stages the next-boot configuration with deploy-rs's `--boot`, then separately requests a reboot after each successful deployment. It is not a dry run.
2. deploy-rs manages only racknerd and bastion, in that order. ThinkPad is not in `deploy.nodes` and carries no `deploy` account — `.#thinkpad` is not a valid target. Bastion uses its Tailscale MagicDNS endpoint with `HostKeyAlias=bastion`: the operator needs an already-authorized tailnet connection and the independently verified OpenSSH host key recorded under `bastion`. This is ordinary OpenSSH, not Tailscale SSH. Preserve LAN recovery access; Racknerd keeps its public endpoint.
3. Confirm the revision is the one reviewed. The task refuses a dirty or uncommitted tree (`git status --short` must be empty), including untracked files; it never stages or commits.
4. For every target run `nix eval --no-update-lock-file --json .#deploy.nodes.HOST --apply 'n: removeAttrs n ["profiles"]'`, confirm the endpoint and settings, then `nix build --no-update-lock-file --no-link .#nixosConfigurations.HOST.config.system.build.toplevel`.
5. Confirm by hand what the task does not probe: the `deploy` login works, its sudo is noninteractive, root activation can use `/run/deploy-rs`, and the host lists `deploy` in Nix `trusted-users`. For normal activation, `command -v rm` in the deploy SSH session must resolve to `/run/current-system/sw/bin/rm`, the exact command named in the NOPASSWD canary rule. Also inspect `readlink -f "$(command -v rm)"`, but do not treat equal resolved files/inodes as proof of a sudo match: pinned sudo 1.9.17p2 compares canonicalized **parent directories** before file identity. A rule for `${pkgs.coreutils-full}/bin/rm` does not match the system PATH symlink, even when both reach the same binary. Use the real deployment wrapper's canary path from the reviewed output as `$canary`, and inspect `sudo -n -ll -u root rm "$canary"` (listing only; never run `rm` as a preflight). The matching entry must show `Options: !authenticate` and the canary-restricted command, not the wheel `ALL` entry. A successful short `sudo -n -l COMMAND` alone is insufficient: the password-requiring wheel rule can allow the same command. Before using `boot=true`, confirm the exact reboot sudo rule is already active.
6. Verify the current system profile has an executable `deploy-rs-activate` and refers to the intended known-good system. A fresh installer-created profile does not; complete the commissioning procedure below before deployment. A mismatch between `/run/current-system` and the system represented by the profile is a recovery blocker, not permission to retry.
7. Evaluation proves neither installed access, credentials, capacity nor backups.

## Account

The approved account is `deploy`: locked password, restricted SSH keys, private `/var/lib/deploy`, explicit Nix trust and passwordless activation/confirmation sudo plus the exact `/run/current-system/sw/bin/systemctl reboot` command. That combination is **root-equivalent**, not a sandbox. Root SSH and agent forwarding stay off; `wheel` keeps its password requirement.

A new account cannot bootstrap itself. For the first access-changing rollout, provision and test the new login through independently verified console or existing access, keep the old path until the new one is proven, and preserve machine SSH and age identities plus off-host recovery.

## First-deployment rollback commissioning

At this pin, rollback runs `nix-env --rollback`, deletes the failed generation, then executes `/nix/var/nix/profiles/system/deploy-rs-activate`. An ordinary nixos-anywhere installation has only the native `bin/switch-to-configuration`; enabling rollback flags does not add the missing helper.

This is a manual, separately authorized commissioning operation, not an extra task or a reason to enable root SSH, broaden sudo or disable rollback. A locked root login does not prevent the existing `deploy` account from using its approved `activate-rs` sudo rule.

### Existing deploy access

If verified SSH and the approved helper still work, review a wrapper built from the exact revision of the healthy **currently active system**. Its evaluated toplevel must match `/run/current-system`, and its native switch program must resolve to that system's program. Check noninteractive helper access with `sudo -n -u root "$baseline/activate-rs" --help`; `$baseline` is the reviewed wrapper store path. Never substitute an arbitrary root command or use Nix trust to bypass missing sudo permissions.

With explicit baseline-staging authorization, run through that existing deploy connection:

```sh
sudo -n -u root "$baseline/activate-rs" activate "$baseline" \
  --profile-path /nix/var/nix/profiles/system \
  --temp-path /run/deploy-rs --confirm-timeout 60 \
  --magic-rollback --auto-rollback --boot
```

This updates the profile **and bootloader**, without switching runtime or rebooting. Do not use the task's `boot=true` for this intermediate step: that would also reboot. Verify the profile now points to the baseline wrapper, both helpers are executable, runtime is unchanged, and the original generation remains. Inspect generation symlinks directly; even `nix-env --list-generations` can require a root-owned lock. Stop on failure: until this step succeeds, its own rollback still encounters the original missing-helper problem.

Then run only the separately authorized deployment. Boot mode needs the existing reboot sudo rule, skips live confirmation, and applies a corrected canary rule only after reboot. Verify the resulting boot and policy; this does not test normal confirmation or a real rollback.

### Root-console fallback

If the approved deployment access cannot perform commissioning, use independently verified root console access. If no usable root shell is available, stop; rescue boot or mounting needs separate authorization:

1. Establish a healthy, explicitly accepted baseline. Record the resolved `/run/current-system`, `/run/booted-system` and `/nix/var/nix/profiles/system` paths, and preserve existing generations. If runtime and profile disagree after a failure, stop. With separate recovery authorization, use the selected known-good system's native `bin/switch-to-configuration switch` from the root console, then verify runtime, profile and boot configuration agree on the intended next-boot system. The running kernel can remain older until a separately authorized reboot. Commission the narrow sudo correction through the same console if installed policy cannot pass the preflight above.
2. From a clean full checkout of the exact baseline revision, evaluate its `nixosConfigurations.HOST.config.system.build.toplevel` and build its `deploy.nodes.HOST.profiles.system.path`. The evaluated toplevel must equal the verified baseline store path; building a wrapper from the newest revision is not sufficient. Inspect the wrapper's `deploy-rs-activate` and confirm its `bin/switch-to-configuration` resolves to the baseline's native switch program. Do not execute either helper during review.
3. Make that reviewed wrapper closure available on the target through the existing strictly verified connection, retaining signature checks. At the authorized root console, recheck the baseline and set only the system profile to that exact wrapper with `nix-env --profile /nix/var/nix/profiles/system --set "$wrapper"`. Here `$wrapper` is the reviewed store path, never a guessed path. This creates a generation; it does not activate, update the bootloader or reboot. Do not delete the installer generation or edit the store.
4. Verify the profile resolves to the reviewed wrapper, both activation helpers are executable, its native switch program is still the baseline's, and `/run/current-system` is unchanged. Repeat the account/canary preflight before a separately authorized normal task deployment. Subsequent failures can then return to an activatable baseline rather than the bare installer closure.

Builds and these metadata checks do not demonstrate a real rollback. A deliberate rollback exercise needs its own explicit activation authorization and console recovery.

## Running it

Enter the locked x86_64-linux shell with `nix run --no-update-lock-file .#devenv -- shell`, then explicitly invoke:

```sh
devenv tasks run fleet:deploy --input target=racknerd
devenv tasks run fleet:deploy --input target=bastion
devenv tasks run fleet:deploy --input target=servers
devenv tasks run fleet:deploy --input target=servers --input boot=true
```

`servers` means Racknerd then Bastion. Native devenv task inputs use `--input boot=true`, not a task-level `--boot`; the input must be a JSON boolean. Missing/unknown inputs and targets fail before remote contact. No fleet task runs on shell entry, and successful runs are not cached or retried by the wrapper.

Normal group deployment uses one ordered multi-target invocation, equivalent to:

```sh
nix run --no-update-lock-file .#deploy-rs -- \
  --checksigs --targets .#racknerd .#bastion -- --no-update-lock-file
```

The final `--` passes Nix options to deploy-rs's internal commands; `--no-update-lock-file` is not a deploy-rs flag at this pin. Keep explicit ordered targets, signature checks, remote builds, batch/strict SSH, noninteractive sudo and rollback. Never pass `--skip-checks`, relax SSH or disable rollback. Remote builds may overlap, but activations follow the explicit order. Direct deploy-rs invocation does not enforce the task's clean-tree/input guards.

With `boot=true`, the task instead runs one `--boot` deployment at a time, then requests `sudo -n /run/current-system/sw/bin/systemctl reboot` through that node's configured endpoint, deploy user and SSH options. Order: Racknerd deploy → Racknerd reboot request → Bastion deploy → Bastion reboot request. Any failure stops the group. An SSH disconnect during reboot can make the request outcome unknown; inspect the console, do not retry blindly. The task does not wait for or prove completed boot; run it from an operator machine that will remain available.

**Bootstrap:** the reboot sudo permission needs a separately authorized normal rollout or commissioning through existing access first. `--boot` does not activate new sudoers rules, so the first boot-only deployment cannot grant itself permission to reboot. A successful reboot request is not boot acceptance.

For a local negative-input smoke check (expected nonzero exits with usage/target errors, no private-file access or remote contact):

```sh
if devenv tasks run fleet:install; then echo 'Unexpected install success' >&2; exit 1; fi
if devenv tasks run fleet:deploy --input target=invalid; then echo 'Unexpected deploy success' >&2; exit 1; fi
```

## Rollback and recovery

`autoRollback` re-activates the previous profile when activation fails. `magicRollback` waits for the deployer to confirm reachability after activation and reverts if it never arrives — which is why an SSH-affecting change can never be deployed without independent console access. A failure late in a normal multi-target run can roll back hosts that already succeeded. The per-host boot/reboot mode uses separate invocations: rollback remains enabled within each deployment, but does not undo an earlier server that has already been rebooted.

Rollback restores a system profile. It does not restore data, `/persist`, disks, databases or secrets, and it does not guarantee the next boot. On failure, stop and let rollback finish; inspect console, power and network instead of retrying blindly. Check the resolved current system and profile yourself: deploy-rs can print “rolled back” even when reactivation failed. A restored profile link does not prove restored runtime or bootloader state. Use the recovery/commissioning procedures above for that mixed state, not an unreviewed reboot. A disk operation is never deployment repair.

Afterwards verify the intended generation, both key logins, sudo policy, units, network and persistent mounts. Completed boot acceptance remains a separate console/runtime check, even when the task successfully requested reboot.
