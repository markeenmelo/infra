---
name: deploy
description: Deploy commissioned hosts with deploy-rs (racknerd, then bastion) through the dedicated deploy account, remote builds and rollback. Use for activation, pre-deployment review and recovery after a failed rollout.
---

# Deploy

Policy lives in `modules/deploy.nix`. The explicit `fleet:deploy` devenv task references `scripts/devenv/deploy.sh`; it validates inputs and a clean tree, then calls the pinned deploy-rs. It does not prove commissioning or readiness. Reading this authorizes no remote contact: deployment and reboot each need explicit authorization for the exact targets and mode in the current task.

## Before contact

1. Confirm the exact targets and mode. Both servers now permit normal switching; Bastion's access/home transition was accepted by the operator. Default deployment activates now without rebooting. Task input `boot=true` stages the next-boot configuration with deploy-rs's `--boot`, then separately requests a reboot after each successful deployment. It is not a dry run.
2. deploy-rs manages only racknerd and bastion, in that order. ThinkPad is not in `deploy.nodes` and carries no `deploy` account — `.#thinkpad` is not a valid target.
3. Confirm the revision is the one reviewed. The task refuses a dirty or uncommitted tree (`git status --short` must be empty), including untracked files; it never stages or commits.
4. For every target run `nix eval --no-update-lock-file --json .#deploy.nodes.HOST --apply 'n: removeAttrs n ["profiles"]'`, confirm the endpoint and settings, then `nix build --no-update-lock-file --no-link .#nixosConfigurations.HOST.config.system.build.toplevel`.
5. Confirm by hand what the task does not probe: the `deploy` login works, its sudo is noninteractive, root activation can use `/run/deploy-rs`, and the host lists `deploy` in Nix `trusted-users`. Before using `boot=true`, confirm the exact reboot sudo rule is already active.
6. Evaluation proves neither installed access, credentials, capacity nor backups.

## Account

The approved account is `deploy`: locked password, restricted SSH keys, private `/var/lib/deploy`, explicit Nix trust and passwordless activation/confirmation sudo plus the exact `/run/current-system/sw/bin/systemctl reboot` command. That combination is **root-equivalent**, not a sandbox. Root SSH and agent forwarding stay off; `wheel` keeps its password requirement.

A new account cannot bootstrap itself. For the first access-changing rollout, provision and test the new login through independently verified console or existing access, keep the old path until the new one is proven, and preserve machine SSH and age identities plus off-host recovery.

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

Rollback restores a system profile. It does not restore data, `/persist`, disks, databases or secrets, and it does not guarantee the next boot. On failure, stop and let rollback finish; inspect console, power and network instead of retrying blindly. A disk operation is never deployment repair.

Afterwards verify the intended generation, both key logins, sudo policy, units, network and persistent mounts. Completed boot acceptance remains a separate console/runtime check, even when the task successfully requested reboot.
